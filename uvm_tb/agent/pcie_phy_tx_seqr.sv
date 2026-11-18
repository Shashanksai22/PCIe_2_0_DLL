`ifndef PCIE_PHY_TX_SEQR
`define PCIE_PHY_TX_SEQR

class pcie_phy_tx_seqr extends uvm_sequencer#(pcie_phy_seq_item);
	`uvm_component_utils(pcie_phy_tx_seqr)

	function new(string name = "pcie_phy_tx_seqr",uvm_component parent);
		super.new(name,parent);
	endfunction

endclass
`endif
