`ifndef PCIE_DLL_IF
`define PCIE_DLL_IF

interface pcie_dll_if(input bit clk);

    parameter int DATA_W       = 32;
    parameter int SEQ_W        = 12;
    parameter int MAX_PKT_DW   = 1024;
    parameter int REPLAY_DEPTH = 8;
    parameter int REPLAY_TIMEOUT_CYCLES = 1024;

    logic             rst_n;

    // Transaction Layer TX
    logic[DATA_W-1:0] tl_tx_data;
    logic             tl_tx_valid;
    logic             tl_tx_ready;
    logic             tl_tx_sop;
    logic             tl_tx_eop;
    logic[3:0]        tl_tx_keep;

    // Transaction Layer RX
    logic[DATA_W-1:0] tl_rx_data;
    logic[3:0]        tl_rx_keep;
    logic             tl_rx_valid;
    logic             tl_rx_ready;
    logic             tl_rx_sop;
    logic             tl_rx_eop;

    // PHY TX
    logic[DATA_W-1:0] phy_tx_data;
    logic[3:0]        phy_tx_keep;
    logic             phy_tx_valid;
    logic             phy_tx_ready;
    logic             phy_tx_sop;
    logic             phy_tx_eop;
    logic             phy_tx_is_tlp;

    // PHY RX
    logic[DATA_W-1:0] phy_rx_data;
    logic[3:0]        phy_rx_keep;
    logic             phy_rx_valid;
    logic             phy_rx_sop;
    logic             phy_rx_eop;
    logic             phy_rx_is_tlp;
    logic             phy_rx_ready;

    // Status
    logic             tx_busy;
    logic             tx_error;
    logic             rx_sequence_error;
    logic             rx_crc_error;
    logic             dllp_crc_error;

    //internal signals
    logic [11:0] dbg_curr_seq;
    logic [11:0] dbg_next_seq;

    clocking tl_tx_cb  @(posedge clk);
	    default input #1step output #1step;

	     output  tl_tx_data, tl_tx_valid, tl_tx_sop, tl_tx_eop, tl_tx_keep;

	     input   tl_tx_ready; 

    endclocking

    clocking tl_rx_cb  @(posedge clk);
	    default input #1step output #1step; 

	     input   tl_rx_data, tl_rx_valid, tl_rx_sop, tl_rx_eop, tl_rx_keep;

	     output  tl_rx_ready; 

    endclocking

    clocking phy_tx_cb  @(posedge clk);
	    default input #1step output #1step; 

	     input    phy_tx_data, phy_tx_valid, phy_tx_sop, phy_tx_eop, phy_tx_keep, phy_tx_is_tlp;

	     output   phy_tx_ready; 

    endclocking

    clocking phy_rx_cb  @(posedge clk);
	    default input #1step output #1step; 

	     output   phy_rx_data, phy_rx_valid, phy_rx_sop, phy_rx_eop, phy_rx_keep, phy_rx_is_tlp;

         input    phy_rx_ready;

    endclocking

    clocking tl_tx_mcb  @(posedge clk);
	    default input #1step output #1step;

	     input  tl_tx_data, tl_tx_valid, tl_tx_sop, tl_tx_eop, tl_tx_keep, tl_tx_ready; 

    endclocking

    clocking tl_rx_mcb  @(posedge clk);
	    default input #1step output #1step; 

	     input   tl_rx_data, tl_rx_valid, tl_rx_sop, tl_rx_eop, tl_rx_keep, tl_rx_ready; 

    endclocking

    clocking phy_tx_mcb  @(posedge clk);
	    default input #1step output #1step; 

	     input    phy_tx_data, phy_tx_valid, phy_tx_sop, phy_tx_eop, phy_tx_keep, phy_tx_is_tlp, phy_tx_ready; 

    endclocking

    clocking phy_rx_mcb  @(posedge clk);
	    default input #1step output #1step; 

	     input   phy_rx_data, phy_rx_valid, phy_rx_sop, phy_rx_eop, phy_rx_keep, phy_rx_is_tlp;

    endclocking

    clocking status_cb @(posedge clk);
        default input #1step output #1step;
        input tx_busy, tx_error, rx_sequence_error, rx_crc_error, dllp_crc_error;
    endclocking


    modport TL_TX   (clocking tl_tx_cb,  input rst_n);
    modport TL_RX   (clocking tl_rx_cb,  input rst_n);
    modport PHY_TX  (clocking phy_tx_cb, input rst_n);
    modport PHY_RX  (clocking phy_rx_cb, input rst_n);
    modport TL_MTX  (clocking tl_tx_mcb,  input rst_n);
    modport TL_MRX  (clocking tl_rx_mcb,  input rst_n);
    modport PHY_MTX (clocking phy_tx_mcb, input rst_n);
    modport PHY_MRX (clocking phy_rx_mcb, input rst_n);
    modport STATUS  (clocking status_cb, input rst_n);



    // =========================================================================
    // SystemVerilog Assertions (SVA) for PCIe 2.0 Data Link Layer Interface
    // =========================================================================

    // ------------------------- 1. Property Definitions -------------------------
   // 1. Reset Behavior: All valid flags & status outputs must be 0 when rst_n is low
    property p_reset_outputs_low;
        @(posedge clk) !rst_n |-> (!tl_rx_valid && !phy_tx_valid &&
                                   !tx_busy && !tx_error &&
                                   !rx_sequence_error && !rx_crc_error && !dllp_crc_error);
    endproperty

    // 2. TL TX AXI-Stream Stability: Data/SOP/EOP must stay stable while stalled (valid && !ready)
    property p_tl_tx_stable_when_stalled;
        @(posedge clk) disable iff (!rst_n)
        (tl_tx_valid && !tl_tx_ready) |=> (tl_tx_valid && $stable(tl_tx_data) &&
                                           $stable(tl_tx_sop) && $stable(tl_tx_eop));
    endproperty

    // 3. PHY TX Stability: Data/SOP/EOP/is_dllp must stay stable while PHY backpressures (valid && !ready)
    property p_phy_tx_stable_when_stalled;
        @(posedge clk) disable iff (!rst_n)
        (phy_tx_valid && !phy_tx_ready) |=> (phy_tx_valid && $stable(phy_tx_data) &&
                                             $stable(phy_tx_sop) && $stable(phy_tx_eop) &&
                                             $stable(phy_tx_is_tlp));
    endproperty

    // 4. TL RX Stability: Data/SOP/EOP must stay stable while TL backpressures (valid && !ready)
    property p_tl_rx_stable_when_stalled;
        @(posedge clk) disable iff (!rst_n)
        (tl_rx_valid && !tl_rx_ready) |=> (tl_rx_valid && $stable(tl_rx_data) &&
                                           $stable(tl_rx_sop) && $stable(tl_rx_eop));
    endproperty

    // 5. PHY TX DLLP Framing: A 6-byte DLLP on a 32-bit bus starts with SOP && !EOP
    //    and finishes on the very next accepted beat with !SOP && EOP
    property p_phy_tx_dllp_two_beats;
        @(posedge clk) disable iff (!rst_n)
        (phy_tx_valid && phy_tx_ready && !phy_tx_is_tlp && phy_tx_sop) |->
        (!phy_tx_eop ##1 (phy_tx_valid && phy_tx_ready)[->1] ##0 (!phy_tx_is_tlp && !phy_tx_sop && phy_tx_eop));
    endproperty

    // 6. Error Pulse Width: rx_crc_error, rx_sequence_error, and dllp_crc_error must be single-cycle pulses
    property p_err_pulses_single_cycle;
        @(posedge clk) disable iff (!rst_n)
        (rx_crc_error || rx_sequence_error || dllp_crc_error) |=>
        (!rx_crc_error && !rx_sequence_error && !dllp_crc_error);
    endproperty

    // 7. RX Error Mutual Exclusion: rx_crc_error and rx_sequence_error must not assert simultaneously
    property p_rx_err_mutex;
        @(posedge clk) disable iff (!rst_n)
        (rx_crc_error || rx_sequence_error) |-> !(rx_crc_error && rx_sequence_error);
    endproperty

    // 8. No X/Z on Control & Status Signals out of Reset
    property p_no_unknown_ctrl;
        @(posedge clk) disable iff (!rst_n)
        !$isunknown({tl_tx_valid, tl_tx_ready, tl_rx_valid, tl_rx_ready,
                     phy_tx_valid, phy_tx_ready, phy_rx_valid, phy_rx_ready,
                     tx_busy, tx_error, rx_crc_error, rx_sequence_error, dllp_crc_error});
    endproperty

    // ------------------------- 2. Assert Properties --------------------------
    a_reset_outputs_low: assert property (p_reset_outputs_low)
        else $error("[SVA] Non-zero output asserted during active reset!");

    a_tl_tx_stable_when_stalled: assert property (p_tl_tx_stable_when_stalled)
        else $error("[SVA] TL TX changed data/sop/eop while tl_tx_ready was low!");

    a_phy_tx_stable_when_stalled: assert property (p_phy_tx_stable_when_stalled)
        else $error("[SVA] PHY TX changed packet signals while phy_tx_ready was low!");

    a_tl_rx_stable_when_stalled: assert property (p_tl_rx_stable_when_stalled)
        else $error("[SVA] TL RX changed data/sop/eop while tl_rx_ready was low!");

    a_phy_tx_dllp_two_beats: assert property (p_phy_tx_dllp_two_beats)
        else $error("[SVA] PHY TX DLLP must span exactly 2 accepted beats (SOP -> EOP)!");

    a_err_pulses_single_cycle: assert property (p_err_pulses_single_cycle)
        else $error("[SVA] DLL error pulse lasted more than 1 clock cycle!");

    a_rx_err_mutex: assert property (p_rx_err_mutex)
        else $error("[SVA] rx_crc_error and rx_sequence_error asserted simultaneously!");

    a_no_unknown_ctrl: assert property (p_no_unknown_ctrl)
        else $error("[SVA] Unknown (X/Z) detected on DLL control/status signals!");

    // ------------------------- 3. Cover Properties ---------------------------
    c_reset_outputs_low         : cover property (p_reset_outputs_low);
    c_tl_tx_stable_when_stalled : cover property (p_tl_tx_stable_when_stalled);
    c_phy_tx_stable_when_stalled: cover property (p_phy_tx_stable_when_stalled);
    c_tl_rx_stable_when_stalled : cover property (p_tl_rx_stable_when_stalled);
    c_phy_tx_dllp_two_beats     : cover property (p_phy_tx_dllp_two_beats);
    c_err_pulses_single_cycle   : cover property (p_err_pulses_single_cycle);
    c_rx_err_mutex              : cover property (p_rx_err_mutex);
    c_no_unknown_ctrl           : cover property (p_no_unknown_ctrl);

endinterface
`endif