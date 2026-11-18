`ifndef BASIC_PHY_RX_TEST
`define BASIC_PHY_RX_TEST

class basic_phy_rx_test extends pcie_dll_base_test;
	`uvm_component_utils(basic_phy_rx_test)

    function new(string name = "basic_phy_tr_test",uvm_component parent);
	    super.new(name,parent);
    endfunction

    task run_phase(uvm_phase phase);

        basic_phy_rx_seq seq;
        phase.raise_objection(this);

        seq = basic_phy_rx_seq::type_id::create("seq");
        seq.start(env.phy_rx_agt.phy_rx_seqr);
        #100;
        phase.drop_objection(this);

    endtask

endclass
`endif