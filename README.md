# SPI-Protocol
I intend to work on to  demonstrate the SPI protocol with 8-bit data transfer with chip or slave select for 1-Master and 1-slaves system using system verilog.  
Basic description:
I have implemented the SPI protocol with chip select or slave select for this week , it means it has one slave only and master has access to control over the data transfer to slave but at the same time slave can also send 8-bit data to master, hence it is full duplex communication. I also tried to implement the CPHA & CPOL and the output for MODE =1 & 3 is coming fine but for 0 & 2 last bit is missing in serial communication due to precision at timing waveform, even though the code is running fine for 2-Modes which makes it complete for data transfer as only 1 mode out of 4 should be present in hardware and 2 are working for me , hence it is achieved. 


I have used Questasim to verify the output & code coverage achieved above 90%  with assertions check
