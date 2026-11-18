/*
4.7 pcie_dllp_ctrl.sv — ACK/NAK DLLP codec
Function: Builds outgoing ACK/NAK DLLPs from RX requests and decodes incoming ACK/NAK DLLPs from PHY RX.
Routes decoded sequence information to replay control.
Inputs: Inputs: clk, rst_n; ACK/NAK requests and sequence values; PHY RX packet stream and packet type.
Outputs: Outputs: DLLP TX stream and ready; decoded ACK valid/sequence; decoded NAK valid/sequence; dllp_error.
Implementation notes: DLLPs have their own format and CRC. Do not use the TLP LCRC engine as the DLLP CRC
implementation. Implement the PCIe 2.0 ACK/NAK DLLP fields and CRC according to the specification.
*/
module pcie_dllp_ctrl (
    input  logic        clk,
    input  logic        rst_n,

    // DLLP transmit request
    input  logic        tx_req_valid,
    input  logic        tx_req_nak,
    input  logic [11:0] tx_req_seq,
    output logic        tx_req_ready,

    // DLLP transmit stream
    output logic [31:0] tx_data,
    output logic [3:0]  tx_keep,
    output logic        tx_valid,
    output logic        tx_sop,
    output logic        tx_eop,
    input  logic        tx_ready,

    // DLLP receive stream
    input  logic [31:0] rx_data,
    input  logic [3:0]  rx_keep,
    input  logic        rx_valid,
    input  logic        rx_sop,
    input  logic        rx_eop,

    // Decoded ACK/NAK
    output logic        ack_valid,
    output logic [11:0] ack_seq,
    output logic        nak_valid,
    output logic [11:0] nak_seq,
    output logic        rx_crc_error
);

    localparam logic [15:0] DLLP_POLY = 16'hD008;

    typedef enum logic [1:0] {
        TX_IDLE,
        TX_BEAT0,
        TX_BEAT1
    } tx_state_t;

    tx_state_t tx_state;

    logic [31:0] tx_header;
    logic [15:0] tx_crc;

    logic [31:0] rx_header;
    logic [15:0] rx_crc;
    logic [15:0] rx_crc_calc;

    logic rx_header_valid;

    integer i;
    integer j;

    // ------------------------------------------------
    // CRC-16 calculation
    // Reflected polynomial: D008
    // Initial value: FFFF
    // ------------------------------------------------
    function automatic logic [15:0] dllp_crc16(
        input logic [31:0] data
    );
        logic [15:0] crc;
        integer byte_idx;
        integer bit_idx;
        begin
            crc = 16'hFFFF;

            for (byte_idx = 0; byte_idx < 4; byte_idx++) begin
                for (bit_idx = 0; bit_idx < 8; bit_idx++) begin
                    if (crc[0] ^ data[byte_idx*8 + bit_idx])
                        crc = (crc >> 1) ^ DLLP_POLY;
                    else
                        crc = crc >> 1;
                end
            end

            dllp_crc16 = ~crc;
        end
    endfunction

    // ------------------------------------------------
    // Transmit logic
    // ------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state <= TX_IDLE;
            tx_header <= '0;
            tx_crc <= '0;
        end
        else begin
            case (tx_state)

                TX_IDLE: begin
                    if (tx_req_valid && tx_req_ready) begin
                        tx_header <= {
                            tx_req_seq,
                            4'b0000,
                            8'b0000_0000
                        };

                        if (tx_req_nak)
                            tx_header[7:0] <= 8'h10;
                        else
                            tx_header[7:0] <= 8'h00;

                        tx_crc <= dllp_crc16({
                            tx_req_seq,
                            4'b0000,
                            tx_req_nak ? 8'h10 : 8'h00
                        });

                        tx_state <= TX_BEAT0;
                    end
                end

                TX_BEAT0: begin
                    if (tx_valid && tx_ready)
                        tx_state <= TX_BEAT1;
                end

                TX_BEAT1: begin
                    if (tx_valid && tx_ready)
                        tx_state <= TX_IDLE;
                end

                default: tx_state <= TX_IDLE;

            endcase
        end
    end

    assign tx_req_ready = (tx_state == TX_IDLE);

    always_comb begin
        tx_data  = '0;
        tx_keep  = 4'b0000;
        tx_valid = 1'b0;
        tx_sop   = 1'b0;
        tx_eop   = 1'b0;

        case (tx_state)

            TX_BEAT0: begin
                tx_data  = tx_header;
                tx_keep  = 4'b1111;
                tx_valid = 1'b1;
                tx_sop   = 1'b1;
            end

            TX_BEAT1: begin
                tx_data  = {16'b0, tx_crc};
                tx_keep  = 4'b0011;
                tx_valid = 1'b1;
                tx_eop   = 1'b1;
            end

            default: begin
            end

        endcase
    end

    // ------------------------------------------------
    // Receive logic
    // ------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_header <= '0;
            rx_crc <= '0;
            rx_crc_calc <= '0;
            rx_header_valid <= 1'b0;

            ack_valid <= 1'b0;
            ack_seq <= '0;
            nak_valid <= 1'b0;
            nak_seq <= '0;
            rx_crc_error <= 1'b0;
        end
        else begin
            ack_valid <= 1'b0;
            nak_valid <= 1'b0;
            rx_crc_error <= 1'b0;

            if (rx_valid && rx_sop) begin
                rx_header <= rx_data;
                rx_header_valid <= 1'b1;
            end

            if (rx_valid && rx_eop && rx_header_valid) begin
                rx_crc <= rx_data[15:0];
                rx_crc_calc <= dllp_crc16(rx_header);

                if (dllp_crc16(rx_header) == rx_data[15:0]) begin
                    if (rx_header[7:0] == 8'h00) begin
                        ack_valid <= 1'b1;
                        ack_seq <= rx_header[27:16];
                    end
                    else if (rx_header[7:0] == 8'h10) begin
                        nak_valid <= 1'b1;
                        nak_seq <= rx_header[27:16];
                    end
                end
                else begin
                    rx_crc_error <= 1'b1;
                end

                rx_header_valid <= 1'b0;
            end
        end
    end

endmodule
