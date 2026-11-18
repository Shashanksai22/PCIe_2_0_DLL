/*
4.8 pcie_phy_tx_arbiter.sv — packet source arbiter
Function: Selects either a complete TLP packet or a complete DLLP packet for the PHY TX stream. Locks the selection
until the final beat transfers.
Inputs: Inputs: clk, rst_n; TLP stream; DLLP stream; PHY ready.
Outputs: Outputs: TLP ready; DLLP ready; PHY output stream; PHY packet type.
Implementation notes: Never interleave beats from two packets. DLLP priority may be applied at packet boundaries, but
an active packet must finish before switching sources.
*/

module pcie_phy_tx_arbiter (
    input logic clk,
    input logic rst_n,

    // New TLP stream
    input logic [31:0] tlp_data,
    input logic [3:0] tlp_keep,
    input logic tlp_valid,
    output logic tlp_ready,
    input logic tlp_sop,
    input logic tlp_eop,

    // Replay TLP stream
    input logic [31:0] replay_data,
    input logic [3:0] replay_keep,
    input logic replay_valid,
    output logic replay_ready,
    input logic replay_sop,
    input logic replay_eop,

    // DLLP stream
    input logic [31:0] dllp_data,
    input logic [3:0] dllp_keep,
    input logic dllp_valid,
    output logic dllp_ready,
    input logic dllp_sop,
    input logic dllp_eop,

    // PHY output
    output logic [31:0] phy_tx_data,
    output logic [3:0] phy_tx_keep,
    output logic phy_tx_valid,
    input logic phy_tx_ready,
    output logic phy_tx_sop,
    output logic phy_tx_eop,
    output logic phy_tx_is_tlp
);

    typedef enum logic [1:0] {
        IDLE,
        NEW_TLP,
        REPLAY_TLP,
        DLLP
    } source_t;

    source_t selected_source;

    always_comb begin
        phy_tx_data = '0;
        phy_tx_keep = '0;
        phy_tx_valid = 1'b0;
        phy_tx_sop = 1'b0;
        phy_tx_eop = 1'b0;
        phy_tx_is_tlp = 1'b0;

        tlp_ready = 1'b0;
        replay_ready = 1'b0;
        dllp_ready = 1'b0;

        case (selected_source)

            NEW_TLP: begin
                phy_tx_data = tlp_data;
                phy_tx_keep = tlp_keep;
                phy_tx_valid = tlp_valid;
                phy_tx_sop = tlp_sop;
                phy_tx_eop = tlp_eop;
                phy_tx_is_tlp = 1'b1;
                tlp_ready = phy_tx_ready;
            end

            REPLAY_TLP: begin
                phy_tx_data = replay_data;
                phy_tx_keep = replay_keep;
                phy_tx_valid = replay_valid;
                phy_tx_sop = replay_sop;
                phy_tx_eop = replay_eop;
                phy_tx_is_tlp = 1'b1;
                replay_ready = phy_tx_ready;
            end

            DLLP: begin
                phy_tx_data = dllp_data;
                phy_tx_keep = dllp_keep;
                phy_tx_valid = dllp_valid;
                phy_tx_sop = dllp_sop;
                phy_tx_eop = dllp_eop;
                phy_tx_is_tlp = 1'b0;
                dllp_ready = phy_tx_ready;
            end

            default: begin
            end

        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            selected_source <= IDLE;
        end
        else begin
            case (selected_source)

                IDLE: begin
                    if (dllp_valid && dllp_sop)
                        selected_source <= DLLP;
                    else if (replay_valid && replay_sop)
                        selected_source <= REPLAY_TLP;
                    else if (tlp_valid && tlp_sop)
                        selected_source <= NEW_TLP;
                end

                NEW_TLP: begin
                    if (phy_tx_valid && phy_tx_ready && phy_tx_eop)
                        selected_source <= IDLE;
                end

                REPLAY_TLP: begin
                    if (phy_tx_valid && phy_tx_ready && phy_tx_eop)
                        selected_source <= IDLE;
                end

                DLLP: begin
                    if (phy_tx_valid && phy_tx_ready && phy_tx_eop)
                        selected_source <= IDLE;
                end

                default: selected_source <= IDLE;

            endcase
        end
    end

endmodule
