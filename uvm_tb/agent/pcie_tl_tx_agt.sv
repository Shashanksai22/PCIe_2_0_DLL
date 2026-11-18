`ifndef PCIE_TL_TX_AGT
`define PCIE_TL_TX_AGT

class pcie_tl_tx_agt extends uvm_agent;
	`uvm_component_utils(pcie_tl_tx_agt)

	pcie_dll_config cfg;

	pcie_tl_tx_seqr tl_tx_seqr;
	pcie_tl_tx_drv  tl_tx_drv;
	pcie_tl_tx_mon  tl_tx_mon;

	function new(string name = "pcie_tl_tx_agt",uvm_component parent);
		super.new(name,parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		if(!uvm_config_db #(pcie_dll_config) ::get(this,"","pcie_dll_config",cfg))
		  `uvm_error(get_type_name,"NOT GETTING CONFIG IN PCIE_TL_TX_AGT")

                tl_tx_mon = pcie_tl_tx_mon::type_id::create("tl_tx_mon",this);

		if(cfg.tl_tx_is_active == UVM_ACTIVE)
		begin
                tl_tx_seqr = pcie_tl_tx_seqr::type_id::create("tl_tx_seqr",this);
		tl_tx_drv  = pcie_tl_tx_drv::type_id::create("tl_tx_drv",this);
	        end	    

    endfunction

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
        tl_tx_drv.seq_item_port.connect(tl_tx_seqr.seq_item_export);
	endfunction

endclass
`endif
