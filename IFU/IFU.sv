module IFU #(
  parameter logic [31:0] RESET_PC = 32'h0000_0000
) (
  input  logic        clk,
  input  logic        reset,  // Active-low reset.
  input  logic        stall,
  output logic [31:0] icache_addr,
  output logic        icache_re
);
  logic [31:0] fetch_PC;
  logic        fetch_advance;

  assign icache_addr = fetch_PC;
  assign fetch_advance = !stall;
  // Temporary sequential-fetch policy; branch control will be added later.
  assign icache_re = fetch_advance;

  always_ff @(posedge clk or negedge reset) begin
    if (!reset)
      fetch_PC <= RESET_PC;
    else if (fetch_advance)
      fetch_PC <= fetch_PC + 32'd4;
  end
endmodule
