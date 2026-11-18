`ifndef PCIE_PHY_TX_MON
`define PCIE_PHY_TX_MON

class pcie_phy_tx_mon extends uvm_monitor;
	`uvm_component_utils(pcie_phy_tx_mon)

	uvm_analysis_port #(pcie_phy_seq_item) analysis_port;
	
	virtual pcie_dll_if.PHY_MTX vif;
	pcie_dll_config cfg;

	pcie_phy_seq_item xtn;

	function new(string name = "pcie_phy_tx_mon",uvm_component parent);
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
        bit [3:0]  keep_q[$];

        wait(vif.rst_n === 1'b1);
        @(vif.phy_tx_mcb);

        forever 
		begin
            dw_q.delete();
            keep_q.delete();
            xtn = pcie_phy_seq_item::type_id::create("xtn");

            // 1. Wait for SOP handshake
            do begin
                @(vif.phy_tx_mcb);
            end while (!(vif.phy_tx_mcb.phy_tx_valid &&     vif.phy_tx_mcb.phy_tx_ready &&     vif.phy_tx_mcb.phy_tx_sop));

            xtn.is_tlp = vif.phy_tx_mcb.phy_tx_is_tlp;
            dw_q.push_back(vif.phy_tx_mcb.phy_tx_data);
            keep_q.push_back(vif.phy_tx_mcb.phy_tx_keep);

            // 2. Collect remaining beats until EOP handshake
            if (!vif.phy_tx_mcb.phy_tx_eop) 
			begin
                forever 
				begin
                    @(vif.phy_tx_mcb);
                    if (vif.phy_tx_mcb.phy_tx_valid && vif.phy_tx_mcb.phy_tx_ready) 
					begin
                        dw_q.push_back(vif.phy_tx_mcb.phy_tx_data);
                        keep_q.push_back(vif.phy_tx_mcb.phy_tx_keep);
                        if (vif.phy_tx_mcb.phy_tx_eop) break;
                    end
                end
            end

            // 3. Assign arrays, unpack fields & broadcast to scoreboard
            xtn.dw_stream   = dw_q;
            xtn.keep_stream = keep_q;
            xtn.unpack();
            analysis_port.write(xtn);
        end
    endtask
endclass
`endif