`ifndef full_duplex_random_regression_vseq
`define full_duplex_random_regression_vseq

class full_duplex_random_regression_seq extends uvm_sequence#(pcie_tlp_seq_item);
    `uvm_object_utils(full_duplex_random_regression_seq);
    
    //  Constructor: new
    function new(string name = "full_duplex_random_regression_seq");
        super.new(name);
    endfunction: new

    task body();

        pcie_phy_seq_item saved_pkt;

        `uvm_info(get_type_name, "full_duplex_random_regression_seq starts", UVM_LOW)

        for(int i=0; i<48; i++)
        begin
        req = pcie_tlp_seq_item::type_id::create("req");
        start_item(req);
        assert(req.randomize());
        `uvm_info(get_type_name(), $sformatf("Generated TLP:\n%s", req.sprint()), UVM_LOW)
        finish_item(req);
        #250;
        end
        repeat(2)
        begin
        req = pcie_tlp_seq_item::type_id::create("req");
        start_item(req);
        assert(req.randomize() with {req.fmt == 3'b011; req.tlp_type == 5'b00000; req.length == 32; req.payload.size() == 32;});
        `uvm_info(get_type_name(), $sformatf("Generated TLP:\n%s", req.sprint()), UVM_LOW)
        finish_item(req);
        #500;
        req = pcie_tlp_seq_item::type_id::create("req");
        start_item(req);
        assert(req.randomize() with {req.fmt == 3'b011; req.tlp_type == 5'b00000; req.length == 4; });
        `uvm_info(get_type_name(), $sformatf("Generated TLP:\n%s", req.sprint()), UVM_LOW)
        finish_item(req);
        #500;
        end
        
        #200;
        `uvm_info(get_type_name, "full_duplex_random_regression_seq completed", UVM_LOW)

    endtask
    
endclass

class full_duplex_random_regression_seq0 extends uvm_sequence#(pcie_phy_seq_item);
    `uvm_object_utils(full_duplex_random_regression_seq0);
    
    //  Constructor: new
    function new(string name = "full_duplex_random_regression_seq0");
        super.new(name);
    endfunction: new

    task body();

        `uvm_info(get_type_name, "full_duplex_random_regression_seq0 starts", UVM_LOW)
        for(int i = 0; i<50; i++)
        begin
        req = pcie_phy_seq_item::type_id::create("req");
        start_item(req);
        assert(req.randomize() with {req.is_tlp == 1; req.seq_num == i; });
        `uvm_info(get_type_name(), $sformatf("Generated TLP:\n%s", req.sprint()), UVM_LOW)
        finish_item(req);
        #250;
        end
        
        #200;
        `uvm_info(get_type_name, "full_duplex_random_regression_seq0 completed", UVM_LOW)

    endtask
    
endclass

class full_duplex_random_regression_vseq extends pcie_base_vseq;
    `uvm_object_utils(full_duplex_random_regression_vseq);

    full_duplex_random_regression_seq  seq;
    full_duplex_random_regression_seq0  seq0;
    reset_sanity_seq  reset_seq;

    //  Constructor: new
    function new(string name = "full_duplex_random_regression_vseq");
        super.new(name);
    endfunction: new

    
    task body();
        
        super.body();

       seq       = full_duplex_random_regression_seq::type_id::create("seq");
       seq0      = full_duplex_random_regression_seq0::type_id::create("seq0");
       reset_seq = reset_sanity_seq::type_id::create("reset_seq");
       
       reset_seq.start(tl_tx_seqr);
       fork
       seq.start(tl_tx_seqr);
       seq0.start(phy_rx_seqr);
       join

    endtask
    
endclass
`endif