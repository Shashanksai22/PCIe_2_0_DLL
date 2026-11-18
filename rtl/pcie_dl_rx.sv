/*
4.3 pcie_dl_rx.sv — TLP receiver
Function: Accepts packet stream from the PHY boundary, distinguishes TLP from DLLP, coordinates LCRC validation,
checks sequence state, strips Data Link fields, and forwards only acceptable TLPs to TL.
Inputs: Inputs: clk, rst_n; PHY RX stream and packet type; RX LCRC done/match; TL RX ready.
Outputs: Outputs: PHY RX ready; RX-LCRC input stream/start; TL RX stream; ACK request and ACK sequence
information; NAK request and NAK sequence information; rx_error.
Implementation notes: Internal state: NEXT_RCV_SEQ (12-bit), packet assembly/parse state. Handle a correct new TLP,
a duplicate TLP, and an invalid TLP as distinct cases. A duplicate must not be forwarded to TL again.
*/

module pcie_dl_rx #(
    parameter int SEQ_W = 12
)(
    input logic clk,
    input logic rst_n,

    // Input from pcie_lcrc_rx
    input logic [31:0] in_data,
    input logic [3:0] in_keep,
    input logic in_valid,
    output logic in_ready,
    input logic in_sop,
    input logic in_eop,

    // Verified TLP output
    output logic [31:0] tlp_data,
    output logic [3:0] tlp_keep,
    output logic tlp_valid,
    input logic tlp_ready,
    output logic tlp_sop,
    output logic tlp_eop,

    // ACK/NAK request to DLLP controller
    output logic ack_req,
    output logic [SEQ_W-1:0] ack_seq,
    output logic nak_req,
    output logic [SEQ_W-1:0] nak_seq,

    input logic lcrc_error,

    output logic sequence_error
);

    logic nak_scheduled;

    logic [SEQ_W-1:0] next_rcv_seq;
    logic [SEQ_W-1:0] received_seq;

    logic packet_active;
    logic packet_accepted;
    logic first_tlp_beat;

    logic [31:0] data_reg;
    logic [3:0] keep_reg;
    logic valid_reg;
    logic sop_reg;
    logic eop_reg;

    assign tlp_data  = data_reg;
    assign tlp_keep  = keep_reg;
    assign tlp_valid = valid_reg;
    assign tlp_sop   = sop_reg;
    assign tlp_eop   = eop_reg;

    assign in_ready = !valid_reg || tlp_ready;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            next_rcv_seq <= '0;
            received_seq <= '0;
            packet_active <= 1'b0;
            packet_accepted <= 1'b0;
            first_tlp_beat <= 1'b0;

            data_reg <= '0;
            keep_reg <= '0;
            valid_reg <= 1'b0;
            sop_reg <= 1'b0;
            eop_reg <= 1'b0;

            ack_req <= 1'b0;
            ack_seq <= '0;
            nak_req <= 1'b0;
            nak_seq <= '0;
            sequence_error <= 1'b0;

            nak_scheduled <= 1'b0;
        end
        else begin
            ack_req <= 1'b0;
            nak_req <= 1'b0;
            sequence_error <= 1'b0;

            // [ADDED] Schedule a single NAK DLLP on RX LCRC error until a valid TLP arrives
            if (lcrc_error && !nak_scheduled) begin
                nak_req       <= 1'b1;
                nak_seq       <= next_rcv_seq - 1'b1;
                nak_scheduled <= 1'b1;
            end

            if (valid_reg && tlp_ready)
                valid_reg <= 1'b0;

            if (in_valid && in_ready) begin

                if (in_sop) begin
                    received_seq <= {
                        in_data[27:24],
                        in_data[23:16]
                    };

                    packet_active <= 1'b1;

                    if ({
                        in_data[27:24],
                        in_data[23:16]
                    } == next_rcv_seq) begin
                        packet_accepted <= 1'b1;
                        first_tlp_beat <= 1'b1;
                    end
                    else if ({
                        in_data[27:24],
                        in_data[23:16]
                    } == (next_rcv_seq - 1'b1)) begin
                        // Duplicate TLP: discard and ACK again.
                        packet_accepted <= 1'b0;
                        ack_req <= 1'b1;
                        ack_seq <= next_rcv_seq - 1'b1;
                    end
                    else begin
                        packet_accepted <= 1'b0;
                        // [UPDATED] Only send NAK if not already scheduled
                        if (!nak_scheduled) begin
                            nak_req       <= 1'b1;
                            nak_seq       <= next_rcv_seq - 1'b1;
                            nak_scheduled <= 1'b1;
                        end
                        sequence_error <= 1'b1;
                    end
                end

                // Skip in_sop (Sequence Number beat); forward only payload/header beats
                if (!in_sop && packet_accepted) begin
                    data_reg       <= in_data;
                    keep_reg       <= in_keep;
                    valid_reg      <= 1'b1;
                    sop_reg        <= first_tlp_beat;
                    eop_reg        <= in_eop;
                    first_tlp_beat <= 1'b0;
                end

                if (in_eop && packet_active) begin
                    first_tlp_beat <= 1'b0;
                    if (packet_accepted ||
                        (in_sop &&
                        ({in_data[27:24], in_data[23:16]} == next_rcv_seq))) begin
                        next_rcv_seq <= next_rcv_seq + 1'b1;
                        ack_req <= 1'b1;
                        ack_seq <= next_rcv_seq;
                        nak_scheduled <= 1'b0; // [ADDED] Clear NAK_SCHEDULED on valid TLP completion
                    end

                    packet_active <= 1'b0;
                    packet_accepted <= 1'b0;
                end
            end
        end
    end

endmodule
