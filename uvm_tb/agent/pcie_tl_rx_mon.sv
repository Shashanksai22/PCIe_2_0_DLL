`ifndef PCIE_TL_RX_MON
`define PCIE_TL_RX_MON

class pcie_tl_rx_mon extends uvm_monitor;
	`uvm_component_utils(pcie_tl_rx_mon)

	uvm_analysis_port #(pcie_tlp_seq_item) analysis_port;

	virtual pcie_dll_if.TL_MRX vif;
	pcie_dll_config cfg;

	pcie_tlp_seq_item xtn;

	function new(string name = "pcie_tl_rx_mon",uvm_component parent);
		super.new(name,parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		analysis_port = new("analysis_port",this);

		if(!uvm_config_db #(pcie_dll_config) ::get(this,"","pcie_dll_config",cfg))
		  `uvm_error(get_type_name,"NOT GETTING CONFIG IN PCIE_DLL_ENV")

		vif = cfg.vif;
	endfunction

	task run_phase(uvm_phase phase);
   		bit [31:0] dw_q[$];

    	wait(vif.rst_n === 1'b1);
    	@(vif.tl_rx_mcb);

    	forever 
	    begin
    	    dw_q.delete();
        	xtn = pcie_tlp_seq_item::type_id::create("xtn");

        	// 1. Wait for SOP handshake
        	do begin
            	@(vif.tl_rx_mcb);
        	end while (!(vif.tl_rx_mcb.tl_rx_valid && vif.tl_rx_mcb.tl_rx_ready && vif.tl_rx_mcb.tl_rx_sop));

        	dw_q.push_back(vif.tl_rx_mcb.tl_rx_data);

        	// 2. Collect remaining beats until EOP handshake
        	if (!vif.tl_rx_mcb.tl_rx_eop) 
			begin
        	    forever 
				begin
            	    @(vif.tl_rx_mcb);
            	    if (vif.tl_rx_mcb.tl_rx_valid && vif.tl_rx_mcb.tl_rx_ready) 
					begin
                	    dw_q.push_back(vif.tl_rx_mcb.tl_rx_data);
                	    if (vif.tl_rx_mcb.tl_rx_eop) break;
                	end
            	end
        	end

        	// 3. Assign TLP DWords & broadcast to scoreboard
        	xtn.dw_stream = dw_q;
        	analysis_port.write(xtn);
        end
    endtask

endclass
`endif