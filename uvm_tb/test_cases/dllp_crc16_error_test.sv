`ifndef dllp_crc16_error_test
`define dllp_crc16_error_test

class dllp_crc16_error_test extends pcie_dll_base_test;
	`uvm_component_utils(dllp_crc16_error_test)

    function new(string name = "dllp_crc16_error_test",uvm_component parent);
	    super.new(name,parent);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
	  super.end_of_elaboration_phase(phase);
	  cfg.enable_auto_ack = 0;
	endfunction

    task run_phase(uvm_phase phase);
        dllp_crc16_error_vseq seq;

        super.run_phase(phase);

        phase.raise_objection(this);
        seq = dllp_crc16_error_vseq::type_id::create("seq");
        seq.start(env.v_seqr);
        #2500;
        phase.drop_objection(this);

    endtask

endclass
`endif 