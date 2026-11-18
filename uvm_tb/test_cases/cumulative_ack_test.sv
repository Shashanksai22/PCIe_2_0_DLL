`ifndef cumulative_ack_test
`define cumulative_ack_test

class cumulative_ack_test extends pcie_dll_base_test;
	`uvm_component_utils(cumulative_ack_test)

    function new(string name = "cumulative_ack_test",uvm_component parent);
	    super.new(name,parent);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
	  super.end_of_elaboration_phase(phase);
	  cfg.enable_auto_ack = 0;
	endfunction

    task run_phase(uvm_phase phase);
        cumulative_ack_vseq seq;

        super.run_phase(phase);

        phase.raise_objection(this);
        seq = cumulative_ack_vseq::type_id::create("seq");
        seq.start(env.v_seqr);
        #2500;
        phase.drop_objection(this);

    endtask

endclass
`endif 