
module audio_video_config (
	clk,
	reset,
	address,
	byteenable,
	read,
	write,
	writedata,
	readdata,
	waitrequest,
	I2C_SDAT,
	I2C_SCLK);	

	input		clk;
	input		reset;
	input	[1:0]	address;
	input	[3:0]	byteenable;
	input		read;
	input		write;
	input	[31:0]	writedata;
	output	[31:0]	readdata;
	output		waitrequest;
	inout		I2C_SDAT;
	output		I2C_SCLK;
endmodule
