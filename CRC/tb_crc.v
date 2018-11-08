module tb_crc();

reg sclk=1'b0;
reg reset=1'b0;


reg		init =1'b0;
reg 	[7:0] Frame_data ='d0;
reg		data_en =1'b0 ;
reg		CRC_rd =1'b0 ;
wire [15:0] CRC_out ;
wire  CRC_end	;	


reg	[7:0]	rx_data='d0;
reg			rx_en=1'b0;
reg			chk_en=1'b0;
wire 		error;


initial begin
	forever #5 sclk = ~sclk;
end

initial begin
	@(posedge sclk );

	@(posedge sclk );
	@(posedge sclk );
	@(posedge sclk );
	@(posedge sclk );
	init<=1'b1;
	@(posedge sclk);
	init<=1'b0;
//data
	@(posedge sclk);
	data_en<=1'b1;
	Frame_data<= 8'h80;

	@(posedge sclk);
	data_en<=1'b1;
	Frame_data<= 8'h00;

	@(posedge sclk);
	data_en<=1'b1;
	Frame_data<= 8'h02;

	@(posedge sclk);
	data_en<=1'b1;
	Frame_data<= 8'h0f;

	@(posedge sclk);
	data_en<=1'b1;
	Frame_data<= 8'h0b;
//end
	@(posedge sclk);
	data_en<=1'b0;
		@(posedge sclk);
	@(posedge sclk);
		@(posedge sclk);
	@(posedge sclk);
	CRC_rd<=1'b1;
	@(posedge sclk);
	@(posedge sclk);
	CRC_rd<=1'b0;
	
	
//*******************************************
	@(posedge sclk);
		@(posedge sclk);	@(posedge sclk);
//data
	@(posedge sclk);
	rx_en<=1'b1;
	rx_data<= 8'h80;

	@(posedge sclk);
	rx_en<=1'b1;
	rx_data<= 8'h00;

	@(posedge sclk);
	rx_en<=1'b1;
	rx_data<= 8'h02;

	@(posedge sclk);
	rx_en<=1'b1;
	rx_data<= 8'h0f;

	@(posedge sclk);
	rx_en<=1'b1;
	rx_data<= 8'h0b;
//end
//crc
	@(posedge sclk);
	rx_en<=1'b1;
	rx_data<= 8'hc0;
		@(posedge sclk);
	rx_en<=1'b1;
	rx_data<= 8'h29;
	
		@(posedge sclk);
	rx_en<=1'b0;
	chk_en<=1'b1;
		@(posedge sclk);
		chk_en<=1'b0;

	
end
CRC16_D8 CRC(
.sclk 		(sclk), 
.reset		(reset), 
.init 		(init),
.Frame_data (Frame_data),
.data_en 	(data_en),
.CRC_rd 	(CRC_rd),
.CRC_out 	(CRC_out),
.CRC_end	(CRC_end)	
);



CRC16_CHK CHK(

.sclk		(sclk),
.reset		(reset),
	
.init			(init),
.crc_din		(rx_data),
.crc_en		(rx_en),

.crc_chk_en	(chk_en),
.crc_err		(error)


);















endmodule

