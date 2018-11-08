
module CRC16_CHK(

	input sclk,
	input reset,
	
	input 		init,
	input [7:0]	crc_din,
	input 		crc_en,

	input 		crc_chk_en,
	output		crc_err


);

reg	[15:0]	crc_reg=16'hffff;


wire	[7:0]	crc_din_turn;
//*******************************************************************
//turn
//*******************************************************************

assign crc_din_turn = {
		crc_din[0],
		crc_din[1],
		crc_din[2],
		crc_din[3],
		crc_din[4],
		crc_din[5],
		crc_din[6],
		crc_din[7]
		
		};





//*******************************************************************
  // polynomial: (0 2 15 16)
  // data width: 8
  // convention: the first serial bit is D[7]
//*******************************************************************
   function [15:0] nextCRC16_D8;

    input [7:0] Data;
    input [15:0] crc;
    reg [7:0] d;
    reg [15:0] c;
    reg [15:0] newcrc;
  begin
    d = Data;
    c = crc;

    newcrc[0] = d[7] ^ d[6] ^ d[5] ^ d[4] ^ d[3] ^ d[2] ^ d[1] ^ d[0] ^ c[8] ^ c[9] ^ c[10] ^ c[11] ^ c[12] ^ c[13] ^ c[14] ^ c[15];
    newcrc[1] = d[7] ^ d[6] ^ d[5] ^ d[4] ^ d[3] ^ d[2] ^ d[1] ^ c[9] ^ c[10] ^ c[11] ^ c[12] ^ c[13] ^ c[14] ^ c[15];
    newcrc[2] = d[1] ^ d[0] ^ c[8] ^ c[9];
    newcrc[3] = d[2] ^ d[1] ^ c[9] ^ c[10];
    newcrc[4] = d[3] ^ d[2] ^ c[10] ^ c[11];
    newcrc[5] = d[4] ^ d[3] ^ c[11] ^ c[12];
    newcrc[6] = d[5] ^ d[4] ^ c[12] ^ c[13];
    newcrc[7] = d[6] ^ d[5] ^ c[13] ^ c[14];
    newcrc[8] = d[7] ^ d[6] ^ c[0] ^ c[14] ^ c[15];
    newcrc[9] = d[7] ^ c[1] ^ c[15];
    newcrc[10] = c[2];
    newcrc[11] = c[3];
    newcrc[12] = c[4];
    newcrc[13] = c[5];
    newcrc[14] = c[6];
    newcrc[15] = d[7] ^ d[6] ^ d[5] ^ d[4] ^ d[3] ^ d[2] ^ d[1] ^ d[0] ^ c[7] ^ c[8] ^ c[9] ^ c[10] ^ c[11] ^ c[12] ^ c[13] ^ c[14] ^ c[15];
    nextCRC16_D8 = newcrc;
  end
  endfunction

//*******************************************************************




always@(posedge sclk)
	if(reset)
		crc_reg <= 16'hffff;
	else if(init)
		crc_reg <= 16'hffff;
	else if(crc_en)
		crc_reg <= nextCRC16_D8(crc_din_turn,crc_reg);
	
assign crc_err = crc_chk_en&(crc_reg[15:0] != 16'h0);

endmodule
