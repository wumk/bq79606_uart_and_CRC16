

module uartlite_tx
#(
	parameter	C_FAMILY = "virtex6",
	parameter	C_DATA_BITS = 8,
	parameter	C_USE_PARITY = 0,
	parameter	C_ODD_PARITY = 0
)
(
	input	wire	Clk,
	input	wire	Reset,
	input	wire	EN_16x_Baud,
	output	reg		TX,
	
	input 	wire	Write_TX_FIFO,
	input 	wire	Reset_TX_FIFO,
	input	wire	[C_DATA_BITS-1:0]	TX_Data,
	output 	wire	TX_Buffer_Full,
	output	wire	TX_Buffer_Empty
 
);

//localparam	bo2sl = {1'b0,1'b1};//not ensure

localparam	MUX_SEL_INIT = (C_DATA_BITS-1);

	reg                     parity=1'b0;
	reg                     tx_Run1='d0;
	reg                     select_Parity=1'b0;
	wire [C_DATA_BITS-1:0]  data_to_transfer;
	wire                    div16;
	reg                     tx_Data_Enable;
	reg                     tx_Start;
	reg                     tx_DataBits;
	wire                    tx_Run;
	reg [2:0]               mux_sel;
	wire                    mux_sel_is_zero;
	wire                    mux_01;
	wire                    mux_23;
	wire                    mux_45;
	wire                    mux_67;
	wire                    mux_0123;
	wire                    mux_4567;
	wire                    mux_Out;
	reg                     serial_Data;
	reg                     fifo_Read;
	wire                    fifo_Data_Present;
	wire                    fifo_Data_Empty;
	wire [C_DATA_BITS-1:0]  fifo_DOut;
		wire [C_DATA_BITS-1:0]  fifo_DOut_temp;
	wire                    fifo_wr;
	wire                    fifo_rd;
	wire                    tx_buffer_full_i;
	wire                    TX_FIFO_Reset;

