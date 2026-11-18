`timescale 1ns/1ps

`ifndef TB_TOP
`define TB_TOP

module tb_top;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  bit clk;
  
  always #5 clk = ~clk;

  pcie_dll_if pcie_if( clk );

  pcie_dl_top dut (
        .clk(clk),
        .rst_n(pcie_if.rst_n),

	.tl_tx_data(pcie_if.tl_tx_data),
        .tl_tx_valid(pcie_if.tl_tx_valid),
        .tl_tx_ready(pcie_if.tl_tx_ready),
        .tl_tx_sop(pcie_if.tl_tx_sop),
        .tl_tx_eop(pcie_if.tl_tx_eop),
        .tl_tx_keep(pcie_if.tl_tx_keep),

	.tl_rx_data(pcie_if.tl_rx_data),
        .tl_rx_keep(pcie_if.tl_rx_keep),
        .tl_rx_valid(pcie_if.tl_rx_valid),
        .tl_rx_ready(pcie_if.tl_rx_ready),
        .tl_rx_sop(pcie_if.tl_rx_sop),
        .tl_rx_eop(pcie_if.tl_rx_eop),

        .phy_tx_data(pcie_if.phy_tx_data),
        .phy_tx_keep(pcie_if.phy_tx_keep),
        .phy_tx_valid(pcie_if.phy_tx_valid),
        .phy_tx_ready(pcie_if.phy_tx_ready),
        .phy_tx_sop(pcie_if.phy_tx_sop),
        .phy_tx_eop(pcie_if.phy_tx_eop),
        .phy_tx_is_tlp(pcie_if.phy_tx_is_tlp),

	.phy_rx_data(pcie_if.phy_rx_data),
        .phy_rx_keep(pcie_if.phy_rx_keep),
        .phy_rx_valid(pcie_if.phy_rx_valid),
        .phy_rx_sop(pcie_if.phy_rx_sop),
        .phy_rx_eop(pcie_if.phy_rx_eop),
        .phy_rx_is_tlp(pcie_if.phy_rx_is_tlp),

        .tx_busy(pcie_if.tx_busy),
        .tx_error(pcie_if.tx_error),
        .rx_sequence_error(pcie_if.rx_sequence_error),
        .rx_crc_error(pcie_if.rx_crc_error),
        .dllp_crc_error(pcie_if.dllp_crc_error)
    );

    initial 
    begin
        uvm_config_db #(virtual pcie_dll_if)::set(null, "*", "pcie_dll_if", pcie_if);
        run_test("");
    end

    always_comb 
    begin
        pcie_if.phy_rx_ready = dut.lcrcrx_ready;
        pcie_if.dbg_curr_seq = dut.u_dl_tx.current_seq;
        pcie_if.dbg_next_seq = dut.u_dl_tx.next_transmit_seq;
    end

    initial 
    begin
        wait (pcie_if.rst_n === 1'b1);
        if ($test$plusargs("ROLLOVER")) 
        begin
            @(posedge clk);
            force   dut.u_dl_tx.next_transmit_seq = 12'd4094;
            force   dut.u_dl_tx.current_seq       = 12'd4094;
            force   dut.u_dl_rx.next_rcv_seq      = 12'd4094;

            @(posedge clk);
            release dut.u_dl_tx.next_transmit_seq;
            release dut.u_dl_tx.current_seq;
            release dut.u_dl_rx.next_rcv_seq;
        end
    end

    initial 
    begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_top);
    end

endmodule
`endif