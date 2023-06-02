// ---------------------------------------------------------------------------
// -- (c) 2016 Alexey Spirkov
// -- I am happy for anyone to use this for non-commercial use.
// -- If my verilog/vhdl/c files are used commercially or otherwise sold,
// -- please contact me for explicit permission at me _at_ alsp.net.
// -- This applies for source and binary form and derived works.
module  hdmi_delay_line
  #(parameter G_WIDTH = 40, G_DEPTH = 11)
   (
    input                i_clk,
    input [G_WIDTH-1:0]  i_d,
    output [G_WIDTH-1:0] o_q
    );

   reg [0:G_DEPTH-1][G_WIDTH-1:0] q_pipe;

   always @(posedge i_clk) begin
      q_pipe   <= { i_d, q_pipe[0 : G_DEPTH-2] };
   end

   assign o_q = q_pipe[G_DEPTH-1];

endmodule