//*******************************************************
//shift register
//
// gets shifted for 16 times(as Addr = 15) when 
//                        EN_16x_Baud is high.
//*******************************************************
//proc_common_v3_00_a.dynshreg_i_f 
//#(
//	.C_DEPTH(16),
//	.C_DWIDTH(1),
//	.C_INIT_VALUE(16'h8000),//?
//	.C_FAMILY(C_FAMILY)
//
//)
//MID_START_BIT_SRL16_I(
//	.Clk(Clk),
//	.Clken(EN_16x_Baud),
//	.Addr(4'b1111),
//	.Din[0]	(div16),
//	.Dout[0](div16)
//);
   SRL16E #(
      .INIT(16'h8000) // Initial Value of Shift Register
   ) SRL16E_inst (
      .Q(div16),       // SRL data output
      .A0(1'b1),     // Select[0] input
      .A1(1'b1),     // Select[1] input
      .A2(1'b1),     // Select[2] input
      .A3(1'b1),     // Select[3] input
      .CE(EN_16x_Baud),     // Clock enable input
      .CLK(Clk),   // Clock input
      .D(div16)        // SRL data input
   );


//*******************************************************
//    -- TX_DATA_ENABLE_DFF : tx_Data_Enable is '1' when div16 is 1 and
//    --                      EN_16x_Baud is 1. It will deasserted in the
//    --                      next clock cycle.
//*******************************************************

always@(posedge Clk)
	begin
		if(Reset)
			tx_Data_Enable <=1'b0;
		else if(tx_Data_Enable==1'b1)
			tx_Data_Enable <=1'b0;
		else if(EN_16x_Baud==1'b1)
			tx_Data_Enable <= div16;
	end

//*******************************************************
////    tx_start is '1' for the start bit in a transmission
////*******************************************************
always@(posedge Clk)
	begin
		if(Reset)
			tx_Start<=1'b0;
		else 
		 	tx_Start <= ((~(tx_Run)) & (tx_Start | (fifo_Data_Present & tx_Data_Enable)));
	end






//*********************************************************
////    tx_DataBits is '1' during all databits transmission
////*******************************************************
always@(posedge Clk)
	begin
		if(Reset)
			tx_DataBits<=1'b0;
		else 
			 tx_DataBits <= ((~(fifo_Read)) & (tx_DataBits | (tx_Start & tx_Data_Enable)));		
	end

//*********************************************************
//    If mux_sel is zero then reload with the init value else if 
//            tx_DataBits = '1', decrement
//////*******************************************************
always@(posedge Clk)
	begin
		if(Reset)
			mux_sel <= ((C_DATA_BITS - 1));
		else if(tx_Data_Enable == 1'b1)
		begin
			if(mux_sel_is_zero == 1'b1)
				mux_sel <= MUX_SEL_INIT;
            else if (tx_DataBits == 1'b1)
               mux_sel <= (mux_sel - 1);	
		end

	end
//*********************************************************
//////Detecting when mux_sel is zero, i.e. all data bits are transfered
//////*******************************************************
assign  mux_sel_is_zero = (mux_sel == 3'b000) ? 1'b1 : 1'b0;


//*********************************************************
//Read out the next data from the transmit fifo when the 
  //  --                 data has been transmitted
//////*******************************************************
always@(posedge Clk)
	begin
		if(Reset)
			fifo_Read<=1'b0;
		else
			fifo_Read <= 	tx_Data_Enable & mux_sel_is_zero;
	end


//*********************************************************
//    -- Select which bit within the data word to transmit
//    --------------------------------------------------------------------------
//
//    --------------------------------------------------------------------------
//    -- PARITY_BIT_INSERTION : Need special treatment for inserting the parity 
//    --                        bit because of parity generation
//////*******************************************************
   assign data_to_transfer[C_DATA_BITS - 1:1] = fifo_DOut[C_DATA_BITS - 1:1];// data_to_transfer(0 to C_DATA_BITS-2) <= fifo_DOut(0 to C_DATA_BITS-2);
   
   assign data_to_transfer[0] = (select_Parity == 1'b1) ? parity : fifo_DOut[0];// data_to_transfer(C_DATA_BITS-1)
   
   assign mux_01 = (mux_sel[0] == 1'b1) ? data_to_transfer[C_DATA_BITS - 2] :  data_to_transfer[C_DATA_BITS - 1];//(2) (1) (0)
   assign mux_23 = (mux_sel[0] == 1'b1) ? data_to_transfer[C_DATA_BITS - 4] :  data_to_transfer[C_DATA_BITS - 3];//(2) (3) (2)

//*********************************************************
//////    Select total N data bits when C_DATA_BITS = N
//////*******************************************************
 generate
      if (C_DATA_BITS == 5)
      begin : DATA_BITS_IS_5
         assign mux_45 = data_to_transfer[C_DATA_BITS - 5];//(4)
         assign mux_67 = 1'b0;
      end
   endgenerate
   
   generate
      if (C_DATA_BITS == 6)
      begin : DATA_BITS_IS_6
         assign mux_45 = (mux_sel[0] == 1'b1) ? data_to_transfer[C_DATA_BITS - 6] : data_to_transfer[C_DATA_BITS - 5];//(2) (5) (4)
         assign mux_67 = 1'b0;
      end
   endgenerate
   
   generate
      if (C_DATA_BITS == 7)
      begin : DATA_BITS_IS_7
         assign mux_45 = (mux_sel[0] == 1'b1) ? data_to_transfer[C_DATA_BITS - 6] : 
                         data_to_transfer[C_DATA_BITS - 5];//(2) (5) (4)
         assign mux_67 = data_to_transfer[C_DATA_BITS - 7];//(6)
      end
   endgenerate
   
   generate
      if (C_DATA_BITS == 8)
      begin : DATA_BITS_IS_8
         assign mux_45 = (mux_sel[0] == 1'b1) ? data_to_transfer[C_DATA_BITS - 6] : 
                         data_to_transfer[C_DATA_BITS - 5];//(2) (5) (4)
         assign mux_67 = (mux_sel[0] == 1'b1) ? data_to_transfer[C_DATA_BITS - 8] : 
                         data_to_transfer[C_DATA_BITS - 7];//(2) (7) (6)
      end
   endgenerate

  assign mux_0123 = (mux_sel[1] == 1'b1) ? mux_23 : mux_01; //(1)
   assign mux_4567 = (mux_sel[1] == 1'b1) ? mux_67 : mux_45; //(1)
   assign mux_Out = (mux_sel[2] == 1'b1) ? mux_4567 : mux_0123; //(0)

//*********************************************************
//////  SERIAL_DATA_DFF : Register the mux_Out
//////*******************************************************



always@(posedge Clk)
begin
	if(Reset)
		serial_Data <= 1'b0;
	else
		serial_Data <= mux_Out;
end

//*********************************************************
//////  :Force a '0' when tx_start is '1', Start_bit
//    --                 Force a '1' when tx_run is '0',   Idle
//    --                 otherwise put out the serial_data
//////*******************************************************


 always @(posedge Clk)
      begin
         if (Reset == 1'b1)
            TX <= 1'b1;
         else
            TX <= ((~(tx_Run)) | serial_Data) & ((~(tx_Start)));
      end


//*********************************************************
//////     Generate parity handling when C_USE_PARITY = 1
//////*******************************************************


   generate
      if (C_USE_PARITY == 1)
      begin : USING_PARITY
         
         
         always @(posedge Clk)
            begin
               if (tx_Start == 1'b1)
                  parity <= (C_ODD_PARITY == 1)?1'b1:1'b0;
               else if (tx_Data_Enable == 1'b1)
                  parity <= parity ^ serial_Data;
            end

         
         always @(posedge Clk)
            begin
               if (Reset == 1'b1)
                  tx_Run1 <= 1'b0;
               else if (tx_Data_Enable == 1'b1)
                  tx_Run1 <= tx_DataBits;
            end

         
         assign tx_Run = tx_Run1 | tx_DataBits;
         
         
         always @(posedge Clk)
            begin
               if (Reset == 1'b1)
                  select_Parity <= 1'b0;
               else if (tx_Data_Enable == 1'b1)
                  select_Parity <= mux_sel_is_zero;
            end
         end
   endgenerate
//*********************************************************
//////   When C_USE_PARITY = 0 select parity as '0'
//////*******************************************************

   generate
      if (C_USE_PARITY == 0)
      begin : NO_PARITY
         assign tx_Run = tx_DataBits;
         initial begin select_Parity <= 1'b0; end
      end
   endgenerate
//*********************************************************
//////  Write TX FIFO when FIFO is not full when AXI writes data in TX FIFO
//////*******************************************************
  
   assign fifo_wr = Write_TX_FIFO & ((~tx_buffer_full_i));
//*********************************************************
//////     Read TX FIFO when FIFO is not empty when AXI reads data from TX FIFO
//////*******************************************************
//
   assign fifo_rd = fifo_Read & ((~fifo_Data_Empty));
//*********************************************************
//////   Reset TX FIFO when requested from the control register or system reset
//////*******************************************************
//
   assign TX_FIFO_Reset = Reset_TX_FIFO | Reset;
   
 //*********************************************************
 //////   Transmit FIFO Interface
 //////*******************************************************
 

   assign TX_Buffer_Full = tx_buffer_full_i;
   assign TX_Buffer_Empty = fifo_Data_Empty;
	 assign fifo_Data_Present = (~fifo_Data_Empty);

//   proc_common_v3_00_a.srl_fifo_f
// #(
//		.C_DWIDTH(C_DATA_BITS),
//		.C_DEPTH(16),
//		.C_FAMILY(C_FAMILY)
//)
//SRL_FIFO_I(
//		.clk(Clk),
//		.reset(TX_FIFO_Reset),
//		.fifo_write(fifo_wr),
//		.data_in(TX_Data),
//		.fifo_read(fifo_rd),
//		.data_out(fifo_DOut),
//		.fifo_full(tx_buffer_full_i),
//		.fifo_empty(fifo_Data_Empty)
//
//);
/*
genvar m;
generate 
	for(m=0;m<=C_DATA_BITS-1;m=m+1)
	begin:turn 
	assign 	fifo_DOut[m] = fifo_DOut_temp[C_DATA_BITS-1-m];
	end
	
endgenerate
*/
 assign fifo_DOut = fifo_DOut_temp;
datafifo tx_fifo (
  .clk(Clk), // input clk
  .srst(TX_FIFO_Reset), // input rst
  .din(TX_Data), // input [7 : 0] din
  .wr_en(fifo_wr), // input wr_en
  .rd_en(fifo_rd), // input rd_en
  .dout(fifo_DOut_temp), // output [7 : 0] dout
  .full(tx_buffer_full_i), // output full
  .empty(fifo_Data_Empty) // output empty
);
  





endmodule 
