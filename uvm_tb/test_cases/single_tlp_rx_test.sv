`ifndef SINGLE_TLP_TX_TEST
`define SINGLE_TLP_TX_TEST

class single_tlp_rx_test extends pcie_dll_base_test;
	`uvm_component_utils(single_tlp_rx_test)

    function new(string name = "single_tlp_rx_test",uvm_component parent);
	    super.new(name,parent);
    endfunction

    task run_phase(uvm_phase phase);

        single_tlp_rx_vseq seq;
        phase.raise_objection(this);

        seq = single_tlp_rx_vseq::type_id::create("seq");
        seq.start(env.v_seqr);
        #2500;
        phase.drop_objection(this);

    endtask

endclass
`endif