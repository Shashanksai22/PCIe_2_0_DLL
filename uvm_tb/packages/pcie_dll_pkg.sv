`ifndef PCIE_DLL_PKG_SV
`define PCIE_DLL_PKG_SV

package pcie_dll_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // 1. Configuration & Sequence Items
    `include "pcie_dll_config.sv"
    `include "pcie_tlp_seq_item.sv"
    `include "pcie_phy_seq_item.sv"

    // 2. Agent Sub-components (Drivers, Monitors, Sequencers)
    `include "pcie_tl_tx_drv.sv"
    `include "pcie_tl_tx_mon.sv"
    `include "pcie_tl_tx_seqr.sv"

    `include "pcie_tl_rx_drv.sv"
    `include "pcie_tl_rx_mon.sv"
    `include "pcie_tl_rx_seqr.sv"

    `include "pcie_phy_tx_drv.sv"
    `include "pcie_phy_tx_mon.sv"
    `include "pcie_phy_tx_seqr.sv"

    `include "pcie_phy_rx_drv.sv"
    `include "pcie_phy_rx_mon.sv"
    `include "pcie_phy_rx_seqr.sv"

    // 3. Agents
    `include "pcie_tl_tx_agt.sv"
    `include "pcie_tl_rx_agt.sv"
    `include "pcie_phy_tx_agt.sv"
    `include "pcie_phy_rx_agt.sv"

    // 4. Environment Components & Top Env
    `include "pcie_dll_scoreboard.sv"
    `include "pcie_dll_v_seqr.sv"
    `include "pcie_dll_env.sv"

    // 5. Sequences (Must be included BEFORE Tests)
    `include "reset_test_seq.sv"
    `include "phy_rx_dllp_resp_seq.sv"
    `include "reset_phy_seq.sv"
    `include "basic_tlp_tx_seq.sv"
    `include "multiples_tlp_tx_seq.sv"
    `include "basic_phy_rx_seq.sv"

    // V SEQ
    `include "pcie_base_vseq.sv"
    `include "reset_sanity_vseq.sv"
    `include "single_tlp_tx_vseq.sv" 
    `include "multiple_tlp_tx_vseq.sv"
    `include "single_tlp_rx_vseq.sv"
    `include "multiple_tlp_rx_vseq.sv"
    `include "rx_lcrc_error_nak_vseq.sv"
    `include "rx_duplicate_vseq.sv"
    `include "rx_out_of_order_vseq.sv"
    `include "tx_nak_retransmit_vseq.sv"
    `include "tx_replay_timeout_vseq.sv"
    `include "cumulative_ack_vseq.sv"
    `include "dllp_crc16_error_vseq.sv"
    `include "phy_arbiter_priority_vseq.sv"
    `include "backpressure_stall_vseq.sv"
    `include "replay_buffer_full_vseq.sv"
    `include "seq_num_rollover_vseq.sv"
    `include "max_payload_1024dw_vseq.sv"
    `include "full_duplex_random_regression_vseq.sv"


    // 6. Tests
    `include "pcie_dll_base_test.sv"
    `include "pcie_reset_test.sv"
    `include "basic_tlp_tx_test.sv"
    `include "multiples_tlp_tx_test.sv"
    `include "basic_phy_rx_test.sv"

    //TESTCASES

    `include "reset_sanity_test.sv"
    `include "single_tlp_tx_test.sv"
    `include "multiple_tlp_tx_test.sv"
    `include "single_tlp_rx_test.sv"
    `include "multiple_tlp_rx_test.sv"
    `include "rx_lcrc_error_nak_test.sv"
    `include "rx_duplicate_seq_test.sv"
    `include "rx_out_of_order_seq_test.sv"
    `include "tx_nak_retransmit_test.sv"
    `include "tx_replay_timeout_test.sv"
    `include "cumulative_ack_test.sv"
    `include "dllp_crc16_error_test.sv"
    `include "phy_arbiter_priority_test.sv"
    `include "backpressure_stall_test.sv"
    `include "replay_buffer_full_test.sv"
    `include "seq_num_rollover_test.sv"
    `include "max_payload_1024dw_test.sv"
    `include "full_duplex_random_regression_test.sv"

endpackage
`endif