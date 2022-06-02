module duo_boot_loader
  (
   input       clock,
   input [3:0] dip,
   input       SW1,
   output      ARDUINO_RESET,
   output      led
   );

   reg [1:0]   clk;

   reg [15:0]  icap_din;
   reg         icap_ce;
   reg         icap_wr;

   reg [15:0]  ff_icap_din_reversed;
   reg         ff_icap_ce;
   reg         ff_icap_wr;

   reg [15:0]  MBT_REBOOT = 16'h0000;

   reg [24:0]  counter;

   ICAP_SPARTAN6 ICAP_SPARTAN6_inst
     (
      .BUSY      (),                      // Busy output
      .O         (),                      // 16-bit data output
      .CE        (ff_icap_ce),            // Clock enable input
      .CLK       (clk[0]),                // Clock input
      .I         (ff_icap_din_reversed),  // 16-bit data input
      .WRITE     (ff_icap_wr)             // Write input
      );


   //  -------------------------------------------------
   //  --  State Machine for ICAP_SPARTAN6 MultiBoot  --
   //  --   sequence.                                 --
   //  -------------------------------------------------


   parameter
     IDLE     = 0,
     SYNC_H   = 1,
     SYNC_L   = 2,

     CWD_H    = 3,
     CWD_L    = 4,

     GEN1_H   = 5,
     GEN1_L   = 6,

     GEN2_H   = 7,
     GEN2_L   = 8,

     GEN3_H   = 9,
     GEN3_L   = 10,

     GEN4_H   = 11,
     GEN4_L   = 12,

     GEN5_H   = 13,
     GEN5_L   = 14,

     NUL_H    = 15,
     NUL_L    = 16,

     MOD_H    = 17,
     MOD_L    = 18,

     HCO_H    = 19,
     HCO_L    = 20,

     RBT_H    = 21,
     RBT_L    = 22,

     NOOP_0   = 23,
     NOOP_1   = 24,
     NOOP_2   = 25,
     NOOP_3   = 26;


   reg [4:0]   state = IDLE;
   reg [4:0]   next_state;

   always @(MBT_REBOOT or state or dip)
     begin: COMB

        case (state)

          IDLE:
            begin
               if (MBT_REBOOT==16'hffff)
                 begin
                    next_state  = SYNC_H;
                    icap_ce     = 0;
                    icap_wr     = 0;
                    icap_din    = 16'hAA99;  // Sync word part 1
                 end
               else
                 begin
                    next_state  = IDLE;
                    icap_ce     = 1;
                    icap_wr     = 1;
                    icap_din    = 16'hFFFF;  // Null data
                 end
            end

          SYNC_H:
            begin
               next_state  = SYNC_L;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = 16'h5566;    // Sync word part 2
            end

          SYNC_L:
            begin
               next_state  = GEN1_H;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = 16'h3261;    //  Write to GENERAL_1 Register....
            end

          GEN1_H:
            begin
               next_state  = GEN1_L;
               icap_ce     = 0;
               icap_wr     = 0;
               // Loader          - 0300-0000
               // Model B         - 0305-4000
               // Master          - 030A-8000
               // Model B (NuLA)  - 030F-C000
               // Master (NuLA)   - 0315-0000
               case (dip[3:2])
                 2'b00:     icap_din    = 16'h4000;
                 2'b01:     icap_din    = 16'h8000;
                 2'b10:     icap_din    = 16'hC000;
                 2'b11:     icap_din    = 16'h0000;
               endcase
            end

          GEN1_L:
            begin
               next_state  = GEN2_H;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = 16'h3281;    //  Write to GENERAL_2 Register....
            end

          GEN2_H:
            begin
               next_state  = GEN2_L;
               icap_ce     = 0;
               icap_wr     = 0;
               // Loader          - 0300-0000
               // Model B         - 0305-4000
               // Master          - 030A-8000
               // Model B (NuLA)  - 030F-C000
               // Master (NuLA)   - 0315-0000
               case (dip[3:2])
                 2'b00:     icap_din    = 16'h0305;
                 2'b01:     icap_din    = 16'h030A;
                 2'b10:     icap_din    = 16'h030F;
                 2'b11:     icap_din    = 16'h0315;
               endcase
            end

          GEN2_L:
            begin
               next_state  = RBT_H;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = 16'h30A1;      //  Write to Command Register....
            end

          RBT_H:
            begin
               next_state  = RBT_L;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = 16'h000E;      // REBOOT Command issued....  value = 0x000E
            end

          RBT_L:
            begin
               next_state  = NOOP_0;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = 16'h2000;    //  NOOP
            end

          NOOP_0:
            begin
               next_state  = NOOP_1;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = 16'h2000;    // NOOP
            end

          NOOP_1:
            begin
               next_state  = NOOP_2;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = 16'h2000;    // NOOP
            end

          NOOP_2:
            begin
               next_state  = NOOP_3;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = 16'h2000;    // NOOP
            end

          NOOP_3:
            begin
               next_state  = IDLE;
               icap_ce     = 1;
               icap_wr     = 1;
               icap_din    = 16'h1111;    // NULL value
            end

          default:
            begin
               next_state  = IDLE;
               icap_ce     = 1;
               icap_wr     = 1;
               icap_din    = 16'h1111;    //  16'h1111"
            end

        endcase
     end

   // Clock ICAP_SPARTAN6 and the state machine with clocks that are 90deg phase apart.
   //
   // This is an attempt to cure some reconfiguration unreliability.
   //
   // The problem is that ICAP_SPARTAN2 isn't treated by the Xilinx tools as a synchronous
   // component, so when clocked off the same clock there can be timing issues.
   //
   // The below clocking patten runs the clock at 8MHz (half what it was before).
   //
   // It ensures there is plenty of setup and hold time margin for signals passing
   // between ICAP_SPARTAN6 and the state machine, regardless of which clk edge is used
   // ICAP_SPARTAN6.
   //
   // See this link for some related discussion:
   // https://forums.xilinx.com/t5/Spartan-Family-FPGAs/20Mhz-limitation-for-ICAP-SPARTAN6/td-p/238060
   //
   // NOTE: I'm hedging here, as this bug is quite difficult to reproduce, and changing almost anything
   // (e.g. connecting state to the test pins) causes the problem to go away.
   //
   // At worst this change should be harmless!
   //
   // Dave Banks - 18/07/2017

   always@(posedge clock) begin
      if (clk == 2'b00)
        clk <= 2'b10;
      else if (clk == 2'b10)
        clk <= 2'b11;
      else if (clk == 2'b11)
        clk <= 2'b01;
      else
        clk <= 2'b00;
   end

   // Give a bit of delay before starting the state machine
   always @(posedge clk[1]) begin
      if (MBT_REBOOT == 16'hffff) begin
         state <= next_state;
      end else begin
         MBT_REBOOT <= MBT_REBOOT + 1'b1;
         state <= IDLE;
      end
   end


   always @(posedge clk[1]) begin:   ICAP_FF
      // need to reverse bits to ICAP module since D0 bit is read first
      ff_icap_din_reversed[0]  <= icap_din[7];
      ff_icap_din_reversed[1]  <= icap_din[6];
      ff_icap_din_reversed[2]  <= icap_din[5];
      ff_icap_din_reversed[3]  <= icap_din[4];
      ff_icap_din_reversed[4]  <= icap_din[3];
      ff_icap_din_reversed[5]  <= icap_din[2];
      ff_icap_din_reversed[6]  <= icap_din[1];
      ff_icap_din_reversed[7]  <= icap_din[0];
      ff_icap_din_reversed[8]  <= icap_din[15];
      ff_icap_din_reversed[9]  <= icap_din[14];
      ff_icap_din_reversed[10] <= icap_din[13];
      ff_icap_din_reversed[11] <= icap_din[12];
      ff_icap_din_reversed[12] <= icap_din[11];
      ff_icap_din_reversed[13] <= icap_din[10];
      ff_icap_din_reversed[14] <= icap_din[9];
      ff_icap_din_reversed[15] <= icap_din[8];
      ff_icap_ce  <= icap_ce;
      ff_icap_wr  <= icap_wr;
   end

   always@(posedge clock) begin
      counter <= counter + 1'b1;
   end

   assign led = 1'b1;

   assign ARDUINO_RESET = SW1;

endmodule
