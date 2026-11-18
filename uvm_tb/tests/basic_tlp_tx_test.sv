`ifndef BASIC_TLP_TX_TEST
`define BASIC_TLP_TX_TEST

class basic_tlp_tx_test extends pcie_dll_base_test;
	`uvm_component_utils(basic_tlp_tx_test)

    function new(string name = "basic_tlp_tx_test",uvm_component parent);
	    super.new(name,parent);
    endfunction

    task run_phase(uvm_phase phase);

        basic_tlp_tx_seq seq;
        phase.raise_objection(this);

        seq = basic_tlp_tx_seq::type_id::create("seq");
        seq.start(env.tl_tx_agt.tl_tx_seqr);
        #2500;
        phase.drop_objection(this);

    endtask

endclass
`endif