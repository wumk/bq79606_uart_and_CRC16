module CRC16_D8(
input sclk,
input reset,
input init,
input [7:0] Frame_data,
input data_en,
input CRC_rd,
output reg [15:0] CRC_out,
output reg CRC_end
);


//*******************************************************************
reg [15:0] CRC_reg=15'hffff;
wire	[7:0] Frame_data_turn; 
reg		Counter='d0;


//*******************************************************************
//turn
//*******************************************************************

assign Frame_data_turn = {
		
		Frame_data [0],
		Frame_data [1],
		Frame_data [2],
		Frame_data [3],
		Frame_data [4],
		Frame_data [5],
		Frame_data [6],
		Frame_data [7]
		
		
		
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


always @ (posedge sclk )
    if (reset)
        CRC_reg     <=16'hffff;
    else if (init)
        CRC_reg     <=16'hffff;//xor 0xffff
    else if (data_en)
        CRC_reg     <=nextCRC16_D8(Frame_data_turn,CRC_reg);
    else if(CRC_rd)
        CRC_reg     <={CRC_reg[7:0],8'hff};




always @ (CRC_rd or CRC_reg)//out turn no xor oxff
    if (CRC_rd)
        CRC_out     <= 
{
					CRC_out[7:0],
			      CRC_reg[8]	 ,
	                  CRC_reg[9]    ,
	                  CRC_reg[10]  ,
	                  CRC_reg[11]  ,
	                  CRC_reg[12]  ,
	                  CRC_reg[13]  ,
	                  CRC_reg[14]  ,
	                  CRC_reg[15]  
	  
	  };
    else
        CRC_out     <=0;
        
//caculate CRC out length ,4 cycles     
//CRC_end aligned to last CRC checksum dat/
always @(posedge sclk )
    if (reset)
        Counter     <=0;
    else if (!CRC_rd)
        Counter     <=0;
    else 
        Counter     <=Counter + 1;
        
always @ (Counter)
    if (Counter==1)
        CRC_end=1;
    else
        CRC_end=0;


endmodule
