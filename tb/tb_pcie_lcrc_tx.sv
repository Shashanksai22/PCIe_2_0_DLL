module tb_pcie_lcrc_tx;

   logic       clk;
   logic       rst_n;

    // Control
   logic       lcrc_start;

    // Input stream
   logic[31:0] lcrc_data;
   logic       lcrc_valid;
   logic       lcrc_ready;
   logic       lcrc_sop;
   logic       lcrc_eop;
   logic[3:0]  lcrc_keep;

    // CRC result
   logic[31:0] lcrc_result;
   logic       lcrc_result_valid;
   logic       lcrc_result_ready;


pcie_lcrc_tx dut(
   .clk( clk),
   .rst_n( rst_n),

    // Control
   .lcrc_start( lcrc_start),

    // Input stream
   .lcrc_data( lcrc_data),
   .lcrc_valid( lcrc_valid),
   .lcrc_ready( lcrc_ready),
   .lcrc_sop( lcrc_sop),
   .lcrc_eop( lcrc_eop),
   .lcrc_keep( lcrc_keep),

    // CRC result
   .lcrc_result( lcrc_result),
   .lcrc_result_valid( lcrc_result_valid),
   .lcrc_result_ready( lcrc_result_ready)
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

    lcrc_valid = 1'b1;
    lcrc_data  = data;
    lcrc_sop   = sop;
    lcrc_eop   = eop;
    lcrc_keep  = keep;

    // Wait until the DUT accepts the beat.
    do @(posedge clk);
    while (!lcrc_ready);
 
    @(negedge clk);
    lcrc_valid = 1'b0;
end
endtask

initial 
    begin
		$dumpfile("pcie_lcrc_tx.vcd"); // Specifies the name of the output waveform file
		$dumpvars(0, tb_pcie_lcrc_tx);   // Dumps all signals in tb_pcie_lcrc_tx and modules below it
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
    lcrc_start = 1'b1;
    @(negedge clk);
    lcrc_start = 1'b0;
    $display("INFO: Starting CRC calculation");
    send_beat( 32'hDB23_9F65, 1, 0, 4'hF );
    send_beat( 32'h1AC7_729D, 0, 0, 4'hF );
    send_beat( 32'hE043_F234, 0, 1, 4'hF );
    $display("INFO: Finished sending data beats");
    lcrc_result_ready = 1'b1;
    
    if(lcrc_result_valid)
        $display($time,"PASS: CRC = %h", lcrc_result);
    else
        $display($time,"FAIL: CRC result not valid");
        @(negedge clk);
    
    #20;
    $finish;    

    end
endmodule

