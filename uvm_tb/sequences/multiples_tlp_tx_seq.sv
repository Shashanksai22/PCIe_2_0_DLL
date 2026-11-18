`ifndef multiples_TLP_TX_SEQ
`define multiples_TLP_TX_SEQ
class multiples_tlp_tx_seq extends reset_test_seq;
    `uvm_object_utils(multiples_tlp_tx_seq);

    //  Constructor: new
    function new(string name = "multiples_tlp_tx_seq");
        super.new(name);
    endfunction

    task body();
        super.body();
        `uvm_info(get_type_name, "multiples_TLP_TX_SEQ starts", UVM_LOW)
        repeat(5)
        begin
        req = pcie_tlp_seq_item::type_id::create("req");
        start_item(req);
        assert(req.randomize());
        finish_item(req);
        #2000;
        end
        `uvm_info(get_type_name, "multiples_TLP_TX_SEQ completed", UVM_LOW)
    endtask
    
endclass
`endif