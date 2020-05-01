module config_rom (
    input            clk,
    input [13:0]     addr,
    output reg [7:0] data
);

   reg [7:0] config_rom [0:16383];

   initial $readmemh("config.dat", config_rom);

   always @(posedge clk)
     begin
        data   <= config_rom  [addr[13:0]];
     end

endmodule
