module SPI
#(parameter SPI_MODE = 0, parameter CLKS_PER_HALF_BIT = 2)
(
   input reset,       // input Reset
   input system_clk,  // input Clock
   
   // TX (MOSI)
   input [7:0]  TX_Byte,        // Master sends this Data byte on MOSI line
   input TX_valid,             // Master Data Valid Pulse 
   output reg TX_start,       // Transmit Ready for next byte
   
   // RX (MISO) 
   output reg       RX_valid,  // Slave Data Valid pulse (1 clock cycle)
   output reg [7:0] RX_Byte,   // Byte received on MISO

   //SPI Interface
   output reg SPI_Clk,
   input      SPI_MISO,
   output reg SPI_MOSI
   );
   
/* SPI Terminology
CPOL: Clock Polarity
CPOL=0 means clock idles at 0, leading edge is rising edge.
CPOL=1 means clock idles at 1, leading edge is falling edge.
  
CPHA: Clock Phase
CPHA=0 means the "out" side changes the data on trailing edge of clock
             the "in" side captures data on leading edge of clock
CPHA=1 means the "out" side changes the data on leading edge of clock
             the "in" side captures data on the trailing edge of clock 
			 
			 Mode | Clock Polarity (CPOL/CKP) | Clock Phase (CPHA)
              0   |             0             |        0    x
              1   |             0             |        1    y
              2   |             1             |        0    x
              3   |             1             |        1    y 
			  My code is working for Mode 1 & 3 fine */
  
  wire CPOL;     // Clock polarity
  wire CPHA;     // Clock phase

// Defined Registers
  reg [$clog2(CLKS_PER_HALF_BIT*2)-1:0] SPI_clk_count;
  reg r_SPI_Clk;
  reg [4:0] SPI_clk_edges;
  reg Leading_Edge;
  reg Trailing_Edge;
  reg       r_TX_valid;
  reg [7:0] r_TX_Byte;

  reg [2:0] RX_Bit_Count;
  reg [2:0] TX_Bit_Count;

  assign CPOL  = (SPI_MODE == 2) | (SPI_MODE == 3);
  assign CPHA  = (SPI_MODE == 1) | (SPI_MODE == 3);
  
//Generation of SPI_Clk for 16 edges( 8-posedge & 8-negedge) after receiveing TX_Valid
always @(posedge system_clk or negedge reset)
  begin
    if (~reset)
		begin
		TX_start      <= 1'b0;
		SPI_clk_edges <= 0;
		Leading_Edge  <= 1'b0;
		Trailing_Edge <= 1'b0;
		r_SPI_Clk       <= CPOL; // assign default state to idle state
		SPI_clk_count <= 0;
    end
    
	else
		begin
		Leading_Edge  <= 1'b0;
		Trailing_Edge <= 1'b0;
      
		if (TX_valid)
			begin
			TX_start      <= 1'b0;
			SPI_clk_edges <= 16;  // Total # edges in one byte ALWAYS 16
		end
		
		else if (SPI_clk_edges > 0)
			begin
			TX_start <= 1'b0;
        
				if (SPI_clk_count == CLKS_PER_HALF_BIT*2-1)
					begin
					SPI_clk_edges <= SPI_clk_edges - 1;
					Trailing_Edge <= 1'b1;
					SPI_clk_count <= 0;
					r_SPI_Clk <= ~r_SPI_Clk;
				end
        
				else if (SPI_clk_count == CLKS_PER_HALF_BIT-1)
					begin
					SPI_clk_edges <= SPI_clk_edges - 1;
					Leading_Edge  <= 1'b1;
					SPI_clk_count <= SPI_clk_count + 1;
					r_SPI_Clk <= ~r_SPI_Clk;
				end
       
				else
					begin
					SPI_clk_count <= SPI_clk_count + 1;
				end
			end  
     
		else
			begin
			TX_start <= 1'b1;
		end
      
     end 
end  


//store the Data send by Master from test bench into a local register:-> r_TX_Byte
always @(posedge system_clk or negedge reset)
begin
		if (~reset)
			begin
		r_TX_Byte <= 8'h00;
		r_TX_valid  <= 1'b0;
		end
			
		else
			begin
		r_TX_valid <= r_TX_valid; 
				if (r_TX_valid)
				begin
				r_TX_Byte <= r_TX_Byte;
				end
		end 
end 
  
  
//send data into MOSI LINE , Works for only two CPOL AND CPHA
always @(posedge system_clk or negedge reset)
begin
    if (~reset)
		begin
		SPI_MOSI     <= 1'b0;
		TX_Bit_Count <= 3'b111; // send MSb first
    end
    
	else
		begin
			if (TX_start)
				begin
			TX_Bit_Count <= 3'b111;
	        end
  
           // Catch the case where we start transaction and CPHA = 0
            else if (r_TX_valid & ~CPHA)
				begin
			SPI_MOSI     <= TX_Byte[3'b111];
			TX_Bit_Count <= 3'b110;
			end
      
			else if ((Leading_Edge & CPHA) | (Trailing_Edge & ~CPHA))
				begin
			TX_Bit_Count <= TX_Bit_Count - 1;
			SPI_MOSI     <= TX_Byte[TX_Bit_Count];
			end
    end
 end
  
// Read MISO Line by Master
always @(posedge system_clk or negedge reset)
	begin
		if (~reset)
			begin
			RX_Byte      <= 8'h00;
			RX_valid        <= 1'b0;
			RX_Bit_Count <= 3'b111;
		end
    
	    else
			begin
			RX_valid   <= 1'b0;

			if (TX_start) // Check if start is high, if so reset bit count to default
				begin
				RX_Bit_Count <= 3'b111;
			end
     
			else if ((Leading_Edge & ~CPHA) | (Trailing_Edge & CPHA))
				begin
				RX_Byte[RX_Bit_Count] <= SPI_MISO;  // Sample data
				RX_Bit_Count            <= RX_Bit_Count - 1;
					if (RX_Bit_Count == 3'b000)
					begin
					RX_valid  <= 1'b1;   // Byte done, pulse Data Valid
					end
				end
			end
  end

//assigning register r_SPI_CLK to SPI_Clk
always @(posedge system_clk or negedge reset)
	begin
		if (~reset)
		begin
		SPI_Clk  <= CPOL;
		end
		
		else
		begin
        SPI_Clk <= r_SPI_Clk;
		end 
	end 
  
endmodule // SPI
