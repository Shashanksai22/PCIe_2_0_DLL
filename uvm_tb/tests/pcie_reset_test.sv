`ifndef PCIE_RESET_TEST
`define PCIE_RESET_TEST

class pcie_reset_test extends pcie_dll_base_test;
	`uvm_component_utils(pcie_reset_test)

    function new(string name = "pcie_reset_test",uvm_component parent);
	    super.new(name,parent);
    endfunction

    task run_phase(uvm_phase phase);

        reset_test_seq seq;

        phase.raise_objection(this);

        seq = reset_test_seq::type_id::create("seq");
        seq.start(env.tl_tx_agt.tl_tx_seqr);

        phase.drop_objection(this);

    endtask

endclass

`endif