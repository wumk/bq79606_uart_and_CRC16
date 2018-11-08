//-- Port Declaration
//-------------------------------------------------------------------------------
//-------------------------------------------------------------------------------
//-- Definition of Generics :
//-------------------------------------------------------------------------------
//-- UART Lite generics
//--  C_DATA_BITS           -- The number of data bits in the serial frame
//--  C_S_AXI_ACLK_FREQ_HZ  -- System clock frequency driving UART lite
//--                           peripheral in Hz
//--  C_BAUDRATE            -- Baud rate of UART Lite in bits per second
//--  C_USE_PARITY          -- Determines whether parity is used or not
//--  C_ODD_PARITY          -- If parity is used determines whether parity
//--                           is even or odd
//-- System generics
//--  C_FAMILY              -- Xilinx FPGA Family
//-------------------------------------------------------------------------------
//-------------------------------------------------------------------------------
//-- Definition of Ports :
//-------------------------------------------------------------------------------
//-- System Signals
//--  Clk                   --  Clock signal
//--  Rst                   --  Reset signal
//-- Slave attachment interface
//--  bus2ip_data           --  bus2ip data signal
//--  bus2ip_rdce           --  bus2ip read CE
//--  bus2ip_wrce           --  bus2ip write CE
//--  ip2bus_rdack          --  ip2bus read acknowledgement
//--  ip2bus_wrack          --  ip2bus write acknowledgement
//--  ip2bus_error          --  ip2bus error
//--  SIn_DBus              --  ip2bus data
//-- UART Lite interface
//--  RX                    --  Receive Data
//--  TX                    --  Transmit Data
//--  Interrupt             --  UART Interrupt
//------------------------------------------------------------------------------

module uartlite_core
#(
   parameter     C_FAMILY = "virtex6",
   parameter     C_S_AXI_ACLK_FREQ_HZ = 100_000_000,
   parameter     C_BAUDRATE = 9600,
   parameter     C_DATA_BITS = 8,
   parameter     C_USE_PARITY = 0,
   parameter     C_ODD_PARITY = 0
)
(
   input                  Clk,
   input                  Reset,
   input [7:0]            bus2ip_data,
   input [3:0]            bus2ip_rdce,
   input [3:0]            bus2ip_wrce,
   input                  bus2ip_cs,
   output                 ip2bus_rdack,
   output                 ip2bus_wrack,
   output                 ip2bus_error,
   output reg [7:0]           SIn_DBus,

  //uart signals 
   input                  RX,
   output                 TX,
   output reg                 Interrupt
);

/*
   function integer CALC_RATIO;
      input                  C_S_AXI_ACLK_FREQ_HZ;
      integer                C_S_AXI_ACLK_FREQ_HZ;
      input                  C_BAUDRATE;
      integer                C_BAUDRATE;
      
      localparam              C_BAUDRATE_16_BY_2 = (16 * C_BAUDRATE)/2;
      localparam              REMAINDER = C_S_AXI_ACLK_FREQ_HZ %(16 * C_BAUDRATE);
      localparam              RATIO = C_S_AXI_ACLK_FREQ_HZ/(16 * C_BAUDRATE);
   begin
      
      if (C_BAUDRATE_16_BY_2 < REMAINDER)
         CALC_RATIO = (RATIO + 1);
      else
         CALC_RATIO = RATIO;
   end
   endfunction


//localparam
localparam   RATIO = CALC_RATIO(C_S_AXI_ACLK_FREQ_HZ, C_BAUDRATE);
*/
      localparam              C_BAUDRATE_16_BY_2 = (16 * C_BAUDRATE)/2;
      localparam              REMAINDER = C_S_AXI_ACLK_FREQ_HZ %(16 * C_BAUDRATE);
      localparam              CALC_RATIO = C_S_AXI_ACLK_FREQ_HZ/(16 * C_BAUDRATE);
		localparam 					RATIO =(C_BAUDRATE_16_BY_2 < REMAINDER)? (CALC_RATIO+1) : CALC_RATIO;



//signals
   
   wire                   en_16x_Baud;
   reg                    enable_interrupts;
   reg                    reset_RX_FIFO;
   wire [C_DATA_BITS-1:0] rx_Data;
   wire                   rx_Data_Present;
   wire                   rx_Buffer_Full;
   wire                   rx_Frame_Error;
   wire                   rx_Overrun_Error;
   wire                   rx_Parity_Error;
   reg                    clr_Status;
   reg                    reset_TX_FIFO;
   wire                   tx_Buffer_Full;
   wire                   tx_Buffer_Empty;
   reg                    tx_Buffer_Empty_Pre;
   reg                    rx_Data_Present_Pre;

   wire [C_DATA_BITS-1:0] rx_Data_turn;

