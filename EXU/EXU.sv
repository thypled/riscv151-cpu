module EXU(
    input logic [6:0] opcode,
    input logic [3:0] funct,
    input logic [31:0] rdata1,
    input logic [31:0] rdata2,
    input logic [31:0] imm,
    input logic alu_src_imm,
    input logic [31:0] PC,

    output logic [31:0] ALU_result,
    output logic [31:0] branch_target,
    output logic ALU_zero
);

    logic [3:0] ALUOp;
    logic [31:0] ALU_input2;


    ALUdec aludec(
        .opcode (opcode),
        .funct  (funct[2:0]),
        .add_rshift_type  (funct[3]),
        .ALUop (ALUOp)
    );

    assign ALU_input2 = alu_src_imm? imm : rdata2;    
    ALU alu(
        .A (rdata1),
        .B (ALU_input2),
        .ALUop (ALUOp),
        .Out (ALU_result) 
    );
    assign ALU_zero = ALU_result == '0;
    assign branch_target = PC + imm;
endmodule