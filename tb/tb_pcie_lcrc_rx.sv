module tb_pcie_lcrc_rx;

    parameter int DATA_W = 32;
    parameter int MAX_PKT_DW = 1024;

    logic clk;
    logic rst_n;

    logic [DATA_W-1:0] rx_data;
    logic [3:0] rx_keep;
    logic rx_valid;
    logic rx_ready;
    logic rx_sop;
    logic rx_eop;

    logic [DATA_W-1:0] out_data;
    logic [3:0] out_keep;
    logic out_valid;
    logic out_ready;
    logic out_sop;
    logic out_eop;

    logic crc_error;
    logic packet_done;


pcie_lcrc_rx #(
    .DATA_W      (DATA_W),
    .MAX_PKT_DW  (MAX_PKT_DW)
) dut (
    .clk         (clk),
    .rst_n       (rst_n),

    // Inbound stream (from Physical/Data Link RX)
    .rx_data     (rx_data),
    .rx_keep     (rx_keep),
    .rx_valid    (rx_valid),
    .rx_ready    (rx_ready),
    .rx_sop      (rx_sop),
    .rx_eop      (rx_eop),

    // Outbound stream (stripped LCRC forwarded to Transaction Layer)
    .out_data    (out_data),
    .out_keep    (out_keep),
    .out_valid   (out_valid),
    .out_ready   (out_ready),
    .out_sop     (out_sop),
    .out_eop     (out_eop),

    // Status flags
    .crc_error   (crc_error),
    .packet_done (packet_done)
);

always
begin
               clk <= 1'b0;
    forever #5 clk <= ~clk;
end

initial 
    begin
		$dumpfile("pcie_lcrc_rx.vcd"); // Specifies the name of the output waveform file
		$dumpvars(0, tb_pcie_lcrc_rx);   // Dumps all signals in tb_pcie_lcrc_rx and modules below it
	end

initial 
  begin
    rst_n            = 1'b0;
    $display("INFO: Reset asserted");
    #20;
    rst_n = 1'b1;
    $display("INFO: Reset deasserted");
    #20;

    //ERROR FREE PKT
    @(negedge clk);
    $display($time,"INFO: Sending a packet with correct LCRC");
    rx_valid=1; rx_sop=1; rx_eop=0; rx_data = 32'h0400_0001; rx_keep = 4'b1111; // Start of packet
    @(negedge clk);
    $display($time,"INFO: Packet memory[0]: %h", dut.packet_mem[0]);
    rx_valid=1; rx_sop=0; rx_eop=0; rx_data = 32'h0000_000F; rx_keep = 4'b1111;
    @(negedge clk);
    $display($time,"INFO: Packet memory[1]: %h", dut.packet_mem[1]);
    rx_valid=1; rx_sop=0; rx_eop=0; rx_data = 32'hDEAD_BEEF; rx_keep = 4'b1111;
    @(negedge clk);
    $display($time,"INFO: Packet memory[2]: %h", dut.packet_mem[2]);
    rx_valid=1; rx_sop=0; rx_eop=1; rx_data = 32'h5FA2_76A3; rx_keep = 4'b1111;
    @(negedge clk);
    $display($time,"INFO: Packet memory[3]: %h", dut.packet_mem[3]);
    wait(out_valid); // Wait for the DUT to process the packet
    out_ready = 1'b1; // Indicate that the output is ready to accept data
    repeat(10)
    begin
        if(out_valid && out_ready) begin
            $display($time,"INFO: Output valid, out_data=%h, out_keep=%b, out_sop=%b, out_eop=%b", out_data, out_keep, out_sop, out_eop);
            if(out_eop) begin
                $display($time,"INFO: End of packet reached, packet_done = %0d",packet_done);
                break;
            end
        end
        @(negedge clk);
    end

    repeat(6) @(negedge clk);

    //ERROR PKT
    @(negedge clk);
    $display($time,"INFO: Sending a packet with correct LCRC");
    rx_valid=1; rx_sop=1; rx_eop=0; rx_data = 32'h0400_0001; rx_keep = 4'b1111; // Start of packet
    @(negedge clk);
    $display($time,"INFO: Packet memory[0]: %h", dut.packet_mem[0]);
    rx_valid=1; rx_sop=0; rx_eop=0; rx_data = 32'h0000_000F; rx_keep = 4'b1111;
    @(negedge clk);
    $display($time,"INFO: Packet memory[1]: %h", dut.packet_mem[1]);
    rx_valid=1; rx_sop=0; rx_eop=0; rx_data = 32'hDEAD_BEEF; rx_keep = 4'b1111;
    @(negedge clk);
    $display($time,"INFO: Packet memory[2]: %h", dut.packet_mem[2]);
    rx_valid=1; rx_sop=0; rx_eop=1; rx_data = 32'h5FA2_7630; rx_keep = 4'b1111;
    @(negedge clk);
    $display($time,"INFO: Packet memory[3]: %h", dut.packet_mem[3]);

    if(crc_error)
      $display($time,"ERROR: ERROR PACKET ,LCRC MISMATCH");
    else 
    begin

    wait(out_valid); // Wait for the DUT to process the packet
    out_ready = 1'b1; // Indicate that the output is ready to accept data
    repeat(10)
    begin
        if(out_valid && out_ready) begin
            $display($time,"INFO: Output valid, out_data=%h, out_keep=%b, out_sop=%b, out_eop=%b", out_data, out_keep, out_sop, out_eop);
            if(out_eop) begin
                $display($time,"INFO: End of packet reached.");
                break;
            end
        end
        @(negedge clk);
    end

    end
    

   repeat(5) @(negedge clk);
   #20;
   $display($time,"INFO: Testbench finished.");
   $finish;
  end

endmodule
