`ifndef PCIE_PHY_TX_DRV
`define PCIE_PHY_TX_DRV

class pcie_phy_tx_drv extends uvm_driver#(pcie_phy_seq_item);
	`uvm_component_utils(pcie_phy_tx_drv)

	virtual pcie_dll_if.PHY_TX vif;
	pcie_dll_config cfg;

	function new(string name = "pcie_phy_tx_drv",uvm_component parent);
		super.new(name,parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		if(!uvm_config_db #(pcie_dll_config) ::get(this,"","pcie_dll_config",cfg))
		  `uvm_error(get_type_name,"NOT GETTING CONFIG IN PCIE_DLL_ENV")

		vif = cfg.vif;

	endfunction

	task run_phase(uvm_phase phase);
		int count;
        vif.phy_tx_cb.phy_tx_ready <= 1'b0;
        wait(vif.rst_n === 1'b1);
        @(vif.phy_tx_cb);

        forever 
		begin
            // Keep ready high (or randomize for backpressure testing)           
            count++;
            /*
			if((count >= 30) && (count < 40)) 
			vif.phy_tx_cb.phy_tx_ready <= 1'b0;
			else*/
			vif.phy_tx_cb.phy_tx_ready <= 1'b1;
			@(vif.phy_tx_cb);
        end
    endtask
	
endclass
`endif