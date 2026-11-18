module tb_pcie_dllp_ctrl;

    logic        clk;
    logic        rst_n;

    // DLLP transmit request
    logic        tx_req_valid;
    logic        tx_req_nak;
    logic [11:0] tx_req_seq;
    logic        tx_req_ready;

    // DLLP transmit stream
    logic [31:0] tx_data;
    logic [3:0]  tx_keep;
    logic        tx_valid;
    logic        tx_sop;
    logic        tx_eop;
    logic        tx_ready;

    // DLLP receive stream
    logic [31:0] rx_data;
    logic [3:0]  rx_keep;
    logic        rx_valid;
    logic        rx_sop;
    logic        rx_eop;

    // Decoded ACK/NAK
    logic        ack_valid;
    logic [11:0] ack_seq;
    logic        nak_valid;
    logic [11:0] nak_seq;
    logic        rx_crc_error;


pcie_dllp_ctrl dut (
    .clk          (clk),
    .rst_n        (rst_n),

    // DLLP transmit request
    .tx_req_valid (tx_req_valid),
    .tx_req_nak   (tx_req_nak),
    .tx_req_seq   (tx_req_seq),
    .tx_req_ready (tx_req_ready),

    // DLLP transmit stream
    .tx_data      (tx_data),
    .tx_keep      (tx_keep),
    .tx_valid     (tx_valid),
    .tx_sop       (tx_sop),
    .tx_eop       (tx_eop),
    .tx_ready     (tx_ready),

    // DLLP receive stream
    .rx_data      (rx_data),
    .rx_keep      (rx_keep),
    .rx_valid     (rx_valid),
    .rx_sop       (rx_sop),
    .rx_eop       (rx_eop),

    // Decoded ACK/NAK
    .ack_valid    (ack_valid),
    .ack_seq      (ack_seq),
    .nak_valid    (nak_valid),
    .nak_seq      (nak_seq),
    .rx_crc_error (rx_crc_error)
);

always
begin
               clk <= 1'b0;
    forever #5 clk <= ~clk;
end

initial 
    begin
		$dumpfile("pcie_dllp_ctrl.vcd"); // Specifies the name of the output waveform file
		$dumpvars(0, tb_pcie_dllp_ctrl);   // Dumps all signals in tb_pcie_dllp_ctrl and modules below it
	end

task automatic send_rx_dllp(
    input logic [31:0] header,
    input logic [15:0] crc
);
begin
    // Beat 0: Header
    @(negedge clk);
    rx_valid = 1'b1;
    rx_sop   = 1'b1;
    rx_eop   = 1'b0;
    rx_data  = header;
    rx_keep  = 4'hF;

    // Beat 1: CRC
    @(negedge clk);
    rx_sop   = 1'b0;
    rx_eop   = 1'b1;
    rx_data  = {16'h0000, crc};
    rx_keep  = 4'h3;

    @(negedge clk);
    rx_valid = 1'b0;
    rx_eop   = 1'b0;
    rx_data  = '0;
    rx_keep  = '0;
end
endtask

initial begin
    rst_n            = 1'b0;
    tx_req_valid     = 1'b0;
    tx_req_nak       = 1'b0;
    tx_req_seq       = '0;
    tx_ready         = 1'b1; // Keep ready asserted during TX transfers
    rx_valid         = 1'b0;
    rx_sop           = 1'b0;
    rx_eop           = 1'b0;
    rx_data          = '0;
    rx_keep          = '0;

    $display("INFO: Reset asserted");
    #20;
    rst_n = 1'b1;
    $display("INFO: Reset deasserted");
    #20;
    
    // -------------------------------------------------------------
    // 1. TX Test: ACK (seq = 5)
    // -------------------------------------------------------------
    wait(dut.tx_req_ready);
    @(negedge clk);
    tx_req_valid = 1'b1;
    tx_req_nak   = 1'b0;
    tx_req_seq   = 12'd5;

    @(negedge clk);
    tx_req_valid = 1'b0; // Pulse ended, Beat 0 is driven now

    $display($time, " INFO: TX ACK Beat 0: data=%08h, sop=%0b, eop=%0b", tx_data, tx_sop, tx_eop);
    @(negedge clk);
    $display($time, " INFO: TX ACK Beat 1: data=%08h, sop=%0b, eop=%0b", tx_data, tx_sop, tx_eop);

    // -------------------------------------------------------------
    // 2. TX Test: NAK (seq = 6)
    // -------------------------------------------------------------
    wait(dut.tx_req_ready);
    @(negedge clk);
    tx_req_valid = 1'b1;
    tx_req_nak   = 1'b1;
    tx_req_seq   = 12'd6;

    @(negedge clk);
    tx_req_valid = 1'b0;

    $display($time, " INFO: TX NAK Beat 0: data=%08h, sop=%0b, eop=%0b", tx_data, tx_sop, tx_eop);
    @(negedge clk);
    $display($time, " INFO: TX NAK Beat 1: data=%08h, sop=%0b, eop=%0b", tx_data, tx_sop, tx_eop);

    // -------------------------------------------------------------
    // 3. RX Tests
    // -------------------------------------------------------------
    // Seq 5: Nibble 4 = 5 -> 32'h0005_0000 (bits [27:16] = 12'h005)
    send_rx_dllp(32'h0005_0000, dut.dllp_crc16(32'h0005_0000));
    $display($time,"INFO: Sent ACK DLLP (seq 5), observed: ack_valid=%0b, ack_seq=%0d", ack_valid, ack_seq);
    
    // Seq 6: Nibble 4 = 6 -> 32'h0006_0010 (bits [27:16] = 12'h006)
    send_rx_dllp(32'h0006_0010, dut.dllp_crc16(32'h0006_0010));
    wait(nak_valid || nak_seq != 12'd6); // Wait for DUT register update
    $display($time,"INFO: Sent NAK DLLP (seq 6), observed: nak_valid=%0b, nak_seq=%0d", nak_valid, nak_seq);

    // Corrupted CRC
    send_rx_dllp(32'h0000_5000, 16'hFFFF);
    $display($time,"INFO: Sent corrupted DLLP, observed: rx_crc_error=%0b", rx_crc_error);

    repeat(5) @(negedge clk);
    $finish;
end

endmodule

