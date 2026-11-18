`ifndef tx_nak_retransmit_vseq
`define tx_nak_retransmit_vseq

class tx_nak_retransmit_seq extends uvm_sequence#(pcie_tlp_seq_item);
    `uvm_object_utils(tx_nak_retransmit_seq);
    
    virtual pcie_dll_if vif;
    pcie_dll_config cfg;

    //  Constructor: new
    function new(string name = "tx_nak_retransmit_seq");
        super.new(name);
    endfunction: new

    task body();

        pcie_phy_seq_item saved_pkt;

        `uvm_info(get_type_name, "tx_nak_retransmit_seq starts", UVM_LOW)

        for(int i=0; i<3; i++)
        begin
        req = pcie_tlp_seq_item::type_id::create("req");
        start_item(req);
        assert(req.randomize() with { req.payload.size() inside {[1:5]}; } != 0);
        `uvm_info(get_type_name(), $sformatf("Generated TLP:\n%s", req.sprint()), UVM_LOW)
        finish_item(req);
        #100;
        end
        
        `uvm_info(get_type_name, "tx_nak_retransmit_seq completed", UVM_LOW)

    endtask
    
endclass

class tx_nck_retransmit_seq extends uvm_sequence#(pcie_phy_seq_item);
    `uvm_object_utils(tx_nck_retransmit_seq);
    
    virtual pcie_dll_if vif;
    pcie_dll_config cfg;

    //  Constructor: new
    function new(string name = "tx_nck_retransmit_seq");
        super.new(name);
    endfunction: new

    task body();

        pcie_phy_seq_item saved_pkt;

        `uvm_info(get_type_name, "tx_nck_retransmit_seq starts", UVM_LOW)

        #500;
        
        req = pcie_phy_seq_item::type_id::create("req");
        start_item(req);
        assert(req.randomize() with {req.is_tlp == 0; req.seq_num == 0; req.dllp_type == 0; });
        `uvm_info(get_type_name(), $sformatf("Generated TLP:\n%s", req.sprint()), UVM_LOW)
        finish_item(req);
        #100;

        req = pcie_phy_seq_item::type_id::create("req");
        start_item(req);
        assert(req.randomize() with {req.is_tlp == 0; req.seq_num == 0; req.dllp_type == 8'H010; });
        `uvm_info(get_type_name(), $sformatf("Generated TLP:\n%s", req.sprint()), UVM_LOW)
        finish_item(req);
        #1000;

        req = pcie_phy_seq_item::type_id::create("req");
        start_item(req);
        assert(req.randomize() with {req.is_tlp == 0; req.seq_num == 2; req.dllp_type == 0; });
        `uvm_info(get_type_name(), $sformatf("Generated TLP:\n%s", req.sprint()), UVM_LOW)
        finish_item(req);

        #1000;
        
        `uvm_info(get_type_name, "tx_nck_retransmit_seq completed", UVM_LOW)

    endtask
    
endclass

class tx_nak_retransmit_vseq extends pcie_base_vseq;
    `uvm_object_utils(tx_nak_retransmit_vseq);

    tx_nak_retransmit_seq  seq;
    tx_nck_retransmit_seq  seq0;
    reset_sanity_seq  reset_seq;

    //  Constructor: new
    function new(string name = "tx_nak_retransmit_vseq");
        super.new(name);
    endfunction: new

    
    task body();
        super.body();

       seq       = tx_nak_retransmit_seq::type_id::create("seq");
       seq0      = tx_nck_retransmit_seq::type_id::create("seq0");
       reset_seq = reset_sanity_seq::type_id::create("reset_seq");
       reset_seq.start(tl_tx_seqr);

       seq.start(tl_tx_seqr);
       #600;
       seq0.start(phy_rx_seqr);
       
    endtask
    
endclass
`endif