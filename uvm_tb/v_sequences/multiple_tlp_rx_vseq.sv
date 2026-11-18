`ifndef multiple_tlp_rx_vseq
`define multiple_tlp_rx_vseq

class multiple_tlp_rx_seq extends uvm_sequence#(pcie_phy_seq_item);
    `uvm_object_utils(multiple_tlp_rx_seq);
    
    virtual pcie_dll_if vif;
    pcie_dll_config cfg;

    //  Constructor: new
    function new(string name = "multiple_tlp_rx_seq");
        super.new(name);
    endfunction: new

    task body();

        `uvm_info(get_type_name, "multiple_tlp_rx_seq starts", UVM_LOW)

        for(int i=0; i<6; i++)
        begin
        req = pcie_phy_seq_item::type_id::create("req");
        start_item(req);
        assert(req.randomize() with {req.is_tlp == 1; req.seq_num == i; req.corrupt_crc == 0; });
        `uvm_info(get_type_name(), $sformatf("Generated TLP:\n%s", req.sprint()), UVM_LOW)
        finish_item(req);
        #100;
        end

        #2000;
        
        `uvm_info(get_type_name, "multiple_tlp_rx_seq completed", UVM_LOW)

    endtask
    
endclass

class multiple_tlp_rx_vseq extends pcie_base_vseq;
    `uvm_object_utils(multiple_tlp_rx_vseq);

    multiple_tlp_rx_seq seq;
    reset_sanity_seq    reset_seq;

    //  Constructor: new
    function new(string name = "multiple_tlp_rx_vseq");
        super.new(name);
    endfunction: new

    
    task body();
        super.body();

       seq       = multiple_tlp_rx_seq::type_id::create("seq");
       reset_seq = reset_sanity_seq::type_id::create("reset_seq");
       reset_seq.start(phy_rx_seqr);
       seq.start(phy_rx_seqr);

    endtask
    
endclass
`endif