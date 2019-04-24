module audio_dac (
	input logic clk, rst_l,
	input logic [15:0] audio,
	inout AUD_DACDAT,
	output logic AUD_DACLRCK,
	output logic AUD_BCLK);

	parameter	REF_CLK			=	18432000;	//	18.432	MHz
	parameter	SAMPLE_RATE		=	48000;		//	48		KHz
	parameter	DATA_WIDTH		=	16;			//	16		Bits
	parameter	CHANNEL_NUM		=	2;			//	Dual Channel

	logic [3:0] bclk_div;
	logic [8:0] lrck_div;
    logic [3:0] wave_i;

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
//////////	16 Bits PISO MSB First	//////////////
always @(negedge AUD_BCLK or negedge rst_l)
begin
	if(!rst_l)
	wave_i	<=	0;
	else
	wave_i	<=	wave_i+1;
end

assign AUD_DACDAT = audio[~wave_i];


endmodule: audio_dac
