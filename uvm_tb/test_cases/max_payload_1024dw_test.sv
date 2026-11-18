`ifndef max_payload_1024dw_test
`define max_payload_1024dw_test

class max_payload_1024dw_test extends pcie_dll_base_test;
	`uvm_component_utils(max_payload_1024dw_test)

    function new(string name = "max_payload_1024dw_test",uvm_component parent);
	    super.new(name,parent);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
	  super.end_of_elaboration_phase(phase);
	  cfg.enable_auto_ack = 0;
	endfunction

    task run_phase(uvm_phase phase);
        max_payload_1024dw_vseq seq;

        super.run_phase(phase);
        cfg.enable_auto_ack = 0;
        phase.raise_objection(this);
        seq = max_payload_1024dw_vseq::type_id::create("seq");
        seq.start(env.v_seqr);
        #2500;
        phase.drop_objection(this);

    endtask

endclass
`endif 