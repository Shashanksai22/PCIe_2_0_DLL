`ifndef RESET_SANITY_VSEQ
`define RESET_SANITY_VSEQ

class reset_sanity_seq extends uvm_sequence;
    `uvm_object_utils(reset_sanity_seq);
    
    virtual pcie_dll_if vif;
    pcie_dll_config cfg;

    //  Constructor: new
    function new(string name = "reset_sanity_seq");
        super.new(name);
    endfunction: new

    task body();

        if(!uvm_config_db #(pcie_dll_config) ::get(m_sequencer,"","pcie_dll_config",cfg))
		  `uvm_error(get_type_name,"NOT GETTING CONFIG IN reset_sanity_seq")
        
        vif = cfg.vif;

        vif.rst_n = 0;
        vif.tl_tx_valid  = 0;
        vif.phy_rx_valid = 0;
        vif.tl_rx_ready  = 1; 
        vif.phy_tx_ready = 1;
        repeat (10) @(posedge vif.clk);

        vif.rst_n = 1;
        repeat (20) @(posedge vif.clk);
        

        `uvm_info(get_full_name(), $sformatf("current_seq = %0d, next_transmit_seq = %0d",  vif.dbg_curr_seq, vif.dbg_next_seq), UVM_NONE)

        `uvm_info("RESET", "reset_sanity_seq sequence completed", UVM_LOW)
            
    endtask
    
endclass

class reset_sanity_vseq extends pcie_base_vseq;
    `uvm_object_utils(reset_sanity_vseq);

    reset_sanity_seq seq;

    //  Constructor: new
    function new(string name = "reset_sanity_vseq");
        super.new(name);
    endfunction: new

    
    task body();
        super.body();

       seq = reset_sanity_seq::type_id::create("seq");
       seq.start(tl_tx_seqr);
    endtask
    
endclass
`endif