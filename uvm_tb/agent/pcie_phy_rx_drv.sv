`ifndef PCIE_PHY_RX_DRV
`define PCIE_PHY_RX_DRV

class pcie_phy_rx_drv extends uvm_driver#(pcie_phy_seq_item);
	`uvm_component_utils(pcie_phy_rx_drv)

	 virtual pcie_dll_if.PHY_RX vif;
	 pcie_dll_config cfg;

	function new(string name = "pcie_phy_rx_drv",uvm_component parent);
		super.new(name,parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		if(!uvm_config_db #(pcie_dll_config) ::get(this,"","pcie_dll_config",cfg))
		  `uvm_error(get_type_name,"NOT GETTING CONFIG IN PCIE_DLL_ENV")

		vif = cfg.vif;

	endfunction

	task run_phase(uvm_phase phase);

       forever 
	     begin
          seq_item_port.get_next_item(req);
          drive(req);
          seq_item_port.item_done();
	     end

    endtask

    task drive(pcie_phy_seq_item xtn);
        @(vif.phy_rx_cb); // Align to clean clock edge before SOP

        foreach (xtn.dw_stream[i]) 
		begin
            vif.phy_rx_cb.phy_rx_data   <= xtn.dw_stream[i];
            vif.phy_rx_cb.phy_rx_keep   <= xtn.keep_stream[i];
            vif.phy_rx_cb.phy_rx_is_tlp <= xtn.is_tlp;
            vif.phy_rx_cb.phy_rx_sop    <= (i == 0) ? 1'b1 : 1'b0;
            vif.phy_rx_cb.phy_rx_eop    <= (i == xtn.dw_stream.size() - 1) ? 1'b1 : 1'b0;
            vif.phy_rx_cb.phy_rx_valid  <= 1'b1;

            @(vif.phy_rx_cb); // Stream 1 beat per clock cycle (no ready on PHY RX)
        end

        // Deassert bus after EOP
        vif.phy_rx_cb.phy_rx_valid  <= 1'b0;
        vif.phy_rx_cb.phy_rx_sop    <= 1'b0;
        vif.phy_rx_cb.phy_rx_eop    <= 1'b0;
        vif.phy_rx_cb.phy_rx_is_tlp <= 1'b0;

        // Small inter-packet gap so u_lcrc_rx finishes checking LCRC before next SOP
        repeat (10) @(vif.phy_rx_cb);
    endtask
endclass
`endif