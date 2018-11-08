

module uartlite_rx
#(
	parameter C_FAMILY = "virtex6",
	parameter	C_DATA_BITS = 8,
	parameter	C_USE_PARITY = 0,
	parameter	C_ODD_PARITY = 0
)
(
	input	wire	Clk,
	input	wire 	Reset,

	input                         EN_16x_Baud,
   input                         RX,
   input                         Read_RX_FIFO,
   input                         Reset_RX_FIFO,
   output [C_DATA_BITS-1:0]      RX_Data,
   output                        RX_Data_Present,
   output                        RX_Buffer_Full,
   output                        RX_Frame_Error,
   output                        RX_Overrun_Error,
   output                        RX_Parity_Error
);


//localparam	bo2sl = {1'b0,1'b1};
//parameter
localparam 
	 SERIAL_TO_PAR_LENGTH = C_DATA_BITS + C_USE_PARITY,
     STOP_BIT_POS = SERIAL_TO_PAR_LENGTH,
     DATA_LSB_POS = SERIAL_TO_PAR_LENGTH,
     CALC_PAR_POS = SERIAL_TO_PAR_LENGTH;



//register

  reg                           start_Edge_Detected;
   wire                          start_Edge_Detected_Bit;
   reg                           running;
   wire                          recycle;
   wire                          sample_Point;
   reg                           stop_Bit_Position;
   reg                           fifo_Write;
   
   reg [SERIAL_TO_PAR_LENGTH:0]  fifo_din='d0;
   wire [SERIAL_TO_PAR_LENGTH:1] serial_to_Par;
   wire                          calc_parity;
   reg                           parity=1'b0;
   wire                          RX_Buffer_Full_I;
   reg                           RX_D1;
   reg                           RX_D2;
   reg                           rx_1;
   reg                           rx_2;
   reg                           rx_3;
   reg                           rx_4;
   reg                           rx_5;
   reg                           rx_6;
   reg                           rx_7;
   reg                           rx_8;
   reg                           rx_9;
   wire                          rx_Data_Empty;
   wire                          fifo_wr;
   wire                          fifo_rd;
   wire                          RX_FIFO_Reset;
   reg                           valid_rx;
   wire                          valid_start;
   reg                           frame_err_ocrd;
   wire                          frame_err;

