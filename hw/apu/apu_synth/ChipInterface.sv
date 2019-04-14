`default_nettype none

module ChipInterface
  (input  logic CLOCK_50,
   input  logic [3:0] KEY,
   input  logic [17:0] SW,
   output logic [6:0] HEX0, HEX1, HEX2, HEX3,
                      HEX4, HEX5, HEX6, HEX7,
    //////////// Audio //////////
    input  AUD_ADCDAT,
    inout  AUD_ADCLRCK,
    inout  AUD_BCLK,
    output AUD_DACDAT,
    inout  AUD_DACLRCK,
    output AUD_XCK,
    //////////// I2C //////////
    output I2C_SCLK,
    inout I2C_SDAT);


    logic rst_n;
    assign rst_n = KEY[3];
    // AUDIO

    logic [31:0][3:0] seq;
    assign seq = 128'hFEDCBA98765432100123456789ABCDEF;
    logic [3:0] wave;
    logic [5:0] seq_i;
    logic seq_en;
    logic counter_clr;
    logic [31:0] counter;
    assign wave = seq[seq_i];
    assign seq_en = (counter == 32'd5000);
    assign counter_clr = seq_en;

    always_ff @(posedge CLOCK_50 or negedge rst_n) begin
        if(~rst_n) begin
            counter <= 32'd0;
        end else begin
            if(counter_clr)
                counter <= 32'd0;
            else 
               counter <= counter + 32'd1;
        end
    end

    always_ff @(posedge CLOCK_50 or negedge rst_n) begin
        if(~rst_n) begin
            seq_i <= 6'd0;
        end else if(seq_en && seq_i < 6'd47) begin
            seq_i <= seq_i + 6'd1;
        end else begin
            seq_i <= 6'd0;
        end
    end

    //  For Audio CODEC
    logic AUD_CTRL_CLK;    //  For Audio Controller
    assign AUD_DACLRCK      = 1'bz;                         
    assign AUD_DACDAT       = 1'bz;                         
    assign AUD_BCLK            = 1'bz;                          
    assign AUD_XCK         = 1'bz;     
    assign  AUD_XCK     =   AUD_CTRL_CLK;

    logic mVGA_CLK, VGA_CTRL_CLK;

    VGA_Audio_PLL       p1  (.areset(rst_n),.inclk0(CLOCK_50),.c0(VGA_CTRL_CLK),.c1(AUD_CTRL_CLK),.c2(mVGA_CLK));


    //  Audio CODEC and video decoder setting
    I2C_AV_Config       u3  (   //  Host Side
                                .iCLK(CLOCK_50),
                                .iRST_N(rst_n),
                                //  I2C Side
                                .I2C_SCLK(I2C_SCLK),
                                .I2C_SDAT(I2C_SDAT));

    AUDIO_DAC           u4  (   //  Audio Side
                                .oAUD_BCK(AUD_BCLK),
                                .oAUD_DATA(AUD_DACDAT),
                                .oAUD_LRCK(AUD_DACLRCK),
                                //  Control Signals
                                .iCLK_18_4(AUD_CTRL_CLK),
                                .iRST_N(rst_n),
                                .data({12'b0, wave}));


endmodule: ChipInterface
