module config_rom (
    input             clk,
    input [13:0]      addr,
    output reg [7:0] data
);

    reg  [7:0] rom[0:16383];

    always @(posedge clk)
        begin
            data <= rom[addr];
        end

    initial $readmemh("config.mem", rom);

endmodule
