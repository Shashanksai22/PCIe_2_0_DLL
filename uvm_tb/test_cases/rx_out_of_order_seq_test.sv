`ifndef rx_out_of_order_seq_test
`define rx_out_of_order_seq_test

class rx_out_of_order_seq_test extends pcie_dll_base_test;
	`uvm_component_utils(rx_out_of_order_seq_test)

    function new(string name = "rx_out_of_order_seq_test",uvm_component parent);
	    super.new(name,parent);
    endfunction

    task run_phase(uvm_phase phase);
        rx_out_of_order_vseq seq;

        super.run_phase(phase);
        phase.raise_objection(this);
        seq = rx_out_of_order_vseq::type_id::create("seq");
        seq.start(env.v_seqr);
        #2500;
        phase.drop_objection(this);

    endtask

endclass
`endif 