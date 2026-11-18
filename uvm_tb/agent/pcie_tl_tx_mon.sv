`ifndef PCIE_TL_TX_MON
`define PCIE_TL_TX_MON

class pcie_tl_tx_mon extends uvm_monitor;
	`uvm_component_utils(pcie_tl_tx_mon)

	uvm_analysis_port #(pcie_tlp_seq_item) analysis_port;

	virtual pcie_dll_if.TL_MTX vif;
	pcie_dll_config cfg;

	pcie_tlp_seq_item xtn;

	function new(string name = "pcie_tl_tx_mon",uvm_component parent);
		super.new(name,parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		analysis_port = new("analysis_port",this);

		if(!uvm_config_db #(pcie_dll_config) ::get(this,"","pcie_dll_config",cfg))
		  `uvm_error(get_type_name,"NOT GETTING CONFIG IN PCIE_TL_TX_MON")

		vif = cfg.vif;
		
	endfunction

	task run_phase(uvm_phase phase);
        bit [31:0] dw_q[$];

        forever begin
            dw_q.delete(); // Clear queue for next packet
            xtn = pcie_tlp_seq_item::type_id::create("xtn");

            // 1. Wait for SOP handshake (valid && ready && sop)
            do begin
                @(vif.tl_tx_mcb);
            end while (!(vif.tl_tx_mcb.tl_tx_valid && vif.tl_tx_mcb.tl_tx_ready && vif.tl_tx_mcb.tl_tx_sop));

            dw_q.push_back(vif.tl_tx_mcb.tl_tx_data);

            // 2. Collect remaining beats until EOP handshake (skip if 1-beat packet)
            if (!vif.tl_tx_mcb.tl_tx_eop) 
			begin
                forever 
				begin
                    @(vif.tl_tx_mcb);
                    if (vif.tl_tx_mcb.tl_tx_valid && vif.tl_tx_mcb.tl_tx_ready) 
					begin
                        dw_q.push_back(vif.tl_tx_mcb.tl_tx_data);
                        if (vif.tl_tx_mcb.tl_tx_eop) break;
                    end
                end
            end

        // 3. Copy queue into dynamic array (auto-allocates exact size) & broadcast
        xtn.dw_stream = dw_q;
        analysis_port.write(xtn);
    end
endtask

endclass
`endif
