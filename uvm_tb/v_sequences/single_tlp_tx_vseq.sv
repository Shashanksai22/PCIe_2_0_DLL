`ifndef single_tlp_tx_vseq
`define single_tlp_tx_vseq

class single_tlp_tx_seq extends uvm_sequence#(pcie_tlp_seq_item);
    `uvm_object_utils(single_tlp_tx_seq);
    
    virtual pcie_dll_if vif;
    pcie_dll_config cfg;

    //  Constructor: new
    function new(string name = "single_tlp_tx_seq");
        super.new(name);
    endfunction: new

    task body();
        `uvm_info(get_type_name, "BASIC_TLP_TX_SEQ starts", UVM_LOW)
        req = pcie_tlp_seq_item::type_id::create("req");
        start_item(req);
        //Randomize 1 pcie_tlp_seq_item (3DW Memory Write, length = 4, 4KB-aligned address[31:0]).
        assert(req.randomize() with {req.fmt[0] == 0; req.length == 4;});
        `uvm_info(get_type_name(), $sformatf("Generated TLP:\n%s", req.sprint()), UVM_LOW)
        finish_item(req);
        `uvm_info(get_type_name, "BASIC_TLP_TX_SEQ completed", UVM_LOW)
    endtask
    
endclass

class single_tlp_tx_vseq extends pcie_base_vseq;
    `uvm_object_utils(single_tlp_tx_vseq);

    single_tlp_tx_seq seq;
    reset_sanity_seq  reset_seq;

    //  Constructor: new
    function new(string name = "single_tlp_tx_vseq");
        super.new(name);
    endfunction: new

    
    task body();
        super.body();

       seq       = single_tlp_tx_seq::type_id::create("seq");
       reset_seq = reset_sanity_seq::type_id::create("reset_seq");

       reset_seq.start(tl_tx_seqr);
       seq.start(tl_tx_seqr);

    endtask
    
endclass
`endif