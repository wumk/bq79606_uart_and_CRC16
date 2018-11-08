module S_CRC16_t(
input sclk,
input rest,
input data_en,
input [7:0] din,
output [15:0] dout


);

wire [7:0] din_turn;

reg	 data_en_r1,data_en_r2;
reg	[16:0]	crc_reg='d0;

//************************************************************
//turn
//************************************************************
 assign din_turn = {
		 din[0],
		 din[1],
		 din[2],
		 din[3],
		 din[4],
		 din[5],
		 din[6],
		 din[7]
		 
		 
		 };

//************************************************************
//xor 0xffff
//************************************************************
always@(posedge sclk)
begin
	data_en_r1<=data_en;
	data_en_r2<=data_en_r1;

end


assign din_turn_xor = ((~data_en_r2)&data_en) din_turn ^ 8'hff; 



//************************************************************
//apend 0x0000
//************************************************************





//************************************************************
//se-CRC16
//************************************************************
always@(posedge sclk)
	if(reset)
		crc_reg
	else /*if(data_en)*/
	begin
		crc_reg <= {din_turn_xor,9'd0};
		if(crc_reg[16]==1'b0)
		begin
				crc_reg <= crc_reg << 1;
		end
		else 

	end










module code_crc(clk,reset,data,out);
input clk,reset;
input[7:0] data;
output[15:0] out;
reg[15:0] out;
//变量声明
reg[16:0] s;
integer i;

always@(posedge clk)
begin
if(!reset)
  begin
		s=17'b0;
		out=16'b0;
  end
else
  begin
   s={data[7:0],9'b0};
	begin
   		for(i=7;i>0;i=i-1)
  		 begin
   			 if(s[16]==0)              //若第一位为0，左移一位；
     			s=s<<1; 
 			 else begin
   		 		s=s^17'b11000000000000101;/*若第一位为1，则与生成多项式进行异或操作；*/
  				s=s<<1;        //左移一位；
       		end
   		end
   out=s[15:0];               //s的后16位即为校验位；
	end
  end
end
endmodule
