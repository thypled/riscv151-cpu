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
        logic [3:0]  funct;
        logic [4:0]  rd;
        logic [2:0]  ctrl_ex;
        logic [2:0]  ctrl_mem;
        logic [1:0]  ctrl_wb;
    } id_ex_reg;
    /* EX: ALUOp[1:0], ALUSrc.
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

    IFU #(.RESET_PC(RESET_PC)) ifu (
        .clk          (clk),
        .reset        (reset),
        .icache_addr  (fetch_addr),
        .icache_re    (fetch_en),
        .stall        (mem_stall)
    );

    IDU #() idu(
        .clk (clk),
        .reset (reset),
        .r_reg1 (r_reg1),
        .r_reg2 (r_reg2),
        .w_reg (w_reg),
        .wdata (wdata),
        .rdata1 (rdata1),
    )

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

    if_id_reg reg1;
    logic     reg1_valid;

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
endmodule
