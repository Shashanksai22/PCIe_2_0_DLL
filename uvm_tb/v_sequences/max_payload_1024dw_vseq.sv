`ifndef max_payload_1024dw_vseq
`define max_payload_1024dw_vseq

class max_payload_1024dw_seq extends uvm_sequence#(pcie_tlp_seq_item);
    `uvm_object_utils(max_payload_1024dw_seq);
    
    //  Constructor: new
    function new(string name = "max_payload_1024dw_seq");
        super.new(name);
    endfunction: new

    task body();

        req = pcie_tlp_seq_item::type_id::create("req");
        start_item(req);
        req.payload_length.constraint_mode(0); // Replace c_payload_len with your constraint block name
        assert(req.randomize() with { fmt == 3'b010;        // 3-DW header with data
        payload.size() == 1021; // 3-DW header + 1021-DW payload = 1024 DW
        });
        finish_item(req);
        
        #100000;
        `uvm_info(get_type_name, "max_payload_1024dw_seq completed", UVM_LOW)

    endtask
    
endclass

class max_payload_1024dw_seq0 extends uvm_sequence#(pcie_phy_seq_item);
    `uvm_object_utils(max_payload_1024dw_seq0);
    
    //  Constructor: new
    function new(string name = "max_payload_1024dw_seq0");
        super.new(name);
    endfunction: new

    task body();

        `uvm_info(get_type_name, "max_payload_1024dw_seq0 starts", UVM_LOW)

        req = pcie_phy_seq_item::type_id::create("req");
        start_item(req);
        req.c_packet.constraint_mode(0);
        assert(req.randomize() with {req.is_tlp == 1; req.seq_num == 0; req.corrupt_crc == 0; req.tlp_payload.size() == 1024; });
        `uvm_info(get_type_name(), $sformatf("Generated TLP:\n%s", req.sprint()), UVM_LOW)
        finish_item(req);
        
        #100000;
        `uvm_info(get_type_name, "max_payload_1024dw_seq0 completed", UVM_LOW)

    endtask
    
endclass

class max_payload_1024dw_vseq extends pcie_base_vseq;
    `uvm_object_utils(max_payload_1024dw_vseq);

    max_payload_1024dw_seq  seq;
    max_payload_1024dw_seq0  seq0;
    reset_sanity_seq  reset_seq;

    //  Constructor: new
    function new(string name = "max_payload_1024dw_vseq");
        super.new(name);
    endfunction: new

    task body();   
        super.body();

       seq       = max_payload_1024dw_seq::type_id::create("seq");
       seq0      = max_payload_1024dw_seq0::type_id::create("seq0");
       reset_seq = reset_sanity_seq::type_id::create("reset_seq");
       reset_seq.start(tl_tx_seqr);
       seq.start(tl_tx_seqr);
       seq0.start(phy_rx_seqr);

    endtask
    
endclass
`endif