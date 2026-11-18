`ifndef cumulative_ack_vseq
`define cumulative_ack_vseq

class cumulative_ack_seq extends uvm_sequence#(pcie_tlp_seq_item);
    `uvm_object_utils(cumulative_ack_seq);
    
    //  Constructor: new
    function new(string name = "cumulative_ack_seq");
        super.new(name);
    endfunction: new

    task body();

        pcie_phy_seq_item saved_pkt;

        `uvm_info(get_type_name, "cumulative_ack_seq starts", UVM_LOW)

        for(int i=0; i<4; i++)
        begin
        req = pcie_tlp_seq_item::type_id::create("req");
        start_item(req);
        assert(req.randomize() with { req.payload.size() inside {[1:5]}; } != 0);
        `uvm_info(get_type_name(), $sformatf("Generated TLP:\n%s", req.sprint()), UVM_LOW)
        finish_item(req);
        end
        
        #200;
        `uvm_info(get_type_name, "cumulative_ack_seq completed", UVM_LOW)

    endtask
    
endclass

class cumulative_nck_seq extends uvm_sequence#(pcie_phy_seq_item);
    `uvm_object_utils(cumulative_nck_seq);
    
    //  Constructor: new
    function new(string name = "cumulative_nck_seq");
        super.new(name);
    endfunction: new

    task body();

        `uvm_info(get_type_name, "cumulative_nck_seq starts", UVM_LOW)

        req = pcie_phy_seq_item::type_id::create("req");
        start_item(req);
        assert(req.randomize() with {req.is_tlp == 0; req.seq_num == 2; req.dllp_type == 0; });
        `uvm_info(get_type_name(), $sformatf("Generated TLP:\n%s", req.sprint()), UVM_LOW)
        finish_item(req);
        
        #200;
        `uvm_info(get_type_name, "cumulative_nck_seq completed", UVM_LOW)

    endtask
    
endclass

class cumulative_ack_vseq extends pcie_base_vseq;
    `uvm_object_utils(cumulative_ack_vseq);

    cumulative_ack_seq  seq;
    cumulative_nck_seq  seq0;
    reset_sanity_seq  reset_seq;

    //  Constructor: new
    function new(string name = "cumulative_ack_vseq");
        super.new(name);
    endfunction: new

    
    task body();
        
        super.body();

       seq       = cumulative_ack_seq::type_id::create("seq");
       seq0      = cumulative_nck_seq::type_id::create("seq0");
       reset_seq = reset_sanity_seq::type_id::create("reset_seq");
       reset_seq.start(tl_tx_seqr);
       seq.start(tl_tx_seqr);
       seq0.start(phy_rx_seqr);

    endtask
    
endclass
`endif