module pcie_lcrc_rx #(
    parameter int DATA_W = 32,
    parameter int MAX_PKT_DW = 1024
)(
    input  logic clk,
    input  logic rst_n,

    input  logic [DATA_W-1:0] rx_data,
    input  logic [3:0] rx_keep,
    input  logic rx_valid,
    output logic rx_ready,
    input  logic rx_sop,
    input  logic rx_eop,

    output logic [DATA_W-1:0] out_data,
    output logic [3:0] out_keep,
    output logic out_valid,
    input  logic out_ready,
    output logic out_sop,
    output logic out_eop,

    output logic crc_error,
    output logic packet_done
);

    logic [31:0] packet_mem [0:MAX_PKT_DW-1];
    logic [3:0]  keep_mem   [0:MAX_PKT_DW-1];

    integer packet_count;
    integer out_index;

    logic collecting;
    logic sending;
    logic packet_good;

    logic [31:0] running_crc;
    logic [31:0] calculated_crc;
    logic [31:0] received_crc;

    // Synthesizable 1-DWORD (32-bit) incremental CRC-32 step with constant loop bounds
    function automatic logic [31:0] crc32_word_step(
        input logic [31:0] crc_in,
        input logic [31:0] word_data,
        input logic [3:0]  word_keep
    );
        logic [31:0] crc;
        integer lane_idx;
        integer bit_idx;
        begin
            crc = crc_in;
            for (lane_idx = 0; lane_idx < 4; lane_idx++) begin
                if (word_keep[lane_idx]) begin
                    for (bit_idx = 0; bit_idx < 8; bit_idx++) begin
                        if (crc[0] ^ word_data[lane_idx*8 + bit_idx])
                            crc = (crc >> 1) ^ 32'hEDB8_8320;
                        else
                            crc = crc >> 1;
                    end
                end
            end
            crc32_word_step = crc;
        end
    endfunction

    assign rx_ready  = !sending;

    assign out_valid = sending;
    assign out_data  = packet_mem[out_index];
    assign out_keep  = keep_mem[out_index];
    assign out_sop   = (out_index == 0);
    assign out_eop   = (out_index == packet_count - 2);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            collecting     <= 1'b0;
            sending        <= 1'b0;
            packet_count   <= 0;
            out_index      <= 0;
            packet_good    <= 1'b0;
            crc_error      <= 1'b0;
            packet_done    <= 1'b0;
            running_crc    <= 32'hFFFF_FFFF;
            calculated_crc <= '0;
            received_crc   <= '0;
        end
        else begin
            crc_error   <= 1'b0;
            packet_done <= 1'b0;

            if (rx_valid && rx_ready) begin
                if (rx_sop) begin
                    packet_count  <= 1;
                    packet_mem[0] <= rx_data;
                    keep_mem[0]   <= rx_keep;
                    collecting    <= 1'b1;

                    // Seed and update CRC with the first beat (unless single-beat)
                    if (!rx_eop)
                        running_crc <= crc32_word_step(32'hFFFF_FFFF, rx_data, rx_keep);
                    else
                        running_crc <= 32'hFFFF_FFFF;
                end
                else if (collecting) begin
                    if (packet_count < MAX_PKT_DW) begin
                        packet_mem[packet_count] <= rx_data;
                        keep_mem[packet_count]   <= rx_keep;
                        packet_count             <= packet_count + 1;

                        // Accumulate CRC on every beat except the final LCRC DWORD
                        if (!rx_eop)
                            running_crc <= crc32_word_step(running_crc, rx_data, rx_keep);
                    end
                    else begin
                        collecting   <= 1'b0;
                        packet_count <= 0;
                        crc_error    <= 1'b1;
                    end
                end

                if (rx_eop && collecting) begin
                    collecting <= 1'b0;

                    if (packet_count >= 2) begin
                        calculated_crc <= ~running_crc;
                        received_crc   <= rx_data;

                        if ((~running_crc) == rx_data) begin
                            packet_good  <= 1'b1;
                            sending      <= 1'b1;
                            out_index    <= 0;
                            packet_count <= packet_count + (rx_sop ? 0 : 1);
                        end
                        else begin
                            packet_good  <= 1'b0;
                            crc_error    <= 1'b1;
                            packet_count <= 0;
                        end
                    end
                    else begin
                        crc_error    <= 1'b1;
                        packet_count <= 0;
                    end
                end
            end

            if (sending && out_valid && out_ready) 
            begin
                if (out_eop) begin
                    sending      <= 1'b0;
                    packet_count <= 0;
                    packet_done  <= 1'b1;
                end
                else begin
                    out_index <= out_index + 1;
                end
            end
        end
    end

endmodule