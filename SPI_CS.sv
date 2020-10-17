module SPI_CS
  #(parameter SPI_MODE = 0,
    parameter CLKS_PER_HALF_BIT = 2,
    parameter MAX_BYTES_PER_CS = 2,
    parameter CS_INACTIVE_CLKS = 1)
  (
   // Control/Data Signals,
   input reset,    
   input system_clk,       
   
   // TX (MOSI) Signals
   input [$clog2(MAX_BYTES_PER_CS+1)-1:0] i_TX_Count,  
   input [7:0]  TX_Byte,       
   input        TX_valid,         
   output       TX_start,      
   
   // RX (MISO) Signals
   output reg [$clog2(MAX_BYTES_PER_CS+1)-1:0] o_RX_Count,  
   output       RX_valid,     
   output [7:0] RX_Byte,  

   // SPI Interface
   output SPI_Clk,
   input  SPI_MISO,
   output SPI_MOSI,
   output o_SPI_CS_n
   );

  localparam IDLE        = 2'b00;
  localparam TRANSFER    = 2'b01;
  localparam CS_INACTIVE = 2'b10;

  reg [1:0] r_SM_CS;
  reg r_CS_n;
  reg [$clog2(CS_INACTIVE_CLKS)-1:0] r_CS_Inactive_Count;
  reg [$clog2(MAX_BYTES_PER_CS+1)-1:0] r_TX_Count;
  wire w_Master_Ready;

// calling SPI without Chip select
  SPI
    #(.SPI_MODE(SPI_MODE),
      .CLKS_PER_HALF_BIT(CLKS_PER_HALF_BIT)
      ) SPI_Master_Inst
   (
   .reset(reset),     
   .system_clk(system_clk),         
   
   // Transmitter (MOSI) Signals
   .TX_Byte(TX_Byte),         
   .TX_valid(TX_valid),              
   .TX_start(w_Master_Ready),   
   
   //Receiver (MISO) Signals
   .RX_valid(RX_valid),       
   .RX_Byte(RX_Byte),   

   // SPI Interface
   .SPI_Clk(SPI_Clk),
   .SPI_MISO(SPI_MISO),
   .SPI_MOSI(SPI_MOSI)
   );

  // Purpose: Control CS line using State Machine
  always @(posedge system_clk or negedge reset)
  begin
    if (~reset)
    begin
      r_SM_CS <= IDLE;
      r_CS_n  <= 1'b1;   
      r_TX_Count <= 0;
      r_CS_Inactive_Count <= CS_INACTIVE_CLKS;
    end
    else
    begin

      case (r_SM_CS)      
      IDLE:
        begin
          if (r_CS_n & TX_valid) // Start of transmission
          begin
            r_TX_Count <= i_TX_Count - 1; 
            r_CS_n     <= 1'b0;       
            r_SM_CS    <= TRANSFER;   
          end
        end

      TRANSFER:
        begin
          // Wait until SPI is done transferring do next thing
          if (w_Master_Ready)
          begin
            if (r_TX_Count > 0)
            begin
              if (TX_valid)
              begin
                r_TX_Count <= r_TX_Count - 1;
              end
            end
            else
            begin
              r_CS_n  <= 1'b1; // we done, so set CS high
              r_CS_Inactive_Count <= CS_INACTIVE_CLKS;
              r_SM_CS             <= CS_INACTIVE;
            end 
          end
        end

      CS_INACTIVE:
        begin
          if (r_CS_Inactive_Count > 0)
          begin
            r_CS_Inactive_Count <= r_CS_Inactive_Count - 1'b1;
          end
          else
          begin
            r_SM_CS <= IDLE;
          end
        end

      default:
        begin
          r_CS_n  <= 1'b1; // we done, so set CS high
          r_SM_CS <= IDLE;
        end
      endcase 
    end
  end 

  // Purpose: Keep track of RX_Count
  always @(posedge system_clk)
  begin
    begin
      if (r_CS_n)
      begin
        o_RX_Count <= 0;
      end
      else if (RX_valid)
      begin
        o_RX_Count <= o_RX_Count + 1'b1;
      end
    end
  end

  assign o_SPI_CS_n = r_CS_n;
  assign TX_start  = ((r_SM_CS == IDLE) | (r_SM_CS == TRANSFER && w_Master_Ready == 1'b1 && r_TX_Count > 0)) & ~TX_valid;

endmodule 