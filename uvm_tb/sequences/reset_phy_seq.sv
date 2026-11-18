`ifndef RESET_PHY_SEQ
`define RESET_PHY_SEQ
class reset_phy_seq extends uvm_sequence#(pcie_phy_seq_item);
    `uvm_object_utils(reset_phy_seq);

    //  Group: Variables
    virtual pcie_dll_if vif;
    pcie_dll_config cfg;

    //  Constructor: new
    function new(string name = "reset_phy_seq");
        super.new(name);
    endfunction

    task body();

        if(!uvm_config_db #(pcie_dll_config) ::get(m_sequencer,"","pcie_dll_config",cfg))
		  `uvm_error(get_type_name,"NOT GETTING CONFIG IN reset_phy_seq")
        
        vif = cfg.vif;

        `uvm_info("RESET", "Reset sequence starts", UVM_LOW)

        vif.rst_n = 0;
        repeat (5) @(posedge vif.clk);

        vif.rst_n = 1;
        repeat (5) @(posedge vif.clk);

        `uvm_info("RESET", "Reset sequence completed", UVM_LOW)
    endtask
    
endclass
`endif