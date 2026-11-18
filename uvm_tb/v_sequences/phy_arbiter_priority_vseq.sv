`ifndef phy_arbiter_priority_vseq
`define phy_arbiter_priority_vseq

class phy_arbiter_priority_seq extends uvm_sequence#(pcie_tlp_seq_item);
    `uvm_object_utils(phy_arbiter_priority_seq);
    
    //  Constructor: new
    function new(string name = "phy_arbiter_priority_seq");
        super.new(name);
    endfunction: new

    task body();

        `uvm_info(get_type_name, "phy_arbiter_priority_seq starts", UVM_LOW)

        for(int i=0; i<2; i++)
        begin
        req = pcie_tlp_seq_item::type_id::create("req");
        start_item(req);
        assert(req.randomize() with { req.payload.size() inside {[1:5]}; } != 0);
        `uvm_info(get_type_name(), $sformatf("Generated TLP:\n%s", req.sprint()), UVM_LOW)
        finish_item(req);
        #200;
        end
        
        `uvm_info(get_type_name, "phy_arbiter_priority_seq completed", UVM_LOW)

    endtask
    
endclass

class phy_arbiter_priority_seq0 extends uvm_sequence#(pcie_phy_seq_item);
    `uvm_object_utils(phy_arbiter_priority_seq0);
    
    //  Constructor: new
    function new(string name = "phy_arbiter_priority_seq0");
        super.new(name);
    endfunction: new

    task body();

        `uvm_info(get_type_name, "phy_arbiter_priority_seq0 starts", UVM_LOW)
        #160;
        req = pcie_phy_seq_item::type_id::create("req");
        start_item(req);
        assert(req.randomize() with {req.is_tlp == 0; req.seq_num == 2; req.dllp_type == 8'H010; });
        `uvm_info(get_type_name(), $sformatf("Generated TLP:\n%s", req.sprint()), UVM_LOW)
        finish_item(req);

        req = pcie_phy_seq_item::type_id::create("req");
        start_item(req);
        assert(req.randomize() with {req.is_tlp == 1; req.seq_num == 0; req.corrupt_crc == 0; req.tlp_payload.size() == 8; });
        `uvm_info(get_type_name(), $sformatf("Generated TLP:\n%s", req.sprint()), UVM_LOW)
        finish_item(req);
        
        #200;
        `uvm_info(get_type_name, "phy_arbiter_priority_seq0 completed", UVM_LOW)

    endtask
    
endclass

class phy_arbiter_priority_vseq extends pcie_base_vseq;
    `uvm_object_utils(phy_arbiter_priority_vseq);

    phy_arbiter_priority_seq  seq;
    phy_arbiter_priority_seq0  seq0;
    reset_sanity_seq  reset_seq;

    //  Constructor: new
    function new(string name = "phy_arbiter_priority_vseq");
        super.new(name);
    endfunction: new

    
    task body();
        
        super.body();

       seq       = phy_arbiter_priority_seq::type_id::create("seq");
       seq0      = phy_arbiter_priority_seq0::type_id::create("seq0");
       reset_seq = reset_sanity_seq::type_id::create("reset_seq");
       reset_seq.start(tl_tx_seqr);
       fork
       seq.start(tl_tx_seqr);
       seq0.start(phy_rx_seqr);
       join

    endtask
    
endclass
`endif