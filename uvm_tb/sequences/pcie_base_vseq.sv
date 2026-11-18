`ifndef PCIE_BASE_VSEQ
`define PCIE_BASE_VSEQ

class pcie_base_vseq extends uvm_sequence;
    `uvm_object_utils(pcie_base_vseq);

    //`uvm_declare_p_sequencer(pcie_dll_v_seqr) // Automatically declares & casts p_sequencer

    //  Group: Variables
    pcie_dll_config cfg;

    pcie_dll_v_seqr     v_seqr;

	pcie_phy_rx_seqr phy_rx_seqr;
	pcie_phy_tx_seqr phy_tx_seqr;
	pcie_tl_rx_seqr tl_rx_seqr;
	pcie_tl_tx_seqr tl_tx_seqr;


    //  Constructor: new
    function new(string name = "pcie_base_vseq");
        super.new(name);
    endfunction: new 
    
    task body();

      if (!$cast(v_seqr, m_sequencer)) 
      begin
        `uvm_fatal(get_type_name(), "Failed to cast m_sequencer to pcie_dll_v_seqr")
      end

      phy_rx_seqr = v_seqr.phy_rx_seqr;
      phy_tx_seqr = v_seqr.phy_tx_seqr;
      tl_rx_seqr  = v_seqr.tl_rx_seqr;
      tl_tx_seqr  = v_seqr.tl_tx_seqr;

    endtask
    /*
    task body();
        // p_sequencer is already valid here!
        phy_rx_seqr = p_sequencer.phy_rx_seqr;
        phy_tx_seqr = p_sequencer.phy_tx_seqr;
        tl_rx_seqr  = p_sequencer.tl_rx_seqr;
        tl_tx_seqr  = p_sequencer.tl_tx_seqr;
    endtask
        */
endclass: pcie_base_vseq
`endif