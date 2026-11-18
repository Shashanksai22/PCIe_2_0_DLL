module tb_pcie_dl_rx;

    parameter int SEQ_W = 12;

    logic clk;
    logic rst_n;

    // Input from pcie_lcrc_rx
    logic [31:0] in_data;
    logic [3:0] in_keep;
    logic in_valid;
    logic in_ready;
    logic in_sop;
    logic in_eop;

    // Verified TLP output
    logic [31:0] tlp_data;
    logic [3:0] tlp_keep;
    logic tlp_valid;
    logic tlp_ready;
    logic tlp_sop;
    logic tlp_eop;

    // ACK/NAK request to DLLP controller
    logic ack_req;
    logic [SEQ_W-1:0] ack_seq;
    logic nak_req;
    logic [SEQ_W-1:0] nak_seq;

    logic sequence_error;

pcie_dl_rx #(
    .SEQ_W          (SEQ_W)
) dut (
    .clk            (clk),
    .rst_n          (rst_n),

    // Ingress stream from pcie_lcrc_rx
    .in_data        (in_data),
    .in_keep        (in_keep),
    .in_valid       (in_valid),
    .in_ready       (in_ready),
    .in_sop         (in_sop),
    .in_eop         (in_eop),

    // Egress verified TLP to Transaction Layer
    .tlp_data       (tlp_data),
    .tlp_keep       (tlp_keep),
    .tlp_valid      (tlp_valid),
    .tlp_ready      (tlp_ready),
    .tlp_sop        (tlp_sop),
    .tlp_eop        (tlp_eop),

    // Feedback to DLLP Controller (pcie_dllp_ctrl)
    .ack_req        (ack_req),
    .ack_seq        (ack_seq),
    .nak_req        (nak_req),
    .nak_seq        (nak_seq),

    // Error status flag
    .sequence_error (sequence_error)
);

always
begin
               clk <= 1'b0;
    forever #5 clk <= ~clk;
end

initial 
    begin
		$dumpfile("pcie_dl_rx.vcd"); // Specifies the name of the output waveform file
		$dumpvars(0, tb_pcie_dl_rx);   // Dumps all signals in tb_pcie_dl_rx and modules below it
	end

initial begin
    rst_n     = 1'b0;
    in_valid  = 1'b0;
    in_sop    = 1'b0;
    in_eop    = 1'b0;
    in_data   = '0;
    in_keep   = '0;
    tlp_ready = 1'b1;

    $display("INFO: Reset asserted");
    #20;
    rst_n = 1'b1;
    $display("INFO: Reset deasserted");
    #20;

    // ---------------------------------------------------------
    // Beat 0: SOP with Sequence Number = 0 (bits [27:16] = 12'h000)
    // ---------------------------------------------------------
    @(negedge clk);
    in_valid = 1'b1;    in_sop   = 1'b1;    in_eop   = 1'b0;   in_data  = 32'h0000_0001;   in_keep  = 4'hF;

    @(negedge clk);
    in_sop  = 1'b0;   in_data = 32'h0000_000F;
    $display($time, " INFO: Output beat 0: tlp_data=%h, sop=%b, eop=%b, valid=%b",   tlp_data, tlp_sop, tlp_eop, tlp_valid);

    @(negedge clk);
    in_data = 32'hDEAD_BEEF;
    $display($time, " INFO: Output beat 1: tlp_data=%h, sop=%b, eop=%b, valid=%b",   tlp_data, tlp_sop, tlp_eop, tlp_valid);

    @(negedge clk);
    in_eop  = 1'b1;    in_data = 32'h5FA2_76A3;
    $display($time, " INFO: Output beat 2: tlp_data=%h, sop=%b, eop=%b, valid=%b",   tlp_data, tlp_sop, tlp_eop, tlp_valid);

    // ---------------------------------------------------------
    // Deassert input stream and capture final beat + ACK
    // ---------------------------------------------------------
    @(negedge clk);
    in_valid = 1'b0;    in_eop   = 1'b0;    in_data  = '0;    in_keep  = '0;
    $display($time, " INFO: Output beat 3 (EOP): tlp_data=%h, sop=%b, eop=%b, valid=%b", tlp_data, tlp_sop, tlp_eop, tlp_valid);
    $display($time, " INFO: Status: ack_req=%0b, ack_seq=%0d, seq_err=%0b",   ack_req, ack_seq, sequence_error);
    
    //DUPLICATE PKT
    @(negedge clk);
    in_valid = 1'b1;    in_sop   = 1'b1;    in_eop   = 1'b0;   in_data  = 32'h0000_1234;   in_keep  = 4'hF;

    @(negedge clk);
    in_valid = 1'b0;    in_eop   = 1'b0;    in_data  = '0;    in_keep  = '0;
    $display($time, " INFO: Duplicate Output beat : tlp_data=%h, sop=%b, eop=%b, valid=%b", tlp_data, tlp_sop, tlp_eop, tlp_valid);
    $display($time, " INFO: Status: ack_req=%0b, ack_seq=%0d, seq_err=%0b",   ack_req, ack_seq, sequence_error);

    //ERROR PKT
    @(negedge clk);
    in_valid = 1'b1;    in_sop   = 1'b1;    in_eop   = 1'b0;   in_data  = 32'hffff_1234;   in_keep  = 4'hF;

    @(negedge clk);
    in_valid = 1'b0;    in_eop   = 1'b0;    in_data  = '0;    in_keep  = '0;
    $display($time, " INFO: Duplicate Output beat : tlp_data=%h, sop=%b, eop=%b, valid=%b", tlp_data, tlp_sop, tlp_eop, tlp_valid);
    $display($time, " INFO: Status: nak_req=%0b, nak_seq=%0d, seq_err=%0b",   nak_req, nak_seq, sequence_error);

    repeat(5) @(negedge clk);
    $display($time, " INFO: Testbench finished.");
    $finish;
end

endmodule

