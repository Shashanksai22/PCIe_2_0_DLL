`ifndef PCIE_TL_RX_AGT
`define PCIE_TL_RX_AGT

class pcie_tl_rx_agt extends uvm_agent;
	`uvm_component_utils(pcie_tl_rx_agt)

	pcie_dll_config cfg;

	pcie_tl_rx_seqr tl_rx_seqr;
	pcie_tl_rx_drv  tl_rx_drv;
	pcie_tl_rx_mon  tl_rx_mon;

	function new(string name = "pcie_tl_rx_agt",uvm_component parent);
		super.new(name,parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		if(!uvm_config_db #(pcie_dll_config) ::get(this,"","pcie_dll_config",cfg))
		  `uvm_error(get_type_name,"NOT GETTING CONFIG IN PCIE_TL_RX_AGT")

	        tl_rx_mon = pcie_tl_rx_mon::type_id::create("tl_rx_mon",this);

		if(cfg.tl_rx_is_active == UVM_ACTIVE)
		begin
                tl_rx_seqr = pcie_tl_rx_seqr::type_id::create("tl_rx_seqr",this);
		tl_rx_drv  = pcie_tl_rx_drv::type_id::create("tl_rx_drv",this);
	        end	

    endfunction

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
        tl_rx_drv.seq_item_port.connect(tl_rx_seqr.seq_item_export);
	endfunction

endclass
`endif
