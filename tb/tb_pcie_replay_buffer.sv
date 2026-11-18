module tb_pcie_replay_buffer ;

    parameter int DATA_W       = 32;
    parameter int SEQ_W        = 12;
    parameter int MAX_PKT_DW   = 1024;
    parameter int REPLAY_DEPTH = 8;

    logic                  clk;
    logic                  rst_n;

    // Buffer status
    logic                  buf_full;
    logic                  buf_ready;

    // Write interface
    logic [DATA_W-1:0]     buf_wr_data;
    logic                  buf_wr_valid;
    logic                  buf_wr_ready;
    logic                  buf_wr_sop;
    logic                  buf_wr_eop;
    logic [DATA_W/8-1:0]   buf_wr_keep;
    logic [SEQ_W-1:0]      buf_wr_seq_num;

    // Read request
    logic                  buf_rd_start;
    logic [SEQ_W-1:0]      buf_rd_seq_num;
    logic                  buf_rd_found;

    // Replay output
    logic [DATA_W-1:0]     replay_data;
    logic                  replay_valid;
    logic                  replay_ready;
    logic                  replay_sop;
    logic                  replay_eop;
    logic [DATA_W/8-1:0]   replay_keep;
    logic                  replay_done;

    // Release acknowledged packet slot
    logic                  buf_free_valid;
    logic [SEQ_W-1:0]      buf_free_seq_num;


pcie_replay_buffer #(
    .DATA_W          (DATA_W),
    .SEQ_W           (SEQ_W),
    .MAX_PKT_DW      (MAX_PKT_DW),
    .REPLAY_DEPTH    (REPLAY_DEPTH)
) dut (
    .clk              (clk),
    .rst_n            (rst_n),

    // Buffer status
    .buf_full         (buf_full),
    .buf_ready        (buf_ready),

    // Write interface
    .buf_wr_data      (buf_wr_data),
    .buf_wr_valid     (buf_wr_valid),
    .buf_wr_ready     (buf_wr_ready),
    .buf_wr_sop       (buf_wr_sop),
    .buf_wr_eop       (buf_wr_eop),
    .buf_wr_keep      (buf_wr_keep),
    .buf_wr_seq_num   (buf_wr_seq_num),

    // Read request
    .buf_rd_start     (buf_rd_start),
    .buf_rd_seq_num   (buf_rd_seq_num),
    .buf_rd_found     (buf_rd_found),

    // Replay output
    .replay_data      (replay_data),
    .replay_valid     (replay_valid),
    .replay_ready     (replay_ready),
    .replay_sop       (replay_sop),
    .replay_eop       (replay_eop),
    .replay_keep      (replay_keep),
    .replay_done      (replay_done),

    // Release acknowledged packet slot
    .buf_free_valid   (buf_free_valid),
    .buf_free_seq_num (buf_free_seq_num)
);


always
begin
               clk <= 1'b0;
    forever #5 clk <= ~clk;
end

task automatic send_beat(
    input logic [31:0] data,
    input logic        sop,
    input logic        eop,
    input logic [3:0]  keep
);
begin
    @(negedge clk);

    buf_wr_valid = 1'b1;
    buf_wr_data  = data;
    buf_wr_sop   = sop;
    buf_wr_eop   = eop;
    buf_wr_keep  = keep;

    // Wait until the DUT accepts the beat.
    do @(posedge clk);
    while (!buf_wr_ready);
 
    @(negedge clk);
    buf_wr_valid = 1'b0;
end
endtask

initial 
    begin
		$dumpfile("pcie_replay_buffer.vcd"); // Specifies the name of the output waveform file
		$dumpvars(0, tb_pcie_replay_buffer);   // Dumps all signals in tb_pcie_replay_buffer and modules below it
	end

initial 
    begin
    rst_n = 1'b0;
    $display("INFO: Reset asserted");
    #20;
    rst_n = 1'b1;
    $display("INFO: Reset deasserted");
    #20;

    @(negedge clk);
    buf_wr_seq_num = 12'd14;
    $display("INFO: Starting sending tlp beats");
    send_beat( 32'hDB23_9F65, 1, 0, 4'hF );
    send_beat( 32'h1AC7_729D, 0, 0, 4'hF );
    send_beat( 32'hE043_F234, 0, 1, 4'hF );
    $display("INFO: Finished sending data beats");
    $display("DATA INSIDE REPLAY BUFFER");
    $display("seq no = %0d", dut.slot_seq[6]);
    $display("mem0 = %0h,mem0 = %0h,mem0 = %0h", dut.mem[6][0], dut.mem[6][1], dut.mem[6][2]);
    $display("----------------------------------------------------");
    //REPLAY
    @(negedge clk); 
    buf_rd_start = 1'b1;
    buf_rd_seq_num = 12'd14;
    replay_ready = 1'b1;
    @(negedge clk);
    buf_rd_start = 1'b0;
    $display("INFO: Starting replay");

    repeat(3)
    begin
    if(replay_valid)
        $display($time,"PASS: replay_data = %h", replay_data);
    else
        $display($time,"FAIL: replay_data not valid");
    @(negedge clk);
    end
    
    $display("INFO: Finished replay");
    @(negedge clk);
    $finish;
    end

endmodule

