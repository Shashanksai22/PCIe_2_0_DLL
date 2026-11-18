`ifndef BASIC_PHY_RX_SEQ
`define BASIC_PHY_RX_SEQ
class basic_phy_rx_seq extends reset_phy_seq;
    `uvm_object_utils(basic_phy_rx_seq);

    //  Constructor: new
    function new(string name = "basic_phy_rx_seq");
        super.new(name);
    endfunction

    task body();
        super.body();
        
        `uvm_info(get_type_name, "BASIC_PHY_RX_SEQ starts", UVM_LOW)
        `uvm_info(get_type_name, "TLP starts", UVM_LOW)
        req = pcie_phy_seq_item::type_id::create("req");
        start_item(req);
        assert(req.randomize() with { is_tlp == 1'b1; seq_num == 12'd0;});
        finish_item(req);
        `uvm_info(get_type_name, "TLP completes", UVM_LOW)
        #500;
        `uvm_info(get_type_name, "DLLP starts", UVM_LOW)
        req = pcie_phy_seq_item::type_id::create("req");
        start_item(req);
        assert(req.randomize() with { is_tlp == 1'b0; seq_num == 12'd0;});
        finish_item(req);
        `uvm_info(get_type_name, "DLLP completes", UVM_LOW)
        `uvm_info(get_type_name, "BASIC_PHY_RX_SEQ completed", UVM_LOW)
    endtask
    
endclass
`endif