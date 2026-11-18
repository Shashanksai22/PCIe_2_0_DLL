module tb_pcie_dl_tx;

    parameter int DATA_W       = 32;
    parameter int SEQ_W        = 12;
    parameter int MAX_PKT_DW   = 1024;
    parameter int REPLAY_DEPTH = 8 ;

    logic clk;                      // Data Link Layer clock
    logic rst_n;                    // Active-low asynchronous reset

    // Transaction Layer input stream
    logic [DATA_W-1:0] tl_tx_data;
    logic              tl_tx_valid;
    logic              tl_tx_ready;
    logic              tl_tx_sop;
    logic              tl_tx_eop;
    logic [3:0]        tl_tx_keep;

    // Replay-buffer write interface
    logic              replay_buf_full;
    logic              replay_buf_ready;

    logic [DATA_W-1:0] buf_wr_data;
    logic              buf_wr_valid;
    logic              buf_wr_ready;
    logic              buf_wr_sop;
    logic              buf_wr_eop;
    logic [3:0]        buf_wr_keep;
    logic [SEQ_W-1:0]  buf_wr_seq_num;

    // TX LCRC generator interface
    logic              lcrc_start;
    logic [DATA_W-1:0] lcrc_data;
    logic              lcrc_valid;
    logic              lcrc_ready;
    logic              lcrc_sop;
    logic              lcrc_eop;
    logic [3:0]        lcrc_keep;

    logic [31:0]       lcrc_result;
    logic              lcrc_result_valid;
    logic              lcrc_result_ready;

    // Replay-buffer read interface
    logic              buf_rd_start;
    logic [SEQ_W-1:0]  buf_rd_seq_num;

    logic [DATA_W-1:0] replay_data;
    logic              replay_valid;
    logic              replay_ready;
    logic              replay_sop;
    logic              replay_eop;
    logic [3:0]        replay_keep;
    logic              replay_done;

    // Replay controller interface
    logic              replay_req;
    logic [SEQ_W-1:0]  replay_req_seq;
    logic              replay_req_ready;

    // PHY transmit interface
    logic [DATA_W-1:0] phy_tx_data;
    logic              phy_tx_valid;
    logic              phy_tx_ready;
    logic              phy_tx_sop;
    logic              phy_tx_eop;
    logic [3:0]        phy_tx_keep;
    logic              phy_tx_is_tlp;

    // Status
    logic              tx_busy; 
    logic              tx_error;

// DUT Instance for Testbench
pcie_dl_tx #(
    .DATA_W       ( 32   ),
    .SEQ_W        ( 12   ),
    .MAX_PKT_DW   ( 1024 ),
    .REPLAY_DEPTH ( 8    )
) dut (
    .clk               ( clk               ),
    .rst_n             ( rst_n             ),

    // Transaction Layer input stream
    .tl_tx_data        ( tl_tx_data        ),
    .tl_tx_valid       ( tl_tx_valid       ),
    .tl_tx_ready       ( tl_tx_ready       ),
    .tl_tx_sop         ( tl_tx_sop         ),
    .tl_tx_eop         ( tl_tx_eop         ),
    .tl_tx_keep        ( tl_tx_keep        ),

    // Replay-buffer write interface
    .replay_buf_full   ( replay_buf_full   ),
    .replay_buf_ready  ( replay_buf_ready  ),
    .buf_wr_data       ( buf_wr_data       ),
    .buf_wr_valid      ( buf_wr_valid      ),
    .buf_wr_ready      ( buf_wr_ready      ),
    .buf_wr_sop        ( buf_wr_sop        ),
    .buf_wr_eop        ( buf_wr_eop        ),
    .buf_wr_keep       ( buf_wr_keep       ),
    .buf_wr_seq_num    ( buf_wr_seq_num    ),

    // TX LCRC generator interface
    .lcrc_start        ( lcrc_start        ),
    .lcrc_data         ( lcrc_data         ),
    .lcrc_valid        ( lcrc_valid        ),
    .lcrc_ready        ( lcrc_ready        ),
    .lcrc_sop          ( lcrc_sop          ),
    .lcrc_eop          ( lcrc_eop          ),
    .lcrc_keep         ( lcrc_keep         ),
    .lcrc_result       ( lcrc_result       ),
    .lcrc_result_valid ( lcrc_result_valid ),
    .lcrc_result_ready ( lcrc_result_ready ),

    // Replay-buffer read interface
    .buf_rd_start      ( buf_rd_start      ),
    .buf_rd_seq_num    ( buf_rd_seq_num    ),
    .replay_data       ( replay_data       ),
    .replay_valid      ( replay_valid      ),
    .replay_ready      ( replay_ready      ),
    .replay_sop        ( replay_sop        ),
    .replay_eop        ( replay_eop        ),
    .replay_keep       ( replay_keep       ),
    .replay_done       ( replay_done       ),

    // Replay controller interface
    .replay_req        ( replay_req        ),
    .replay_req_seq    ( replay_req_seq    ),
    .replay_req_ready  ( replay_req_ready  ),

    // PHY transmit interface
    .phy_tx_data       ( phy_tx_data       ),
    .phy_tx_valid      ( phy_tx_valid      ),
    .phy_tx_ready      ( phy_tx_ready      ),
    .phy_tx_sop        ( phy_tx_sop        ),
    .phy_tx_eop        ( phy_tx_eop        ),
    .phy_tx_keep       ( phy_tx_keep       ),
    .phy_tx_is_tlp     ( phy_tx_is_tlp     ),

    // Status
    .tx_busy           ( tx_busy           ),
    .tx_error          ( tx_error          )
);


