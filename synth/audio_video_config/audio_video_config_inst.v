	audio_video_config u0 (
		.clk         (<connected-to-clk>),         //                    clk.clk
		.reset       (<connected-to-reset>),       //                  reset.reset
		.address     (<connected-to-address>),     // avalon_av_config_slave.address
		.byteenable  (<connected-to-byteenable>),  //                       .byteenable
		.read        (<connected-to-read>),        //                       .read
		.write       (<connected-to-write>),       //                       .write
		.writedata   (<connected-to-writedata>),   //                       .writedata
		.readdata    (<connected-to-readdata>),    //                       .readdata
		.waitrequest (<connected-to-waitrequest>), //                       .waitrequest
		.I2C_SDAT    (<connected-to-I2C_SDAT>),    //     external_interface.SDAT
		.I2C_SCLK    (<connected-to-I2C_SCLK>)     //                       .SCLK
	);

