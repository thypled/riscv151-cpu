// Module: ALUdecoder
// Desc:   Sets the ALU operation
// Inputs: opcode: the top 6 bits of the instruction
//         funct: the funct, in the case of r-type instructions
//         add_rshift_type: selects whether an ADD vs SUB, or an SRA vs SRL
// Outputs: ALUop: Selects the ALU's operation
//

`include "Opcode.vh"
`include "ALUop.vh"

module ALUdec(
  input [6:0]       opcode,
  input [2:0]       funct,
  input             add_rshift_type,
  output reg [3:0]  ALUop
);

  always_comb begin
    case (opcode)
      `OPC_LUI: begin
        ALUop = `ALU_COPY_B;
      end

      `OPC_AUIPC,
      `OPC_JAL,
      `OPC_JALR,
      `OPC_BRANCH,
      `OPC_STORE,
      `OPC_LOAD: begin
        ALUop = `ALU_ADD;
      end

      `OPC_ARI_RTYPE,
      `OPC_ARI_ITYPE: begin
        case (funct)
          `FNC_ADD_SUB: begin
            if ((opcode == `OPC_ARI_RTYPE) &&
                (add_rshift_type == `FNC2_SUB)) begin
              ALUop = `ALU_SUB;
            end else begin
              ALUop = `ALU_ADD;
            end
          end
          `FNC_SLL: begin
            ALUop = `ALU_SLL;
          end
          `FNC_SLT: begin
            ALUop = `ALU_SLT;
          end
          `FNC_SLTU: begin
            ALUop = `ALU_SLTU;
          end
          `FNC_XOR: begin
            ALUop = `ALU_XOR;
          end
          `FNC_SRL_SRA: begin
            if (add_rshift_type == `FNC2_SRA) begin
              ALUop = `ALU_SRA;
            end else begin
              ALUop = `ALU_SRL;
            end
          end
          `FNC_OR: begin
            ALUop = `ALU_OR;
          end
          `FNC_AND: begin
            ALUop = `ALU_AND;
          end
          default: begin
            ALUop = `ALU_XXX;
          end
        endcase
      end

      `OPC_CSR: begin
        case (funct)
          `FNC_RW,
          `FNC_RWI: begin
            ALUop = `ALU_COPY_B;
          end
          default: begin
            ALUop = `ALU_XXX;
          end
        endcase
      end

      default: begin
        ALUop = `ALU_XXX;
      end
    endcase
  end

endmodule
