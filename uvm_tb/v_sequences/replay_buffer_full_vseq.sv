`ifndef replay_buffer_full_vseq
`define replay_buffer_full_vseq

class replay_buffer_full_seq extends uvm_sequence#(pcie_tlp_seq_item);
    `uvm_object_utils(replay_buffer_full_seq);
    
    //  Constructor: new
    function new(string name = "replay_buffer_full_seq");
        super.new(name);
    endfunction: new

    task body();

        `uvm_info(get_type_name, "replay_buffer_full_seq starts", UVM_LOW)

        for(int i=0; i<10; i++)
        begin
        req = pcie_tlp_seq_item::type_id::create("req");
        start_item(req);
        assert(req.randomize() with { req.payload.size() == 1; } != 0);
        `uvm_info(get_type_name(), $sformatf("Generated TLP:\n%s", req.sprint()), UVM_LOW)
        finish_item(req);
        end
        
        #200;
        `uvm_info(get_type_name, "replay_buffer_full_seq completed", UVM_LOW)

    endtask
    
endclass

class replay_buffer_full_seq0 extends uvm_sequence#(pcie_phy_seq_item);
    `uvm_object_utils(replay_buffer_full_seq0);
    
    //  Constructor: new
    function new(string name = "replay_buffer_full_seq0");
        super.new(name);
    endfunction: new

    task body();

        `uvm_info(get_type_name, "replay_buffer_full_seq0 starts", UVM_LOW)
        #4700;
        req = pcie_phy_seq_item::type_id::create("req");
        start_item(req);
        assert(req.randomize() with {req.is_tlp == 0; req.seq_num == 7; req.dllp_type == 0; });
        `uvm_info(get_type_name(), $sformatf("Generated TLP:\n%s", req.sprint()), UVM_LOW)
        finish_item(req);
        
        #300;
        `uvm_info(get_type_name, "replay_buffer_full_seq0 completed", UVM_LOW)

    endtask
    
endclass

class replay_buffer_full_vseq extends pcie_base_vseq;
    `uvm_object_utils(replay_buffer_full_vseq);

    replay_buffer_full_seq  seq;
    replay_buffer_full_seq0  seq0;
    reset_sanity_seq  reset_seq;

    //  Constructor: new
    function new(string name = "replay_buffer_full_vseq");
        super.new(name);
    endfunction: new

    
    task body();
        
        super.body();

       seq       = replay_buffer_full_seq::type_id::create("seq");
       seq0      = replay_buffer_full_seq0::type_id::create("seq0");
       reset_seq = reset_sanity_seq::type_id::create("reset_seq");
       reset_seq.start(tl_tx_seqr);
       fork
       seq.start(tl_tx_seqr);
       seq0.start(phy_rx_seqr);
       join

    endtask
    
endclass
`endif