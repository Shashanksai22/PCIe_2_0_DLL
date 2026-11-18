`ifndef PCIE_TL_TX_DRV
`define PCIE_TL_TX_DRV

class pcie_tl_tx_drv extends uvm_driver#(pcie_tlp_seq_item);
	`uvm_component_utils(pcie_tl_tx_drv)

	virtual pcie_dll_if vif;
	pcie_dll_config cfg;

	pcie_tlp_seq_item xtn;

	function new(string name = "pcie_tl_tx_drv",uvm_component parent);
		super.new(name,parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		if(!uvm_config_db #(pcie_dll_config) ::get(this,"","pcie_dll_config",cfg))
		  `uvm_error(get_type_name,"NOT GETTING CONFIG IN PCIE_TL_TX_DRV")

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

    task drive(pcie_tlp_seq_item xtn);
		    @(vif.tl_tx_cb);
        foreach (xtn.dw_stream[i]) 
       	  begin
            vif.tl_tx_cb.tl_tx_data  <= xtn.dw_stream[i];
            vif.tl_tx_cb.tl_tx_keep  <= 4'b1111;
            vif.tl_tx_cb.tl_tx_sop <= (i == 0) ? 1'b1 : 1'b0;
            vif.tl_tx_cb.tl_tx_eop <= (i == xtn.dw_stream.size() - 1) ? 1'b1 : 1'b0;
            vif.tl_tx_cb.tl_tx_valid <= 1'b1;

            // Synchronized handshake: hold beat until sampled with ready == 1
            do begin
                @(vif.tl_tx_cb);
            end while (!vif.tl_tx_cb.tl_tx_ready);

          end

          // Deassert valid & framing after EOP handshake completes
          vif.tl_tx_cb.tl_tx_valid <= 1'b0;
          vif.tl_tx_cb.tl_tx_sop   <= 1'b0;
          vif.tl_tx_cb.tl_tx_eop   <= 1'b0;

	endtask	

endclass
`endif