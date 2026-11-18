`ifndef PCIE_TL_TX_SEQR
`define PCIE_TL_TX_SEQR

class pcie_tl_tx_seqr extends uvm_sequencer#(pcie_tlp_seq_item);
	`uvm_component_utils(pcie_tl_tx_seqr)

	function new(string name = "pcie_tl_tx_seqr",uvm_component parent);
		super.new(name,parent);
	endfunction

endclass
`endif
