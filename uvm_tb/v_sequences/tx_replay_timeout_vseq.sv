`ifndef tx_replay_timeout_vseq
`define tx_replay_timeout_vseq

class tx_replay_timeout_seq extends uvm_sequence#(pcie_tlp_seq_item);
    `uvm_object_utils(tx_replay_timeout_seq);
    
    virtual pcie_dll_if vif;
    pcie_dll_config cfg;

    //  Constructor: new
    function new(string name = "tx_replay_timeout_seq");
        super.new(name);
    endfunction: new

    task body();

        pcie_phy_seq_item saved_pkt;

        `uvm_info(get_type_name, "tx_replay_timeout_seq starts", UVM_LOW)

        for(int i=0; i<3; i++)
        begin
        req = pcie_tlp_seq_item::type_id::create("req");
        start_item(req);
        assert(req.randomize() with { req.payload.size() inside {[1:5]}; } != 0);
        `uvm_info(get_type_name(), $sformatf("Generated TLP:\n%s", req.sprint()), UVM_LOW)
        finish_item(req);
        #100;
        end
        #15000;
        `uvm_info(get_type_name, "tx_replay_timeout_seq completed", UVM_LOW)

    endtask
    
endclass

class tx_replay_timeout_vseq extends pcie_base_vseq;
    `uvm_object_utils(tx_replay_timeout_vseq);

    tx_replay_timeout_seq  seq;
    reset_sanity_seq  reset_seq;

    //  Constructor: new
    function new(string name = "tx_replay_timeout_vseq");
        super.new(name);
    endfunction: new

    
    task body();
        super.body();

       seq       = tx_replay_timeout_seq::type_id::create("seq");
       reset_seq = reset_sanity_seq::type_id::create("reset_seq");
       reset_seq.start(tl_tx_seqr);
       seq.start(tl_tx_seqr);

    endtask
    
endclass
`endif