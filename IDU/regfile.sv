module regfile #(
    parameter logic [31:0] reset_register_value = '0
)(
    input  logic        clk,
    input  logic        reset,
    input  logic        reg_write,
    input  logic [4:0]  raddr1,
    input  logic [4:0]  raddr2,
    input  logic [4:0]  waddr,
    input  logic [31:0] wdata,
    output logic [31:0] rdata1,
    output logic [31:0] rdata2
);

    logic [31:0] registers [32];

    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            foreach (registers[i]) begin
                registers[i] <= (i == 0) ? 32'b0 : reset_register_value;
            end
        end else begin
            if (reg_write && (waddr != 5'd0)) begin
                registers[waddr] <= wdata;
            end

            registers[0] <= 32'b0;
        end
    end

    always_comb begin
        rdata1 = (raddr1 == 5'd0) ? 32'b0 : registers[raddr1];
        rdata2 = (raddr2 == 5'd0) ? 32'b0 : registers[raddr2];
    end

endmodule
