module generic_ram #
  (
   parameter ADDR_BITS = 10,
   parameter DATA_BITS = 8,
   parameter INIT_FILE = "pynqz2_rom.hex"
   )

   (
    input                      clk,
    input                      ena,
    input                      wea,
    input [ADDR_BITS-1:0]      addr,
    input [DATA_BITS-1:0]      din,
    output reg [DATA_BITS-1:0] dout
    );

   reg [DATA_BITS-1:0] ram[(2**ADDR_BITS)-1:0];

   initial begin
      if (INIT_FILE != "") begin
         $readmemh(INIT_FILE, ram, 0, (2**ADDR_BITS)-1);
      end
   end

   always @(posedge clk) begin
      if (ena) begin
         if (wea) begin
            ram[addr[ADDR_BITS-1:0]] <= din;
         end
         dout <= ram[addr[ADDR_BITS-1:0]];
      end
   end

endmodule
