`ifndef PCIE_DLL_CONFIG
`define PCIE_DLL_CONFIG

class pcie_dll_config extends uvm_object;
	`uvm_object_utils(pcie_dll_config)

    // Virtual Interface
    virtual pcie_dll_if vif;

    // 1. Per-Agent Mode Controls
    uvm_active_passive_enum tl_tx_is_active  = UVM_ACTIVE;
    uvm_active_passive_enum tl_rx_is_active  = UVM_ACTIVE;
    uvm_active_passive_enum phy_tx_is_active = UVM_ACTIVE;
    uvm_active_passive_enum phy_rx_is_active = UVM_ACTIVE;

    // 2. DUT Parameters (Match pcie_dl_top)
    int seq_width             = 12;
    int replay_depth          = 8;
    int replay_timeout_cycles = 1024;
    int max_pkt_dw            = 1024;

    // 3. Testbench & Protocol Knobs
    bit has_scoreboard        = 1;
    bit has_coverage          = 1;
    bit enable_auto_ack       = 1;


    function new(string name = "pcie_dll_config");
	    super.new(name);
    endfunction

endclass
`endif
