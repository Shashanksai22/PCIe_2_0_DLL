`ifndef full_duplex_random_regression_test
`define full_duplex_random_regression_test

class full_duplex_random_regression_test extends pcie_dll_base_test;
	`uvm_component_utils(full_duplex_random_regression_test)

    function new(string name = "full_duplex_random_regression_test",uvm_component parent);
	    super.new(name,parent);
    endfunction

    task run_phase(uvm_phase phase);
        full_duplex_random_regression_vseq seq;

        super.run_phase(phase);
        phase.raise_objection(this);
        seq = full_duplex_random_regression_vseq::type_id::create("seq");
        seq.start(env.v_seqr);
        #2500;
        phase.drop_objection(this);

    endtask

endclass
`endif 