`ifndef backpressure_stall_test
`define backpressure_stall_test

class backpressure_stall_test extends pcie_dll_base_test;
	`uvm_component_utils(backpressure_stall_test)

    function new(string name = "backpressure_stall_test",uvm_component parent);
	    super.new(name,parent);
    endfunction

    task run_phase(uvm_phase phase);
        
        backpressure_stall_vseq seq;

        super.run_phase(phase);
        cfg.enable_auto_ack = 0;
        phase.raise_objection(this);
        seq = backpressure_stall_vseq::type_id::create("seq");
        seq.start(env.v_seqr);
        #2500;
        phase.drop_objection(this);

    endtask

endclass
`endif 