`include "Memory/const.svh"

module top #(
    // Use the one-cycle behavioral memory while the cache is unfinished.
    parameter bit USE_NO_CACHE = 1'b1,
    parameter logic [31:0] RESET_PC = 32'h0000_0000,
    parameter string IMEM_INIT_FILE = ""
) (
    input  logic clk,
    input  logic reset,  // Active-low reset.

    output logic                       mem_req_valid,
    input  logic                       mem_req_ready,
    output logic                       mem_req_rw,
    output logic [`MEM_ADDR_BITS-1:0]   mem_req_addr,
    output logic [`MEM_TAG_BITS-1:0]    mem_req_tag,
    output logic                       mem_req_data_valid,
    input  logic                       mem_req_data_ready,
    output logic [`MEM_DATA_BITS-1:0]   mem_req_data_bits,
    output logic [(`MEM_DATA_BITS/8)-1:0] mem_req_data_mask,
    input  logic                       mem_resp_valid,
    input  logic [`MEM_DATA_BITS-1:0]   mem_resp_data,
    input  logic [`MEM_TAG_BITS-1:0]    mem_resp_tag
);

    typedef struct packed {
        logic [31:0] PC;
        logic [31:0] inst;
    } if_id_reg;

    typedef struct packed {
        logic [31:0] PC;
        logic [31:0] rdata1;
        logic [31:0] rdata2;
        logic [31:0] imm;
        logic [6:0]  opcode;
        // ALUdec consumes opcode, funct[2:0], and funct[3].
        logic [3:0]  funct;
        logic [4:0]  rd;
        logic        alu_src_imm;
        logic [2:0]  ctrl_mem;
        logic [1:0]  ctrl_wb;
    } id_ex_reg;
    /* EX: alu_src_imm selects rs2 or the immediate as ALU operand B.
       ALUdec generates the final four-bit ALU control from opcode and funct.
       M: Branch, MemRead, MemWrite.
       WB: RegWrite, MemtoReg. */

    typedef struct packed {
        logic [31:0] branch_target;
        logic        ALU_zero;
        logic [31:0] ALU_result;
        logic [31:0] wdata;
        logic [4:0]  rd;
        logic [2:0]  ctrl_mem;
        logic [1:0]  ctrl_wb;
    } ex_mem_reg;

    typedef struct packed {
        logic [31:0] rdata;
        logic [31:0] ALU_result;
        logic [4:0]  rd;
        logic [1:0]  ctrl_wb;
    } mem_wb_reg;

    logic [31:0] fetch_addr;
    logic [31:0] fetch_data;
    logic        fetch_en;
    logic        fetch_resp_valid;
    logic        mem_stall;
    logic [31:0] request_PC;

    if_id_reg reg1;
    logic     reg1_valid;

    logic [4:0] id_rs1;
    logic [4:0] id_rs2;
    id_ex_reg   reg2_d;
    id_ex_reg   reg2;
    logic       reg2_valid;

    IFU #(.RESET_PC(RESET_PC)) ifu (
        .clk          (clk),
        .reset        (reset),
        .icache_addr  (fetch_addr),
        .icache_re    (fetch_en),
        .stall        (mem_stall)
    );

    // Decode and register reads both complete within the ID cycle.
    IDU idu (
        .inst        (reg1.inst),
        .rs1         (id_rs1),
        .rs2         (id_rs2),
        .imm         (reg2_d.imm),
        .opcode      (reg2_d.opcode),
        .funct       (reg2_d.funct),
        .rd          (reg2_d.rd),
        .alu_src_imm (reg2_d.alu_src_imm),
        .ctrl_mem    (reg2_d.ctrl_mem),
        .ctrl_wb     (reg2_d.ctrl_wb)
    );

    regfile rf (
        .clk       (clk),
        .reset     (reset),
        .raddr1    (id_rs1),
        .raddr2    (id_rs2),
        .rdata1    (reg2_d.rdata1),
        .rdata2    (reg2_d.rdata2),
        // WB is not implemented yet; keep the write port disabled.
        .reg_write (1'b0),
        .waddr     (5'b0),
        .wdata     (32'b0)
    );

    assign reg2_d.PC = reg1.PC;

    Memory151 #(
        .USE_NO_CACHE  (USE_NO_CACHE),
        .IMEM_INIT_FILE(IMEM_INIT_FILE)
    ) mem (
        .clk              (clk),
        .reset            (!reset),
        .dcache_addr      (32'b0),
        .dcache_we        (4'b0),
        .dcache_re        (1'b0),
        .dcache_din       (32'b0),
        .dcache_dout      (),
        .icache_addr      (fetch_addr),
        .icache_re        (fetch_en),
        .icache_dout      (fetch_data),
        .icache_resp_valid(fetch_resp_valid),
        .stall            (mem_stall),
        .mem_req_valid    (mem_req_valid),
        .mem_req_ready    (mem_req_ready),
        .mem_req_rw       (mem_req_rw),
        .mem_req_addr     (mem_req_addr),
        .mem_req_tag      (mem_req_tag),
        .mem_req_data_valid(mem_req_data_valid),
        .mem_req_data_ready(mem_req_data_ready),
        .mem_req_data_bits(mem_req_data_bits),
        .mem_req_data_mask(mem_req_data_mask),
        .mem_resp_valid   (mem_resp_valid),
        .mem_resp_data    (mem_resp_data),
        .mem_resp_tag     (mem_resp_tag)
    );

    // Save the PC at the same edge that the one-cycle memory accepts its address.
    // A future variable-latency cache will also need request tracking/backpressure.
    always_ff @(posedge clk or negedge reset) begin
        if (!reset)
            request_PC <= RESET_PC;
        else if (fetch_en)
            request_PC <= fetch_addr;
    end

    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            reg1 <= '0;
            reg1_valid <= 1'b0;
        end else begin
            reg1_valid <= fetch_resp_valid;
            if (fetch_resp_valid) begin
                reg1.inst <= fetch_data;
                reg1.PC   <= request_PC;
            end
        end
    end

    // Capture one instruction's PC, operands and controls at the same boundary.
    // Basic valid propagation only; hazard stalls and branch flushes come later.
    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            reg2 <= '0;
            reg2_valid <= 1'b0;
        end else begin
            reg2_valid <= reg1_valid;
            if (reg1_valid)
                reg2 <= reg2_d;
            else
                reg2 <= '0;
        end
    end
endmodule
