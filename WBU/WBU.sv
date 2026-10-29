module WBU(
    input logic MemtoReg,
    input logic [31:0] rdata,
    input logic [31:0] wdata,
    output logic [31:0] SelectedData
);
    // MemtoReg selects memory read data; otherwise write back the ALU result.
    assign SelectedData = MemtoReg ? rdata : wdata;
endmodule
