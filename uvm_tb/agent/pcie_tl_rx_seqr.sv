`ifndef PCIE_TL_RX_SEQR
`define PCIE_TL_RX_SEQR

class pcie_tl_rx_seqr extends uvm_sequencer#(pcie_tlp_seq_item);
	`uvm_component_utils(pcie_tl_rx_seqr)

	function new(string name = "pcie_tl_rx_seqr",uvm_component parent);
		super.new(name,parent);
	endfunction

endclass
`endif
