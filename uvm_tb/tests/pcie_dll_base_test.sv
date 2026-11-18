`ifndef PCIE_DLL_BASE_TEST
`define PCIE_DLL_BASE_TEST

class pcie_dll_base_test extends uvm_test;
	`uvm_component_utils(pcie_dll_base_test)

    pcie_dll_env  env;
    pcie_dll_config cfg;

    function new(string name = "pcie_dll_config",uvm_component parent);
	    super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
	  super.build_phase(phase);

	  cfg = pcie_dll_config::type_id::create("cfg");

	  if(!uvm_config_db #(virtual pcie_dll_if) ::get(this,"","pcie_dll_if",cfg.vif))
		  `uvm_error(get_type_name,"NOT GETTING VIRTUAL INTERFACE IN PCIE_DLL_BASE_TEST")

	   cfg.tl_tx_is_active  = UVM_ACTIVE;
	   cfg.tl_rx_is_active  = UVM_ACTIVE;
	   cfg.phy_tx_is_active = UVM_ACTIVE;
	   cfg.phy_rx_is_active = UVM_ACTIVE;

	   uvm_config_db #(pcie_dll_config) ::set(this,"*","pcie_dll_config",cfg);

	   env = pcie_dll_env::type_id::create("env",this);

    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
	  super.end_of_elaboration_phase(phase);

	  uvm_top.print_topology;
	endfunction

    // Inside pcie_base_test.sv:
	task run_phase(uvm_phase phase);
    	super.run_phase(phase);

    	if (cfg.enable_auto_ack) 
		begin
        	fork
            	begin
                	phy_rx_dllp_resp_seq resp_seq = phy_rx_dllp_resp_seq::type_id::create("resp_seq");
                	resp_seq.start(env.phy_rx_agt.phy_rx_seqr);
            	end
        	join_none
    	end
		
	endtask

endclass
`endif