//   -- bit 7 rx_Data_Present
//    -- bit 6 rx_Buffer_Full
//    -- bit 5 tx_Buffer_Empty
//    -- bit 4 tx_Buffer_Full
//    -- bit 3 enable_interrupts
//    -- bit 2 Overrun Error
//    -- bit 1 Frame Error
//    -- bit 0 Parity Error (If C_USE_PARITY is true, otherwise '0')
//
//    -- Write Only
//    -- Below mentioned bits belong to Control Register and are declared as
//    -- signals below
//    -- bit 0-2 Dont'Care
//    -- bit 3   enable_interrupts
//    -- bit 4-5 Dont'Care
//    -- bit 6   Reset_RX_FIFO
//    -- bit 7   Reset_TX_FIF

  reg [7:0]              status_reg='d0;

reg bus2ip_wrce_r1,bus2ip_wrce_r2,bus2ip_wrce_r3;
//*********************************************************************
////acknowledgement
////*******************************************************************
  
   assign ip2bus_rdack = bus2ip_rdce[3] | bus2ip_rdce[1] | bus2ip_rdce[2] | bus2ip_rdce[0];//(0) (2) (1) (3)
   
   assign ip2bus_wrack = bus2ip_wrce[2] | bus2ip_wrce[0] | bus2ip_wrce[3] | bus2ip_wrce[1];//
   
   assign ip2bus_error = ((bus2ip_rdce[3] & (~rx_Data_Present)) | (bus2ip_wrce[2] & tx_Buffer_Full));//(0) (1)


//*********************************************************************
////Status register handling
////*******************************************************************
   always @(*) status_reg[0] <= rx_Data_Present;//7
   always @(*) status_reg[1] <= rx_Buffer_Full;//6
   always @(*) status_reg[2] <= tx_Buffer_Empty;//5
   always @(*) status_reg[3] <= tx_Buffer_Full;//4
   always @(*) status_reg[4] <= enable_interrupts;//3

   
   

   
   
