`ifndef reset_sanity_test
`define reset_sanity_test

class reset_sanity_test extends pcie_dll_base_test;
	`uvm_component_utils(reset_sanity_test)

    function new(string name = "reset_sanity_test",uvm_component parent);
	    super.new(name,parent);
    endfunction

    task run_phase(uvm_phase phase);
        reset_sanity_vseq seq;

        super.run_phase(phase);
        phase.raise_objection(this);
        seq = reset_sanity_vseq::type_id::create("seq");
        seq.start(env.v_seqr);
        #2500;
        phase.drop_objection(this);

    endtask

endclass
`endif 