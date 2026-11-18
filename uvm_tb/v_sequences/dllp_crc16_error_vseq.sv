`ifndef dllp_crc16_error_vseq
`define dllp_crc16_error_vseq

class dllp_crc16_error_seq extends uvm_sequence#(pcie_tlp_seq_item);
    `uvm_object_utils(dllp_crc16_error_seq);
    
    //  Constructor: new
    function new(string name = "dllp_crc16_error_seq");
        super.new(name);
    endfunction: new

    task body();

        `uvm_info(get_type_name, "dllp_crc16_error_seq starts", UVM_LOW)

        req = pcie_tlp_seq_item::type_id::create("req");
        start_item(req);
        assert(req.randomize() with { req.payload.size() inside {[1:5]}; } != 0);
        `uvm_info(get_type_name(), $sformatf("Generated TLP:\n%s", req.sprint()), UVM_LOW)
        finish_item(req);
        #100;

        `uvm_info(get_type_name, "dllp_crc16_error_seq completed", UVM_LOW)

    endtask
    
endclass

class dllp_crc16_error_seq0 extends uvm_sequence#(pcie_phy_seq_item);
    `uvm_object_utils(dllp_crc16_error_seq0);
    
    //  Constructor: new
    function new(string name = "dllp_crc16_error_seq0");
        super.new(name);
    endfunction: new

    task body();

        `uvm_info(get_type_name, "dllp_crc16_error_seq0 starts", UVM_LOW)

        req = pcie_phy_seq_item::type_id::create("req");
        start_item(req);
        assert(req.randomize() with {req.is_tlp == 0; req.dllp_type == 8'h00; req.seq_num == 12'd0; req.corrupt_crc == 1; });
        `uvm_info(get_type_name(), $sformatf("Generated TLP:\n%s", req.sprint()), UVM_LOW)
        finish_item(req);
        
        #1200;

        req = pcie_phy_seq_item::type_id::create("req");
        start_item(req);
        assert(req.randomize() with {req.is_tlp == 0; req.dllp_type == 8'h00; req.seq_num == 12'd0; req.corrupt_crc == 0; });
        `uvm_info(get_type_name(), $sformatf("Generated TLP:\n%s", req.sprint()), UVM_LOW)
        finish_item(req);

        `uvm_info(get_type_name, "dllp_crc16_error_seq0 completed", UVM_LOW)

    endtask
    
endclass

class dllp_crc16_error_vseq extends pcie_base_vseq;
    `uvm_object_utils(dllp_crc16_error_vseq);

    dllp_crc16_error_seq  seq;
    dllp_crc16_error_seq0  seq0;
    reset_sanity_seq  reset_seq;

    //  Constructor: new
    function new(string name = "dllp_crc16_error_vseq");
        super.new(name);
    endfunction: new

    
    task body();
        
        super.body();

       seq       = dllp_crc16_error_seq::type_id::create("seq");
       seq0      = dllp_crc16_error_seq0::type_id::create("seq0");
       reset_seq = reset_sanity_seq::type_id::create("reset_seq");
       reset_seq.start(tl_tx_seqr);
       seq.start(tl_tx_seqr);
       seq0.start(phy_rx_seqr);

    endtask
    
endclass
`endif