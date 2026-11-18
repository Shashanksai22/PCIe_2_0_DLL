/*
4.9 pcie_dl_top.sv — integration top
Function: Instantiates and connects the eight functional blocks. Exposes TL TX/RX and PHY RX/TX streams, packet-type
sidebands, and status outputs.
Inputs: Inputs: clk, rst_n; TL TX stream; PHY RX stream and packet type; PHY TX ready; TL RX ready.
Outputs: Outputs: TL TX ready; TL RX stream; PHY RX ready; PHY TX stream and packet type; tx_busy, replay_active,
link_error.
Implementation notes: Use explicit internal wires/interfaces for all submodule handshakes. Keep top-level logic limited to
integration and status aggregation
*/

module pcie_dl_top #(
    parameter int DATA_W       = 32,
    parameter int SEQ_W        = 12,
    parameter int MAX_PKT_DW   = 1024,
    parameter int REPLAY_DEPTH = 8,
    parameter int REPLAY_TIMEOUT_CYCLES = 1024
)(
    input  logic clk,
    input  logic rst_n,

    // Transaction Layer TX
    input  logic [DATA_W-1:0] tl_tx_data,
    input  logic              tl_tx_valid,
    output logic              tl_tx_ready,
    input  logic              tl_tx_sop,
    input  logic              tl_tx_eop,
    input  logic [3:0]        tl_tx_keep,

    // Transaction Layer RX
    output logic [DATA_W-1:0] tl_rx_data,
    output logic [3:0]        tl_rx_keep,
    output logic              tl_rx_valid,
    input  logic              tl_rx_ready,
    output logic              tl_rx_sop,
    output logic              tl_rx_eop,

    // PHY TX
    output logic [DATA_W-1:0] phy_tx_data,
    output logic [3:0]        phy_tx_keep,
    output logic              phy_tx_valid,
    input  logic              phy_tx_ready,
    output logic              phy_tx_sop,
    output logic              phy_tx_eop,
    output logic              phy_tx_is_tlp,

    // PHY RX
    input  logic [DATA_W-1:0] phy_rx_data,
    input  logic [3:0]        phy_rx_keep,
    input  logic              phy_rx_valid,
    input  logic              phy_rx_sop,
    input  logic              phy_rx_eop,
    input  logic              phy_rx_is_tlp,

    // Status
    output logic              tx_busy,
    output logic              tx_error,
    output logic              rx_sequence_error,
    output logic              rx_crc_error,
    output logic              dllp_crc_error
);

    // =========================================================
    // Internal signals
    // =========================================================

    // TX LCRC
    logic lcrc_start;
    logic [DATA_W-1:0] lcrc_data;
    logic lcrc_valid, lcrc_ready;
    logic lcrc_sop, lcrc_eop;
    logic [3:0] lcrc_keep;
    logic [31:0] lcrc_result;
    logic lcrc_result_valid, lcrc_result_ready;

    // Replay buffer
    logic replay_buf_full, replay_buf_ready;
    logic buf_wr_ready;
    logic [DATA_W-1:0] buf_wr_data;
    logic buf_wr_valid, buf_wr_sop, buf_wr_eop;
    logic [3:0] buf_wr_keep;
    logic [SEQ_W-1:0] buf_wr_seq_num;

    logic buf_rd_start, buf_rd_found;
    logic [SEQ_W-1:0] buf_rd_seq_num;
    logic [DATA_W-1:0] replay_data;
    logic [3:0] replay_keep;
    logic replay_valid, replay_ready;
    logic replay_sop, replay_eop, replay_done;

    // Replay controller
    logic replay_req, replay_req_ready;
    logic [SEQ_W-1:0] replay_req_seq;
    logic buf_free_valid;
    logic [SEQ_W-1:0] buf_free_seq;

    // DLLP TX/RX
    logic ack_req, nak_req;
    logic [SEQ_W-1:0] ack_req_seq, nak_req_seq;

    logic dllp_tx_req_ready;
    logic [DATA_W-1:0] dllp_tx_data;
    logic [3:0] dllp_tx_keep;
    logic dllp_tx_valid, dllp_tx_sop, dllp_tx_eop;
    logic dllp_tx_ready;

    logic ack_valid, nak_valid;
    logic [SEQ_W-1:0] ack_seq, nak_seq;

    // RX LCRC checker
    logic lcrcrx_ready;
    logic [DATA_W-1:0] lcrcrx_data;
    logic [3:0] lcrcrx_keep;
    logic lcrcrx_valid, lcrcrx_sop, lcrcrx_eop;
    logic lcrcrx_crc_error, lcrcrx_packet_done;

    // RX sequence checker
    logic dlrx_ready;
    logic [DATA_W-1:0] dlrx_data;
    logic [3:0] dlrx_keep;
    logic dlrx_valid, dlrx_sop, dlrx_eop;

    // PHY arbiter
    logic arb_tlp_ready;
    logic arb_replay_ready;
    logic arb_dllp_ready;

    logic [DATA_W-1:0] tx_stream_data;
    logic [3:0] tx_stream_keep;
    logic tx_stream_valid, tx_stream_sop, tx_stream_eop;
    logic tx_stream_is_tlp;

    // =========================================================
    // 4.1 TX controller
    // =========================================================

    pcie_dl_tx #(
        .DATA_W(DATA_W),
        .SEQ_W(SEQ_W),
        .MAX_PKT_DW(MAX_PKT_DW),
        .REPLAY_DEPTH(REPLAY_DEPTH)
    ) u_dl_tx (
        .clk(clk),
        .rst_n(rst_n),

        .tl_tx_data(tl_tx_data),
        .tl_tx_valid(tl_tx_valid),
        .tl_tx_ready(tl_tx_ready),
        .tl_tx_sop(tl_tx_sop),
        .tl_tx_eop(tl_tx_eop),
        .tl_tx_keep(tl_tx_keep),

        .replay_buf_full(replay_buf_full),
        .replay_buf_ready(replay_buf_ready),

        .buf_wr_data(buf_wr_data),
        .buf_wr_valid(buf_wr_valid),
        .buf_wr_ready(buf_wr_ready),
        .buf_wr_sop(buf_wr_sop),
        .buf_wr_eop(buf_wr_eop),
        .buf_wr_keep(buf_wr_keep),
        .buf_wr_seq_num(buf_wr_seq_num),

        .lcrc_start(lcrc_start),
        .lcrc_data(lcrc_data),
        .lcrc_valid(lcrc_valid),
        .lcrc_ready(lcrc_ready),
        .lcrc_sop(lcrc_sop),
        .lcrc_eop(lcrc_eop),
        .lcrc_keep(lcrc_keep),
        .lcrc_result(lcrc_result),
        .lcrc_result_valid(lcrc_result_valid),
        .lcrc_result_ready(lcrc_result_ready),

        .buf_rd_start(buf_rd_start),
        .buf_rd_seq_num(buf_rd_seq_num),
        .buf_rd_found(buf_rd_found),

        .replay_data(replay_data),
        .replay_valid(replay_valid),
        .replay_ready(replay_ready),
        .replay_sop(replay_sop),
        .replay_eop(replay_eop),
        .replay_keep(replay_keep),
        .replay_done(replay_done),

        .replay_req(replay_req),
        .replay_req_seq(replay_req_seq),
        .replay_req_ready(replay_req_ready),

        .phy_tx_data(tx_stream_data),
        .phy_tx_valid(tx_stream_valid),
        .phy_tx_ready(arb_tlp_ready),
        .phy_tx_sop(tx_stream_sop),
        .phy_tx_eop(tx_stream_eop),
        .phy_tx_keep(tx_stream_keep),
        .phy_tx_is_tlp(tx_stream_is_tlp),

        .tx_busy(tx_busy),
        .tx_error(tx_error)
    );

    // =========================================================
    // 4.2 TX LCRC generator
    // =========================================================

    pcie_lcrc_tx u_lcrc_tx (
        .clk(clk),
        .rst_n(rst_n),
        .lcrc_start(lcrc_start),
        .lcrc_data(lcrc_data),
        .lcrc_valid(lcrc_valid),
        .lcrc_ready(lcrc_ready),
        .lcrc_sop(lcrc_sop),
        .lcrc_eop(lcrc_eop),
        .lcrc_keep(lcrc_keep),
        .lcrc_result(lcrc_result),
        .lcrc_result_valid(lcrc_result_valid),
        .lcrc_result_ready(lcrc_result_ready)
    );

    // =========================================================
    // 4.5 Replay buffer
    // =========================================================

    pcie_replay_buffer #(
        .DATA_W(DATA_W),
        .SEQ_W(SEQ_W),
        .MAX_PKT_DW(MAX_PKT_DW + 2),
        .REPLAY_DEPTH(REPLAY_DEPTH)
    ) u_replay_buffer (
        .clk(clk),
        .rst_n(rst_n),

        .buf_full(replay_buf_full),
        .buf_ready(replay_buf_ready),

        .buf_wr_data(buf_wr_data),
        .buf_wr_valid(buf_wr_valid),
        .buf_wr_ready(buf_wr_ready),
        .buf_wr_sop(buf_wr_sop),
        .buf_wr_eop(buf_wr_eop),
        .buf_wr_keep(buf_wr_keep),
        .buf_wr_seq_num(buf_wr_seq_num),

        .buf_rd_start(buf_rd_start),
        .buf_rd_seq_num(buf_rd_seq_num),
        .buf_rd_found(buf_rd_found),

        .replay_data(replay_data),
        .replay_valid(replay_valid),
        .replay_ready(replay_ready),
        .replay_sop(replay_sop),
        .replay_eop(replay_eop),
        .replay_keep(replay_keep),
        .replay_done(replay_done),

        .buf_free_valid(buf_free_valid),
        .buf_free_seq_num(buf_free_seq)
    );

    // =========================================================
    // 4.6 Replay controller
    // =========================================================

    pcie_replay_ctrl #(
        .SEQ_W(SEQ_W),
        .REPLAY_DEPTH(REPLAY_DEPTH),
        .REPLAY_TIMEOUT_CYCLES(REPLAY_TIMEOUT_CYCLES)
    ) u_replay_ctrl (
        .clk(clk),
        .rst_n(rst_n),

        .tx_tlp_valid(buf_wr_valid && buf_wr_ready && buf_wr_eop),
        .tx_tlp_seq(buf_wr_seq_num),

        .ack_valid(ack_valid),
        .ack_seq(ack_seq),
        .nak_valid(nak_valid),
        .nak_seq(nak_seq),

        .replay_req(replay_req),
        .replay_req_seq(replay_req_seq),
        .replay_req_ready(replay_req_ready),
        .replay_done(replay_done),

        .buf_free_valid(buf_free_valid),
        .buf_free_seq(buf_free_seq)
    );

    // =========================================================
    // 4.4 RX LCRC checker
    // =========================================================

    pcie_lcrc_rx #(
        .DATA_W(DATA_W),
        .MAX_PKT_DW(MAX_PKT_DW + 2)
    ) u_lcrc_rx (
        .clk(clk),
        .rst_n(rst_n),

        .rx_data(phy_rx_data),
        .rx_keep(phy_rx_keep),
        .rx_valid(phy_rx_valid && phy_rx_is_tlp),
        .rx_ready(lcrcrx_ready),
        .rx_sop(phy_rx_sop),
        .rx_eop(phy_rx_eop),

        .out_data(lcrcrx_data),
        .out_keep(lcrcrx_keep),
        .out_valid(lcrcrx_valid),
        .out_ready(dlrx_ready),
        .out_sop(lcrcrx_sop),
        .out_eop(lcrcrx_eop),

        .crc_error(lcrcrx_crc_error),
        .packet_done(lcrcrx_packet_done)
    );

    assign rx_crc_error = lcrcrx_crc_error;

    // =========================================================
    // 4.3 RX sequence checker
    // =========================================================

    pcie_dl_rx #(
        .SEQ_W(SEQ_W)
    ) u_dl_rx (
        .clk(clk),
        .rst_n(rst_n),

        .in_data(lcrcrx_data),
        .in_keep(lcrcrx_keep),
        .in_valid(lcrcrx_valid),
        .in_ready(dlrx_ready),
        .in_sop(lcrcrx_sop),
        .in_eop(lcrcrx_eop),

        .tlp_data(tl_rx_data),
        .tlp_keep(tl_rx_keep),
        .tlp_valid(tl_rx_valid),
        .tlp_ready(tl_rx_ready),
        .tlp_sop(tl_rx_sop),
        .tlp_eop(tl_rx_eop),

        .ack_req(ack_req),
        .ack_seq(ack_req_seq),
        .nak_req(nak_req),
        .nak_seq(nak_req_seq),

        .lcrc_error(lcrcrx_crc_error),

        .sequence_error(rx_sequence_error)
    );

    // =========================================================
    // 4.7 DLLP controller
    // =========================================================

    pcie_dllp_ctrl u_dllp_ctrl (
        .clk(clk),
        .rst_n(rst_n),

        .tx_req_valid(ack_req || nak_req),
        .tx_req_nak(nak_req),
        .tx_req_seq(nak_req ? nak_req_seq : ack_req_seq),
        .tx_req_ready(dllp_tx_req_ready),

        .tx_data(dllp_tx_data),
        .tx_keep(dllp_tx_keep),
        .tx_valid(dllp_tx_valid),
        .tx_sop(dllp_tx_sop),
        .tx_eop(dllp_tx_eop),
        .tx_ready(dllp_tx_ready),

        .rx_data(phy_rx_data),
        .rx_keep(phy_rx_keep),
        .rx_valid(phy_rx_valid && !phy_rx_is_tlp),
        .rx_sop(phy_rx_sop),
        .rx_eop(phy_rx_eop),

        .ack_valid(ack_valid),
        .ack_seq(ack_seq),
        .nak_valid(nak_valid),
        .nak_seq(nak_seq),
        .rx_crc_error(dllp_crc_error)
    );

    // =========================================================
    // 4.8 PHY TX arbiter
    // =========================================================

    pcie_phy_tx_arbiter u_phy_tx_arbiter (
        .clk(clk),
        .rst_n(rst_n),

        // TX controller provides both new and replay TLP streams.
        .tlp_data(tx_stream_data),
        .tlp_keep(tx_stream_keep),
        .tlp_valid(tx_stream_valid),
        .tlp_ready(arb_tlp_ready),
        .tlp_sop(tx_stream_sop),
        .tlp_eop(tx_stream_eop),

        // Replay is already selected and forwarded by pcie_dl_tx.
        .replay_data('0),
        .replay_keep('0),
        .replay_valid(1'b0),
        .replay_ready(arb_replay_ready),
        .replay_sop(1'b0),
        .replay_eop(1'b0),

        .dllp_data(dllp_tx_data),
        .dllp_keep(dllp_tx_keep),
        .dllp_valid(dllp_tx_valid),
        .dllp_ready(dllp_tx_ready),
        .dllp_sop(dllp_tx_sop),
        .dllp_eop(dllp_tx_eop),

        .phy_tx_data(phy_tx_data),
        .phy_tx_keep(phy_tx_keep),
        .phy_tx_valid(phy_tx_valid),
        .phy_tx_ready(phy_tx_ready),
        .phy_tx_sop(phy_tx_sop),
        .phy_tx_eop(phy_tx_eop),
        .phy_tx_is_tlp(phy_tx_is_tlp)
    );

endmodule
