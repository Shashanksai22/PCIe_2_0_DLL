`ifndef PCIE_TL_RX_DRV
`define PCIE_TL_RX_DRV

class pcie_tl_rx_drv extends uvm_driver#(pcie_tlp_seq_item);
	`uvm_component_utils(pcie_tl_rx_drv)

	virtual pcie_dll_if.TL_RX vif;
	pcie_dll_config cfg;

	function new(string name = "pcie_tl_rx_drv",uvm_component parent);
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

        vif.tl_rx_cb.tl_rx_ready <= 1'b0;
        wait(vif.rst_n === 1'b1);
        @(vif.tl_rx_cb);

        forever 
		begin
            // Keep ready high (or randomize for backpressure testing)           
            count++;
			/*
			if((count >= 64) && (count < 72)) 
			vif.tl_rx_cb.tl_rx_ready <= 1'b0;
			else*/
			vif.tl_rx_cb.tl_rx_ready <= 1'b1;
			@(vif.tl_rx_cb);
        end

    endtask

endclass
`endif