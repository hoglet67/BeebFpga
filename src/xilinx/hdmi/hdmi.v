// ---------------------------------------------------------------------------
// -- (c) 2016 Alexey Spirkov
// -- I am happy for anyone to use this for non-commercial use.
// -- If my verilog/vhdl/c files are used commercially or otherwise sold,
// -- please contact me for explicit permission at me _at_ alsp.net.
// -- This applies for source and binary form and derived works.
// ---------------------------------------------------------------------------
// -- Recommended params:
// -- N=0x1800 CTS=0x6FD1 (28.625MHz pixel clock -> 48KHz audio clock)
// -- N=0x1000 CTS=0x6FD1 (28.625MHz pixel clock -> 32KHz audio clock)
// -- N=0x1000 CTS=0x6978 (27MHz pixel clock -> 32KHz audio clock)
// -- N=0x1800 CTS=0x6978 (27MHz pixel clock -> 48KHz audio clock)
// ---------------------------------------------------------------------------

`define controlData         3'b000
`define videoData           3'b001
`define videoDataPreamble   3'b010
`define videoDataGuardBand  3'b011
`define dataIslandPreamble  3'b100
`define dataIslandPreGuard  3'b101
`define dataIslandPostGuard 3'b110
`define dataIsland          3'b111

module hdmi
#(parameter FREQ=27000000, FS=48000, CTS=27000, N=6144)
 (
   // clocks
   input        I_CLK_PIXEL,
   // components
   input [7:0]  I_R,
   input [7:0]  I_G,
   input [7:0]  I_B,
   input        I_BLANK,
   input        I_HSYNC,
   input        I_VSYNC,
   // PCM audio
   input        I_AUDIO_ENABLE,
   input [15:0] I_AUDIO_PCM_L,
   input [15:0] I_AUDIO_PCM_R,
   // TMDS parallel pixel synchronous outputs (serialize LSB first)
   output [9:0] O_RED,   // Red
   output [9:0] O_GREEN, // Green
   output [9:0] O_BLUE   // Blue
);

   wire [9:0]   red;
   wire [9:0]   green;
   wire [9:0]   blue;

   wire [9:0]   enc0out;
   wire [9:0]   enc1out;
   wire [9:0]   enc2out;


   wire [29:0]  tx_in;
   wire [3:0]   tmds_d;

   wire         data;
   wire [3:0]   dataPacket0;
   wire [3:0]   dataPacket1;
   wire [3:0]   dataPacket2;

   wire [39:0]  delayLineIn;
   wire [39:0]  delayLineOut;


   wire [7:0]   ROut;
   wire [7:0]   GOut;
   wire [7:0]   BOut;

   wire         hSyncOut;
   wire         vSyncOut;
   wire         vdeOut;
   wire         dataOut;
   wire [1:0]   vhSyncOut;

   reg          prevBlank;
   reg          prevData;

   wire [3:0]   dataPacket0Out;
   wire [3:0]   dataPacket1Out;
   wire [3:0]   dataPacket2Out;

   reg          ctl0;
   reg          ctl1;
   reg          ctl2;
   reg          ctl3;

   wire [1:0]   ctl_10;
   wire [1:0]   ctl_32;


   reg [2:0]    state = 0;


   reg [10:0]   clockCounter = 0;


// data should be delayed for 11 clocks to allow preamble and guard band generation

// delay line inputs
   assign delayLineIn[39:32] = I_R;
   assign delayLineIn[31:24] = I_G;
   assign delayLineIn[23:16] = I_B;
   assign delayLineIn[15] = I_HSYNC;
   assign delayLineIn[14] = I_VSYNC;
   assign delayLineIn[13] = !I_BLANK;
   assign delayLineIn[12] = data;
   assign delayLineIn[11:8] = dataPacket0;
   assign delayLineIn[7:4] = dataPacket1;
   assign delayLineIn[3:0] = dataPacket2;

