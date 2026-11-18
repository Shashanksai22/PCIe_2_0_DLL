`ifndef BASIC_TLP_TX_SEQ
`define BASIC_TLP_TX_SEQ
class basic_tlp_tx_seq extends reset_test_seq;
    `uvm_object_utils(basic_tlp_tx_seq);

    //  Constructor: new
    function new(string name = "basic_tlp_tx_seq");
        super.new(name);
    endfunction

    task body();
        super.body();
        `uvm_info(get_type_name, "BASIC_TLP_TX_SEQ starts", UVM_LOW)
        req = pcie_tlp_seq_item::type_id::create("req");
        start_item(req);
        assert(req.randomize());
        finish_item(req);
        `uvm_info(get_type_name, "BASIC_TLP_TX_SEQ completed", UVM_LOW)
    endtask
    
endclass
`endif