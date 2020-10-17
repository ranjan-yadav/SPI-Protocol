`include "SPI.sv"
module SPI_CS_TB ();
  parameter SPI_MODE = 3;           
  parameter CLKS_PER_HALF_BIT = 4;  
  parameter MAIN_CLK_DELAY = 2;     
  parameter MAX_BYTES_PER_CS = 2;   
  parameter CS_INACTIVE_CLKS = 10;  
  
  logic reset= 1'b0;  
  logic SPI_Clk;
  logic system_clk= 1'b0;
  logic SPI_CS_n;
  logic SPI_MOSI;

  // Master Specific
  logic [7:0] Master_TX_Byte = 0;
  logic Master_TX_DV = 1'b0;
  logic Master_TX_Ready;
  logic Master_RX_DV;
  logic [7:0] Master_RX_Byte;
  logic [$clog2(MAX_BYTES_PER_CS+1)-1:0] Master_RX_Count, Master_TX_Count = 2'b10;

  always #(MAIN_CLK_DELAY) system_clk  = ~system_clk ;
  
  SPI_CS
  #(.SPI_MODE(SPI_MODE),
    .CLKS_PER_HALF_BIT(CLKS_PER_HALF_BIT),
    .MAX_BYTES_PER_CS(MAX_BYTES_PER_CS),
    .CS_INACTIVE_CLKS(CS_INACTIVE_CLKS)
    ) UUT
  (
   .reset(reset),     
   .system_clk(system_clk),         
   
   // TX (MOSI) Signals
   .i_TX_Count(Master_TX_Count),   
   .TX_Byte(Master_TX_Byte),     
   .TX_valid(Master_TX_DV),         
   .TX_start(Master_TX_Ready),   
   
   // RX (MISO) Signals
   .o_RX_Count(Master_RX_Count),
   .RX_valid(Master_RX_DV),       
   .RX_Byte(Master_RX_Byte),   

   // SPI Interface
   .SPI_Clk(SPI_Clk),
   .SPI_MISO(SPI_MOSI),
   .SPI_MOSI(SPI_MOSI),
   .o_SPI_CS_n(SPI_CS_n)
   );

// cs will be driven on its own
task BYTE_TRANSFER(input [7:0] data);
    @(posedge system_clk );
    Master_TX_Byte <= data;
    Master_TX_DV   <= 1'b1;
    @(posedge system_clk );
    Master_TX_DV <= 1'b0;
    @(posedge system_clk );
    @(posedge Master_TX_Ready);
  endtask 
 
initial
    begin
      repeat(10) @(posedge system_clk );
      reset  = 1'b0;
      repeat(10) @(posedge system_clk );
      reset  = 1'b1;

      BYTE_TRANSFER(8'hC1);
      $display("Sent out 0xc1, Received 0x%X",Master_RX_Byte); 
      BYTE_TRANSFER(8'hC2);
      $display("Sent out 0xc2, Received 0x%X",Master_RX_Byte); 
	  
	  BYTE_TRANSFER(8'hA1);
      $display("Sent out 0xa1, Received 0x%X",Master_RX_Byte); 
      BYTE_TRANSFER(8'hB2);
      $display("Sent out 0xb2, Received 0x%X",Master_RX_Byte); 
	  
	  
      repeat(100) @(posedge system_clk );
      $finish();      
    end // initial begin

endmodule 
