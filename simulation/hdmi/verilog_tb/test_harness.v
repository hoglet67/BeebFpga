`timescale 1ns / 100ps

module test_harness();


   reg clock_27         = 1'b0;
   reg [7:0] hdmi_red   = 8'h00;
   reg [7:0] hdmi_green = 8'h00;
   reg [7:0] hdmi_blue  = 8'h00;
   reg       hdmi_hsync = 1'b0;
   reg       hdmi_vsync = 1'b0;
   reg       hdmi_blank = 1'b0;
   reg       hsync      = 1'b1;
   reg       vsync      = 1'b1;
   reg       hsync1     = 1'b1;
   reg       vsync1     = 1'b1;
   reg [9:0] hcnt       = 10'b0;
   reg [9:0] vcnt       = 10'b0;


   wire [9:0] tdms_r;
   wire [9:0] tdms_g;
   wire [9:0] tdms_b;
   wire [31:0] tdms;

   integer     fd, f, h, v;

   // clock generation
   always
     # 18.5185 clock_27 = ~clock_27;


   // logging process
    initial begin
      fd = $fopen("out.txt","w");
    end

   always @(posedge clock_27) begin
      $fwrite(fd, "%x\n", tdms);
   end


   initial begin
      $dumpvars;
      // Modeline "720x576 @ 50hz"  27    720   732   796   864   576   581   586   625
      for (f = 0; f <= 1; f = f + 1) begin
         for (v = 0; v < 625; v = v + 1) begin
            $write("line %d\n", v);
            for (h = 0; h < 864; h = h + 1) begin
               @(negedge clock_27);
               if (h == 732) begin
                  hsync <= 1'b0;
               end
               if (h == 796) begin
                  hsync <= 1'b1;
                  if (v == 581) begin
                     vsync <= 1'b0;
                  end
                  if (v == 586) begin
                     vsync <= 1'b1;
                  end
               end
            end
         end
      end
      $finish;
   end

   always @(posedge clock_27) begin
      hsync1 <= hsync;
      if (!hsync1 && hsync) begin
         hcnt <= 0;
         vsync1 <= vsync;
         if (!vsync1 && vsync) begin
            vcnt <= 0;
         end else begin
            vcnt <= vcnt + 1;
         end
      end else begin
         hcnt <= hcnt + 1;
      end
      if (hcnt < 68 || hcnt >= 68 + 720 || vcnt < 39 || vcnt >= 39 + 576) begin
         hdmi_blank <= 1'b1;
         hdmi_red   <= 8'h00;
         hdmi_green <= 8'h00;
         hdmi_blue  <= 8'h00;
      end else begin
         hdmi_blank <= 1'b0;
         if (hcnt == 68 || hcnt == 68 + 719 || vcnt == 39 || vcnt == 39 + 575) begin
            hdmi_red   <= 8'h00;
            hdmi_green <= 8'hFF;
            hdmi_blue  <= 8'h00;
         end else begin
            hdmi_red   <= 8'h80;
            hdmi_green <= 8'h80;
            hdmi_blue  <= 8'h80;
         end
      end
      if (hcnt >= 732 + 68) begin // 800
         hdmi_hsync <= 1'b0;
         if (vcnt >= 581 + 39) begin // 620
            hdmi_vsync <= 1'b0;
         end else begin
            hdmi_vsync <= 1'b1;
         end
      end else begin
         hdmi_hsync <= 1'b1;
      end
   end

   hdmi
     #(
      .FREQ(27000000),  // pixel clock frequency
      .FS(32000),     // audio sample rate - should be 32000, 44100 or 48000
      .CTS(27000),     // CTS = Freq(pixclk) * N / (128 * Fs)
      .N(4096)       // N = 128 * Fs /1000,  128 * Fs /1500 <= N <= 128 * Fs /300
    )
   hdmi
     (
      // clocks
      .I_CLK_PIXEL      (clock_27),
      // components
      .I_R              (hdmi_red),
      .I_G              (hdmi_green),
      .I_B              (hdmi_blue),
      .I_BLANK          (hdmi_blank),
      .I_HSYNC          (hdmi_hsync),
      .I_VSYNC          (hdmi_vsync),
      // PCM audio
      .I_AUDIO_ENABLE   (1'b1),
      .I_AUDIO_PCM_L    (16'hAAAA),
      .I_AUDIO_PCM_R    (16'h5555),
      // TMDS parallel pixel synchronous outputs (serialize LSB first)
      .O_RED            (tdms_r),
      .O_GREEN          (tdms_g),
      .O_BLUE           (tdms_b)
      );

    assign tdms = {2'b00, tdms_r, tdms_g, tdms_b};

endmodule