always
begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

task automatic send_beat(
    input logic [31:0] data,
    input logic        sop,
    input logic        eop,
    input logic [3:0]  keep
);
begin
    @(negedge clk);

    tl_tx_valid = 1'b1;
    tl_tx_data  = data;
    tl_tx_sop   = sop;
    tl_tx_eop   = eop;
    tl_tx_keep  = keep;

    // Wait until the DUT accepts the beat.
    do @(posedge clk);
    while (!tl_tx_ready);

   // @(posedge clk);
   // @(posedge clk);
    @(negedge clk);
    tl_tx_valid = 1'b0;
end
endtask

initial 
    begin
		$dumpfile("pcie_dl_tx.vcd"); // Specifies the name of the output waveform file
		$dumpvars(0, tb_pcie_dl_tx);   // Dumps all signals in tb_pcie_dl_tx and modules below it
	end

initial 
    begin
    rst_n = 1'b0;
    #20;
    rst_n = 1'b1;
    #20;

    replay_buf_ready = 1'b1;
    replay_buf_full  = 1'b0;
    replay_req       = 1'b0;

    // IDLE -> CAPTURE
    send_beat(32'hDEADBEEF, 1'b1, 1'b0, 4'hF);
    wait(dut.ps == 1);
    $display("PASS: IDLE -> CAPTURE");

    // Remaining TLP beats
    send_beat(32'h5678ABCD, 1'b0, 1'b0, 4'hF);
    send_beat(32'h3210FEDC, 1'b0, 1'b0, 4'hF);
    send_beat(32'hCAFEBABE, 1'b0, 1'b1, 4'hF);

    // CAPTURE -> FORMAT
    wait(dut.ps == 2);
    $display("PASS: CAPTURE -> FORMAT");

    if (dut.payload_byte_count == 16)
        $display("PASS: All 4 DWORDs captured");
    else
        $error("FAIL: Incorrect captured byte count");

    // FORMAT -> LCRC_START -> LCRC_FEED
    wait(dut.ps == 3);
    $display("PASS: FORMAT -> LCRC_START");

    wait(lcrc_valid);
    lcrc_ready = 1'b1;

    // Wait until all LCRC input beats are accepted.
    wait(dut.ps == 5);
    lcrc_ready = 1'b0;
    $display("PASS: LCRC_FEED completed");

    // WAIT_LCRC -> APPEND_LCRC
    lcrc_result = 32'h12345678;
    lcrc_result_valid = 1'b1;

    wait(dut.ps == 6);
    lcrc_result_valid = 1'b0;
    $display("PASS: WAIT_LCRC -> APPEND_LCRC");

    // APPEND_LCRC -> BUF_WRITE
    wait(dut.ps == 7);
    $display("PASS: APPEND_LCRC -> BUF_WRITE");

    // BUF_WRITE -> READ_START
    buf_wr_ready = 1'b1;
    wait(dut.ps == 8);
    buf_wr_ready = 1'b0;
    $display("PASS: BUF_WRITE -> READ_START");

    // READ_START -> PHY_TX
    wait(dut.ps == 9);
    $display("PASS: READ_START -> PHY_TX");
    phy_tx_ready = 1'b1;
    replay_valid <= 1'b1;
    replay_sop   <= 1'b1;
    replay_eop   <= 1'b1;
    replay_data  <= 32'hBC5A_BC5A;
    replay_keep  <= 4'hF;
    wait(dut.ps == 0);
    $display("PASS: S_PHY_TX -> IDLE");
    replay_valid <= 1'b0;
    replay_sop   <= 1'b0;
    replay_eop   <= 1'b0;
    #100;
    // TODO: Drive the complete packet from the replay buffer here.
    // Do not use only one replay beat for a multi-beat packet.
    replay_req = 1'b1;
    replay_req_seq = 12'h000;
    wait(dut.ps == 8);
    $display("PASS: Replay request accepted");
    replay_req = 1'b0; 

    #200;
    $finish; 
    end
    
endmodule
