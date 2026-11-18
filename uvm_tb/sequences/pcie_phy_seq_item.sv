`ifndef PCIE_PHY_SEQ_ITEM
`define PCIE_PHY_SEQ_ITEM

class pcie_phy_seq_item extends uvm_sequence_item;

    // Packet type
    rand bit is_tlp;      // 1 - tlp , 0 - dllp

    // Common fields
    rand bit [11:0] seq_num;
    rand bit corrupt_crc;

    // DLLP fields
    rand bit [7:0] dllp_type;   // ACK = 8'H000 , NCK = 8'H010

    // TLP fields: original TLP DWORDs, without prefix/LCRC
    rand bit [31:0] tlp_payload[];

    // Packed PHY stream
    bit [31:0] dw_stream[];
    bit [3:0]  keep_stream[];
    byte unsigned bytes[];

    // Calculated CRCs
    bit [31:0] lcrc;
    bit [15:0] dllp_crc;

    
    `uvm_object_utils_begin(pcie_phy_seq_item)
        `uvm_field_int(is_tlp,            UVM_ALL_ON | UVM_BIN)
        `uvm_field_int(seq_num,           UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(corrupt_crc,       UVM_ALL_ON | UVM_BIN)
        `uvm_field_int(dllp_type,         UVM_ALL_ON | UVM_HEX)
        `uvm_field_array_int(tlp_payload, UVM_ALL_ON | UVM_HEX)
        `uvm_field_array_int(dw_stream,   UVM_ALL_ON | UVM_HEX)
        `uvm_field_array_int(keep_stream, UVM_ALL_ON | UVM_BIN)
        `uvm_field_array_int(bytes,       UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(lcrc,              UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(dllp_crc,          UVM_ALL_ON | UVM_HEX)
    `uvm_object_utils_end

    //  Group: Constraints
     constraint c_packet {
        soft corrupt_crc == 0;

        if (is_tlp) {
            tlp_payload.size() inside {[3:20]};
        }
        else {
            tlp_payload.size() == 0;
            dllp_type inside {8'h00, 8'h10};
        }

        if (is_tlp) {
            tlp_payload.size() inside {[3:10]};
            foreach (tlp_payload[i]) tlp_payload[i] != 32'h0;
        }
    }

    //  Group: Functions
    function void post_randomize();
        pack();
    endfunction

     // CRC-32: PCIe TLP LCRC
    static function bit [31:0] calc_lcrc32(  input byte unsigned data[]  );

        bit [31:0] crc = 32'hFFFF_FFFF;

        foreach (data[i]) 
        begin
            for (int b = 0; b < 8; b++) 
            begin
                crc = (crc[0] ^ data[i][b])
                    ? ((crc >> 1) ^ 32'hEDB8_8320)
                    : (crc >> 1);
            end
        end

        return ~crc;

    endfunction

    // CRC-16: DLLP
    static function bit [15:0] calc_crc16(   input bit [31:0] data   );

        bit [15:0] crc = 16'hFFFF;

        for (int b = 0; b < 4; b++) begin
            for (int i = 0; i < 8; i++) begin
                crc = (crc[0] ^ data[b*8+i])
                    ? ((crc >> 1) ^ 16'hD008)
                    : (crc >> 1);
            end
        end

        return ~crc;

    endfunction

    // ------------------------------------------------
    // PACK (4-byte prefix + TLP + 4-byte LCRC)
    // ------------------------------------------------
    function void pack();
        byte unsigned crc_bytes[];
        int total_bytes;
        int num_beats;

        if (is_tlp) 
        begin

            // 4-byte prefix + TLP + 4-byte LCRC
            total_bytes = 4 + (tlp_payload.size() * 4) + 4;
            bytes = new[total_bytes];
   
            // 4-byte Sequence prefix: {16'h0000, 4'b0000, seq_num[11:0]}
            bytes[0] = 8'h00;
            bytes[1] = 8'h00;
            bytes[2] = seq_num[7:0];              // bits [23:16] = seq_num[7:0]
            bytes[3] = {4'b0000, seq_num[11:8]};

            // Original TLP DWORDs starting at byte 4
            foreach (tlp_payload[i]) 
            begin
                bytes[4 + i*4 + 0] = tlp_payload[i][7:0];
                bytes[4 + i*4 + 1] = tlp_payload[i][15:8];
                bytes[4 + i*4 + 2] = tlp_payload[i][23:16];
                bytes[4 + i*4 + 3] = tlp_payload[i][31:24];
            end

            // Calculate LCRC over 4-byte prefix + TLP (excluding LCRC)
            crc_bytes = new[total_bytes - 4];
            for (int i = 0; i < total_bytes - 4; i++)
                crc_bytes[i] = bytes[i];

            lcrc = calc_lcrc32(crc_bytes);
            if (corrupt_crc)
                lcrc[0] = ~lcrc[0];

            // Append LCRC at last 4 bytes
            bytes[total_bytes - 4] = lcrc[7:0];
            bytes[total_bytes - 3] = lcrc[15:8];
            bytes[total_bytes - 2] = lcrc[23:16];
            bytes[total_bytes - 1] = lcrc[31:24];
            
        end
        else 
        begin
            // DLLP: 4-byte header + 2-byte CRC
            total_bytes = 6;
            bytes = new[total_bytes];

            bytes[0] = dllp_type;
            bytes[1] = 8'h00;
            bytes[2] = seq_num[7:0];              // bits [23:16] = seq_num[7:0]
            bytes[3] = {4'b0000, seq_num[11:8]};  // bits [27:24] = seq_num[11:8]

            dllp_crc = calc_crc16({bytes[3], bytes[2], bytes[1], bytes[0]});
            if (corrupt_crc)
                dllp_crc[0] = ~dllp_crc[0];

            bytes[4] = dllp_crc[7:0];
            bytes[5] = dllp_crc[15:8];
        end

        // Convert byte stream to 32-bit PHY beats (all TLP beats now have keep = 4'hF)
        num_beats   = (total_bytes + 3) / 4;
        dw_stream   = new[num_beats];
        keep_stream = new[num_beats];

        foreach (dw_stream[i]) begin
            dw_stream[i]   = '0;
            keep_stream[i] = '0;
        end

        foreach (bytes[i]) begin
            dw_stream[i/4][(i%4)*8 +: 8] = bytes[i];
            keep_stream[i/4][i%4]        = 1'b1;
        end
    endfunction

    // ------------------------------------------------
    // UNPACK (4-byte prefix + TLP + 4-byte LCRC)
    // ------------------------------------------------
    function void unpack();
        int total_bytes = 0;
        int idx = 0;

        foreach (keep_stream[i])
            for (int b = 0; b < 4; b++)
                if (keep_stream[i][b])
                    total_bytes++;

        bytes = new[total_bytes];
        foreach (dw_stream[i]) begin
            for (int b = 0; b < 4; b++) begin
                if (keep_stream[i][b]) begin
                    bytes[idx] = dw_stream[i][b*8 +: 8];
                    idx++;
                end
            end
        end

        // Min TLP: 4B prefix + 12B (3-DW header) + 4B LCRC = 20 bytes
        if (is_tlp && total_bytes >= 20) begin
            seq_num = {bytes[3][3:0], bytes[2]};

            // Exclude 4-byte prefix and 4-byte LCRC (8 bytes total)
            tlp_payload = new[(total_bytes - 8) / 4];

            foreach (tlp_payload[i]) begin
                tlp_payload[i] = {
                    bytes[4 + i*4 + 3],
                    bytes[4 + i*4 + 2],
                    bytes[4 + i*4 + 1],
                    bytes[4 + i*4 + 0]
                };
            end

            lcrc = {
                bytes[total_bytes - 1],
                bytes[total_bytes - 2],
                bytes[total_bytes - 3],
                bytes[total_bytes - 4]
            };
        end
        else if (!is_tlp && total_bytes == 6) begin
            dllp_type = bytes[0];
            seq_num   = {bytes[3][3:0], bytes[2]};
            dllp_crc  = {bytes[5], bytes[4]};
        end
    endfunction

    //  Constructor: new
    function new(string name = "pcie_phy_seq_item");
        super.new(name);
    endfunction: new
    
endclass: pcie_phy_seq_item
`endif