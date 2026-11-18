`ifndef PCIE_PHY_RX_SEQR
`define PCIE_PHY_RX_SEQR

class pcie_phy_rx_seqr extends uvm_sequencer#(pcie_phy_seq_item);
	`uvm_component_utils(pcie_phy_rx_seqr)

	uvm_tlm_analysis_fifo #(pcie_phy_seq_item) dllp_resp_fifo;

	function new(string name = "pcie_phy_rx_seqr",uvm_component parent);
		super.new(name,parent);
		
		dllp_resp_fifo = new("dllp_resp_fifo", this);
	endfunction

endclass
`endif