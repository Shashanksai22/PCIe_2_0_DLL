`ifndef multiple_tlp_tx_vseq
`define multiple_tlp_tx_vseq

class multiple_tlp_tx_seq extends uvm_sequence#(pcie_tlp_seq_item);
    `uvm_object_utils(multiple_tlp_tx_seq);
    
    virtual pcie_dll_if vif;
    pcie_dll_config cfg;

    //  Constructor: new
    function new(string name = "multiple_tlp_tx_seq");
        super.new(name);
    endfunction: new

    task body();
        `uvm_info(get_type_name, "BASIC_TLP_TX_SEQ starts", UVM_LOW)
        repeat(5)
        begin
        req = pcie_tlp_seq_item::type_id::create("req");
        start_item(req);
        assert(req.randomize() );
        `uvm_info(get_type_name(), $sformatf("Generated TLP:\n%s", req.sprint()), UVM_LOW)
        finish_item(req);
        end
        #2000;
        `uvm_info(get_type_name, "BASIC_TLP_TX_SEQ completed", UVM_LOW)
    endtask
    
endclass

class multiple_tlp_tx_vseq extends pcie_base_vseq;
    `uvm_object_utils(multiple_tlp_tx_vseq);

    multiple_tlp_tx_seq seq;
    reset_sanity_seq    reset_seq;

    //  Constructor: new
    function new(string name = "multiple_tlp_tx_vseq");
        super.new(name);
    endfunction: new

    
    task body();
        super.body();

       seq       = multiple_tlp_tx_seq::type_id::create("seq");
       reset_seq = reset_sanity_seq::type_id::create("reset_seq");
       reset_seq.start(tl_tx_seqr);
       seq.start(tl_tx_seqr);

    endtask
    
endclass
`endif