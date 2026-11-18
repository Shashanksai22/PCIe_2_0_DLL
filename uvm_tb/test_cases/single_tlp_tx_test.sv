`ifndef single_tlp_tx_test
`define single_tlp_tx_test

class single_tlp_tx_test extends pcie_dll_base_test;
	`uvm_component_utils(single_tlp_tx_test)

    function new(string name = "single_tlp_tx_test",uvm_component parent);
	    super.new(name,parent);
    endfunction

    task run_phase(uvm_phase phase);
        single_tlp_tx_vseq seq;

        super.run_phase(phase);
        phase.raise_objection(this);
        seq = single_tlp_tx_vseq::type_id::create("seq");
        seq.start(env.v_seqr);
        #2500;
        phase.drop_objection(this);

    endtask

endclass
`endif 