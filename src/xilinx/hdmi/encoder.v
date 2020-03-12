// -------------------------------------------------------------------[01.11.2014]
// -- Encoder
// -------------------------------------------------------------------------------
// -- V1.0     03.08.2014  Initial release
// -- V2.0     01.11.2014  Added AUX
// ---------------------------------------------------------------------------
// -- (c) 2016 Alexey Spirkov
// -- I am happy for anyone to use this for non-commercial use.
// -- If my verilog/vhdl/c files are used commercially or otherwise sold,
// -- please contact me for explicit permission at me _at_ alsp.net.
// -- This applies for source and binary form and derived works.
// ---------------------------------------------------------------------------
//

module encoder
(
 input CLK,
 input [7:0] DATA,
 input [1:0] C,
 input VDE,   // Video Data Enable (VDE)
 input ADE,   // Audio/auxiliary Data Enable (ADE)
 input [3:0] AUX,
 output reg [9:0] ENCODED

 );

   wire [8:0]     xored;
   wire [8:0]     xnored;
   wire [3:0]     ones;
   reg [8:0]      data_word;
   reg [8:0]      data_word_inv;
   wire [3:0]     data_word_disparity;
   reg [3:0]      dc_bias = 0;


   // Work our the two different encodings for the byte
   assign xored[0] = DATA[0];
   assign xored[1] = DATA[1] ^ xored[0];
   assign xored[2] = DATA[2] ^ xored[1];
   assign xored[3] = DATA[3] ^ xored[2];
   assign xored[4] = DATA[4] ^ xored[3];
   assign xored[5] = DATA[5] ^ xored[4];
   assign xored[6] = DATA[6] ^ xored[5];
   assign xored[7] = DATA[7] ^ xored[6];
   assign xored[8] = 1'b1;

   assign xnored[0] = DATA[0];
   assign xnored[1] = DATA[1] ~^ xnored[0];
   assign xnored[2] = DATA[2] ~^ xnored[1];
   assign xnored[3] = DATA[3] ~^ xnored[2];
   assign xnored[4] = DATA[4] ~^ xnored[3];
   assign xnored[5] = DATA[5] ~^ xnored[4];
   assign xnored[6] = DATA[6] ~^ xnored[5];
   assign xnored[7] = DATA[7] ~^ xnored[6];
   assign xnored[8] = 1'b0;

   // Count how many ones are set in data
   assign ones = 4'b0 + DATA[0] + DATA[1] + DATA[2] + DATA[3] + DATA[4] + DATA[5] + DATA[6] + DATA[7];

   // Decide which encoding to use
   always @(ones, DATA[0], xnored, xored) begin
      if (ones > 4 || (ones == 4 && !DATA[0])) begin
         data_word     = xnored;
         data_word_inv = ~xnored;
      end else begin
         data_word     = xored;
         data_word_inv = ~xored;
      end
   end

   // Work out the DC bias of the dataword;
   assign data_word_disparity = 4'b1100 + data_word[0] + data_word[1] + data_word[2] + data_word[3] + data_word[4] + data_word[5] + data_word[6] + data_word[7];

   // Now work out what the output should be
   always @(posedge CLK) begin
      // Video Data Coding
      if (VDE) begin
         if (dc_bias == 0 || data_word_disparity == 0) begin
            // dataword has no disparity
            if (data_word[8]) begin
               ENCODED <= {2'b01, data_word[7:0]};
               dc_bias <= dc_bias + data_word_disparity;
            end else begin
               ENCODED <= {2'b10, data_word_inv[7:0]};
               dc_bias <= dc_bias - data_word_disparity;
            end
         end else if ((!dc_bias[3] && !data_word_disparity[3]) || (dc_bias[3] && data_word_disparity[3])) begin
            ENCODED <= {1'b1, data_word[8], data_word_inv[7:0]};
            dc_bias <= dc_bias + data_word[8] - data_word_disparity;
         end else begin
            ENCODED <= {1'b0, data_word};
            dc_bias <= dc_bias - data_word_inv[8] + data_word_disparity;
         end
         // TERC4 Coding
      end else if (ADE) begin
         case (AUX)
           4'b0000 : ENCODED <= 10'b1010011100;
           4'b0001 : ENCODED <= 10'b1001100011;
           4'b0010 : ENCODED <= 10'b1011100100;
           4'b0011 : ENCODED <= 10'b1011100010;
           4'b0100 : ENCODED <= 10'b0101110001;
           4'b0101 : ENCODED <= 10'b0100011110;
           4'b0110 : ENCODED <= 10'b0110001110;
           4'b0111 : ENCODED <= 10'b0100111100;
           4'b1000 : ENCODED <= 10'b1011001100;
           4'b1001 : ENCODED <= 10'b0100111001;
           4'b1010 : ENCODED <= 10'b0110011100;
           4'b1011 : ENCODED <= 10'b1011000110;
           4'b1100 : ENCODED <= 10'b1010001110;
           4'b1101 : ENCODED <= 10'b1001110001;
           4'b1110 : ENCODED <= 10'b0101100011;
           default : ENCODED <= 10'b1011000011;
         endcase
      end else begin
         // In the control periods, all values have and have balanced bit count
         case (C)
           2'b00   : ENCODED <= 10'b1101010100;
           2'b01   : ENCODED <= 10'b0010101011;
           2'b10   : ENCODED <= 10'b0101010100;
           default : ENCODED <= 10'b1010101011;
         endcase
         dc_bias <= 0;
      end
   end

endmodule
