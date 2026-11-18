`ifndef PCIE_TLP_SEQ_ITEM
`define PCIE_TLP_SEQ_ITEM

class pcie_tlp_seq_item extends uvm_sequence_item;
    
    rand bit [2:0]  fmt;
    rand bit [4:0]  tlp_type;
    rand bit [2:0]  tc;
    rand bit [9:0]  length;

    rand bit [15:0] requester_id;
    rand bit [7:0]  tag;

    rand bit [3:0]  first_dw_be;
    rand bit [3:0]  last_dw_be;

    rand bit [63:0] address;
    rand bit [31:0] payload[];

    bit [31:0] dw_stream[];

    `uvm_object_utils_begin(pcie_tlp_seq_item)
        `uvm_field_int(fmt,          UVM_ALL_ON | UVM_BIN)
        `uvm_field_int(tlp_type,     UVM_ALL_ON | UVM_BIN)
        `uvm_field_int(tc,           UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(length,       UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(requester_id, UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(tag,          UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(first_dw_be,  UVM_ALL_ON | UVM_BIN)
        `uvm_field_int(last_dw_be,   UVM_ALL_ON | UVM_BIN)
        `uvm_field_int(address,      UVM_ALL_ON | UVM_HEX)
        `uvm_field_array_int(payload,   UVM_ALL_ON | UVM_HEX)
        `uvm_field_array_int(dw_stream, UVM_ALL_ON | UVM_HEX)
    `uvm_object_utils_end

    //  Group: Constraints
     constraint fmt_tlp_type {
        fmt[2] == 1'b0;
        if(tlp_type == 5'b00000) fmt inside {[0:3]};
        else if( tlp_type inside {5'b00010, 5'b00100, 5'b00101, 5'b01010} ) fmt inside {3'b000, 3'b010};
        else tlp_type == 0;//deafult
     }

     constraint payload_length {
        //length inside {[0:16];}//initially not using 0 as it give payload of 1024dw
        soft length inside  {[1:16]};
        if(fmt[1] == 1'b1) payload.size() == ((length == 0) ? 1024 : length);
        else {
            payload.size() == 0;
        }
     }

     constraint addressing {
        address[1:0] == 2'b00;
        if(fmt[0] == 0) address[63:32] == 0;
        else if(fmt[0] == 1) address[63:32] != 0;

        //4KB Boundary rule Memory in PCIe is divided into 4-KB ($4096$-byte) aligned pages (0x0000–0x0FFF, 0x1000–0x1FFF, etc.). Because $2^{12} = 4096$, the lower 12 bits of the target memory address (address[11:0]) tell you where inside the current 4-KB page the write/read starts (the starting byte offset).
        (address[11:0] + (((length == 0) ? 1024 : length)*4)) <= 4096;
     }

     constraint byte_enables {
        if(length == 1) last_dw_be == 0;
        else  {last_dw_be != 0 ; first_dw_be !=0;}
     }

     constraint io_config_restriction {
        if(tlp_type inside {5'b00010, 5'b00100, 5'b00101} ) 
        {
            fmt[0] == 0; 
            tc == 3'b000; 
            length == 10'd1; 
            last_dw_be == 4'b0000;
        }
     }


    //  Group: Functions
     function void post_randomize();
        pack(); // Automatically populates dw_stream[] right after randomize()
    endfunction

    function void pack();

        int header_dw = (fmt[0]) ? 4 : 3;
        dw_stream     = new[header_dw + payload.size()];

        dw_stream[0] = {fmt, tlp_type, 1'b0, tc, 4'h0, 1'b0, 1'b0, 2'b00, 2'b00, length};
        dw_stream[1] = {requester_id, tag, last_dw_be, first_dw_be};

        if(!fmt[0])
            dw_stream[2] = {address[31:2],2'b00};
        else
         begin
            dw_stream[2] = address[63:32];
            dw_stream[3] = {address[31:2],2'b00};
         end

        foreach (payload[i]) 
         begin
          dw_stream[header_dw + i] = payload[i];
         end

    endfunction

    //  Constructor: new
    function new(string name = "pcie_tlp_seq_item");
        super.new(name);
    endfunction: new

endclass: pcie_tlp_seq_item
`endif 
