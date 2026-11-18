/* 
4.1 pcie_dl_tx.sv — TLP transmitter
Function: Accepts TL TLP stream, assigns sequence number, sends packet data through TX LCRC, writes the completed
TLP into replay storage, and transmits it. New TLP acceptance is blocked when the replay buffer cannot accept another
complete packet.
Inputs: clk, rst_n; TL stream (data/valid/sop/eop/keep); replay-buffer full/ready; replay request and replay stream;
LCRC input ready/result valid; PHY ready.
Outputs: TL ready; TX-LCRC stream and start; replay-buffer packet write stream with sequence metadata; PHY
TLP stream; tx_busy.
Implementation notes: Internal state: NEXT_TRANSMIT_SEQ (12-bit), packet assembly state, sequence allocation state,
packet transmission state. A replayed packet must retain its original sequence number and LCRC; do not rebuild it as a new
TLP
*/



module pcie_dl_tx #(
    parameter int DATA_W       = 32,       // Packet stream width
    parameter int SEQ_W        = 12,       // PCIe TLP sequence-number width
    parameter int MAX_PKT_DW   = 1024,     // Maximum input packet size in DWORDs
    parameter int REPLAY_DEPTH = 8         // Replay-buffer depth (managed by buffer)
) (
    input  logic clk,                      // Data Link Layer clock
    input  logic rst_n,                    // Active-low asynchronous reset

    // Transaction Layer input stream
    input  logic [DATA_W-1:0] tl_tx_data,
    input  logic              tl_tx_valid,
    output logic              tl_tx_ready,
    input  logic              tl_tx_sop,
    input  logic              tl_tx_eop,
    input  logic [3:0]        tl_tx_keep,

    // Replay-buffer write interface
    input  logic              replay_buf_full,
    input  logic              replay_buf_ready,

    output logic [DATA_W-1:0] buf_wr_data,
    output logic              buf_wr_valid,
    input  logic              buf_wr_ready,
    output logic              buf_wr_sop,
    output logic              buf_wr_eop,
    output logic [3:0]        buf_wr_keep,
    output logic [SEQ_W-1:0]  buf_wr_seq_num,

    // TX LCRC generator interface
    output logic              lcrc_start,
    output logic [DATA_W-1:0] lcrc_data,
    output logic              lcrc_valid,
    input  logic              lcrc_ready,
    output logic              lcrc_sop,
    output logic              lcrc_eop,
    output logic [3:0]        lcrc_keep,

    input  logic [31:0]       lcrc_result,
    input  logic              lcrc_result_valid,
    output logic              lcrc_result_ready,

    // Replay-buffer read interface
    output logic              buf_rd_start,
    output logic [SEQ_W-1:0]  buf_rd_seq_num,
    input logic               buf_rd_found,

    input  logic [DATA_W-1:0] replay_data,
    input  logic              replay_valid,
    output logic              replay_ready,
    input  logic              replay_sop,
    input  logic              replay_eop,
    input  logic [3:0]        replay_keep,
    input  logic              replay_done,

    // Replay controller interface
    input  logic              replay_req,
    input  logic [SEQ_W-1:0]  replay_req_seq,
    output logic              replay_req_ready,

    // PHY transmit interface
    output logic [DATA_W-1:0] phy_tx_data,
    output logic              phy_tx_valid,
    input  logic              phy_tx_ready,
    output logic              phy_tx_sop,
    output logic              phy_tx_eop,
    output logic [3:0]        phy_tx_keep,
    output logic              phy_tx_is_tlp,

    // Status
    output logic              tx_busy,
    output logic              tx_error
);

    // ------------------------------------------------------------
    // Local parameters and FSM states
    // ------------------------------------------------------------

    // Number of bytes that can be stored from one input TLP.
    localparam int MAX_PKT_BYTES = MAX_PKT_DW * 4;

    // Extra storage is needed for the 2-byte sequence prefix
    // and the 4-byte LCRC.
    localparam int MAX_PROTECTED_BYTES = MAX_PKT_BYTES + 8;

    // Widths of the word-index and byte-count registers.
    localparam int WORD_IDX_W = $clog2(MAX_PKT_DW + 3);
    localparam int BYTE_CNT_W = $clog2(MAX_PROTECTED_BYTES + 1);

    // FSM state encoding.
    typedef enum logic [3:0] {
        S_IDLE,             // Wait for a new TLP or replay request  0
        S_CAPTURE,          // Capture remaining TL TLP beats        1
        S_FORMAT,           // Insert the sequence-number prefix     2
        S_LCRC_START,       // Start the LCRC generator              3
        S_LCRC_FEED,        // Send prefixed TLP to LCRC generator   4
        S_WAIT_LCRC,        // Wait for the LCRC result              5
        S_APPEND_LCRC,      // Append the LCRC bytes                 6
        S_BUF_WRITE,        // Write the complete protected TLP      7
        S_READ_START,       // Request a packet from replay buffer   8
        S_PHY_TX            // Transmit the packet read from buffer  9
    } state_t;

    state_t ps;             // Present FSM state

    // ------------------------------------------------------------
    // Handshake signals
    // ------------------------------------------------------------

    // A TL beat is accepted only when valid and ready are both high.
    wire tl_handshake = tl_tx_valid && tl_tx_ready;

    // A replay-buffer write beat is accepted on this handshake.
    wire buf_wr_handshake = buf_wr_valid && buf_wr_ready;

    // An LCRC input beat is accepted on this handshake.
    wire lcrc_handshake = lcrc_valid && lcrc_ready;

    // The LCRC result is accepted on this handshake.
    wire lcrc_result_handshake =
        lcrc_result_valid && lcrc_result_ready;

    // A replay-buffer output beat is accepted on this handshake.
    wire replay_handshake = replay_valid && replay_ready;

    // A replay request is accepted on this handshake.
    wire replay_req_handshake =
        replay_req && replay_req_ready;

    // A PHY output beat is accepted on this handshake.
    wire phy_tx_handshake = phy_tx_valid && phy_tx_ready;

    // ------------------------------------------------------------
    // Sequence-number registers
    // ------------------------------------------------------------

    // Sequence number assigned to the next newly accepted TLP.
    logic [SEQ_W-1:0] next_transmit_seq;

    // Sequence number assigned to the TLP currently being processed.
    logic [SEQ_W-1:0] current_seq;

    // ------------------------------------------------------------
    // Raw TLP capture storage
    // ------------------------------------------------------------

    // Store only valid TLP bytes, in increasing byte-lane order.
    logic [7:0] raw_byte_mem [0:MAX_PKT_BYTES-1];

    // Number of valid payload bytes captured so far.
    logic [BYTE_CNT_W-1:0] payload_byte_count;

    // ------------------------------------------------------------
    // Protected TLP storage
    // ------------------------------------------------------------

    // Stores the prefixed TLP DWORDs used by the LCRC generator.
    logic [DATA_W-1:0] protected_mem [0:MAX_PKT_DW+1];

    // KEEP information for each prefixed TLP DWORD.
    logic [3:0] protected_keep_mem [0:MAX_PKT_DW+1];

    // Number of bytes in the prefixed TLP, excluding LCRC.
    logic [BYTE_CNT_W-1:0] formatted_byte_count;

    // Number of DWORDs in the prefixed TLP.
    logic [WORD_IDX_W-1:0] formatted_word_count;

    // Index used while generating the prefixed TLP.
    logic [WORD_IDX_W-1:0] format_index;

    // ------------------------------------------------------------
    // LCRC and final-packet registers
    // ------------------------------------------------------------

    // Registered LCRC result.
    logic [31:0] lcrc_result_q;

    // Final packet byte storage, including sequence prefix and LCRC.
    logic [7:0] final_byte_mem [0:MAX_PROTECTED_BYTES-1];

    // Total number of bytes in the final protected packet.
    logic [BYTE_CNT_W-1:0] final_byte_count;

    // Number of DWORDs in the final protected packet.
    logic [WORD_IDX_W-1:0] final_word_count;

    // Index used while feeding the LCRC generator.
    logic [WORD_IDX_W-1:0] lcrc_index;

    // Index used while writing the final packet into the replay buffer.
    logic [WORD_IDX_W-1:0] write_index;

    logic [BYTE_CNT_W-1:0] copy_index;

    // ------------------------------------------------------------
    // Replay and read-control registers
    // ------------------------------------------------------------

    // Sequence number requested from the replay buffer.
    logic [SEQ_W-1:0] read_seq_q;

    // Indicates that a replay request, rather than a new TLP,
    // initiated the current buffer read.
    logic read_is_replay_q;

    // ------------------------------------------------------------
    // Temporary variables used by the capture and formatting logic
    // ------------------------------------------------------------

    integer i;              // Loop variable
    integer byte_offset;    // Number of valid bytes in the current beat
    integer keep_count;     // Number of asserted KEEP bits

    // Combinationally generated formatted DWORD and KEEP.
    logic [DATA_W-1:0] format_word;
    logic [3:0]        format_keep;

    // Combinationally generated final DWORD and KEEP.
    logic [DATA_W-1:0] final_word;
    logic [3:0]        final_keep;

    // ------------------------------------------------------------
    // Sequence-number assignment
    // ------------------------------------------------------------

    // A new sequence number is assigned when the first TL beat
    // of a new TLP is accepted.
    //
    // The counter naturally wraps modulo 2**SEQ_W.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            next_transmit_seq <= '0;
            current_seq       <= '0;
        end
        else if ((ps == S_IDLE) &&
                 tl_handshake &&
                 tl_tx_sop) begin

            current_seq       <= next_transmit_seq;
            next_transmit_seq <= next_transmit_seq + 1'b1;
        end
    end

    // ------------------------------------------------------------
    // Count valid bytes in the current TL input beat
    // ------------------------------------------------------------

    // This implementation expects KEEP to contain contiguous
    // valid bytes starting from lane zero.
    always_comb begin
        keep_count = 0;

        for (int k = 0; k < 4; k++) begin
            if (tl_tx_keep[k])
                keep_count = keep_count + 1;
        end
    end

    // ------------------------------------------------------------
    // Capture the input TLP
    // ------------------------------------------------------------

    // Capture the first beat in S_IDLE and subsequent beats in
    // S_CAPTURE. This avoids losing the first beat during the
    // transition from IDLE to CAPTURE.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            payload_byte_count <= '0;
            tx_error           <= 1'b0;
        end
        else begin

            // Clear the error flag when a new packet is accepted.
            if ((ps == S_IDLE) && tl_handshake && tl_tx_sop)
                tx_error <= 1'b0;

            // Capture the first beat of a new TLP.
            if ((ps == S_IDLE) &&
                tl_handshake &&
                tl_tx_sop &&
                !replay_buf_full &&
                replay_buf_ready) begin

                byte_offset = 0;

                // Store each valid byte from the first beat.
                for (i = 0; i < 4; i++) begin
                    if (tl_tx_keep[i]) begin
                        raw_byte_mem[byte_offset] <=
                            tl_tx_data[i*8 +: 8];

                        byte_offset = byte_offset + 1;
                    end
                end

                // Record the number of captured payload bytes.
                payload_byte_count <= keep_count;
            end

            // Capture all following beats of the same TLP.
            else if ((ps == S_CAPTURE) &&
                     tl_handshake) begin

                byte_offset = payload_byte_count;

                // Store each valid byte at the next free location.
                for (i = 0; i < 4; i++) begin
                    if (tl_tx_keep[i]) begin

                        if (byte_offset < MAX_PKT_BYTES) begin
                            raw_byte_mem[byte_offset] <=
                                tl_tx_data[i*8 +: 8];

                            byte_offset = byte_offset + 1;
                        end
                        else begin
                            tx_error <= 1'b1;
                        end
                    end
                end

                // Update the total payload byte count.
                payload_byte_count <= byte_offset;
            end
        end
    end

    // ------------------------------------------------------------
    // Create the sequence-prefixed TLP DWORD
    // ------------------------------------------------------------

    // Byte mapping used by this educational implementation:
    //
    // Byte 0 = sequence number bits [7:0]
    // Byte 1 = reserved bits [3:0] + sequence number bits [11:8]
    // Byte 2 onward = original TLP payload bytes
    //
    // Verify this byte mapping against the PCIe 2.0 specification
    // before treating the implementation as wire-format compliant.
    always_comb begin

        format_word = '0;
        format_keep = 4'b0000;

        for (int k = 0; k < 4; k++) begin

            // Absolute byte position in the formatted packet.
            int byte_index;

            byte_index = (format_index * 4) + k;

            if (byte_index < formatted_byte_count) begin

                format_keep[k] = 1'b1;

                if (byte_index == 0 || byte_index == 1)
                    format_word[k*8 +: 8] = 8'h00;
                else if (byte_index == 2)
                    format_word[k*8 +: 8] = current_seq[7:0];
                else if (byte_index == 3)
                    format_word[k*8 +: 8] = {4'b0000, current_seq[11:8]};
                else
                    format_word[k*8 +: 8] = raw_byte_mem[byte_index-4];
            end
        end
    end

    // ------------------------------------------------------------
    // Generate the final packet DWORD for replay-buffer writing
    // ------------------------------------------------------------

    // The final packet consists of:
    //   1. Sequence-prefixed TLP
    //   2. Four LCRC bytes
    //
    // The LCRC byte ordering here is an implementation convention
    // and must be checked against PCIe 2.0 Table 3-3.
    always_comb begin

        final_word = '0;
        final_keep = 4'b0000;

        for (int k = 0; k < 4; k++) begin

            int byte_index;

            byte_index = (write_index * 4) + k;

            if (byte_index < final_byte_count) begin
                final_keep[k] = 1'b1;

                final_word[k*8 +: 8] =
                    final_byte_mem[byte_index];
            end
        end
    end

    // ------------------------------------------------------------
    // Main FSM and datapath control
    // ------------------------------------------------------------

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            // Reset the FSM.
            ps <= S_IDLE;

            // Reset packet counters and indexes.
            formatted_byte_count <= '0;
            formatted_word_count <= '0;
            final_byte_count     <= '0;
            final_word_count     <= '0;

            format_index <= '0;
            lcrc_index   <= '0;
            write_index  <= '0;
            copy_index   <= '0;

            // Reset LCRC result.
            lcrc_result_q <= '0;

            // Reset replay information.
            read_seq_q       <= '0;
            read_is_replay_q <= 1'b0;
        end

        else begin

            case (ps)

                // ------------------------------------------------
                // IDLE
                // ------------------------------------------------

                S_IDLE: begin

                    // Clear indexes before processing a new packet.
                    format_index <= '0;
                    lcrc_index   <= '0;
                    write_index  <= '0;

                    // A replay request has priority over a new TLP.
                    if (replay_req_handshake) begin

                        // Remember the requested sequence number.
                        read_seq_q <= replay_req_seq;

                        // Mark this read as a replay.
                        read_is_replay_q <= 1'b1;

                        // Start reading the requested packet.
                        ps <= S_READ_START;
                    end

                    // Otherwise accept a new TLP if the buffer
                    // has space and is ready for a new packet.
                    else if (tl_handshake &&
                             tl_tx_sop &&
                             !replay_buf_full &&
                             replay_buf_ready) begin

                        // This is a new packet, not a replay.
                        read_is_replay_q <= 1'b0;

                        // The first beat has already been captured
                        // by the capture logic above.
                        if (tl_tx_eop) begin

                            // Include the two-byte sequence prefix.
                            formatted_byte_count <= keep_count + 4;

                            // Calculate the number of formatted DWORDs.
                            formatted_word_count <=
                                (keep_count + 4 + 3) / 4;

                            // Begin formatting the packet.
                            format_index <= '0;
                            ps <= S_FORMAT;
                        end
                        else begin

                            // More TLP beats must be captured.
                            ps <= S_CAPTURE;
                        end
                    end
                end

                // ------------------------------------------------
                // CAPTURE
                // ------------------------------------------------

                S_CAPTURE: begin

                    // Wait for each remaining TL beat.
                    if (tl_handshake && tl_tx_eop) begin

                        // Add the two-byte sequence prefix.
                        formatted_byte_count <=
                            payload_byte_count + keep_count + 4;

                        // Calculate the number of DWORDs.
                        formatted_word_count <=
                            (payload_byte_count + keep_count + 4 + 3) / 4;

                        // Start formatting from DWORD zero.
                        format_index <= '0;

                        // Move to the formatting state.
                        ps <= S_FORMAT;
                    end
                end

                // ------------------------------------------------
                // FORMAT
                // ------------------------------------------------

                S_FORMAT: begin

                    // Store one formatted DWORD per clock cycle.
                    protected_mem[format_index] <= format_word;

                    // Store the corresponding byte-valid information.
                    protected_keep_mem[format_index] <= format_keep;

                    // Continue until every formatted DWORD is stored.
                    if (format_index == formatted_word_count - 1'b1) begin

                        // Start the LCRC generator.
                        ps <= S_LCRC_START;

                        // Start feeding from the first DWORD.
                        lcrc_index <= '0;
                    end
                    else begin

                        // Advance to the next DWORD.
                        format_index <= format_index + 1'b1;
                    end
                end

                // ------------------------------------------------
                // LCRC START
                // ------------------------------------------------

                S_LCRC_START: begin

                    // lcrc_start is asserted combinationally in this
                    // state for one clock cycle.
                    //
                    // The LCRC generator must accept this start pulse.
                    lcrc_index <= '0;

                    // Begin sending the prefixed TLP.
                    ps <= S_LCRC_FEED;
                end

                // ------------------------------------------------
                // LCRC FEED
                // ------------------------------------------------

                S_LCRC_FEED: begin

                    // Advance only when the LCRC block accepts a beat.
                    if (lcrc_handshake) begin

                        if (lcrc_index == formatted_word_count - 1'b1) begin

                            // All TLP DWORDs have been sent to LCRC.
                            ps <= S_WAIT_LCRC;
                        end
                        else begin

                            // Send the next DWORD.
                            lcrc_index <= lcrc_index + 1'b1;
                        end
                    end
                end

                // ------------------------------------------------
                // WAIT FOR LCRC
                // ------------------------------------------------

                S_WAIT_LCRC: begin

                    // Capture the LCRC result only when valid and ready.
                    if (lcrc_result_handshake) begin

                        // Store the result.
                        lcrc_result_q <= lcrc_result;
                        copy_index <= '0;
                        // Move to the append stage.
                        ps <= S_APPEND_LCRC;
                    end
                end

                // ------------------------------------------------
                // APPEND LCRC
                // ------------------------------------------------

                S_APPEND_LCRC: begin

    // Copy the prefixed TLP bytes, followed by the four LCRC bytes.
    if (copy_index < formatted_byte_count) begin

        // Copy sequence-prefix bytes.
        if (copy_index == 0 || copy_index == 1)
            final_byte_mem[copy_index] <= 8'h00;
        else if (copy_index == 2)
            final_byte_mem[copy_index] <= current_seq[7:0];
        else if (copy_index == 3)
            final_byte_mem[copy_index] <= {4'b0000, current_seq[11:8]};
        else
            final_byte_mem[copy_index] <= raw_byte_mem[copy_index-4];
            copy_index <= copy_index + 1'b1;
    end
    else begin

        // Append LCRC bytes one byte per clock.
        case (copy_index - formatted_byte_count)

            0: final_byte_mem[copy_index] <= lcrc_result_q[7:0];

            1: final_byte_mem[copy_index] <= lcrc_result_q[15:8];

            2: final_byte_mem[copy_index] <= lcrc_result_q[23:16];

            3: final_byte_mem[copy_index] <= lcrc_result_q[31:24];

            default: final_byte_mem[copy_index] <= 8'h00;

        endcase

        if (copy_index == formatted_byte_count + 3) begin

            // Total packet size includes four LCRC bytes.
            final_byte_count <= formatted_byte_count + 4;

            // Calculate total DWORD count.
            final_word_count <=
                (formatted_byte_count + 4 + 3) / 4;

            // Start replay-buffer writing.
            write_index <= '0;
            copy_index  <= '0;
            ps <= S_BUF_WRITE;

        end
        else begin
            copy_index <= copy_index + 1'b1;
        end

    end
end
                // ------------------------------------------------
                // REPLAY BUFFER WRITE
                // ------------------------------------------------

                S_BUF_WRITE: begin

                    // Advance only when the buffer accepts a DWORD.
                    if (buf_wr_handshake) begin

                        if (write_index == final_word_count - 1'b1) begin

                            // The complete protected TLP is stored.
                            // Request an initial transmission read.
                            read_seq_q <= current_seq;
                            read_is_replay_q <= 1'b0;

                            ps <= S_READ_START;
                        end
                        else begin

                            // Write the next DWORD.
                            write_index <= write_index + 1'b1;
                        end
                    end
                end

                // ------------------------------------------------
                // READ START
                // ------------------------------------------------

                S_READ_START: begin
                    if (buf_rd_found)
                        ps <= S_PHY_TX;
                    else begin
                        tx_error <= 1'b1;
                        ps <= S_IDLE;
                    end
                end

                // ------------------------------------------------
                // PHY TRANSMIT
                // ------------------------------------------------

                S_PHY_TX: begin

                    // Wait until the final replay-buffer beat has
                    // actually been accepted by the PHY.
                    if (replay_handshake && replay_eop) begin

                        // The current packet transmission is complete.
                        ps <= S_IDLE;
                    end
                end

                // ------------------------------------------------
                // Default recovery
                // ------------------------------------------------

                default: begin
                    ps <= S_IDLE;
                    tx_error <= 1'b1;
                end

            endcase
        end
    end

    // ------------------------------------------------------------
    // Combinational output control
    // ------------------------------------------------------------

    always_comb begin

        // Default values prevent unintended latches.
        tl_tx_ready        = 1'b0;

        buf_wr_data        = '0;
        buf_wr_valid       = 1'b0;
        buf_wr_sop         = 1'b0;
        buf_wr_eop         = 1'b0;
        buf_wr_keep        = 4'b0000;
        buf_wr_seq_num     = current_seq;

        lcrc_start         = 1'b0;
        lcrc_data          = '0;
        lcrc_valid         = 1'b0;
        lcrc_sop           = 1'b0;
        lcrc_eop           = 1'b0;
        lcrc_keep          = 4'b0000;
        lcrc_result_ready  = 1'b0;

        buf_rd_start       = 1'b0;
        buf_rd_seq_num     = read_seq_q;

        replay_ready       = 1'b0;

        phy_tx_data        = '0;
        phy_tx_valid       = 1'b0;
        phy_tx_sop         = 1'b0;
        phy_tx_eop         = 1'b0;
        phy_tx_keep        = 4'b0000;
        phy_tx_is_tlp      = 1'b1;

        replay_req_ready   = 1'b0;

        // Busy is asserted in every state other than IDLE.
        tx_busy = (ps != S_IDLE);

        case (ps)

            // ----------------------------------------------------
            // IDLE outputs
            // ----------------------------------------------------

            S_IDLE: begin

                // Accept a new TLP only if the buffer can accept it.
                tl_tx_ready = !replay_buf_full && replay_buf_ready;

                // Accept a replay request while idle.
                replay_req_ready = 1'b1;
            end

            // ----------------------------------------------------
            // CAPTURE outputs
            // ----------------------------------------------------

            S_CAPTURE: begin

                // Continue accepting the remaining TLP beats.
                tl_tx_ready = 1'b1;
            end

            // ----------------------------------------------------
            // LCRC START outputs
            // ----------------------------------------------------

            S_LCRC_START: begin

                // Pulse the LCRC generator start signal.
                lcrc_start = 1'b1;
            end

            // ----------------------------------------------------
            // LCRC FEED outputs
            // ----------------------------------------------------

            S_LCRC_FEED: begin

                // Send the current formatted DWORD to the LCRC block.
                lcrc_data  = protected_mem[lcrc_index];
                lcrc_valid = 1'b1;

                // Identify the first DWORD.
                lcrc_sop = (lcrc_index == 0);

                // Identify the last DWORD.
                lcrc_eop =
                    (lcrc_index == formatted_word_count - 1'b1);

                // Send the corresponding byte-valid mask.
                lcrc_keep = protected_keep_mem[lcrc_index];
            end

            // ----------------------------------------------------
            // WAIT LCRC outputs
            // ----------------------------------------------------

            S_WAIT_LCRC: begin

                // Accept the LCRC result in this state.
                lcrc_result_ready = 1'b1;
            end

            // ----------------------------------------------------
            // REPLAY BUFFER WRITE outputs
            // ----------------------------------------------------

            S_BUF_WRITE: begin

                // Present the current final packet DWORD.
                buf_wr_data  = final_word;
                buf_wr_valid = 1'b1;

                // Mark the first DWORD.
                buf_wr_sop = (write_index == 0);

                // Mark the final DWORD.
                buf_wr_eop =
                    (write_index == final_word_count - 1'b1);

                // Indicate valid bytes in this DWORD.
                buf_wr_keep = final_keep;

                // Store the sequence number with every beat.
                buf_wr_seq_num = current_seq;
            end

            // ----------------------------------------------------
            // REPLAY BUFFER READ START outputs
            // ----------------------------------------------------

            S_READ_START: begin

                // Request a read of the selected sequence number.
                buf_rd_start = 1'b1;

                // Supply the requested sequence number.
                buf_rd_seq_num = read_seq_q;
            end

            // ----------------------------------------------------
            // PHY TRANSMIT outputs
            // ----------------------------------------------------

            S_PHY_TX: begin

                // Apply backpressure from the PHY to the replay buffer.
                replay_ready = phy_tx_ready;

                // Forward the replay-buffer stream to the PHY.
                phy_tx_data  = replay_data;
                phy_tx_valid = replay_valid;

                // Forward packet boundary information.
                phy_tx_sop  = replay_sop;
                phy_tx_eop  = replay_eop;
                phy_tx_keep = replay_keep;

                // This path transmits TLPs.
                phy_tx_is_tlp = 1'b1;
            end

            default: begin
                // All outputs remain at their safe default values.
            end

        endcase
    end

endmodule
