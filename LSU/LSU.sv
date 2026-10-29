module LSU(
    input logic [31:0] ALU_result,
    input logic [31:0] wdata,
    input logic [2:0] ctrl_mem,
    input logic ALU_zero,
    input logic [31:0] branch_target,
    
    output logic [31:0] rdata,
    output logic [31:0] address,
    output logic PC_mux_ctrl
);
    assign PC_mux_ctrl = ALU_zero && ctrl_mem[2];
endmodule
