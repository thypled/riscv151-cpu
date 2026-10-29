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

    // The synchronous memory registers read data; top registers its matching metadata.
    typedef struct packed {
        logic [31:0] ALU_result;
        logic [4:0]  rd;
        logic [1:0]  ctrl_wb;
        logic        is_load;
    } mem_wb_meta_reg;

    logic [31:0] fetch_addr;
    logic [31:0] fetch_data;
    logic        fetch_en;
    logic        fetch_resp_valid;
    logic        mem_stall;
    logic [31:0] if_id_PC;
    logic        if_id_valid;

    if_id_reg reg1;
    logic     reg1_valid;

    id_ex_reg   reg2_d;
    id_ex_reg   reg2;
    logic       reg2_valid;

    logic [4:0] id_rs1;
    logic [4:0] id_rs2;

    ex_mem_reg reg3_d;
    ex_mem_reg reg3;
    logic      reg3_valid;

    logic [3:0]  dcache_we;
    logic        dcache_re;
    logic [31:0] dcache_rdata;
    logic        dcache_resp_valid;

    mem_wb_meta_reg reg4_meta_d;
    mem_wb_meta_reg reg4_meta;
    logic           reg4_meta_valid;
    mem_wb_reg      reg4;
    logic           reg4_valid;

    logic [31:0] wb_data;
    logic        wb_reg_write;

    logic hazard_ex;
    logic hazard_mem;
    logic hazard_wb;
    logic stall_id;
    logic stall_fetch;

    IFU #(.RESET_PC(RESET_PC)) ifu (
        .clk          (clk),
        .reset        (reset),
        .icache_addr  (fetch_addr),
        .icache_re    (fetch_en),
        .stall        (stall_fetch)
    );

    // Decode and register reads both complete within the ID cycle.
    IDU idu (
        .clk         (clk),
        .reset       (reset),
        .inst        (reg1.inst),
        .rdata1      (reg2_d.rdata1),
        .rdata2      (reg2_d.rdata2),
        .imm         (reg2_d.imm),
        .opcode      (reg2_d.opcode),
        .funct       (reg2_d.funct),
        .rd          (reg2_d.rd),
        .alu_src_imm (reg2_d.alu_src_imm),
        .ctrl_mem    (reg2_d.ctrl_mem),
        .ctrl_wb     (reg2_d.ctrl_wb),
        .wb_reg_write(wb_reg_write),
        .wb_rd       (reg4.rd),
        .wb_data     (wb_data),
        .rs1         (id_rs1),
        .rs2         (id_rs2)
    );

    assign reg2_d.PC = reg1.PC;

    EXU exu (
        .opcode        (reg2.opcode),
        .funct         (reg2.funct),
        .rdata1        (reg2.rdata1),
        .rdata2        (reg2.rdata2),
        .imm           (reg2.imm),
        .alu_src_imm   (reg2.alu_src_imm),
        .PC            (reg2.PC),
        .ALU_result    (reg3_d.ALU_result),
        .branch_target (reg3_d.branch_target),
        .ALU_zero      (reg3_d.ALU_zero)
    );

    // Store data remains rs2 even when the ALU uses the immediate for its address.
    assign reg3_d.wdata    = reg2.rdata2;
    assign reg3_d.rd       = reg2.rd;
    assign reg3_d.ctrl_mem = reg2.ctrl_mem;
    assign reg3_d.ctrl_wb  = reg2.ctrl_wb;

    // Current access subset: aligned LW/SW, with all four byte lanes enabled for SW.
    assign dcache_re = reset && reg3_valid && reg3.ctrl_mem[1];
    assign dcache_we = {4{reset && reg3_valid && reg3.ctrl_mem[0]}};

    assign reg4_meta_d.ALU_result = reg3.ALU_result;
    assign reg4_meta_d.rd         = reg3.rd;
    assign reg4_meta_d.ctrl_wb    = reg3.ctrl_wb;
    assign reg4_meta_d.is_load    = reg3.ctrl_mem[1];

    // Read data and metadata become available together after the memory sampling edge.
    // Use the memory's output register directly as the MEM/WB data boundary.
    assign reg4.rdata      = reg4_meta.is_load ? dcache_rdata : 32'b0;
    assign reg4.ALU_result = reg4_meta.ALU_result;
    assign reg4.rd         = reg4_meta.rd;
    assign reg4.ctrl_wb    = reg4_meta.ctrl_wb;
    assign reg4_valid     = reg4_meta_valid &&
                            (!reg4_meta.is_load || dcache_resp_valid);

    WBU wbu (
        .MemtoReg    (reg4.ctrl_wb[0]),
        .rdata       (reg4.rdata),
        .wdata       (reg4.ALU_result),
        .SelectedData(wb_data)
    );

    // Only valid instructions with RegWrite set may update the register file.
    assign wb_reg_write = reset && reg4_valid && reg4.ctrl_wb[1];

    Memory151 #(
        .USE_NO_CACHE  (USE_NO_CACHE),
        .IMEM_INIT_FILE(IMEM_INIT_FILE)
    ) mem (
        .clk              (clk),
        .reset            (!reset),
        .dcache_addr      (reg3.ALU_result),
        .dcache_we        (dcache_we),
        .dcache_re        (dcache_re),
        .dcache_din       (reg3.wdata),
        .dcache_dout      (dcache_rdata),
        .dcache_resp_valid(dcache_resp_valid),
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

    assign hazard_ex = reg1_valid && reg2_valid && reg2.ctrl_wb[1] &&
                       reg2.rd != '0 && ((id_rs1 == reg2.rd) || (id_rs2 == reg2.rd));
    assign hazard_mem = reg1_valid && reg3_valid && reg3.ctrl_wb[1] &&
                        reg3.rd != '0 && ((id_rs1 == reg3.rd) || (id_rs2 == reg3.rd));
    assign hazard_wb = reg1_valid && reg4_valid && reg4.ctrl_wb[1] &&
                       reg4.rd != '0 && ((id_rs1 == reg4.rd) || (id_rs2 == reg4.rd));

    assign stall_id = hazard_ex || hazard_mem || hazard_wb;
    assign stall_fetch = mem_stall || stall_id;

    // The synchronous instruction memory supplies the IF/ID instruction register.
    // With the one-cycle no-cache model, fetch_en marks the instruction captured at this edge.
    // During an ID stall, fetch_en is low and the memory holds its instruction output.
    assign reg1.inst = fetch_data;
    assign reg1.PC = if_id_PC;
    assign reg1_valid = reset && if_id_valid;

    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            if_id_PC <= RESET_PC;
            if_id_valid <= 1'b0;
        end else if (!stall_id) begin
            // Occupancy stays valid while ID waits, even without a fresh memory response.
            if_id_valid <= fetch_en;
            if (fetch_en)
                if_id_PC <= fetch_addr;
        end
    end

    // Capture one instruction's PC, operands and controls at the same boundary.
    // Keep the dependent instruction in ID and send a bubble into EX while older work drains.
    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            reg2 <= '0;
            reg2_valid <= 1'b0;
        end else if (stall_id) begin
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

    // Keep the EX result, store data and downstream controls in the same stage.
    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            reg3 <= '0;
            reg3_valid <= 1'b0;
        end else begin
            reg3_valid <= reg2_valid;
            if (reg2_valid)
                reg3 <= reg3_d;
            else
                reg3 <= '0;
        end
    end

    // One-cycle behavioral-memory timing: metadata advances with each MEM instruction.
    // A future variable-latency cache also needs stalls and metadata retention.
    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            reg4_meta <= '0;
            reg4_meta_valid <= 1'b0;
        end else begin
            reg4_meta_valid <= reg3_valid;
            if (reg3_valid)
                reg4_meta <= reg4_meta_d;
            else
                reg4_meta <= '0;
        end
    end
endmodule
