`ifndef single_tlp_rx_vseq
`define single_tlp_rx_vseq

class single_tlp_rx_seq extends uvm_sequence#(pcie_phy_seq_item);
    `uvm_object_utils(single_tlp_rx_seq);
    
    virtual pcie_dll_if vif;
    pcie_dll_config cfg;

    //  Constructor: new
    function new(string name = "single_tlp_rx_seq");
        super.new(name);
    endfunction: new

    task body();
        `uvm_info(get_type_name, "single_tlp_rx_seq starts", UVM_LOW)
        req = pcie_phy_seq_item::type_id::create("req");
        start_item(req);
        //Randomize pcie_phy_seq_item with is_tlp = 1, seq_num = 12'd0, corrupt_crc = 0 (3DW header + 2 payload DWs ).
        assert(req.randomize() with {req.is_tlp == 1; req.seq_num == 12'd0; req.corrupt_crc == 0; req.tlp_payload.size() == 5;});
        `uvm_info(get_type_name(), $sformatf("Generated TLP:\n%s", req.sprint()), UVM_LOW)
        finish_item(req);
        `uvm_info(get_type_name, "single_tlp_rx_seq completed", UVM_LOW)
    endtask
    
endclass

class single_tlp_rx_vseq extends pcie_base_vseq;
    `uvm_object_utils(single_tlp_rx_vseq);

    single_tlp_rx_seq seq;
    reset_sanity_seq  reset_seq;

    //  Constructor: new
    function new(string name = "single_tlp_rx_vseq");
        super.new(name);
    endfunction: new

    
    task body();
        super.body();

       seq       = single_tlp_rx_seq::type_id::create("seq");
       reset_seq = reset_sanity_seq::type_id::create("reset_seq");

       reset_seq.start(phy_rx_seqr);
       seq.start(phy_rx_seqr);

    endtask
    
endclass
`endif