module minimal_modelb_rom_set (
    input            clk,
    input [17:0]     addr,
    output reg [7:0] data
);

   reg [7:0]                     mos_data;
   reg [7:0]                     basic_data;
   reg [7:0]                     mmfs_data;

   reg [7:0]                     mos_rom  [0:16383];
   reg [7:0]                     basic_rom[0:16383];
   reg [7:0]                     mmfs_rom [0:16383];


   initial $readmemh("os12.dat", mos_rom);
   initial $readmemh("basic2.dat", basic_rom);
   initial $readmemh("mmfs.dat", mmfs_rom);

   always @(posedge clk)
     begin
        mos_data   <= mos_rom  [addr[13:0]];
        basic_data <= basic_rom[addr[13:0]];
        mmfs_data  <= mmfs_rom [addr[13:0]];
     end

   always @(*)
     begin
        case (addr[17:14])
          4'h4: data <= mos_data;
          4'hE: data <= mmfs_data;
          4'hF: data <= basic_data;
          default: data <= 8'hFF;
        endcase
     end


endmodule
