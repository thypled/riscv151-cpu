module IDU (
    input  logic        clk,
    input  logic        reset,
    input  logic [31:0] inst,
    input  logic [31:0] PC,

    output logic [4:0]  rs1,
    output logic [4:0]  rs2,
    output logic [31:0] imm,
    output logic [3:0]  funct,
    output logic [4:0]  rd,
    output logic [2:0]  ctrl_ex,
    output logic [2:0]  ctrl_mem,
    output logic [2:0]  ctrl_wb
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

    localparam logic [1:0] ALU_ADD_SUB = 2'b00;
    localparam logic [1:0] ALU_BRANCH  = 2'b01;
    localparam logic [1:0] ALU_FUNC    = 2'b10;

    localparam logic [3:0] F_ADD   = 4'd0;
    localparam logic [3:0] F_SUB   = 4'd1;
    localparam logic [3:0] F_SLL   = 4'd2;
    localparam logic [3:0] F_SLT   = 4'd3;
    localparam logic [3:0] F_SLTU  = 4'd4;
    localparam logic [3:0] F_XOR   = 4'd5;
    localparam logic [3:0] F_SRL   = 4'd6;
    localparam logic [3:0] F_SRA   = 4'd7;
    localparam logic [3:0] F_OR    = 4'd8;
    localparam logic [3:0] F_AND   = 4'd9;
    localparam logic [3:0] F_LUI   = 4'd10;
    localparam logic [3:0] F_AUIPC = 4'd11;
    localparam logic [3:0] F_JAL   = 4'd12;
    localparam logic [3:0] F_JALR  = 4'd13;

    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    logic [4:0]  rs1_next;
    logic [4:0]  rs2_next;
    logic [31:0] imm_next;
    logic [3:0]  funct_next;
    logic [4:0]  rd_next;
    logic [2:0]  ctrl_ex_next;
    logic [2:0]  ctrl_mem_next;
    logic [2:0]  ctrl_wb_next;

    assign opcode = inst[6:0];
    assign funct3 = inst[14:12];
    assign funct7 = inst[31:25];

    always_comb begin
        rs1_next     = 5'b0;
        rs2_next     = 5'b0;
        imm_next     = 32'b0;
        funct_next   = F_ADD;
        rd_next      = 5'b0;
        ctrl_ex_next = 3'b0;
        ctrl_mem_next = 3'b0;
        ctrl_wb_next  = 3'b0;

        case (opcode)

            OPC_RTYPE: begin
                rs1_next = inst[19:15];
                rs2_next = inst[24:20];
                rd_next  = inst[11:7];

                ctrl_ex_next = {ALU_FUNC, 1'b0};
                ctrl_wb_next = 3'b100;

                case (funct3)
                    3'b000: begin
                        if (funct7 == 7'b0000000)
                            funct_next = F_ADD;
                        else if (funct7 == 7'b0100000)
                            funct_next = F_SUB;
                    end

                    3'b001: begin
                        if (funct7 == 7'b0000000)
                            funct_next = F_SLL;
                    end

                    3'b010: begin
                        if (funct7 == 7'b0000000)
                            funct_next = F_SLT;
                    end

                    3'b011: begin
                        if (funct7 == 7'b0000000)
                            funct_next = F_SLTU;
                    end

                    3'b100: begin
                        if (funct7 == 7'b0000000)
                            funct_next = F_XOR;
                    end

                    3'b101: begin
                        if (funct7 == 7'b0000000)
                            funct_next = F_SRL;
                        else if (funct7 == 7'b0100000)
                            funct_next = F_SRA;
                    end

                    3'b110: begin
                        if (funct7 == 7'b0000000)
                            funct_next = F_OR;
                    end

                    3'b111: begin
                        if (funct7 == 7'b0000000)
                            funct_next = F_AND;
                    end

                    default: ;
                endcase
            end

            OPC_ITYPE: begin
                rs1_next = inst[19:15];
                rd_next  = inst[11:7];
                imm_next = {{20{inst[31]}}, inst[31:20]};

                ctrl_ex_next = {ALU_FUNC, 1'b1};
                ctrl_wb_next = 3'b100;

                case (funct3)
                    3'b000: funct_next = F_ADD;
                    3'b001: begin
                        if (funct7 == 7'b0000000)
                            funct_next = F_SLL;
                    end
                    3'b010: funct_next = F_SLT;
                    3'b011: funct_next = F_SLTU;
                    3'b100: funct_next = F_XOR;
                    3'b101: begin
                        if (funct7 == 7'b0000000)
                            funct_next = F_SRL;
                        else if (funct7 == 7'b0100000)
                            funct_next = F_SRA;
                    end
                    3'b110: funct_next = F_OR;
                    3'b111: funct_next = F_AND;
                    default: ;
                endcase
            end

            OPC_LOAD: begin
                rs1_next = inst[19:15];
                rd_next  = inst[11:7];
                imm_next = {{20{inst[31]}}, inst[31:20]};
                funct_next = F_ADD;

                ctrl_ex_next  = {ALU_ADD_SUB, 1'b1};
                ctrl_mem_next = 3'b010;
                ctrl_wb_next  = 3'b110;
            end

            OPC_STORE: begin
                rs1_next = inst[19:15];
                rs2_next = inst[24:20];
                imm_next = {{20{inst[31]}}, inst[31:25], inst[11:7]};
                funct_next = F_ADD;

                ctrl_ex_next  = {ALU_ADD_SUB, 1'b1};
                ctrl_mem_next = 3'b001;
            end

            OPC_BRANCH: begin
                rs1_next = inst[19:15];
                rs2_next = inst[24:20];

                imm_next = {{19{inst[31]}}, inst[31], inst[7],
                            inst[30:25], inst[11:8], 1'b0};

                funct_next = {1'b0, funct3};

                ctrl_ex_next  = {ALU_BRANCH, 1'b0};
                ctrl_mem_next = 3'b100;
            end

            OPC_LUI: begin
                rd_next  = inst[11:7];
                imm_next = {inst[31:12], 12'b0};
                funct_next = F_LUI;

                ctrl_ex_next = {ALU_FUNC, 1'b1};
                ctrl_wb_next = 3'b100;
            end

            OPC_AUIPC: begin
                rd_next  = inst[11:7];
                imm_next = {inst[31:12], 12'b0};
                funct_next = F_AUIPC;

                ctrl_ex_next = {ALU_FUNC, 1'b1};
                ctrl_wb_next = 3'b100;
            end

            OPC_JAL: begin
                rd_next = inst[11:7];

                imm_next = {{11{inst[31]}}, inst[31],
                            inst[19:12], inst[20],
                            inst[30:21], 1'b0};

                funct_next = F_JAL;
                ctrl_ex_next = {ALU_FUNC, 1'b0};
                ctrl_wb_next = 3'b100;
            end

            OPC_JALR: begin
                rs1_next = inst[19:15];
                rd_next  = inst[11:7];
                imm_next = {{20{inst[31]}}, inst[31:20]};

                funct_next = F_JALR;
                ctrl_ex_next = {ALU_FUNC, 1'b1};
                ctrl_wb_next = 3'b100;
            end

            default: ;
        endcase
    end

    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            rs1      <= 5'b0;
            rs2      <= 5'b0;
            imm      <= 32'b0;
            funct    <= 4'b0;
            rd       <= 5'b0;
            ctrl_ex  <= 3'b0;
            ctrl_mem <= 3'b0;
            ctrl_wb  <= 3'b0;
        end else begin
            rs1      <= rs1_next;
            rs2      <= rs2_next;
            imm      <= imm_next;
            funct    <= funct_next;
            rd       <= rd_next;
            ctrl_ex  <= ctrl_ex_next;
            ctrl_mem <= ctrl_mem_next;
            ctrl_wb  <= ctrl_wb_next;
        end
    end

endmodule