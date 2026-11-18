/*
4.6 pcie_replay_ctrl.sv — ACK/NAK and timeout controller
Function: Validates received ACK/NAK sequence information, commits valid ACK progress to the replay buffer, and
initiates replay after a valid NAK or replay timeout.
Inputs: Inputs: clk, rst_n; ACK valid/sequence; NAK valid/sequence; oldest/newest outstanding sequence;
outstanding_valid; replay_done.
Outputs: Outputs: ACK commit/sequence; replay_start/replay_start_seq; replay_active; replay_timeout; protocol_error.
Implementation notes: Timer value is a configurable simulation parameter for the educational implementation. Do not
present an arbitrary counter value as the PCIe-specified timeout. Avoid overlapping/conflicting replay requests.
*/

module pcie_replay_ctrl #(
    parameter int SEQ_W = 12,
    parameter int REPLAY_DEPTH = 8,
    parameter int REPLAY_TIMEOUT_CYCLES = 1024
)(
    input  logic                 clk,
    input  logic                 rst_n,

    // Transmitted TLP tracking
    input  logic                 tx_tlp_valid,
    input  logic [SEQ_W-1:0]     tx_tlp_seq,

    // Received ACK / NAK
    input  logic                 ack_valid,
    input  logic [SEQ_W-1:0]     ack_seq,

    input  logic                 nak_valid,
    input  logic [SEQ_W-1:0]     nak_seq,

    // Replay buffer interface
    output logic                 replay_req,
    output logic [SEQ_W-1:0]     replay_req_seq,
    input  logic                 replay_req_ready,
    input  logic                 replay_done,

    // Release acknowledged packet
    output logic                 buf_free_valid,
    output logic [SEQ_W-1:0]     buf_free_seq
);

    localparam int PTR_W =
        (REPLAY_DEPTH <= 1) ? 1 : $clog2(REPLAY_DEPTH);

    localparam int COUNT_W = $clog2(REPLAY_DEPTH + 1);

    localparam int TIMER_W =
        (REPLAY_TIMEOUT_CYCLES <= 1) ? 1 :
        $clog2(REPLAY_TIMEOUT_CYCLES + 1);

    typedef enum logic [2:0] {
        IDLE,
        ACK_RELEASE,
        REPLAY_REQUEST,
        REPLAY_WAIT
    } state_t;

    state_t state;

    // Outstanding TLP queue
    logic [SEQ_W-1:0] outstanding [0:REPLAY_DEPTH-1];

    logic [COUNT_W-1:0] outstanding_count;
    logic [COUNT_W-1:0] ack_remove_count;
    logic [COUNT_W-1:0] ack_pending_count;

    logic [PTR_W-1:0] replay_index;

    // Replay timer
    logic [TIMER_W-1:0] timer_count;

    // ACK and NAK search
    logic ack_found;
    logic nak_found;
    logic [PTR_W-1:0] nak_index;

    integer i;

    // Find cumulative ACK and NAK positions
    always_comb begin
        ack_found       = 1'b0;
        ack_remove_count = '0;

        nak_found = 1'b0;
        nak_index = '0;

        for (integer k = 0; k < REPLAY_DEPTH; k++) begin

            if ((k < outstanding_count) &&
                !ack_found &&
                (outstanding[k] == ack_seq)) begin

                ack_found = 1'b1;
                ack_remove_count = k + 1;
            end

            if ((k < outstanding_count) &&
                !nak_found &&
                (outstanding[k] == (nak_seq + 1'b1))) begin

                nak_found = 1'b1;
                nak_index = k[PTR_W-1:0];
            end
        end
    end

    // Replay request
    always_comb begin
        replay_req = (state == REPLAY_REQUEST);
        replay_req_seq = '0;

        if (state == REPLAY_REQUEST)
            replay_req_seq = outstanding[replay_index];
    end

    // Controller and timer
    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin
            state              <= IDLE;
            outstanding_count <= '0;
            ack_pending_count  <= '0;
            replay_index       <= '0;
            timer_count        <= '0;

            buf_free_valid <= 1'b0;
            buf_free_seq   <= '0;

            for (i = 0; i < REPLAY_DEPTH; i++)
                outstanding[i] <= '0;
        end
        else begin

            buf_free_valid <= 1'b0;

            case (state)

                // --------------------------------
                IDLE: begin

                    // Timer runs while TLPs are outstanding
                    if (outstanding_count != 0) begin

                        if (timer_count >= REPLAY_TIMEOUT_CYCLES - 1) begin
                            timer_count  <= '0;
                            replay_index <= '0;
                            state        <= REPLAY_REQUEST;
                        end
                        else begin
                            timer_count <= timer_count + 1'b1;
                        end
                    end
                    else begin
                        timer_count <= '0;
                    end

                    // Cumulative ACK
                    if (ack_valid && ack_found) begin

                        ack_pending_count <= ack_remove_count;
                        timer_count <= '0;
                        state <= ACK_RELEASE;

                    end

                    // NAK: replay from nak_seq + 1
                    else if (nak_valid && nak_found &&
                             outstanding_count != 0) begin

                        replay_index <= nak_index;
                        timer_count  <= '0;
                        state        <= REPLAY_REQUEST;

                    end

                    // Record transmitted TLP
                    else if (tx_tlp_valid &&
                             outstanding_count < REPLAY_DEPTH) begin

                        outstanding[outstanding_count] <= tx_tlp_seq;
                        outstanding_count <= outstanding_count + 1'b1;
                    end
                end

                // --------------------------------
                // Release acknowledged entries
                ACK_RELEASE: begin
                    if (outstanding_count != 0) begin
                        // Release the oldest acknowledged sequence
                        buf_free_valid <= 1'b1;
                        buf_free_seq   <= outstanding[0];

                        // Shift remaining entries toward index 0
                        for (int j = 0; j < REPLAY_DEPTH-1; j++) begin
                            if (j < outstanding_count - 1)
                                outstanding[j] <= outstanding[j+1];
                        end

                        // Clear the now-unused last entry
                        outstanding[outstanding_count - 1'b1] <= '0;

                        outstanding_count <= outstanding_count - 1'b1;
                        ack_pending_count <= ack_pending_count - 1'b1;

                        if (ack_pending_count == 1)
                            state <= IDLE;
                    end
                    else begin
                        state <= IDLE;
                    end
                end

                // --------------------------------
                // Request replay packet
                REPLAY_REQUEST: begin

                    if (replay_req_ready)
                        state <= REPLAY_WAIT;

                end

                // --------------------------------
                // Wait for replay packet completion
                REPLAY_WAIT: begin

                    if (replay_done) begin

                        if (replay_index + 1'b1 < outstanding_count) begin
                            replay_index <= replay_index + 1'b1;
                            state <= REPLAY_REQUEST;
                        end
                        else begin
                            timer_count <= '0;
                            state <= IDLE;
                        end

                    end
                end

                default: state <= IDLE;

            endcase
        end
    end

endmodule
