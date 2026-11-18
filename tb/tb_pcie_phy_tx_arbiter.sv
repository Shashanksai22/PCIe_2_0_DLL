module tb_pcie_phy_tx_arbiter;

    logic clk;
    logic rst_n;

    // New TLP stream
    logic [31:0] tlp_data;
    logic [3:0] tlp_keep;
    logic tlp_valid;
    logic tlp_ready;
    logic tlp_sop;
    logic tlp_eop;

    // Replay TLP stream
    logic [31:0] replay_data;
    logic [3:0] replay_keep;
    logic replay_valid;
    logic replay_ready;
    logic replay_sop;
    logic replay_eop;

    // DLLP stream
    logic [31:0] dllp_data;
    logic [3:0] dllp_keep;
    logic dllp_valid;
    logic dllp_ready;
    logic dllp_sop;
    logic dllp_eop;

    // PHY output
    logic [31:0] phy_tx_data;
    logic [3:0] phy_tx_keep;
    logic phy_tx_valid;
    logic phy_tx_ready;
    logic phy_tx_sop;
    logic phy_tx_eop;
    logic phy_tx_is_tlp;

    pcie_phy_tx_arbiter dut (
    .clk           (clk),
    .rst_n         (rst_n),

    // New TLP Stream
    .tlp_data      (tlp_data),
    .tlp_keep      (tlp_keep),
    .tlp_valid     (tlp_valid),
    .tlp_ready     (tlp_ready),
    .tlp_sop       (tlp_sop),
    .tlp_eop       (tlp_eop),

    // Replay TLP Stream
    .replay_data   (replay_data),
    .replay_keep   (replay_keep),
    .replay_valid  (replay_valid),
    .replay_ready  (replay_ready),
    .replay_sop    (replay_sop),
    .replay_eop    (replay_eop),

    // DLLP Stream
    .dllp_data     (dllp_data),
    .dllp_keep     (dllp_keep),
    .dllp_valid    (dllp_valid),
    .dllp_ready    (dllp_ready),
    .dllp_sop      (dllp_sop),
    .dllp_eop      (dllp_eop),

    // PHY Output
    .phy_tx_data   (phy_tx_data),
    .phy_tx_keep   (phy_tx_keep),
    .phy_tx_valid  (phy_tx_valid),
    .phy_tx_ready  (phy_tx_ready),
    .phy_tx_sop    (phy_tx_sop),
    .phy_tx_eop    (phy_tx_eop),
    .phy_tx_is_tlp (phy_tx_is_tlp)
);


always
begin
               clk <= 1'b0;
    forever #5 clk <= ~clk;
end

initial 
    begin
		$dumpfile("pcie_phy_tx_arbiter.vcd"); // Specifies the name of the output waveform file
		$dumpvars(0, tb_pcie_phy_tx_arbiter);   // Dumps all signals in tb_pcie_phy_tx_arbiter and modules below it
	end

initial begin
    rst_n         = 1'b0;
    phy_tx_ready  = 1'b1;
    tlp_valid     = 1'b0;
    tlp_sop       = 1'b0;
    tlp_eop       = 1'b0;
    tlp_data      = '0;
    tlp_keep      = '0;
    dllp_valid    = 1'b0;
    dllp_sop      = 1'b0;
    dllp_eop      = 1'b0;
    dllp_data     = '0;
    dllp_keep     = '0;

    $display("INFO: Reset asserted");
    #20;
    rst_n = 1'b1;
    $display("INFO: Reset deasserted");
    #20;

    // -------------------------------------------------------------
    // 1. TLP Stream: Beat 0 (SOP)
    // -------------------------------------------------------------
    @(negedge clk);
    tlp_valid = 1'b1; tlp_sop = 1'b1; tlp_eop = 1'b0;
    tlp_data  = 32'h0000_0001; tlp_keep = 4'hF;

    // Wait until arbiter grants and latches NEW_TLP
    do @(negedge clk); while (!(dut.selected_source == dut.NEW_TLP));
    $display($time, " INFO: TLP Beat 0: data=%08h, sop=%0b, eop=%0b, is_tlp=%0b", 
             phy_tx_data, phy_tx_sop, phy_tx_eop, phy_tx_is_tlp);

    // -------------------------------------------------------------
    // 2. TLP Stream: Beat 1 (Assert DLLP concurrently -> check lockout)
    // -------------------------------------------------------------
    tlp_sop    = 1'b0;
    tlp_data   = 32'hDEAD_BEEF;
    dllp_valid = 1'b1; dllp_sop = 1'b1; dllp_data = 32'h0000_5000; dllp_keep = 4'hF;
    #1; // Sample immediately in current cycle
    $display($time, " INFO: TLP Beat 1: data=%08h, sop=%0b, eop=%0b (DLLP blocked: dllp_ready=%0b)", 
             phy_tx_data, phy_tx_sop, phy_tx_eop, dut.dllp_ready);

    // -------------------------------------------------------------
    // 3. TLP Stream: Beat 2 (EOP)
    // -------------------------------------------------------------
    @(negedge clk);
    tlp_eop   = 1'b1;
    tlp_data  = 32'h0985_3200;
    #1; // Sample active beat before the posedge transition clears it
    $display($time, " INFO: TLP Beat 2 (EOP): data=%08h, sop=%0b, eop=%0b, is_tlp=%0b", 
             phy_tx_data, phy_tx_sop, phy_tx_eop, phy_tx_is_tlp);

    // Finish TLP; arbiter returns to IDLE and picks up pending DLLP
    @(negedge clk);
    tlp_valid = 1'b0; tlp_eop = 1'b0; tlp_data = '0;

    // -------------------------------------------------------------
    // 4. DLLP Stream: Beat 0 (SOP)
    // -------------------------------------------------------------
    do @(negedge clk); while (!(dut.selected_source == dut.DLLP));
    $display($time, " INFO: DLLP Beat 0: data=%08h, sop=%0b, eop=%0b, is_tlp=%0b", 
             phy_tx_data, phy_tx_sop, phy_tx_eop, phy_tx_is_tlp);

    // -------------------------------------------------------------
    // 5. DLLP Stream: Beat 1 (EOP)
    // -------------------------------------------------------------
    dllp_sop  = 1'b0;
    dllp_eop  = 1'b1;
    dllp_data = 32'h0000_52A4;
    #1; // Sample active beat before the posedge transition clears it
    $display($time, " INFO: DLLP Beat 1 (EOP): data=%08h, sop=%0b, eop=%0b, is_tlp=%0b", 
             phy_tx_data, phy_tx_sop, phy_tx_eop, phy_tx_is_tlp);

    // Finish DLLP
    @(negedge clk);
    dllp_valid = 1'b0; dllp_eop = 1'b0; dllp_data = '0;

    repeat(5) @(negedge clk);
    $display($time, " INFO: Testbench finished.");
    $finish;
end

endmodule

