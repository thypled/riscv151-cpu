module EXU(
    input [6:0] opcode,
    input [3:0] funct,

);
    logic [3:0] ALUOp;
    logic [31:0] Out;

    ALUdec aludec(
        .opcode (opcode),
        .funct  (funct[2:0]),
        .add_rshift_type  (funct[3]),
        .ALUop (ALUOp)
    );
    ALU alu(
        .A (rdata1),
        .B (rdata2),
        .ALUop (ALUOp),
        .Out (out) 
    );