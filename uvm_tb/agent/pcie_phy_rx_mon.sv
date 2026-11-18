`ifndef PCIE_PHY_RX_MON
`define PCIE_PHY_RX_MON

class pcie_phy_rx_mon extends uvm_monitor;
	`uvm_component_utils(pcie_phy_rx_mon)

	uvm_analysis_port #(pcie_phy_seq_item) analysis_port;
	
	virtual pcie_dll_if.PHY_MRX vif;
	pcie_dll_config cfg;

	pcie_phy_seq_item xtn;

	function new(string name = "pcie_phy_rx_mon", uvm_component parent);
		super.new(name,parent);
	endfunction

	function void build_phase(uvm_phase phase);
		
		if(!uvm_config_db #(pcie_dll_config) ::get(this,"","pcie_dll_config",cfg))
		  `uvm_error(get_type_name,"NOT GETTING CONFIG IN PCIE_DLL_ENV")

		super.build_phase(phase);

		analysis_port = new("analysis_port",this);

		vif = cfg.vif;
	endfunction

	task run_phase(uvm_phase phase);
        bit [31:0] dw_q[$];
        bit [3:0]  k_q[$];

        wait(vif.rst_n === 1'b1);
        @(vif.phy_rx_mcb);

        forever 
		begin
            dw_q.delete();
            k_q.delete();
            xtn = pcie_phy_seq_item::type_id::create("xtn");

            // 1. Wait for SOP valid beat
            do begin
                @(vif.phy_rx_mcb);
            end while (!(vif.phy_rx_mcb.phy_rx_valid && vif.phy_rx_mcb.phy_rx_sop));

            xtn.is_tlp = vif.phy_rx_mcb.phy_rx_is_tlp;
            dw_q.push_back(vif.phy_rx_mcb.phy_rx_data);
            k_q.push_back(vif.phy_rx_mcb.phy_rx_keep);

            // 2. Collect remaining beats until EOP
            if (!vif.phy_rx_mcb.phy_rx_eop) 
			begin
                forever 
				begin
                    @(vif.phy_rx_mcb);
                    if (vif.phy_rx_mcb.phy_rx_valid) 
				    begin
                        dw_q.push_back(vif.phy_rx_mcb.phy_rx_data);
                        k_q.push_back(vif.phy_rx_mcb.phy_rx_keep);
                        if (vif.phy_rx_mcb.phy_rx_eop) break;
                    end
                end
            end

            // 3. Assign arrays, unpack fields & broadcast
            xtn.dw_stream   = dw_q;
            xtn.keep_stream = k_q;
            xtn.unpack();
            analysis_port.write(xtn);
        end
    endtask

endclass
`endif