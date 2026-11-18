`ifndef PCIE_DLL_SB
`define PCIE_DLL_SB

class pcie_dll_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(pcie_dll_scoreboard)

    pcie_dll_config cfg;
    virtual pcie_dll_if.STATUS status_vif;

    pcie_phy_seq_item   cov_phy_seq_item;
    pcie_tlp_seq_item   cov_tlp_seq_item;

    // [ADDED] State & sampling variables for cg_dll_events
    int cov_replay_event = 0;
    int cov_rx_seq_event = 0;
    bit nak_seen         = 0;

    // Monitor Analysis FIFOs
    uvm_tlm_analysis_fifo #(pcie_tlp_seq_item) tl_tx_fifo;
    uvm_tlm_analysis_fifo #(pcie_tlp_seq_item) tl_rx_fifo;
    uvm_tlm_analysis_fifo #(pcie_phy_seq_item) phy_tx_fifo;
    uvm_tlm_analysis_fifo #(pcie_phy_seq_item) phy_rx_fifo;

    uvm_analysis_port #(pcie_phy_seq_item) dllp_resp_ap;

    // Internal separated queues so TX TLP checking and RX ACK/NAK DLLP checking never steal items
    pcie_phy_seq_item phy_tx_tlp_q[$];
    pcie_phy_seq_item phy_tx_dllp_q[$];
    pcie_phy_seq_item phy_rx_tlp_q[$];

    // Store originally transmitted PHY TLPs by seq_num to verify NAK / Timeout retransmissions
    pcie_phy_seq_item sent_tx_tlps[bit [11:0]];

    // Summary counters
    int tx_tlp_pass_cnt     = 0;
    int tx_tlp_err_cnt      = 0;
    int tx_replay_pass_cnt  = 0;
    int tx_replay_err_cnt   = 0;
    int rx_tlp_pass_cnt     = 0;
    int rx_tlp_err_cnt      = 0;
    int rx_drop_exp_cnt     = 0;
    int rx_dup_drop_cnt     = 0;
    int dllp_pass_cnt       = 0;
    int dllp_err_cnt        = 0;

    // Status pulse counters
    int rx_crc_err_pulse_cnt   = 0;
    int rx_seq_err_pulse_cnt   = 0;
    int dllp_crc_err_pulse_cnt = 0;
    int tx_err_pulse_cnt       = 0;
    int status_err_cnt         = 0;

    bit [11:0] exp_tx_seq = 0;
    bit [11:0] exp_rx_seq = 0;

    // Helper function in scoreboard to get payload DW length from monitored dw_stream
    function int get_tlp_payload_dws(pcie_tlp_seq_item t);
        int hdr_dws;
        if (t.dw_stream.size() == 0) return 0;
        hdr_dws = t.dw_stream[0][29] ? 4 : 3; // fmt[0]==1 -> 4DW header, else 3DW header
        return (t.dw_stream.size() > hdr_dws) ? (t.dw_stream.size() - hdr_dws) : 0;
    endfunction

    // Covergroups
    covergroup cg_tl_tlp;
        cp_fmt: coverpoint cov_tlp_seq_item.dw_stream[0][31:29] {
            bins fmt_bin[] = {3'b000, 3'b001, 3'b010, 3'b011};
        }

        cp_tlp_type: coverpoint cov_tlp_seq_item.dw_stream[0][28:24] {
            bins tlp_type_bin[] = {5'b00000, 5'b00010, 5'b00100, 5'b00101, 5'b01010};
        }

        cp_len: coverpoint get_tlp_payload_dws(cov_tlp_seq_item) {
            bins len_zero  = {0};
            bins len_one   = {1};
            bins len_small = {[2:16]};
            bins len_max   = {[17:1024]};
        }

        cp_tc: coverpoint cov_tlp_seq_item.dw_stream[0][22:20] {
            bins tc_bin[] = {[0:7]};
        }

        cross_fmt_len: cross cp_fmt, cp_len {
            ignore_bins nodata_with_payload = binsof(cp_fmt) intersect {3'b000, 3'b001} && !binsof(cp_len.len_zero);
            ignore_bins data_with_zero      = binsof(cp_fmt) intersect {3'b010, 3'b011} && binsof(cp_len.len_zero);
        }
    endgroup

    covergroup cg_phy_pkt;
        cp_is_tlp: coverpoint cov_phy_seq_item.is_tlp {
            bins is_tlp_bin[] = {0, 1};
        }

        cp_dllp_type: coverpoint cov_phy_seq_item.dllp_type iff (!cov_phy_seq_item.is_tlp) {
            bins ack_bin   = {8'h00};
            bins nak_bin   = {8'h10};
        }

        cp_corrupt_crc: coverpoint cov_phy_seq_item.corrupt_crc {
            bins corrupt_crc_bin[] = {0, 1};
        }

        cp_seq_num: coverpoint cov_phy_seq_item.seq_num {
            bins seq_num_zero     = {0};
            bins seq_num_low      = {[1:15]};
            bins seq_num_mid      = {[16:4093]};
            bins seq_num_rollover = {4094, 4095};
        }

        cross_kind_crc: cross cp_is_tlp, cp_corrupt_crc;
    endgroup

    // [ADDED] DLL Protocol Events Covergroup (Replay triggers & RX Sequence outcomes)
    covergroup cg_dll_events;
        cp_replay_reason: coverpoint cov_replay_event {
            bins normal_tx      = {0};
            bins nak_retransmit = {1};
            bins timer_timeout  = {2};
        }

        cp_rx_seq_status: coverpoint cov_rx_seq_event {
            bins in_order     = {0};
            bins duplicate    = {1};
            bins out_of_order = {2};
        }
    endgroup

    function new(string name = "pcie_dll_scoreboard", uvm_component parent);
        super.new(name, parent);
        cg_phy_pkt    = new();
        cg_tl_tlp     = new();
        cg_dll_events = new(); // [ADDED] Instantiate DLL events covergroup
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db #(pcie_dll_config)::get(this, "", "pcie_dll_config", cfg))
            `uvm_error(get_type_name(), "NOT GETTING CONFIG IN PCIE_DLL_SB")

        status_vif = cfg.vif;

        tl_tx_fifo  = new("tl_tx_fifo",  this);
        tl_rx_fifo  = new("tl_rx_fifo",  this);
        phy_tx_fifo = new("phy_tx_fifo", this);
        phy_rx_fifo = new("phy_rx_fifo", this);

        dllp_resp_ap = new("dllp_resp_ap", this);

        if ($test$plusargs("ROLLOVER")) begin
            exp_tx_seq = 12'd4094;
            exp_rx_seq = 12'd4094;
        end
    endfunction

    // Reference Model 1: PCIe 32-bit LCRC (Polynomial 0x04C11DB7)
    static function bit [31:0] calc_lcrc32(input byte unsigned data[]);
        bit [31:0] crc = 32'hFFFF_FFFF;

        foreach (data[i]) begin
            for (int b = 0; b < 8; b++) begin
                crc = (crc[0] ^ data[i][b])
                    ? ((crc >> 1) ^ 32'hEDB8_8320)
                    : (crc >> 1);
            end
        end

        return ~crc;
    endfunction

    // Reference Model 2: PCIe 16-bit DLLP CRC
    static function bit [15:0] calc_crc16(input bit [31:0] data);
        bit [15:0] crc = 16'hFFFF;

        for (int b = 0; b < 4; b++) begin
            for (int i = 0; i < 8; i++) begin
                crc = (crc[0] ^ data[b*8 + i])
                    ? ((crc >> 1) ^ 16'hD008)
                    : (crc >> 1);
            end
        end

        return ~crc;
    endfunction

    // Helper: Extract bytes excluding trailing 4-byte LCRC
    function bit [31:0] compute_pkt_lcrc(pcie_phy_seq_item pkt);
        byte unsigned crc_data[];
        int crc_len;

        if (pkt.bytes.size() <= 4)
            return 32'h0;

        crc_len  = pkt.bytes.size() - 4;
        crc_data = new[crc_len];
        for (int i = 0; i < crc_len; i++) begin
            crc_data[i] = pkt.bytes[i];
        end

        return calc_lcrc32(crc_data);
    endfunction

    // Parallel Run Phase: Demux + TX Path + RX Path + DLLP Path + Status Monitor
    task run_phase(uvm_phase phase);
        fork
            demux_phy_tx();
            demux_phy_rx();
            check_tx_path();
            check_rx_path();
            check_tx_dllps();
            check_status_signals();
        join
    endtask

    // 1. Separate outgoing PHY TX stream into TLPs vs ACK/NAK DLLPs
    task demux_phy_tx();
        pcie_phy_seq_item item;
        forever begin
            phy_tx_fifo.get(item);

            cov_phy_seq_item = item;
            cg_phy_pkt.sample();

            if (item.is_tlp)
                phy_tx_tlp_q.push_back(item);
            else
                phy_tx_dllp_q.push_back(item);
        end
    endtask

    // 2. Filter incoming PHY RX stream (keep TLPs for RX check; track valid RX NAK DLLPs)
    task demux_phy_rx();
        pcie_phy_seq_item item;
        forever begin
            phy_rx_fifo.get(item);

            if (item.is_tlp)
                item.corrupt_crc = (item.lcrc !== compute_pkt_lcrc(item));
            else if (item.bytes.size() == 6) begin
                item.corrupt_crc = (item.dllp_crc !== calc_crc16({item.bytes[3], item.bytes[2], item.bytes[1], item.bytes[0]}));
                // [ADDED] Record if a valid NAK DLLP arrived on PHY RX so check_tx_path distinguishes NAK vs Timeout replay
                if (!item.corrupt_crc && (item.dllp_type == 8'h10))
                    nak_seen = 1'b1;
            end

            cov_phy_seq_item = item;
            cg_phy_pkt.sample();

            if (item.is_tlp)
                phy_rx_tlp_q.push_back(item);
        end
    endtask

    // 3. TX Path Verification: handles BOTH fresh TLPs (tl_tx_fifo) AND Replay Buffer retransmissions
    task check_tx_path();
        pcie_tlp_seq_item tlp_tx_xtn;
        pcie_phy_seq_item phy_tx_xtn;
        pcie_phy_seq_item resp;
        bit [31:0] exp_lcrc;

        forever begin
            wait (phy_tx_tlp_q.size() > 0);
            phy_tx_xtn = phy_tx_tlp_q.pop_front();
            exp_lcrc   = compute_pkt_lcrc(phy_tx_xtn);

            // Case A: Fresh TLP from Transaction Layer (seq_num == exp_tx_seq and tl_tx_fifo has an entry)
            if ((phy_tx_xtn.seq_num === exp_tx_seq) && (tl_tx_fifo.try_get(tlp_tx_xtn))) begin
                resp = pcie_phy_seq_item::type_id::create("resp");
                resp.is_tlp  = 1'b0;
                resp.seq_num = phy_tx_xtn.seq_num;

                cov_tlp_seq_item = tlp_tx_xtn;
                cg_tl_tlp.sample();

                // [ADDED] Sample normal fresh TX event
                cov_replay_event = 0;
                cg_dll_events.sample();

                if (phy_tx_xtn.lcrc !== exp_lcrc) begin
                    resp.dllp_type = 8'h10;
                    tx_tlp_err_cnt++;
                    `uvm_error(get_full_name(), $sformatf("[TX] LCRC MISMATCH | seq=%0d exp_lcrc=0x%08h got_lcrc=0x%08h", exp_tx_seq, exp_lcrc, phy_tx_xtn.lcrc))
                end
                else if (phy_tx_xtn.tlp_payload != tlp_tx_xtn.dw_stream) begin
                    resp.dllp_type = 8'h10;
                    tx_tlp_err_cnt++;
                    `uvm_error(get_full_name(), $sformatf("[TX] TLP PAYLOAD MISMATCH | seq=%0d exp_dw_stream=%0d got_dw_stream=%0d", exp_tx_seq, tlp_tx_xtn.dw_stream.size(), phy_tx_xtn.tlp_payload.size()))
                end
                else begin
                    tx_tlp_pass_cnt++;
                    sent_tx_tlps[phy_tx_xtn.seq_num] = phy_tx_xtn; // Save for replay verification
                    `uvm_info(get_full_name(), $sformatf("[TX] TLP MATCHED (LCRC + SEQ + PAYLOAD) | seq=%0d", exp_tx_seq), UVM_LOW)
                    resp.dllp_type = 8'h00;
                    exp_tx_seq = exp_tx_seq + 12'd1;
                end
                dllp_resp_ap.write(resp);
            end
            // Case B: Retransmitted TLP from Replay Buffer (NAK or Replay Timer Timeout)
            else if (sent_tx_tlps.exists(phy_tx_xtn.seq_num)) begin
                // [ADDED] Sample replay trigger reason (1 = NAK retransmit, 2 = Replay timer timeout)
                cov_replay_event = nak_seen ? 1 : 2;
                cg_dll_events.sample();
                nak_seen = 1'b0;

                if ((phy_tx_xtn.lcrc === exp_lcrc) &&
                    (phy_tx_xtn.dw_stream == sent_tx_tlps[phy_tx_xtn.seq_num].dw_stream)) begin
                    tx_replay_pass_cnt++;
                    `uvm_info(get_full_name(), $sformatf("[TX REPLAY] TLP RETRANSMITTED & MATCHED | seq=%0d", phy_tx_xtn.seq_num), UVM_LOW)
                end
                else begin
                    tx_replay_err_cnt++;
                    `uvm_error(get_full_name(), $sformatf("[TX REPLAY] RETRANSMITTED TLP CORRUPTED | seq=%0d", phy_tx_xtn.seq_num))
                end
            end
            // Case C: Unexpected sequence number with no matching TL packet
            else begin
                tx_tlp_err_cnt++;
                `uvm_error(get_full_name(), $sformatf("[TX] UNEXPECTED SEQ NUM | exp_seq=%0d got_seq=%0d", exp_tx_seq, phy_tx_xtn.seq_num))
            end
        end
    endtask

    // 4. RX Path Verification: phy_rx_tlp_q -> tl_rx_fifo
    task check_rx_path();
        pcie_phy_seq_item phy_rx_xtn;
        pcie_tlp_seq_item tlp_rx_xtn;
        bit [31:0] exp_lcrc;

        forever begin
            wait (phy_rx_tlp_q.size() > 0);
            phy_rx_xtn = phy_rx_tlp_q.pop_front();

            exp_lcrc = compute_pkt_lcrc(phy_rx_xtn);

            // Valid RX TLP: LCRC must match AND sequence number must equal NEXT_RCV_SEQ
            if ((phy_rx_xtn.lcrc === exp_lcrc) && (phy_rx_xtn.seq_num === exp_rx_seq)) begin
                tl_rx_fifo.get(tlp_rx_xtn);

                cov_tlp_seq_item = tlp_rx_xtn;
                cg_tl_tlp.sample();

                // [ADDED] Sample in-order RX sequence event
                cov_rx_seq_event = 0;
                cg_dll_events.sample();

                if (tlp_rx_xtn.dw_stream == phy_rx_xtn.tlp_payload) begin
                    rx_tlp_pass_cnt++;
                    `uvm_info(get_full_name(), $sformatf("[RX] TLP MATCHED (Prefix & LCRC stripped cleanly) | seq=%0d", exp_rx_seq), UVM_LOW)
                    exp_rx_seq = exp_rx_seq + 12'd1;
                end
                else begin
                    rx_tlp_err_cnt++;
                    `uvm_error(get_full_name(), $sformatf("[RX] TLP PAYLOAD MISMATCH | seq=%0d exp_dws=%0d got_dws=%0d", exp_rx_seq, phy_rx_xtn.tlp_payload.size(), tlp_rx_xtn.dw_stream.size()))
                end
            end
            else if ((phy_rx_xtn.lcrc === exp_lcrc) && (((exp_rx_seq - phy_rx_xtn.seq_num) & 12'hFFF) <= 12'd2048) && (phy_rx_xtn.seq_num !== exp_rx_seq)) begin
                // Duplicate RX TLP: PCIe spec drops silently and resends ACK without pulsing rx_sequence_error
                rx_dup_drop_cnt++;

                // [ADDED] Sample duplicate RX sequence event
                cov_rx_seq_event = 1;
                cg_dll_events.sample();

                `uvm_info(get_full_name(), $sformatf("[RX] DUPLICATE TLP DROPPED SILENTLY | exp_seq=%0d got_seq=%0d", exp_rx_seq, phy_rx_xtn.seq_num), UVM_LOW)
            end
            else begin
                // Corrupted LCRC or forward out-of-order sequence: must pulse rx_crc_error or rx_sequence_error
                rx_drop_exp_cnt++;

                // [ADDED] Sample out-of-order RX sequence event (when LCRC was valid)
                if (phy_rx_xtn.lcrc === exp_lcrc) begin
                    cov_rx_seq_event = 2;
                    cg_dll_events.sample();
                end

                `uvm_info(get_full_name(), $sformatf("[RX] TLP DROPPED AS EXPECTED | exp_seq=%0d got_seq=%0d exp_lcrc=0x%08h got_lcrc=0x%08h", exp_rx_seq, phy_rx_xtn.seq_num, exp_lcrc, phy_rx_xtn.lcrc), UVM_LOW)
            end
        end
    endtask

    // 5. Verify DUT-generated ACK / NAK DLLPs on PHY TX
    task check_tx_dllps();
        pcie_phy_seq_item dllp_xtn;
        bit [15:0] exp_crc16;

        forever begin
            wait (phy_tx_dllp_q.size() > 0);
            dllp_xtn = phy_tx_dllp_q.pop_front();

            if (dllp_xtn.bytes.size() == 6) begin
                exp_crc16 = calc_crc16({dllp_xtn.bytes[3], dllp_xtn.bytes[2], dllp_xtn.bytes[1], dllp_xtn.bytes[0]});
                if (dllp_xtn.dllp_crc === exp_crc16) begin
                    dllp_pass_cnt++;
                    `uvm_info(get_full_name(), $sformatf("[DLLP TX] %s DLLP VALID | seq=%0d crc16=0x%04h", (dllp_xtn.dllp_type == 8'h00) ? "ACK" : (dllp_xtn.dllp_type == 8'h10) ? "NAK" : "UNKNOWN", dllp_xtn.seq_num, dllp_xtn.dllp_crc), UVM_LOW)
                end
                else begin
                    dllp_err_cnt++;
                    `uvm_error(get_full_name(), $sformatf("[DLLP TX] CRC-16 MISMATCH | exp=0x%04h got=0x%04h", exp_crc16, dllp_xtn.dllp_crc))
                end
            end
            else begin
                dllp_err_cnt++;
                `uvm_error(get_full_name(), $sformatf("[DLLP TX] INVALID LENGTH | exp=6 bytes, got=%0d bytes", dllp_xtn.bytes.size()))
            end
        end
    endtask

    // 6. Monitor DUT Status Outputs via status_vif.status_cb
    task check_status_signals();
        if (status_vif == null) return;

        forever begin
            @(status_vif.status_cb);
            if (!status_vif.rst_n) begin
                // During reset, all status outputs must remain deasserted (0)
                if (status_vif.status_cb.tx_busy ||
                    status_vif.status_cb.tx_error ||
                    status_vif.status_cb.rx_sequence_error ||
                    status_vif.status_cb.rx_crc_error ||
                    status_vif.status_cb.dllp_crc_error) begin
                    status_err_cnt++;
                    `uvm_error(get_full_name(), "[STATUS] Non-zero status output asserted during active reset!")
                end
            end
            else begin
                // Count active status pulses and flag unexpected tx_error
                if (status_vif.status_cb.rx_crc_error) begin
                    rx_crc_err_pulse_cnt++;
                    `uvm_info(get_full_name(), "[STATUS] rx_crc_error pulse observed", UVM_MEDIUM)
                end
                if (status_vif.status_cb.rx_sequence_error) begin
                    rx_seq_err_pulse_cnt++;
                    `uvm_info(get_full_name(), "[STATUS] rx_sequence_error pulse observed", UVM_MEDIUM)
                end
                if (status_vif.status_cb.dllp_crc_error) begin
                    dllp_crc_err_pulse_cnt++;
                    `uvm_info(get_full_name(), "[STATUS] dllp_crc_error pulse observed", UVM_MEDIUM)
                end
                if (status_vif.status_cb.tx_error) begin
                    tx_err_pulse_cnt++;
                    status_err_cnt++;
                    `uvm_error(get_full_name(), "[STATUS] Unexpected tx_error asserted by DUT!")
                end
            end
        end
    endtask

    // Report Phase Summary
    function void report_phase(uvm_phase phase);
        super.report_phase(phase);

        // Cross-check dropped RX packets against observed rx_crc_error + rx_sequence_error pulses
        if ((status_vif != null) && ((rx_crc_err_pulse_cnt + rx_seq_err_pulse_cnt) != rx_drop_exp_cnt)) 
        begin
            `uvm_error(get_full_name(), $sformatf("[STATUS] RX Error Pulse Mismatch: rx_crc_error(%0d) + rx_sequence_error(%0d) != Dropped RX TLPs(%0d)",
                rx_crc_err_pulse_cnt, rx_seq_err_pulse_cnt, rx_drop_exp_cnt))
        end

        `uvm_info(get_full_name(), $sformatf("\n==================== SCOREBOARD SUMMARY ====================\n  TX TLPs Passed    : %0d | Failed : %0d\n  TX Replays Passed : %0d | Failed : %0d\n  RX TLPs Passed    : %0d | Failed : %0d | Dropped(Err): %0d | Dup: %0d\n  TX DLLPs Passed   : %0d | Failed : %0d\n  Status Pulses     : rx_crc_err=%0d, rx_seq_err=%0d, dllp_crc_err=%0d, status_err=%0d\n============================================================",
            tx_tlp_pass_cnt, tx_tlp_err_cnt,
            tx_replay_pass_cnt, tx_replay_err_cnt,
            rx_tlp_pass_cnt, rx_tlp_err_cnt, rx_drop_exp_cnt, rx_dup_drop_cnt,
            dllp_pass_cnt, dllp_err_cnt,
            rx_crc_err_pulse_cnt, rx_seq_err_pulse_cnt, dllp_crc_err_pulse_cnt, status_err_cnt), UVM_NONE)

        // [UPDATED] Print all 3 covergroups
        `uvm_info(get_full_name(), $sformatf("FUNCTIONAL COVERAGE | cg_tl_tlp = %0.2f%% | cg_phy_pkt = %0.2f%% | cg_dll_events = %0.2f%%",
            cg_tl_tlp.get_coverage(), cg_phy_pkt.get_coverage(), cg_dll_events.get_coverage()), UVM_NONE)

    endfunction

endclass
`endif