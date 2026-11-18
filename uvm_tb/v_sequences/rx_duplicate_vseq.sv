`ifndef rx_duplicate_vseq
`define rx_duplicate_vseq

class rx_duplicate_seq extends uvm_sequence#(pcie_phy_seq_item);
    `uvm_object_utils(rx_duplicate_seq);
    
    virtual pcie_dll_if vif;
    pcie_dll_config cfg;

    //  Constructor: new
    function new(string name = "rx_duplicate_seq");
        super.new(name);
    endfunction: new

    task body();

        pcie_phy_seq_item saved_pkt;

        `uvm_info(get_type_name, "rx_duplicate_seq starts", UVM_LOW)

        repeat(2)
        begin
        req = pcie_phy_seq_item::type_id::create("req");
        start_item(req);
        assert(req.randomize() with { is_tlp == 1; seq_num == 0; corrupt_crc == 0; });
        `uvm_info(get_type_name(), $sformatf("Generated TLP:\n%s", req.sprint()), UVM_LOW)
        finish_item(req);
        #100;
        end      

        req = pcie_phy_seq_item::type_id::create("req");
        start_item(req);
        assert(req.randomize() with { is_tlp == 1; seq_num == 1; corrupt_crc == 0; });
        `uvm_info(get_type_name(), $sformatf("Generated TLP:\n%s", req.sprint()), UVM_LOW)
        finish_item(req);

        #2000;
        
        `uvm_info(get_type_name, "rx_duplicate_seq completed", UVM_LOW)

    endtask
    
endclass

class rx_duplicate_vseq extends pcie_base_vseq;
    `uvm_object_utils(rx_duplicate_vseq);

    rx_duplicate_seq  seq;
    reset_sanity_seq  reset_seq;

    //  Constructor: new
    function new(string name = "rx_duplicate_vseq");
        super.new(name);
    endfunction: new

    
    task body();
        super.body();

       seq       = rx_duplicate_seq::type_id::create("seq");
       reset_seq = reset_sanity_seq::type_id::create("reset_seq");
       reset_seq.start(phy_rx_seqr);
       seq.start(phy_rx_seqr);

    endtask
    
endclass
`endif