//*******************************************************************
//// RX_SAMPLING : Double sample RX to avoid meta-stability
////*******************************************************************
always @(posedge Clk)
   begin: RX_SAMPLING
      
      begin
         if (Reset == 1'b1)
         begin
            RX_D1 <= 1'b1;
            RX_D2 <= 1'b1;
         end
         else
         begin
            RX_D1 <= RX;
            RX_D2 <= RX_D1;
         end
      end
   end

//*******************************************************************
////Detect a falling edge on RX and start a new reception if idle
////*******************************************************************
//
//detect the start of the frame 
  always @(posedge Clk)
   begin: RX_DFFS
      
      begin
         if (Reset == 1'b1)
         begin
            rx_1 <= 1'b0;
            rx_2 <= 1'b0;
            rx_3 <= 1'b0;
            rx_4 <= 1'b0;
            rx_5 <= 1'b0;
            rx_6 <= 1'b0;
            rx_7 <= 1'b0;
            rx_8 <= 1'b0;
            rx_9 <= 1'b0;
         end
         else if (EN_16x_Baud == 1'b1)
         begin
            rx_1 <= RX_D2;
            rx_2 <= rx_1;
            rx_3 <= rx_2;
            rx_4 <= rx_3;
            rx_5 <= rx_4;
            rx_6 <= rx_5;
            rx_7 <= rx_6;
            rx_8 <= rx_7;
            rx_9 <= rx_8;
         end
      end
   end


//Start bit valid when RX is continuously low for atleast 8 samples
	 assign valid_start = rx_8 | rx_7 | rx_6 | rx_5 | rx_4 | rx_3 | rx_2 | rx_1;

//START_EDGE_DFF : Start a new reception if idle
  
   always @(posedge Clk)
   begin: START_EDGE_DFF
      
      begin
         if (Reset == 1'b1)
            start_Edge_Detected <= 1'b0;
         else if (EN_16x_Baud == 1'b1)
            start_Edge_Detected <= (((~running)) & (frame_err_ocrd == 1'b0) & (rx_9 == 1'b1) & (valid_start == 1'b0));
      end
   end	

// FRAME_ERR_CAPTURE : frame_err_ocrd is '1' when a frame error is occured
//                    and deasserted when the next low to high on RX
  always @(posedge Clk)
   begin: FRAME_ERR_CAPTURE
      
      begin
         if (Reset == 1'b1)
            frame_err_ocrd <= 1'b0;
         else if (frame_err == 1'b1)
            frame_err_ocrd <= 1'b1;
         else if (RX_D2 == 1'b1)
            frame_err_ocrd <= 1'b0;
      end
   end
	
// VALID_XFER : valid_rx is '1' when a valid start edge detected
   always @(posedge Clk)
   begin: VALID_XFER
      
      begin
         if (Reset == 1'b1)
            valid_rx <= 1'b0;
         else if (start_Edge_Detected == 1'b1)
            valid_rx <= 1'b1;
         else if (fifo_Write == 1'b1)
            valid_rx <= 1'b0;
      end
   end

//- RUNNING_DFF : Running is '1' during a reception
   always @(posedge Clk)
   begin: RUNNING_DFF
      
      begin
         if (Reset == 1'b1)
            running <= 1'b0;
         else if (EN_16x_Baud == 1'b1)
         begin
            if (start_Edge_Detected)
               running <= 1'b1;
            else if ((sample_Point == 1'b1) && (stop_Bit_Position == 1'b1))
               running <= 1'b0;
         end
      end
   end


//Boolean to std logic conversion of start edg
  assign start_Edge_Detected_Bit = (start_Edge_Detected) ? 1'b1 :  1'b0;


//After the start edge is detected, generate recycle to generate sample
//    -- point
 assign recycle = (valid_rx & ((~stop_Bit_Position)) & (start_Edge_Detected_Bit | sample_Point));

//    -------------------------------------------------------------------------
//    -- DELAY_16_I : Keep regenerating new values into the 16 clock delay, 
//    -- Starting with the first start_Edge_Detected_Bit and for every new 
//    -- sample_points until stop_Bit_Position is reached
//    ------------------------------------------------------------------------
 //  proc_common_v3_00_a.dynshreg_i_f #(16, 1, C_FAMILY) 
 //  DELAY_16_I(
 //   	   .clk(Clk), 
 //   	   .clken(EN_16x_Baud), 
 //   	   .addr(4'b1111), 
 //   	   .din(0)(recycle), 
 //   	   .dout(0)(sample_Point)
 //  );
   SRL16E #(
      .INIT(16'h0000) // Initial Value of Shift Register
   ) SRL16E_inst (
      .Q(sample_Point),       // SRL data output
      .A0(1'b1),     // Select[0] input
      .A1(1'b1),     // Select[1] input
      .A2(1'b1),     // Select[2] input
      .A3(1'b1),     // Select[3] input
      .CE(EN_16x_Baud),     // Clock enable input
      .CLK(Clk),   // Clock input
      .D(recycle)        // SRL data input
   );

 //STOP_BIT_HANDLER : Detect when the stop bit is receive
  always @(posedge Clk)
   begin: STOP_BIT_HANDLER
      
      begin
         if (Reset == 1'b1)
            stop_Bit_Position <= 1'b0;
         else if (EN_16x_Baud == 1'b1)
         begin
            if (stop_Bit_Position == 1'b0)
				//                  -- Start bit has reached the end of the shift register 
               //   -- (Stop bit position
               stop_Bit_Position <= sample_Point & fifo_din[STOP_BIT_POS];//(STOP_BIT_POS)//SERIAL_TO_PAR_LENGTH-
            else if (sample_Point == 1'b1)
				//  -- if stop_Bit_Position is 1 clear it at next sample_Point
               stop_Bit_Position <= 1'b0;
         end
      end
   end

//USING_PARITY : Generate parity handling when C_USE_PARITY = 
generate
	if (C_USE_PARITY == 1)
	begin : USING_PARITY
		always @(posedge Clk)
         begin: PARITY_DFF
            begin
               if (Reset == 1'b1 || start_Edge_Detected_Bit == 1'b1)
                  parity <= (C_ODD_PARITY == 1)? 1'b1 : 1'b0;//bo2sl[C_ODD_PARITY == 1];
               else if (EN_16x_Baud == 1'b1)
                  parity <= calc_parity;
            end
         end
         
	assign calc_parity = ((stop_Bit_Position | ((~sample_Point))) == 1'b1) ? parity : (parity ^ RX_D2);
         
	assign RX_Parity_Error = (running & (RX_D2 != parity)) ? ((EN_16x_Baud & sample_Point) & (fifo_din[CALC_PAR_POS]) & (~stop_Bit_Position)) : 1'b0;//(CALC_PAR_POS)//SERIAL_TO_PAR_LENGTH-
      end
endgenerate	
 always @(*) fifo_din[0] <= RX_D2 & (~Reset);//(0)//SERIAL_TO_PAR_LENGTH



 // SERIAL_TO_PARALLEL : Serial to parrallel conversion data part
 
genvar i;
generate 
for(i=1;i<=(SERIAL_TO_PAR_LENGTH);i=i+1)
begin:SERIAL_TO_PARALLEL

			  assign serial_to_Par[i] = ((stop_Bit_Position | (~sample_Point)) == 1'b1) ? fifo_din[i] : fifo_din[i-1];//(i) (i) (i-1)//SERIAL_TO_PAR_LENGTH+1- [SERIAL_TO_PAR_LENGTH- [SERIAL_TO_PAR_LENGTH-i+1

		
always @(posedge Clk)
	begin: BIT_I
               
		begin
			if (Reset == 1'b1)
				fifo_din[i] <= 1'b0;//(i)	//	SERIAL_TO_PAR_LENGTH-
			else if (start_Edge_Detected_Bit == 1'b1)
				fifo_din[i] <= (i==1)? 1'b1:1'b0;	// bo2sl[i == 1];// -- Bit 1 resets to '1'; //(i)SERIAL_TO_PAR_LENGTH-
                                               //-- others to '0'
			else if (EN_16x_Baud == 1'b1)
				fifo_din[i] <= serial_to_Par[i];//(i) (i)SERIAL_TO_PAR_LENGTH- SERIAL_TO_PAR_LENGTH+1-
		end
	end
end	
endgenerate


//   -- FIFO_WRITE_DFF : Write in the received word when the stop_bit has been 
//    --                  received and it is a '1'

   always @(posedge Clk)
   begin: FIFO_WRITE_DFF
      
      begin
         if (Reset == 1'b1)
            fifo_Write <= 1'b0;
         else
            fifo_Write <= stop_Bit_Position & RX_D2 & sample_Point & EN_16x_Baud;
      end
   end
   assign frame_err = stop_Bit_Position & sample_Point & EN_16x_Baud & (~RX_D2);
    assign RX_Frame_Error = frame_err;
//fifo
   assign fifo_wr = fifo_Write & ((~RX_Buffer_Full_I)) & valid_rx;
   
   assign fifo_rd = Read_RX_FIFO & ((~rx_Data_Empty));
   
   assign RX_FIFO_Reset = Reset_RX_FIFO | Reset;



   assign RX_Data_Present = (~rx_Data_Empty);
   assign RX_Overrun_Error = RX_Buffer_Full_I & fifo_Write;
   // -- Note that if
  //      -- the RX FIFO is read on the same cycle as it is written while full,
  //      -- there is no loss of data. However this case is not optimized and
  //      -- is also reported as an overrun.
   assign RX_Buffer_Full = RX_Buffer_Full_I;


 //  proc_common_v3_00_a.srl_fifo_f #(C_DATA_BITS, 16, C_FAMILY) 
 //  SRL_FIFO_I(
 //   	   .clk(Clk), 
 //   	   .reset(RX_FIFO_Reset), 
 //   	   .fifo_write(fifo_wr), 
 //   	   .data_in(fifo_din[(DATA_LSB_POS - C_DATA_BITS + 1):DATA_LSB_POS]), 
 //   	   .fifo_read(fifo_rd), .data_out(RX_Data), 
 //   	   .fifo_full(RX_Buffer_Full_I), 
 //   	   .fifo_empty(rx_Data_Empty), 
 //   	   .addr()
 //  );
   
rxdatafifo rx_fifo (
  .clk(Clk), // input clk
  .srst(RX_FIFO_Reset), // input rst
  .din(fifo_din[DATA_LSB_POS:(DATA_LSB_POS - C_DATA_BITS + 1)]), // input [8 : 0] din //(DATA_LSB_POS - C_DATA_BITS + 1):DATA_LSB_POS//(SERIAL_TO_PAR_LENGTH-(DATA_LSB_POS - C_DATA_BITS + 1)):(SERIAL_TO_PAR_LENGTH-DATA_LSB_POS)]
  .wr_en(fifo_wr), // input wr_en
  .rd_en(fifo_rd), // input rd_en
  .dout(RX_Data), // output [8 : 0] dout
  .full(RX_Buffer_Full_I), // output full
  .empty(rx_Data_Empty) // output empty
);
  
endmodule
