`ifndef PCIE_DLL_ENV
`define PCIE_DLL_ENV

class pcie_dll_env extends uvm_env;
	`uvm_component_utils(pcie_dll_env)

	pcie_dll_config cfg;

	pcie_dll_scoreboard sb;
	pcie_dll_v_seqr     v_seqr;

	pcie_tl_tx_agt      tl_tx_agt;
	pcie_tl_rx_agt      tl_rx_agt;
	pcie_phy_tx_agt     phy_tx_agt;
	pcie_phy_rx_agt     phy_rx_agt;


	function new(string name = "pcie_dll_env",uvm_component parent);
		super.new(name,parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		if(!uvm_config_db #(pcie_dll_config) ::get(this,"","pcie_dll_config",cfg))
		  `uvm_error(get_type_name,"NOT GETTING CONFIG IN PCIE_DLL_ENV")


	     if(cfg.has_scoreboard)
	      sb = pcie_dll_scoreboard::type_id::create("sb",this);

	      v_seqr = pcie_dll_v_seqr::type_id::create("v_seqr",this);

	      tl_tx_agt  = pcie_tl_tx_agt::type_id::create("tl_tx_agt",this);
	      tl_rx_agt  = pcie_tl_rx_agt::type_id::create("tl_rx_agt",this);

	      phy_tx_agt = pcie_phy_tx_agt::type_id::create("phy_tx_agt",this);
	      phy_rx_agt = pcie_phy_rx_agt::type_id::create("phy_rx_agt",this);

      endfunction

      function void connect_phase(uvm_phase phase);
	      super.connect_phase(phase);
	      
                  // vseqr 
		  v_seqr.phy_rx_seqr = phy_rx_agt.phy_rx_seqr;
		  v_seqr.phy_tx_seqr = phy_tx_agt.phy_tx_seqr;

		  v_seqr.tl_rx_seqr  = tl_rx_agt.tl_rx_seqr;
		  v_seqr.tl_tx_seqr  = tl_tx_agt.tl_tx_seqr;

		  //mon-sb
		  tl_tx_agt.tl_tx_mon.analysis_port.connect(sb.tl_tx_fifo.analysis_export);
		  tl_rx_agt.tl_rx_mon.analysis_port.connect(sb.tl_rx_fifo.analysis_export);

		  phy_tx_agt.phy_tx_mon.analysis_port.connect(sb.phy_tx_fifo.analysis_export);
		  phy_rx_agt.phy_rx_mon.analysis_port.connect(sb.phy_rx_fifo.analysis_export);

		  sb.dllp_resp_ap.connect(phy_rx_agt.phy_rx_seqr.dllp_resp_fifo.analysis_export);

      endfunction

endclass
`endif