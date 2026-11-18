/*
4.5 pcie_replay_buffer.sv — eight-entry TLP retry storage
Function: Stores complete transmitted TLPs until acknowledged and supplies the original packet stream for replay.
Inputs: Inputs: clk, rst_n; packet write stream and sequence number; ACK commit plus ACK sequence; replay start plus
requested sequence.
Outputs: Outputs: write ready/full/empty; replay data/valid/sop/eop/keep; replay sequence metadata; replay_last and
replay_done; oldest/newest outstanding sequence status.
Implementation notes: Use eight packet slots, each with packet words, length/KEEP metadata and sequence number.
Support wraparound-aware sequence ordering. ACK release and replay selection must use protocol sequence semantics,
not ordinary integer comparisons alone.
*/


module pcie_replay_buffer #(
    parameter int DATA_W       = 32,
    parameter int SEQ_W        = 12,
    parameter int MAX_PKT_DW   = 1024,
    parameter int REPLAY_DEPTH = 8
)(
    input  logic                  clk,
    input  logic                  rst_n,

    // Buffer status
    output logic                  buf_full,
    output logic                  buf_ready,

    // Write interface
    input  logic [DATA_W-1:0]     buf_wr_data,
    input  logic                  buf_wr_valid,
    output logic                  buf_wr_ready,
    input  logic                  buf_wr_sop,
    input  logic                  buf_wr_eop,
    input  logic [DATA_W/8-1:0]   buf_wr_keep,
    input  logic [SEQ_W-1:0]      buf_wr_seq_num,

    // Read request
    input  logic                  buf_rd_start,
    input  logic [SEQ_W-1:0]      buf_rd_seq_num,
    output logic                  buf_rd_found,

    // Replay output
    output logic [DATA_W-1:0]     replay_data,
    output logic                  replay_valid,
    input  logic                  replay_ready,
    output logic                  replay_sop,
    output logic                  replay_eop,
    output logic [DATA_W/8-1:0]   replay_keep,
    output logic                  replay_done,

    // Release acknowledged packet slot
    input  logic                  buf_free_valid,
    input  logic [SEQ_W-1:0]      buf_free_seq_num
);

    localparam int KEEP_W = DATA_W/8;
    localparam int PTR_W =
        (MAX_PKT_DW <= 1) ? 1 : $clog2(MAX_PKT_DW);

    logic [DATA_W-1:0] mem
        [0:REPLAY_DEPTH-1][0:MAX_PKT_DW-1];

    logic [KEEP_W-1:0] keep_mem
        [0:REPLAY_DEPTH-1][0:MAX_PKT_DW-1];

    logic [SEQ_W-1:0] slot_seq
        [0:REPLAY_DEPTH-1];

    logic [REPLAY_DEPTH-1:0] slot_valid;

    logic [PTR_W:0] packet_count
        [0:REPLAY_DEPTH-1];

    logic [PTR_W-1:0] wr_index;
    logic [PTR_W-1:0] rd_index;

    logic [PTR_W-1:0] rd_slot_q;

    logic [SEQ_W-1:0] wr_seq;
    logic [PTR_W-1:0] wr_slot;
    logic [PTR_W-1:0] rd_slot;

    logic wr_active;
    logic rd_active;

    integer i;
    integer j;

    // Sequence number maps to a buffer slot.
    always_comb begin
        wr_slot = buf_wr_seq_num % REPLAY_DEPTH;
    end

    // Buffer status and write readiness.
    always_comb begin
        buf_full  = &slot_valid;
        buf_ready = !buf_full;

        if (wr_active)
            buf_wr_ready = 1'b1;
        else
            buf_wr_ready = !slot_valid[wr_slot];
    end

    // Find requested sequence number.
    always_comb begin
        buf_rd_found = 1'b0;
        rd_slot      = '0;

        for (integer k = 0; k < REPLAY_DEPTH; k++) begin
            if (slot_valid[k] &&
                slot_seq[k] == buf_rd_seq_num) begin
                buf_rd_found = 1'b1;
                rd_slot = k;
            end
        end
    end

    // Replay output.
    always_comb begin
        replay_valid = rd_active;
        replay_data  = '0;
        replay_keep  = '0;
        replay_sop   = 1'b0;
        replay_eop   = 1'b0;

        if (rd_active) begin
            replay_data = mem[rd_slot_q][rd_index];
            replay_keep = keep_mem[rd_slot_q][rd_index];
            replay_sop  = (rd_index == 0);
            replay_eop  = (rd_index == packet_count[rd_slot_q]-1'b1);
        end
    end

    // Write and replay control.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            slot_valid <= '0;
            wr_index   <= '0;
            rd_index   <= '0;
            wr_seq     <= '0;
            wr_active  <= 1'b0;
            rd_active  <= 1'b0;
            replay_done <= 1'b0;
            rd_slot_q <= '0;

            for (i = 0; i < REPLAY_DEPTH; i++) begin
                slot_seq[i]     <= '0;
                packet_count[i] <= '0;
            end
        end
        else begin
            replay_done <= 1'b0;

            // Release an acknowledged packet.
            if (buf_free_valid) begin
                for (i = 0; i < REPLAY_DEPTH; i++) begin
                    if (slot_valid[i] &&
                        slot_seq[i] == buf_free_seq_num)
                        slot_valid[i] <= 1'b0;
                end
            end

            // Accept a new packet beat.
            if (buf_wr_valid && buf_wr_ready) begin

                if (buf_wr_sop) begin
                    wr_active <= 1'b1;
                    wr_index  <= '0;
                    wr_seq    <= buf_wr_seq_num;

                    mem[wr_slot][0]      <= buf_wr_data;
                    keep_mem[wr_slot][0] <= buf_wr_keep;
                    slot_seq[wr_slot]    <= buf_wr_seq_num;
                    slot_valid[wr_slot]  <= 1'b1;

                    if (buf_wr_eop) begin
                        packet_count[wr_slot] <= 1;
                        wr_active <= 1'b0;
                    end
                    else begin
                        wr_index <= 1;
                    end
                end
                else if (wr_active) begin
                    mem[wr_seq % REPLAY_DEPTH][wr_index]
                        <= buf_wr_data;

                    keep_mem[wr_seq % REPLAY_DEPTH][wr_index]
                        <= buf_wr_keep;

                    if (buf_wr_eop) begin
                        packet_count[wr_seq % REPLAY_DEPTH]
                            <= wr_index + 1'b1;
                        wr_active <= 1'b0;
                    end
                    else begin
                        wr_index <= wr_index + 1'b1;
                    end
                end
            end

            // Start reading a stored packet.
            if (buf_rd_start && !rd_active && buf_rd_found) begin
                rd_active <= 1'b1;
                rd_index  <= '0;
                rd_slot_q <= rd_slot;
            end

            // Replay beat handshake.
            if (rd_active && replay_ready) begin
                if (rd_index == packet_count[rd_slot_q]-1'b1) begin
                    rd_active <= 1'b0;
                    replay_done <= 1'b1;
                end
                else begin
                    rd_index <= rd_index + 1'b1;
                end
            end
        end
    end

endmodule

