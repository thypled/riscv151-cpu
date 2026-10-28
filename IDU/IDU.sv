module IDU (
    input  logic [31:0] inst,

    output logic [4:0]  rs1,
    output logic [4:0]  rs2,
    output logic [31:0] imm,
    output logic [6:0]  opcode,
    // Raw instruction fields for ALUdec: {inst[30], inst[14:12]}.
    output logic [3:0]  funct,
    output logic [4:0]  rd,
    // ALU operand B: 0 selects rs2, 1 selects the immediate.
    output logic        alu_src_imm,
    output logic [2:0]  ctrl_mem,
    // {RegWrite, MemtoReg}
    output logic [1:0]  ctrl_wb
);

    localparam logic [6:0] OPC_RTYPE  = 7'b0110011;
    localparam logic [6:0] OPC_ITYPE  = 7'b0010011;
    localparam logic [6:0] OPC_LOAD   = 7'b0000011;
    localparam logic [6:0] OPC_JALR   = 7'b1100111;
    localparam logic [6:0] OPC_STORE  = 7'b0100011;
    localparam logic [6:0] OPC_BRANCH = 7'b1100011;
    localparam logic [6:0] OPC_LUI    = 7'b0110111;
    localparam logic [6:0] OPC_AUIPC  = 7'b0010111;
    localparam logic [6:0] OPC_JAL    = 7'b1101111;

    assign opcode = inst[6:0];

    // Decode within the ID cycle; top owns the ID/EX pipeline registers.
    always_comb begin
        rs1      = 5'b0;
        rs2      = 5'b0;
        imm      = 32'b0;
        funct    = {inst[30], inst[14:12]};
        rd       = 5'b0;
        alu_src_imm = 1'b0;
        ctrl_mem = 3'b0;
        ctrl_wb  = 2'b00;

        case (opcode)

            OPC_RTYPE: begin
                rs1 = inst[19:15];
                rs2 = inst[24:20];
                rd  = inst[11:7];

                alu_src_imm = 1'b0;
                ctrl_wb = 2'b10;
            end

            OPC_ITYPE: begin
                rs1 = inst[19:15];
                rd  = inst[11:7];
                imm = {{20{inst[31]}}, inst[31:20]};

                alu_src_imm = 1'b1;
                ctrl_wb = 2'b10;
            end

            OPC_LOAD: begin
                rs1 = inst[19:15];
                rd  = inst[11:7];
                imm = {{20{inst[31]}}, inst[31:20]};

                alu_src_imm = 1'b1;
                ctrl_mem = 3'b010;
                ctrl_wb  = 2'b11;
            end

            OPC_STORE: begin
                rs1 = inst[19:15];
                rs2 = inst[24:20];
                imm = {{20{inst[31]}}, inst[31:25], inst[11:7]};

                alu_src_imm = 1'b1;
                ctrl_mem = 3'b001;
            end

            OPC_BRANCH: begin
                rs1 = inst[19:15];
                rs2 = inst[24:20];

                imm = {{19{inst[31]}}, inst[31], inst[7],
                       inst[30:25], inst[11:8], 1'b0};

                alu_src_imm = 1'b0;
                ctrl_mem = 3'b100;
            end

            OPC_LUI: begin
                rd  = inst[11:7];
                imm = {inst[31:12], 12'b0};

                alu_src_imm = 1'b1;
                ctrl_wb = 2'b10;
            end

            OPC_AUIPC: begin
                rd  = inst[11:7];
                imm = {inst[31:12], 12'b0};

                alu_src_imm = 1'b1;
                ctrl_wb = 2'b10;
            end

            OPC_JAL: begin
                rd = inst[11:7];

                imm = {{11{inst[31]}}, inst[31],
                       inst[19:12], inst[20],
                       inst[30:21], 1'b0};

                alu_src_imm = 1'b0;
                ctrl_wb = 2'b10;
            end

            OPC_JALR: begin
                rs1 = inst[19:15];
                rd  = inst[11:7];
                imm = {{20{inst[31]}}, inst[31:20]};

                alu_src_imm = 1'b1;
                ctrl_wb = 2'b10;
            end

            default: ;
        endcase
    end

endmodule
