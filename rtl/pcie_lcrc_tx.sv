/*
4.2 pcie_lcrc_tx.sv — TLP LCRC generator
Function: Calculates the PCIe 2.0 TLP LCRC over the specification-defined protected fields. Returns a 32-bit LCRC result
with a valid/ready completion handshake.
Inputs: Inputs: clk, rst_n, start; data/valid/sop/eop/keep stream; result_ready.
Outputs: Outputs: input ready; lcrc[31:0]; lcrc_valid.
Implementation notes: The TX controller appends the resulting LCRC to the TLP. Confirm polynomial, initial value,
reflection/bit order, final XOR, covered fields, and byte order against the PCIe 2.0 specification. Do not assume a generic
CRC-32 implementation is equivalent.
*/


module pcie_lcrc_tx (
    input  logic        clk,
    input  logic        rst_n,

    // Control
    input  logic        lcrc_start,

    // Input stream
    input  logic [31:0] lcrc_data,
    input  logic        lcrc_valid,
    output logic        lcrc_ready,
    input  logic        lcrc_sop,
    input  logic        lcrc_eop,
    input  logic [3:0]  lcrc_keep,

    // CRC result
    output logic [31:0] lcrc_result,
    output logic        lcrc_result_valid,
    input  logic        lcrc_result_ready
);

    localparam logic [31:0] CRC_POLY = 32'hEDB88320;
    // Reflected form of PCIe polynomial 04C11DB7.

    logic [31:0] crc_reg;
    logic [31:0] crc_next;
    logic        active;

    integer lane;
    integer bit_idx;

    // Calculate CRC for the current input beat.
    always_comb begin
        crc_next = crc_reg;

        for (lane = 0; lane < 4; lane = lane + 1) begin
            if (lcrc_keep[lane]) begin
                for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                    if (crc_next[0] ^ lcrc_data[lane*8 + bit_idx])
                        crc_next = (crc_next >> 1) ^ CRC_POLY;
                    else
                        crc_next = crc_next >> 1;
                end
            end
        end
    end

    // CRC control and result generation.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            crc_reg          <= 32'hFFFFFFFF;
            lcrc_result      <= 32'b0;
            lcrc_result_valid <= 1'b0;
            active           <= 1'b0;
        end
        else begin

            // Start a new packet CRC calculation.
            if (lcrc_start) begin
                crc_reg           <= 32'hFFFFFFFF;
                lcrc_result_valid <= 1'b0;
                active            <= 1'b1;
            end

            // Accept input data.
            else if (active && lcrc_valid && lcrc_ready) begin
                crc_reg <= crc_next;

                // Last beat: complement and publish CRC.
                if (lcrc_eop) begin
                    lcrc_result       <= ~crc_next;
                    lcrc_result_valid <= 1'b1;
                    active            <= 1'b0;
                end
            end

            // Result accepted by downstream logic.
            if (lcrc_result_valid && lcrc_result_ready)
                lcrc_result_valid <= 1'b0;
        end
    end

    assign lcrc_ready = active && !lcrc_result_valid;

endmodule
