`ifndef PHY_RX_DLLP_RESP_SEQ
`define PHY_RX_DLLP_RESP_SEQ

class phy_rx_dllp_resp_seq extends uvm_sequence #(pcie_phy_seq_item);
    `uvm_object_utils(phy_rx_dllp_resp_seq)
    `uvm_declare_p_sequencer(pcie_phy_rx_seqr)

    function new(string name = "phy_rx_dllp_resp_seq");
        super.new(name);
    endfunction

    task body();
        pcie_phy_seq_item sb_cmd;

        forever 
        begin
            p_sequencer.dllp_resp_fifo.get(sb_cmd); // Blocks until SB approves a TX TLP

            req = pcie_phy_seq_item::type_id::create("dllp_pkt");
            start_item(req);
            assert(req.randomize() with {
                is_tlp      == 1'b0;
                dllp_type   == sb_cmd.dllp_type; // 8'h00 = ACK, 8'h10 = NAK
                seq_num     == sb_cmd.seq_num;
                corrupt_crc == 1'b0;
            }); // post_randomize() automatically calls pack() and computes CRC-16!
            finish_item(req);
        end
    endtask
endclass
`endif