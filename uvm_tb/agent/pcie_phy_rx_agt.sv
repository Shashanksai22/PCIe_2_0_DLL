`ifndef PCIE_PHY_RX_AGT
`define PCIE_PHY_RX_AGT

class pcie_phy_rx_agt extends uvm_agent;
	`uvm_component_utils(pcie_phy_rx_agt)

	pcie_dll_config cfg;

	pcie_phy_rx_seqr phy_rx_seqr;
	pcie_phy_rx_drv  phy_rx_drv;
	pcie_phy_rx_mon  phy_rx_mon;

	function new(string name = "pcie_phy_rx_agt",uvm_component parent);
		super.new(name,parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		if(!uvm_config_db #(pcie_dll_config) ::get(this,"","pcie_dll_config",cfg))
		  `uvm_error(get_type_name,"NOT GETTING CONFIG IN PCIE_PHY_RX_AGT")

         	phy_rx_mon = pcie_phy_rx_mon::type_id::create("phy_rx_mon",this);

		if(cfg.phy_rx_is_active == UVM_ACTIVE)
		begin
                phy_rx_seqr = pcie_phy_rx_seqr::type_id::create("phy_rx_seqr",this);
		phy_rx_drv  = pcie_phy_rx_drv::type_id::create("phy_rx_drv",this);
	        end	

    endfunction

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
        phy_rx_drv.seq_item_port.connect(phy_rx_seqr.seq_item_export);
	endfunction

endclass
`endif
