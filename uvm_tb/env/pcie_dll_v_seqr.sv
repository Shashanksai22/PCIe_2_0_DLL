`ifndef PCIE_DLL_V_SEQR
`define PCIE_DLL_V_SEQR

class pcie_dll_v_seqr extends uvm_sequencer;
	`uvm_component_utils(pcie_dll_v_seqr)

	pcie_dll_config cfg;

	pcie_phy_rx_seqr phy_rx_seqr;
	pcie_phy_tx_seqr phy_tx_seqr;
	pcie_tl_rx_seqr tl_rx_seqr;
	pcie_tl_tx_seqr tl_tx_seqr;

	function new(string name = "pcie_dll_v_seqr",uvm_component parent);
		super.new(name,parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		if(!uvm_config_db #(pcie_dll_config) ::get(this,"","pcie_dll_config",cfg))
		  `uvm_error(get_type_name,"NOT GETTING CONFIG IN PCIE_DLL_V_SEQR")

    endfunction

endclass
`endif
