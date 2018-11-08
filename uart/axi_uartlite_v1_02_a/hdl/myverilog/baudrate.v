//
//-------------------------------------------------------------------------------
//-- Port Declaration
//-------------------------------------------------------------------------------
//-------------------------------------------------------------------------------
//-- Definition of Generics :
//-------------------------------------------------------------------------------
//-- UART Lite generics
//--  C_RATIO               -- The ratio between clk and the asked baudrate
//--                           multiplied with 16
//-------------------------------------------------------------------------------
//-------------------------------------------------------------------------------
//-- Definition of Ports :
//-------------------------------------------------------------------------------
//-- System Signals
//--  Clk                   --  Clock signal
//--  Reset                 --  Reset signal
//-- Internal UART interface signals
//--  EN_16x_Baud           --  Enable signal which is 16x times baud rate
//------------------------------------------------------------------------------
module baudrate
#(
	parameter C_RATIO = 48
)
(

   input      Clk,
   input      Reset,
   output reg    EN_16x_Baud

);

function integer width;
	input integer ratio;
	integer i;
	begin
	i = 31 ;
	while((ratio[i]>0)&&(i>0))
	begin
		i= i-1;
	end

	width = i;	
end
endfunction 

localparam WIDTH = width(C_RATIO)+1;

reg	 [WIDTH-1:0] count ;//

   always @(posedge Clk)
   begin: COUNTER_PROCESS
      
      begin
         if (Reset == 1'b1)
         begin
            count <= 0;
            EN_16x_Baud <= 1'b0;
         end
         else if (count == 0)
			begin
               count <= C_RATIO - 1;
               EN_16x_Baud <= 1'b1;
            end
         else
            begin
               count <= count - 1;
               EN_16x_Baud <= 1'b0;
            end
      end
   end


endmodule
