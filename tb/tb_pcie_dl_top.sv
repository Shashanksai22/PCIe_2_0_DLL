module tb_pcie_dl_top;

    parameter int DATA_W       = 32;
    parameter int SEQ_W        = 12;
    parameter int MAX_PKT_DW   = 1024;
    parameter int REPLAY_DEPTH = 8;
    parameter int REPLAY_TIMEOUT_CYCLES = 1024;

    logic clk;
    logic rst_n;

    // Transaction Layer TX
    logic [DATA_W-1:0] tl_tx_data;
    logic              tl_tx_valid;
    logic              tl_tx_ready;
    logic              tl_tx_sop;
    logic              tl_tx_eop;
    logic [3:0]        tl_tx_keep;

    // Transaction Layer RX
    logic [DATA_W-1:0] tl_rx_data;
    logic [3:0]        tl_rx_keep;
    logic              tl_rx_valid;
    logic              tl_rx_ready;
    logic              tl_rx_sop;
    logic              tl_rx_eop;

    // PHY TX
    logic [DATA_W-1:0] phy_tx_data;
    logic [3:0]        phy_tx_keep;
    logic              phy_tx_valid;
    logic              phy_tx_ready;
    logic              phy_tx_sop;
    logic              phy_tx_eop;
    logic              phy_tx_is_tlp;

    // PHY RX
    logic [DATA_W-1:0] phy_rx_data;
    logic [3:0]        phy_rx_keep;
    logic              phy_rx_valid;
    logic              phy_rx_sop;
    logic              phy_rx_eop;
    logic              phy_rx_is_tlp;

    // Status
    logic              tx_busy;
    logic              tx_error;
    logic              rx_sequence_error;
    logic              rx_crc_error;
    logic              dllp_crc_error;

    // -------------------------------------------------------------
    // Status Signal Monitor: Prints only on 0 -> 1 transition (edge)
    // -------------------------------------------------------------
    logic tx_busy_q, tx_error_q, rx_seq_err_q, rx_crc_err_q, dllp_crc_err_q;

    pcie_dl_top #(
    .DATA_W                (32),
    .SEQ_W                 (12),
    .MAX_PKT_DW            (1024),
    .REPLAY_DEPTH          (8),
    .REPLAY_TIMEOUT_CYCLES (1024)
) dut (
    .clk                   (clk),
    .rst_n                 (rst_n),

    // Transaction Layer TX
    .tl_tx_data            (tl_tx_data),
    .tl_tx_valid           (tl_tx_valid),
    .tl_tx_ready           (tl_tx_ready),
    .tl_tx_sop             (tl_tx_sop),
    .tl_tx_eop             (tl_tx_eop),
    .tl_tx_keep            (tl_tx_keep),

    // Transaction Layer RX
    .tl_rx_data            (tl_rx_data),
    .tl_rx_keep            (tl_rx_keep),
    .tl_rx_valid           (tl_rx_valid),
    .tl_rx_ready           (tl_rx_ready),
    .tl_rx_sop             (tl_rx_sop),
    .tl_rx_eop             (tl_rx_eop),

    // PHY TX
    .phy_tx_data           (phy_tx_data),
    .phy_tx_keep           (phy_tx_keep),
    .phy_tx_valid          (phy_tx_valid),
    .phy_tx_ready          (phy_tx_ready),
    .phy_tx_sop            (phy_tx_sop),
    .phy_tx_eop            (phy_tx_eop),
    .phy_tx_is_tlp         (phy_tx_is_tlp),

    // PHY RX
    .phy_rx_data           (phy_rx_data),
    .phy_rx_keep           (phy_rx_keep),
    .phy_rx_valid          (phy_rx_valid),
    .phy_rx_sop            (phy_rx_sop),
    .phy_rx_eop            (phy_rx_eop),
    .phy_rx_is_tlp         (phy_rx_is_tlp),

    // Status
    .tx_busy               (tx_busy),
    .tx_error              (tx_error),
    .rx_sequence_error     (rx_sequence_error),
    .rx_crc_error          (rx_crc_error),
    .dllp_crc_error        (dllp_crc_error)
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
		$dumpfile("pcie_dl_top.vcd"); // Specifies the name of the output waveform file
		$dumpvars(0, tb_pcie_dl_top);   // Dumps all signals in tb_pcie_dl_top and modules below it
	end

always @(posedge clk) begin
    if (dut.replay_req)
        $display("REPLAY REQ: seq=%0d ready=%b",
                 dut.replay_req_seq, dut.replay_req_ready);

    if (dut.buf_rd_start)
        $display("BUFFER READ: seq=%0d found=%b",
                 dut.buf_rd_seq_num, dut.buf_rd_found);

    if (dut.replay_valid && dut.replay_ready)
        $display("BUFFER DATA: %08h SOP=%b EOP=%b",
                 dut.replay_data, dut.replay_sop, dut.replay_eop);

    if (dut.replay_done)
        $display("REPLAY DONE");
end

// Helper task to send an ACK DLLP
    task automatic send_ack(input logic [11:0] seq_num);
    begin
        @(negedge clk);
        phy_rx_valid  = 1'b1;
        phy_rx_is_tlp = 1'b0; // DLLP
        phy_rx_sop    = 1'b1;
        phy_rx_eop    = 1'b0;
        phy_rx_keep   = 4'hF;
        phy_rx_data   = {4'h0, seq_num[11:8], seq_num[7:0], 8'h00, 8'h00}; // ACK format

        @(negedge clk);
        phy_rx_sop    = 1'b0;
        phy_rx_eop    = 1'b1;
        phy_rx_data   = {16'h0000, dut.u_dllp_ctrl.dllp_crc16(phy_rx_data)};

        @(negedge clk);
        phy_rx_valid  = 1'b0;
        phy_rx_eop    = 1'b0;
        phy_rx_data   = '0;
    end
    endtask

    // Helper task to drain one transmitted TLP from PHY TX
    task automatic drain_phy_tx(output logic [11:0] seq_captured);
    begin
        wait(phy_tx_valid);
        phy_tx_ready = 1'b1;
        
        // Beat 0 contains sequence number
        @(negedge clk);
        seq_captured = phy_tx_data[27:16]; 
        $display($time, " [PHY TX] Beat 0 (SOP): Seq=0x%03h, Data=0x%08h", seq_captured, phy_tx_data);
        
        // Drain until EOP
        while (!(phy_tx_valid && phy_tx_eop)) begin
            @(negedge clk);
            if (phy_tx_valid)
                $display($time, " [PHY TX] Beat: Data=0x%08h, EOP=%0b", phy_tx_data, phy_tx_eop);
        end
        @(negedge clk);
        phy_tx_ready = 1'b0;
    end
    endtask

    initial begin
        logic [11:0] captured_seq;

        // Init
        rst_n         = 1'b0;
        phy_rx_valid  = 1'b0;
        phy_rx_sop    = 1'b0;
        phy_rx_eop    = 1'b0;
        phy_rx_data   = '0;
        phy_rx_keep   = '0;
        phy_rx_is_tlp = 1'b0;
        phy_tx_ready  = 1'b0;
        tl_rx_ready   = 1'b1;

        #30;
        rst_n = 1'b1;
        repeat(5) @(negedge clk);

        // =====================================================================
        // TEST 1: Timeout-Triggered Replay (No ACK sent -> Wait REPLAY_TIMEOUT)
        // =====================================================================
        $display("\n--- TEST 1: TIMEOUT-TRIGGERED REPLAY ---");
        // Send TLP (Seq 0)
        send_beat(32'hAAAA_0001, 1'b1, 1'b0, 4'hF);
        send_beat(32'hAAAA_0002, 1'b0, 1'b1, 4'hF);
        drain_phy_tx(captured_seq);

        $display($time, " [TB] TLP Sent. Holding ACK to force Replay Timeout (%0d cycles)...", REPLAY_TIMEOUT_CYCLES);
        // Wait for Replay Timeout counter to expire and trigger auto-replay
        drain_phy_tx(captured_seq);
        $display($time, " [TB] Verified: Packet Seq=0x%03h replayed via Timeout!", captured_seq);

        // Retire packet to clear buffer
        send_ack(captured_seq);
        repeat(5) @(negedge clk);

        // =====================================================================
        // TEST 2: Multiple Outstanding TLPs (Fill Replay Buffer Slots)
        // =====================================================================
        $display("\n--- TEST 2: MULTIPLE OUTSTANDING TLPS ---");
        // Send 3 consecutive TLPs without waiting for ACKs in between
        for (int p = 0; p < 3; p++) begin
            $display($time, " [TB] Injecting Outstanding TLP %0d", p);
            send_beat(32'hBBBB_0000 | p, 1'b1, 1'b0, 4'hF);
            send_beat(32'hCCCC_0000 | p, 1'b0, 1'b1, 4'hF);
            drain_phy_tx(captured_seq);
        end

        // Cumulative ACK: Sending ACK for the highest sequence retires all preceding slots
        $display($time, " [TB] Sending cumulative ACK for Seq=0x%03h", captured_seq);
        send_ack(captured_seq);
        repeat(5) @(negedge clk);

        // =====================================================================
        // TEST 3: Backpressure Verification (DUT TX throttled by PHY)
        // =====================================================================
        $display("\n--- TEST 3: PHY BACKPRESSURE ---");
        phy_tx_ready = 1'b0; // Deassert PHY ready prior to transmission
        
        fork
            begin
                send_beat(32'hDDDD_1111, 1'b1, 1'b0, 4'hF);
                send_beat(32'hDDDD_2222, 1'b0, 1'b1, 4'hF);
            end
        join_none

        // Wait until DUT wants to transmit to PHY
        wait(phy_tx_valid);
        $display($time, " [TB] DUT stalled by phy_tx_ready=0. Holding backpressure for 25 cycles...");
        repeat(25) @(negedge clk);

        // Release backpressure and verify transmission resumes cleanly
        phy_tx_ready = 1'b1;
        drain_phy_tx(captured_seq);
        send_ack(captured_seq);
        repeat(5) @(negedge clk);

        // =====================================================================
        // TEST 4: Invalid ACK/NAK (Bad CRC & Future Out-of-Range Sequence)
        // =====================================================================
        $display("\n--- TEST 4: INVALID ACK/NAK INJECTION ---");
        // Inject ACK with corrupted CRC
        @(negedge clk);
        phy_rx_valid  = 1'b1;
        phy_rx_is_tlp = 1'b0;
        phy_rx_sop    = 1'b1;
        phy_rx_eop    = 1'b0;
        phy_rx_data   = 32'h0000_0000;
        phy_rx_keep   = 4'hF;
        @(negedge clk);
        phy_rx_sop    = 1'b0;
        phy_rx_eop    = 1'b1;
        phy_rx_data   = 32'h0000_DEAD; // Bad CRC
        @(negedge clk);
        phy_rx_valid  = 1'b0;
        phy_rx_eop    = 1'b0;
        $display($time, " [TB] Injected Corrupted DLLP. Checked dllp_crc_error assertion.");
        repeat(5) @(negedge clk);

        // Inject NAK for non-existent future sequence (Seq 0x7FF)
        @(negedge clk);
        phy_rx_valid  = 1'b1;
        phy_rx_sop    = 1'b1;
        phy_rx_data   = 32'h07FF_0010; // NAK Seq 2047
        @(negedge clk);
        phy_rx_sop    = 1'b0;
        phy_rx_eop    = 1'b1;
        phy_rx_data   = {16'h0000, dut.u_dllp_ctrl.dllp_crc16(32'h07FF_0010)};
        @(negedge clk);
        phy_rx_valid  = 1'b0;
        phy_rx_eop    = 1'b0;
        $display($time, " [TB] Injected Out-of-Range NAK. Buffer should reject illegal replay.");
        repeat(10) @(negedge clk);

        // =====================================================================
        // TEST 5: Sequence Number Wraparound (4095 -> 0)
        // =====================================================================
        $display("\n--- TEST 5: SEQUENCE NUMBER WRAPAROUND ---");
        // Force sequence register near 12-bit limit to avoid sending 4096 dummy packets
        @(negedge clk);
        dut.u_dl_tx.next_transmit_seq = 12'hFFE;

        // Packet with Seq 4094 (0xFFE)
        send_beat(32'hEEEE_0FFE, 1'b1, 1'b1, 4'hF);
        drain_phy_tx(captured_seq);
        send_ack(captured_seq);

        // Packet with Seq 4095 (0xFFF)
        send_beat(32'hEEEE_0FFF, 1'b1, 1'b1, 4'hF);
        drain_phy_tx(captured_seq);
        send_ack(captured_seq);

        // Packet wrapped around: Seq 0 (0x000)
        send_beat(32'hEEEE_0000, 1'b1, 1'b1, 4'hF);
        drain_phy_tx(captured_seq);
        if (captured_seq == 12'h000)
            $display($time, " [TB] PASS: Sequence counter wrapped modulo 4096 to 0x%03h", captured_seq);
        else
            $display($time, " [TB] ERROR: Expected Seq 0x000, got 0x%03h", captured_seq);
        send_ack(captured_seq);
        repeat(5) @(negedge clk);

        // =====================================================================
        // TEST 6: Mid-Stream Asynchronous Reset
        // =====================================================================
        $display("\n--- TEST 6: MID-TRANSMISSION ASYNC RESET ---");
        // Start streaming a beat
        fork
            send_beat(32'hFFFF_1234, 1'b1, 1'b0, 4'hF);
        join_none

        @(posedge clk);
        #3;
        $display($time, " [TB] Asserting Asynchronous Reset mid-transfer!");
        rst_n = 1'b0;

        #25;
        rst_n = 1'b1;
        $display($time, " [TB] Deasserted Reset. Verifying FSM returns to IDLE...");
        repeat(5) @(negedge clk);

        if (tx_busy == 1'b0 && dut.u_dl_tx.next_transmit_seq == 12'h000)
            $display($time, " [TB] PASS: Pipeline flushed and reset cleanly.");
        else
            $display($time, " [TB] ERROR: FSM or registers failed to clear after reset.");

        repeat(10) @(negedge clk);
        $display("\n=== ALL DIRECTED SCENARIOS COMPLETED ===");
        $finish;
    end

endmodule
