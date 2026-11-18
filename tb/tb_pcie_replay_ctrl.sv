module tb_pcie_replay_ctrl;

    parameter int SEQ_W = 12;
    parameter int REPLAY_DEPTH = 8;
    parameter int REPLAY_TIMEOUT_CYCLES = 20;

    logic                 clk;
    logic                 rst_n;

    // Transmitted TLP tracking
    logic                 tx_tlp_valid;
    logic [SEQ_W-1:0]     tx_tlp_seq;

    // Received ACK / NAK
    logic                 ack_valid;
    logic [SEQ_W-1:0]     ack_seq;

    logic                 nak_valid;
    logic [SEQ_W-1:0]     nak_seq;

    // Replay timeout
    logic                 replay_timeout;

    // Replay buffer request
    logic                 replay_req;
    logic [SEQ_W-1:0]     replay_req_seq;
    logic                 replay_req_ready;
    logic                 replay_done;

    // Release acknowledged packet
    logic                 buf_free_valid;
    logic [SEQ_W-1:0]     buf_free_seq;



pcie_replay_ctrl #(
    .SEQ_W            (SEQ_W),
    .REPLAY_DEPTH     (REPLAY_DEPTH),
    .REPLAY_TIMEOUT_CYCLES (REPLAY_TIMEOUT_CYCLES)
) dut (
    .clk              (clk),
    .rst_n            (rst_n),

    // Transmitted TLP tracking
    .tx_tlp_valid     (tx_tlp_valid),
    .tx_tlp_seq       (tx_tlp_seq),

    // Received ACK / NAK
    .ack_valid        (ack_valid),
    .ack_seq          (ack_seq),
    .nak_valid        (nak_valid),
    .nak_seq          (nak_seq),

    // Replay buffer request
    .replay_req       (replay_req),
    .replay_req_seq   (replay_req_seq),
    .replay_req_ready (replay_req_ready),
    .replay_done      (replay_done),

    // Release acknowledged packet
    .buf_free_valid   (buf_free_valid),
    .buf_free_seq     (buf_free_seq)
);


always
begin
               clk <= 1'b0;
    forever #5 clk <= ~clk;
end

initial 
    begin
		$dumpfile("pcie_replay_ctrl.vcd"); // Specifies the name of the output waveform file
		$dumpvars(0, tb_pcie_replay_ctrl);   // Dumps all signals in tb_pcie_replay_ctrl and modules below it
	end

initial begin
    // Initialize inputs
    rst_n            = 1'b0;
    tx_tlp_valid     = 1'b0;
    tx_tlp_seq       = '0;
    ack_valid        = 1'b0;
    ack_seq          = '0;
    nak_valid        = 1'b0;
    nak_seq          = '0;
    replay_timeout   = 1'b0;
    replay_req_ready = 1'b0;
    replay_done      = 1'b0;

    // Reset sequence
    $display("INFO: Reset asserted");
    #20;
    rst_n = 1'b1;
    $display("INFO: Reset deasserted");
    #20;

    // 1. Send 3 TLPs with in-order sequence numbers (10, 11, 12)
    @(negedge clk);
    tx_tlp_valid = 1'b1; tx_tlp_seq = 12'd10;
    @(negedge clk);
    tx_tlp_valid = 1'b1; tx_tlp_seq = 12'd11;
    @(negedge clk);
    tx_tlp_valid = 1'b1; tx_tlp_seq = 12'd12;
    @(negedge clk);
    tx_tlp_valid = 1'b0;
    $display("INFO: Sent 3 TLPs (10, 11, 12)");

    $display("outstanding_count: %d", dut.outstanding_count);
    $display("outstanding[0]: %d", dut.outstanding[0]);
    $display("outstanding[1]: %d", dut.outstanding[1]); 
    $display("outstanding[2]: %d", dut.outstanding[2]);
    // 2. Cumulative ACK for packet 10 (frees packet 10; 11 and 12 remain)
    @(negedge clk);
    ack_valid = 1'b1; ack_seq = 12'd10;
    @(negedge clk);
    ack_valid = 1'b0; // REMOVED: sticky ack_valid
    $display("INFO: ACK 10 done. Remaining count: %0d", dut.outstanding_count);

    $display("outstanding_count: %d", dut.outstanding_count);
    $display("outstanding[0]: %d", dut.outstanding[0]);
    $display("outstanding[1]: %d", dut.outstanding[1]); 
    $display("outstanding[2]: %d", dut.outstanding[2]);
    // 3. Send NAK for 10 (triggers replay for nak_seq + 1 = 11, then 12)
    @(negedge clk);
    nak_valid = 1'b1; nak_seq = 12'd10; // ADDED: matches (nak_seq+1)==11 in queue
    @(negedge clk);
    nak_valid = 1'b0; // ADDED: 1-cycle pulse deassertion

    // Replay packet 11
    wait(dut.replay_req);
    @(negedge clk);
    $display("INFO: Replay request seq: %0d (expected 11)", replay_req_seq);
    replay_req_ready = 1'b1;
    @(negedge clk);
    replay_req_ready = 1'b0;
    replay_done      = 1'b1;
    @(negedge clk);
    replay_done      = 1'b0;

    // Replay packet 12
    wait(dut.replay_req);
    @(negedge clk);
    $display("INFO: Replay request seq: %0d (expected 12)", replay_req_seq);
    replay_req_ready = 1'b1;
    @(negedge clk);
    replay_req_ready = 1'b0;
    replay_done      = 1'b1;
    @(negedge clk);
    replay_done      = 1'b0;

    $display("outstanding_count: %d", dut.outstanding_count);
    $display("outstanding[0]: %d", dut.outstanding[0]);
    $display("outstanding[1]: %d", dut.outstanding[1]); 
    $display("outstanding[2]: %d", dut.outstanding[2]);

    // Replay timeout test
    
    $display("INFO: Waiting for internal replay timer");
    
    wait(dut.replay_req);
    
    @(negedge clk);
    $display("INFO: Timeout replay request seq: %0d (expected 11)",replay_req_seq);
    
    replay_req_ready = 1'b1;
    @(negedge clk);
    replay_req_ready = 1'b0;
    
    replay_done = 1'b1;
    @(negedge clk);
    replay_done = 1'b0;
    
    $display("outstanding_count: %d", dut.outstanding_count);
    $display("outstanding[0]: %d", dut.outstanding[0]);
    $display("outstanding[1]: %d", dut.outstanding[1]); 
    $display("outstanding[2]: %d", dut.outstanding[2]);

    #100;
    $finish;
end

endmodule