// delay line outputs
   assign ROut = delayLineOut[39:32];
   assign GOut = delayLineOut[31:24];
   assign BOut = delayLineOut[23:16];
   assign hSyncOut = delayLineOut[15];
   assign vSyncOut = delayLineOut[14];
   assign vdeOut = delayLineOut[13];
   assign dataOut = delayLineOut[12];
   assign dataPacket0Out = delayLineOut[11:8];
   assign dataPacket1Out = delayLineOut[7:4];
   assign dataPacket2Out = delayLineOut[3:0];

   assign vhSyncOut = {vSyncOut , hSyncOut};

   assign ctl_10 = {ctl1, ctl0};
   assign ctl_32 = {ctl3, ctl2};

   always @(posedge I_CLK_PIXEL) begin
      if (!prevBlank  && I_BLANK) begin
         state <= `controlData;
         clockCounter <= 0;
      end else begin
         case (state)
            `controlData:
               if (!prevData && data) begin      // ok - data stared - needs data preamble
                  state <= `dataIslandPreamble;
                  ctl0 <= 1'b1;
                  ctl1 <= 1'b0;
                  ctl2 <= 1'b1;
                  ctl3 <= 1'b0;
                  clockCounter <= 0;
               end else if (prevBlank && !I_BLANK) begin // ok blank os out - start generation video preamble
                  state <= `videoDataPreamble;
                  ctl0 <= 1'b1;
                  ctl1 <= 1'b0;
                  ctl2 <= 1'b0;
                  ctl3 <= 1'b0;
                  clockCounter <= 0;
               end
            `dataIslandPreamble:                    // data island preable needed for 8 clocks
               if (clockCounter == 8) begin
                  state <= `dataIslandPreGuard;
                  ctl0 <= 1'b0;
                  ctl1 <= 1'b0;
                  ctl2 <= 1'b0;
                  ctl3 <= 1'b0;
                  clockCounter <= 0;
               end else begin
                  clockCounter <= clockCounter + 1'b1;
               end
            `dataIslandPreGuard:                    // data island preguard needed for 2 clocks
               if (clockCounter == 1) begin
                  state <= `dataIsland;
                  clockCounter <= 0;
               end else begin
                  clockCounter <= clockCounter + 1'b1;
               end
            `dataIsland:
               if (clockCounter == 11) begin                  // ok we at the end of data island - post guard is needed
                  state <= `dataIslandPostGuard;
                  clockCounter <= 0;
               end else if (prevBlank && !I_BLANK) begin // something fails - no data were detected but blank os out
                  state <= `videoDataPreamble;
                  ctl0 <= 1'b1;
                  ctl1 <= 1'b0;
                  ctl2 <= 1'b0;
                  ctl3 <= 1'b0;
                  clockCounter <= 0;
               end else if (!data) begin                         // start count and count only when data is over
                  clockCounter <= clockCounter + 1'b1;
               end

            `dataIslandPostGuard:                   // data island postguard needed for 2 clocks
               if (clockCounter == 1) begin
                  state <= `controlData;
                  clockCounter <= 0;
               end else begin
                  clockCounter <= clockCounter + 1'b1;
               end
            `videoDataPreamble:                     // video data preable needed for 8 clocks
               if (clockCounter == 8)  begin
                  state <= `videoDataGuardBand;
                  ctl0 <= 1'b0;
                  ctl1 <= 1'b0;
                  ctl2 <= 1'b0;
                  ctl3 <= 1'b0;
                  clockCounter <= 0;
               end else begin
                  clockCounter <= clockCounter + 1'b1;
               end
            `videoDataGuardBand:                    // video data guard needed for 2 clocks
               if (clockCounter == 1)  begin
                  state <= `videoData;
                  clockCounter <= 0;
               end else begin
                  clockCounter <= clockCounter + 1'b1;
               end
            `videoData:
               if (clockCounter == 11)  begin                 // ok we at the end of video data - just switch to control
                  state <= `controlData;
                  clockCounter <= 0;
               end else if (I_BLANK) begin                         // start count and count only when video is over
                  clockCounter <= clockCounter + 1'b1;
               end
         endcase
      end
      prevBlank <= I_BLANK;
      prevData <= data;
   end

   assign blue =  ((state == `dataIslandPreGuard || state == `dataIslandPostGuard) && vhSyncOut == 2'b00) ? 10'b1010001110 :
                  ((state == `dataIslandPreGuard || state == `dataIslandPostGuard) && vhSyncOut == 2'b01) ? 10'b1001110001 :
                  ((state == `dataIslandPreGuard || state == `dataIslandPostGuard) && vhSyncOut == 2'b10) ? 10'b0101100011 :
                  ((state == `dataIslandPreGuard || state == `dataIslandPostGuard) && vhSyncOut == 2'b11) ? 10'b1011000011 :
                  (state == `videoDataGuardBand)                                                          ? 10'b1011001100 : enc0out;

   assign green = (state == `videoDataGuardBand                                 ) ? 10'b0100110011 :
                  (state == `dataIslandPreGuard || state == `dataIslandPostGuard) ? 10'b0100110011 : enc1out;

   assign red =   (state == `videoDataGuardBand                                 ) ? 10'b1011001100 :
                  (state == `dataIslandPreGuard || state == `dataIslandPostGuard) ? 10'b0100110011 : enc2out;


   hdmi_delay_line delay_line
     (
      .i_clk(I_CLK_PIXEL),
      .i_d(delayLineIn),
      .o_q(delayLineOut)
      );

   hdmidataencoder
     #(
       .FREQ(FREQ),
       .FS(FS),
       .CTS(CTS),
       .N(N)
       )
   dataencoder
     (
      .i_pixclk    (I_CLK_PIXEL),
      .i_blank     (I_BLANK),
      .i_hSync     (I_HSYNC),
      .i_vSync     (I_VSYNC),
      .i_audio_enable  (I_AUDIO_ENABLE),
      .i_audioL    (I_AUDIO_PCM_L),
      .i_audioR    (I_AUDIO_PCM_R),
      .o_d0        (dataPacket0),
      .o_d1        (dataPacket1),
      .o_d2        (dataPacket2),
      .o_data      (data)
      );

   encoder enc0
     (
      .CLK      (I_CLK_PIXEL),
      .DATA     (BOut),
      .C        (vhSyncOut),
      .VDE      (vdeOut),
      .ADE      (dataOut),
      .AUX      (dataPacket0Out),
      .ENCODED  (enc0out)
     );

   encoder enc1
     (
     .CLK      (I_CLK_PIXEL),
     .DATA     (GOut),
     .C        (ctl_10),
     .VDE      (vdeOut),
     .ADE      (dataOut),
     .AUX      (dataPacket1Out),
     .ENCODED  (enc1out)
      );

   encoder enc2
     (
      .CLK     (I_CLK_PIXEL),
      .DATA    (ROut),
      .C       (ctl_32),
      .VDE     (vdeOut),
      .ADE     (dataOut),
      .AUX     (dataPacket2Out),
      .ENCODED (enc2out)
      );


assign O_RED   = red;
assign O_GREEN = green;
assign O_BLUE  = blue;

endmodule
