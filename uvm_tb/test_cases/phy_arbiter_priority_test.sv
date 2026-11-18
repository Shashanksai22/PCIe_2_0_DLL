`ifndef phy_arbiter_priority_test
`define phy_arbiter_priority_test

class phy_arbiter_priority_test extends pcie_dll_base_test;
	`uvm_component_utils(phy_arbiter_priority_test)

    function new(string name = "phy_arbiter_priority_test",uvm_component parent);
	    super.new(name,parent);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
	  super.end_of_elaboration_phase(phase);
	  cfg.enable_auto_ack = 0;
	endfunction

    task run_phase(uvm_phase phase);
        phy_arbiter_priority_vseq seq;

        super.run_phase(phase);
        cfg.enable_auto_ack = 0;
        phase.raise_objection(this);
        seq = phy_arbiter_priority_vseq::type_id::create("seq");
        seq.start(env.v_seqr);
        #2500;
        phase.drop_objection(this);

    endtask

endclass
`endif 