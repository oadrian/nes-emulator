module audio_dac (
	input logic clk, rst_l,
	inout AUD_DACDAT,
	output logic AUD_DACLRCK,
	output logic AUD_BCLK);

	parameter	REF_CLK			=	18432000;	//	18.432	MHz
	parameter	SAMPLE_RATE		=	48000;		//	48		KHz
	parameter	DATA_WIDTH		=	16;			//	16		Bits
	parameter	CHANNEL_NUM		=	2;			//	Dual Channel

parameter	SIN_SAMPLE_DATA	=	48;

////////////	Input Source Number	//////////////
parameter	SIN_SANPLE		=	0;

	logic [3:0] bclk_div;
	logic [8:0] lrck_div;
  logic [5:0] SIN_Cont;
  logic [3:0] SEL_Cont;
  logic [DATA_WIDTH-1:0] Sin_Out;

    logic [31:0][3:0] seq;
    logic [15:0] wave;
    logic [4:0] seq_i;
    logic seq_en;
    logic counter_clr;
    logic [31:0] counter;

////////////	AUD_BCK Generator	//////////////
	always_ff @(posedge clk or negedge rst_l)
		if(~rst_l) begin
			bclk_div <= 'b0;
		 	AUD_BCLK <= 'b0;
		end else if (bclk_div >= REF_CLK/(SAMPLE_RATE*DATA_WIDTH*CHANNEL_NUM*2)-1)
		begin
			bclk_div <= 'b0;
			AUD_BCLK <= ~AUD_BCLK;
		end else
			bclk_div <= bclk_div + 1;

////////////	AUD_LRCK Generator	//////////////
	always_ff @(posedge clk or negedge rst_l)
		if(~rst_l) begin
			AUD_DACLRCK <= 'b0;
			lrck_div <= 'b0;
		end else if (lrck_div >= REF_CLK/(SAMPLE_RATE*2)-1) begin
			AUD_DACLRCK <= ~AUD_DACLRCK;
			lrck_div <= 'b0;
		end else
      lrck_div <= lrck_div + 1;

//////////////////////////////////////////////////
//////////	Sin LUT ADDR Generator	//////////////
always@(negedge AUD_DACLRCK or negedge rst_l)
begin
	if(!rst_l)
	SIN_Cont	<=	0;
	else
	begin
		if(SIN_Cont < SIN_SAMPLE_DATA-1 )
		SIN_Cont	<=	SIN_Cont+1;
		else
		SIN_Cont	<=	0;
	end
end

//////////////////////////////////////////////////
//////////	16 Bits PISO MSB First	//////////////
always@(negedge AUD_BCLK or negedge rst_l)
begin
	if(!rst_l)
	SEL_Cont	<=	0;
	else
	SEL_Cont	<=	SEL_Cont+1;
end

assign AUD_DACDAT = wave[~SEL_Cont];

    assign seq = 128'hFEDCBA98765432100123456789ABCDEF;
    assign wave = {12'b0, seq[seq_i]};
    assign seq_en = (counter == 32'd160);
    assign counter_clr = seq_en;

    always_ff @(posedge clk or negedge rst_l) begin
        if(~rst_l) begin
            counter <= 32'd0;
        end else begin
            if(counter_clr)
                counter <= 32'd0;
            else 
               counter <= counter + 32'd1;
        end
    end

    always_ff @(negedge AUD_DACLRCK or negedge rst_l) begin
        if(~rst_l)
            seq_i <= 6'd0;
        else if(seq_en)
            seq_i <= seq_i + 6'd1;
    end

//////////////////////////////////////////////////
////////////	Sin Wave ROM Table	//////////////
always@(SIN_Cont)
begin
    case(SIN_Cont)
    0  :  Sin_Out       <=      0       ;
    1  :  Sin_Out       <=      4276    ;
    2  :  Sin_Out       <=      8480    ;
    3  :  Sin_Out       <=      12539   ;
    4  :  Sin_Out       <=      16383   ;
    5  :  Sin_Out       <=      19947   ;
    6  :  Sin_Out       <=      23169   ;
    7  :  Sin_Out       <=      25995   ;
    8  :  Sin_Out       <=      28377   ;
    9  :  Sin_Out       <=      30272   ;
    10  :  Sin_Out      <=      31650   ;
    11  :  Sin_Out      <=      32486   ;
    12  :  Sin_Out      <=      32767   ;
    13  :  Sin_Out      <=      32486   ;
    14  :  Sin_Out      <=      31650   ;
    15  :  Sin_Out      <=      30272   ;
    16  :  Sin_Out      <=      28377   ;
    17  :  Sin_Out      <=      25995   ;
    18  :  Sin_Out      <=      23169   ;
    19  :  Sin_Out      <=      19947   ;
    20  :  Sin_Out      <=      16383   ;
    21  :  Sin_Out      <=      12539   ;
    22  :  Sin_Out      <=      8480    ;
    23  :  Sin_Out      <=      4276    ;
    24  :  Sin_Out      <=      0       ;
    25  :  Sin_Out      <=      61259   ;
    26  :  Sin_Out      <=      57056   ;
    27  :  Sin_Out      <=      52997   ;
    28  :  Sin_Out      <=      49153   ;
    29  :  Sin_Out      <=      45589   ;
    30  :  Sin_Out      <=      42366   ;
    31  :  Sin_Out      <=      39540   ;
    32  :  Sin_Out      <=      37159   ;
    33  :  Sin_Out      <=      35263   ;
    34  :  Sin_Out      <=      33885   ;
    35  :  Sin_Out      <=      33049   ;
    36  :  Sin_Out      <=      32768   ;
    37  :  Sin_Out      <=      33049   ;
    38  :  Sin_Out      <=      33885   ;
    39  :  Sin_Out      <=      35263   ;
    40  :  Sin_Out      <=      37159   ;
    41  :  Sin_Out      <=      39540   ;
    42  :  Sin_Out      <=      42366   ;
    43  :  Sin_Out      <=      45589   ;
    44  :  Sin_Out      <=      49152   ;
    45  :  Sin_Out      <=      52997   ;
    46  :  Sin_Out      <=      57056   ;
    47  :  Sin_Out      <=      61259   ;
	default	:
		   Sin_Out		<=		0		;
	endcase
end
endmodule: audio_dac
