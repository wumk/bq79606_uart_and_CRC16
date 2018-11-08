//--------------------------------------------------------------------------------------------
//
// Generated by X-HDL VHDL Translator - Version 2.0.0 Feb. 1, 2011
// ?? ??? 5 2018 16:46:43
//
//      Input file      : 
//      Component name  : uartlite_rx
//      Author          : 
//      Company         : 
//
//      Description     : 
//
//
//--------------------------------------------------------------------------------------------


module uartlite_rx(Clk, Reset, EN_16x_Baud, RX, Read_RX_FIFO, Reset_RX_FIFO, RX_Data, RX_Data_Present, RX_Buffer_Full, RX_Frame_Error, RX_Overrun_Error, RX_Parity_Error);
   parameter [32*8:1]            C_FAMILY = "virtex6";
   parameter [3:0]               C_DATA_BITS = 8;
   parameter [0:0]               C_USE_PARITY = 0;
   parameter [0:0]               C_ODD_PARITY = 0;
   input                         Clk;
   input                         Reset;
   input                         EN_16x_Baud;
   input                         RX;
   input                         Read_RX_FIFO;
   input                         Reset_RX_FIFO;
   output [0:C_DATA_BITS-1]      RX_Data;
   output                        RX_Data_Present;
   output                        RX_Buffer_Full;
   output                        RX_Frame_Error;
   output                        RX_Overrun_Error;
   output                        RX_Parity_Error;
   
   
   
   parameter                     bo2sl = {1'b0, 1'b1};
   
   parameter                     SERIAL_TO_PAR_LENGTH = C_DATA_BITS + C_USE_PARITY;
   parameter                     STOP_BIT_POS = SERIAL_TO_PAR_LENGTH;
   parameter                     DATA_LSB_POS = SERIAL_TO_PAR_LENGTH;
   parameter                     CALC_PAR_POS = SERIAL_TO_PAR_LENGTH;
   
   reg                           start_Edge_Detected;
   wire                          start_Edge_Detected_Bit;
   reg                           running;
   wire                          recycle;
   wire                          sample_Point;
   reg                           stop_Bit_Position;
   reg                           fifo_Write;
   
   reg [0:SERIAL_TO_PAR_LENGTH]  fifo_din;
   wire [1:SERIAL_TO_PAR_LENGTH] serial_to_Par;
   wire                          calc_parity;
   reg                           parity;
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
   
   assign valid_start = rx_8 | rx_7 | rx_6 | rx_5 | rx_4 | rx_3 | rx_2 | rx_1;
   
   
   always @(posedge Clk)
   begin: START_EDGE_DFF
      
      begin
         if (Reset == 1'b1)
            start_Edge_Detected <= 1'b0;
         else if (EN_16x_Baud == 1'b1)
            start_Edge_Detected <= (((~running)) & (frame_err_ocrd == 1'b0) & (rx_9 == 1'b1) & (valid_start == 1'b0));
      end
   end
   
   
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
   
   
   always @(posedge Clk)
   begin: RUNNING_DFF
      
      begin
         if (Reset == 1'b1)
            running <= 1'b0;
         else if (EN_16x_Baud == 1'b1)
         begin
            if (start_Edge_Detected)
               running <= 1'b1;
            else if ((sample_Point == 1'b1) & (stop_Bit_Position == 1'b1))
               running <= 1'b0;
         end
      end
   end
   
   assign start_Edge_Detected_Bit = (start_Edge_Detected) ? 1'b1 : 
                                    1'b0;
   
   assign recycle = (valid_rx & ((~stop_Bit_Position)) & (start_Edge_Detected_Bit | sample_Point));
   
   
   proc_common_v3_00_a.dynshreg_i_f #(16, 1, C_FAMILY) DELAY_16_I(.clk(Clk), .clken(EN_16x_Baud), .addr(4'b1111), .din(0)(recycle), .dout(0)(sample_Point));
   
   
   always @(posedge Clk)
   begin: STOP_BIT_HANDLER
      
      begin
         if (Reset == 1'b1)
            stop_Bit_Position <= 1'b0;
         else if (EN_16x_Baud == 1'b1)
         begin
            if (stop_Bit_Position == 1'b0)
               stop_Bit_Position <= sample_Point & fifo_din[STOP_BIT_POS];
            else if (sample_Point == 1'b1)
               stop_Bit_Position <= 1'b0;
         end
      end
   end
   
   generate
      if (C_USE_PARITY == 1)
      begin : USING_PARITY
         
         
         always @(posedge Clk)
         begin: PARITY_DFF
            
            begin
               if (Reset == 1'b1 | start_Edge_Detected_Bit == 1'b1)
                  parity <= bo2sl[C_ODD_PARITY == 1];
               else if (EN_16x_Baud == 1'b1)
                  parity <= calc_parity;
            end
         end
         
         assign calc_parity = ((stop_Bit_Position | ((~sample_Point))) == 1'b1) ? parity : 
                              parity ^ RX_D2;
         
         assign RX_Parity_Error = (running & (RX_D2 != parity)) ? (EN_16x_Baud & sample_Point) & (fifo_din[CALC_PAR_POS]) & (~stop_Bit_Position) : 
                                  1'b0;
      end
   endgenerate
   
   always @(*) fifo_din[0] <= RX_D2 & (~Reset);
   
   generate
      begin : xhdl0
         genvar                        i;
         for (i = 1; i <= SERIAL_TO_PAR_LENGTH; i = i + 1)
         begin : SERIAL_TO_PARALLEL
            
            assign serial_to_Par[i] = ((stop_Bit_Position | (~sample_Point)) == 1'b1) ? fifo_din[i] : 
                                      fifo_din[i - 1];
            
            
            always @(posedge Clk)
            begin: BIT_I
               
               begin
                  if (Reset == 1'b1)
                     fifo_din[i] <= 1'b0;
                  else
                     if (start_Edge_Detected_Bit == 1'b1)
                        fifo_din[i] <= bo2sl[i == 1];
                     else if (EN_16x_Baud == 1'b1)
                        fifo_din[i] <= serial_to_Par[i];
               end
            end
         end
      end
   endgenerate
   
   
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
   
   assign fifo_wr = fifo_Write & ((~RX_Buffer_Full_I)) & valid_rx;
   
   assign fifo_rd = Read_RX_FIFO & ((~rx_Data_Empty));
   
   assign RX_FIFO_Reset = Reset_RX_FIFO | Reset;
   
   
   proc_common_v3_00_a.srl_fifo_f #(C_DATA_BITS, 16, C_FAMILY) SRL_FIFO_I(.clk(Clk), .reset(RX_FIFO_Reset), .fifo_write(fifo_wr), .data_in(fifo_din[(DATA_LSB_POS - C_DATA_BITS + 1):DATA_LSB_POS]), .fifo_read(fifo_rd), .data_out(RX_Data), .fifo_full(RX_Buffer_Full_I), .fifo_empty(rx_Data_Empty), .addr());
   
   assign RX_Data_Present = (~rx_Data_Empty);
   assign RX_Overrun_Error = RX_Buffer_Full_I & fifo_Write;
   assign RX_Buffer_Full = RX_Buffer_Full_I;
   
endmodule