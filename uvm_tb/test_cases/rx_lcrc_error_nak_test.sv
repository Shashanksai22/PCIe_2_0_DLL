`ifndef rx_lcrc_error_nak_test
`define rx_lcrc_error_nak_test

class rx_lcrc_error_nak_test extends pcie_dll_base_test;
	`uvm_component_utils(rx_lcrc_error_nak_test)

    function new(string name = "rx_lcrc_error_nak_test",uvm_component parent);
	    super.new(name,parent);
    endfunction

    task run_phase(uvm_phase phase);
        rx_lcrc_error_nak_vseq seq;

        super.run_phase(phase);
        phase.raise_objection(this);
        seq = rx_lcrc_error_nak_vseq::type_id::create("seq");
        seq.start(env.v_seqr);
        #2500;
        phase.drop_objection(this);

    endtask

endclass
`endif 