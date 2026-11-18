`ifndef seq_num_rollover_test
`define seq_num_rollover_test

class seq_num_rollover_test extends pcie_dll_base_test;
	`uvm_component_utils(seq_num_rollover_test)

    function new(string name = "seq_num_rollover_test",uvm_component parent);
	    super.new(name,parent);
    endfunction

    task run_phase(uvm_phase phase);
        seq_num_rollover_vseq seq;

        super.run_phase(phase);
        phase.raise_objection(this);
        seq = seq_num_rollover_vseq::type_id::create("seq");
        seq.start(env.v_seqr);
        #2500;
        phase.drop_objection(this);

    endtask

endclass
`endif 