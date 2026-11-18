`ifndef seq_num_rollover_vseq
`define seq_num_rollover_vseq

class seq_num_rollover_seq extends uvm_sequence#(pcie_tlp_seq_item);
    `uvm_object_utils(seq_num_rollover_seq);
    
    //  Constructor: new
    function new(string name = "seq_num_rollover_seq");
        super.new(name);
    endfunction: new

    task body();

        pcie_phy_seq_item saved_pkt;

        `uvm_info(get_type_name, "seq_num_rollover_seq starts", UVM_LOW)

        for(int i=0; i<4; i++)
        begin
        req = pcie_tlp_seq_item::type_id::create("req");
        start_item(req);
        assert(req.randomize() with { req.payload.size() inside {[1:5]}; } != 0);
        `uvm_info(get_type_name(), $sformatf("Generated TLP:\n%s", req.sprint()), UVM_LOW)
        finish_item(req);
        #100;
        end
        
        #200;
        `uvm_info(get_type_name, "seq_num_rollover_seq completed", UVM_LOW)

    endtask
    
endclass

class seq_num_rollover_seq0 extends uvm_sequence#(pcie_phy_seq_item);
    `uvm_object_utils(seq_num_rollover_seq0);
    
    //  Constructor: new
    function new(string name = "seq_num_rollover_seq0");
        super.new(name);
    endfunction: new

    task body();

        `uvm_info(get_type_name, "seq_num_rollover_seq0 starts", UVM_LOW)
        for(int i=0; i<4; i++)
        begin
           req = pcie_phy_seq_item::type_id::create("req");
           start_item(req);
           assert(req.randomize() with { req.is_tlp == 1; req.seq_num == (4094+i)%4096; req.corrupt_crc == 0; });
           `uvm_info(get_type_name(), $sformatf("Generated TLP:\n%s", req.sprint()), UVM_LOW)
           finish_item(req); 
           #100;
        end
        
        #200;
        `uvm_info(get_type_name, "seq_num_rollover_seq0 completed", UVM_LOW)

    endtask
    
endclass

class seq_num_rollover_vseq extends pcie_base_vseq;
    `uvm_object_utils(seq_num_rollover_vseq);

    seq_num_rollover_seq  seq;
    seq_num_rollover_seq0  seq0;
    reset_sanity_seq  reset_seq;

    //  Constructor: new
    function new(string name = "seq_num_rollover_vseq");
        super.new(name);
    endfunction: new

    
    task body();
        
        super.body();

       seq       = seq_num_rollover_seq::type_id::create("seq");
       seq0      = seq_num_rollover_seq0::type_id::create("seq0");
       reset_seq = reset_sanity_seq::type_id::create("reset_seq");
       reset_seq.start(tl_tx_seqr);
       seq.start(tl_tx_seqr);
       seq0.start(phy_rx_seqr);

    endtask
    
endclass
`endif