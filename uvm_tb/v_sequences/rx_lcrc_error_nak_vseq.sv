`ifndef rx_lcrc_error_nak_vseq
`define rx_lcrc_error_nak_vseq

class rx_lcrc_error_nak_seq extends uvm_sequence#(pcie_phy_seq_item);
    `uvm_object_utils(rx_lcrc_error_nak_seq);
    
    virtual pcie_dll_if vif;
    pcie_dll_config cfg;

    //  Constructor: new
    function new(string name = "rx_lcrc_error_nak_seq");
        super.new(name);
    endfunction: new

    task body();

        pcie_phy_seq_item saved_pkt;

        `uvm_info(get_type_name, "rx_lcrc_error_nak_seq starts", UVM_LOW)

        // 1. Send seq_num=0 (valid)
        req = pcie_phy_seq_item::type_id::create("req");
        start_item(req);
        assert(req.randomize() with { is_tlp == 1; seq_num == 0; corrupt_crc == 0; });
        finish_item(req);
        #100;
        
        // 2. Randomize seq_num=1 as VALID first, clone it, then corrupt the first copy
        req = pcie_phy_seq_item::type_id::create("req");
        start_item(req);
        assert(req.randomize() with { is_tlp == 1; seq_num == 1; corrupt_crc == 0; });
        $cast(saved_pkt, req.clone()); // Saved copy has clean, valid LCRC!
        req.corrupt_crc = 1;
        req.lcrc ^= 32'h1;               // Corrupt only the first transmission
        req.dw_stream[req.dw_stream.size()-1] ^= 32'h1; // Corrupt LCRC DW driven on phy_rx_data
        req.bytes[req.bytes.size()-4]         ^= 8'h01; // Keep bytes[] in sync
        finish_item(req);
        #100;

        // 3. Retransmit the clean cloned packet (already has valid LCRC!)
        start_item(saved_pkt);
        finish_item(saved_pkt);
        #2000;
        
        `uvm_info(get_type_name, "rx_lcrc_error_nak_seq completed", UVM_LOW)

    endtask
    
endclass

class rx_lcrc_error_nak_vseq extends pcie_base_vseq;
    `uvm_object_utils(rx_lcrc_error_nak_vseq);

    rx_lcrc_error_nak_seq seq;
    reset_sanity_seq    reset_seq;

    //  Constructor: new
    function new(string name = "rx_lcrc_error_nak_vseq");
        super.new(name);
    endfunction: new

    
    task body();
        super.body();

       seq       = rx_lcrc_error_nak_seq::type_id::create("seq");
       reset_seq = reset_sanity_seq::type_id::create("reset_seq");
       reset_seq.start(phy_rx_seqr);
       seq.start(phy_rx_seqr);

    endtask
    
endclass
`endif