//*********************************************************************
// CLEAR_STATUS_REG : Process to clear status register
////*******************************************************************

   always @(posedge Clk)
   begin: CLEAR_STATUS_REG
      
      begin
         if (Reset == 1'b1)
            clr_Status <= 1'b0;
         else
            clr_Status <= bus2ip_rdce[1];//(2)
      end
   end

//*********************************************************************
/////Process to register rx_Overrun_Error
////*******************************************************************

   always @(posedge Clk)
   begin: RX_OVERRUN_ERROR_DFF
      
      begin
         if ((Reset == 1'b1) || (clr_Status == 1'b1))
            status_reg[5] <= 1'b0;//(2)
         else if (rx_Overrun_Error == 1'b1)
            status_reg[5] <= 1'b1;//(2)
      end
   end

//*********************************************************************
////Process to register rx_Frame_Error
//////*******************************************************************


   always @(posedge Clk)
   begin: RX_FRAME_ERROR_DFF
      
      begin
         if (Reset == 1'b1)
            status_reg[6] <= 1'b0;//(1)
         else
            if (clr_Status == 1'b1)
               status_reg[6] <= 1'b0;//(1)
            else if (rx_Frame_Error == 1'b1)
               status_reg[6] <= 1'b1;//(1)
      end
   end


//*********************************************************************
////If C_USE_PARITY = 1, register rx_Parity_Error
//////*******************************************************************
 generate
      if (C_USE_PARITY == 1)
      begin : USING_PARITY
         
         always @(posedge Clk)
         begin: RX_PARITY_ERROR_DFF
            
            begin
               if (Reset == 1'b1)
                  status_reg[7] <= 1'b0;//(0)
               else
                  if (clr_Status == 1'b1)
                     status_reg[7] <= 1'b0;
                  else if (rx_Parity_Error == 1'b1)
                     status_reg[7] <= 1'b1;
            end
         end
      end
   endgenerate   


//*********************************************************************
//// NO_PARITY : If C_USE_PARITY = 0, rx_Parity_Error bit is not present
//////*******************************************************************

  generate
      if (C_USE_PARITY == 0)
      begin : NO_PARITY
    initial    begin status_reg[7] <= 1'b0; end//(0)
      end
   endgenerate

//*********************************************************************
////CTRL_REG_DFF : Control Register Handling 
//////*******************************************************************

 always @(posedge Clk)
   begin: CTRL_REG_DFF
      
      begin
         if (Reset == 1'b1)
         begin
            reset_TX_FIFO <= 1'b1;
            reset_RX_FIFO <= 1'b1;
            enable_interrupts <= 1'b0;
         end
         else if (bus2ip_wrce[0] == 1'b1)//(3)
         begin
            reset_RX_FIFO <= bus2ip_data[1];//(6)
            reset_TX_FIFO <= bus2ip_data[0];//(7)
            enable_interrupts <= bus2ip_data[4];//(3)
         end
         else
         begin
            reset_TX_FIFO <= 1'b0;
            reset_RX_FIFO <= 1'b0;
         end
      end
   end



//*********************************************************************
//// Tx Fifo Interrupt handling
//////*******************************************************************
always@(posedge Clk)
begin
	bus2ip_wrce_r1 <= bus2ip_wrce[2] ;
	bus2ip_wrce_r2 <= bus2ip_wrce_r1;
	bus2ip_wrce_r3 <= bus2ip_wrce_r2;
end	
   
  always @(posedge Clk)
   begin: TX_BUFFER_EMPTY_DFF_I
      
      begin
         if (Reset == 1'b1)
            tx_Buffer_Empty_Pre <= 1'b0;
         else
            if (bus2ip_wrce_r3 == 1'b1)//(1)bus2ip_wrce[2]
               tx_Buffer_Empty_Pre <= 1'b0;
            else
               tx_Buffer_Empty_Pre <= tx_Buffer_Empty;
      end
   end

//*********************************************************************
//// Rx Fifo Interrupt handling
//////*******************************************************************


   always @(posedge Clk)
   begin: RX_BUFFER_DATA_DFF_I
      
      begin
         if (Reset == 1'b1)
            rx_Data_Present_Pre <= 1'b0;
         else
            if (bus2ip_rdce[3] == 1'b1)//(0)
               rx_Data_Present_Pre <= 1'b0;
            else
               rx_Data_Present_Pre <= rx_Data_Present;
      end
   end
   

//*********************************************************************
////Interrupt register handling
//////*******************************************************************

  always @(posedge Clk)
   begin: INTERRUPT_DFF
      
      begin
         if (Reset == 1'b1)
            Interrupt <= 1'b0;
         else
            Interrupt <= enable_interrupts & ((rx_Data_Present & (~rx_Data_Present_Pre)) | (tx_Buffer_Empty & (~tx_Buffer_Empty_Pre)));
      end
   end

//*********************************************************************
//// READ_MUX : Read bus interface handling
//////*******************************************************************
genvar w;
generate 
	for(w=0;w<=C_DATA_BITS-1;w=w+1)
	begin:turn 
		assign rx_Data_turn[w] = rx_Data[C_DATA_BITS-1-w];
	end
endgenerate



 always @(status_reg or bus2ip_rdce[1] or bus2ip_rdce[3] or rx_Data)//(2) (0)
   begin: READ_MUX
      if (bus2ip_rdce[1] == 1'b1)//(2)
         SIn_DBus <= status_reg;
      else if (bus2ip_rdce[3] == 1'b1)//(0)
         SIn_DBus[(C_DATA_BITS-1):0] <= rx_Data_turn;//(8-C_DATA_BITS) to 7
      else
         SIn_DBus <= 8'd0;
   end



//*******************************************************************
////BAUD_RATE_I : Instansiating the baudrate module
////*******************************************************************
baudrate 
#(.C_RATIO(RATIO)) 
BAUD_RATE_I(
		.Clk(Clk), 
		.Reset(Reset), 
		.EN_16x_Baud(en_16x_Baud)

);

uartlite_rx
  #(
		 .C_FAMILY		(C_FAMILY), 
		 .C_DATA_BITS	(C_DATA_BITS), 
		 .C_USE_PARITY	(C_USE_PARITY), 
		 .C_ODD_PARITY	(C_ODD_PARITY)
 ) 
  UARTLITE_RX_I(
		  .Clk(Clk), 
		  .Reset(Reset), 
		  .EN_16x_Baud(en_16x_Baud), 
		  .RX(RX), 
		  .Read_RX_FIFO(bus2ip_rdce[3]), //(0)
		  .Reset_RX_FIFO(reset_RX_FIFO), 
		  .RX_Data(rx_Data), 
		  .RX_Data_Present(rx_Data_Present), 
		  .RX_Buffer_Full(rx_Buffer_Full), 
		  .RX_Frame_Error(rx_Frame_Error), 
		  .RX_Overrun_Error(rx_Overrun_Error), 
		  .RX_Parity_Error(rx_Parity_Error)
  );


uartlite_tx 
#(
		.C_FAMILY(C_FAMILY), 
		.C_DATA_BITS(C_DATA_BITS), 
		.C_USE_PARITY(C_USE_PARITY), 
		.C_ODD_PARITY(C_ODD_PARITY)
) 
UARTLITE_TX_I(
		.Clk(Clk), 
		.Reset(Reset), 
		.EN_16x_Baud(en_16x_Baud), 
		.TX(TX), 
		.Write_TX_FIFO(bus2ip_wrce[2]), //(1)
		.Reset_TX_FIFO(reset_TX_FIFO), 
		.TX_Data(bus2ip_data[(C_DATA_BITS-1):0]), //8-C_DATA_BITS to 7/
		.TX_Buffer_Full(tx_Buffer_Full), 
		.TX_Buffer_Empty(tx_Buffer_Empty)
);
   


endmodule 
