// CLKS_PER_BIT = (Frequency of i_Clock)/(Frequency of UART)
// Example: 10 MHz Clock, 115200 baud UART
// (10000000)/(115200) = 87
  
module uart1
  (
   input        i_Clock,
   input [0:7]  data,
   input        start,
   output       w_o_Tx_Serial,
   output wire  end_of_transmit
   );
  
  parameter CLKS_PER_BIT   = 867;
  parameter s_IDLE         = 3'b000;
  parameter s_TX_START_BIT = 3'b001;
  parameter s_TX_DATA_BITS = 3'b010;
  parameter s_TX_STOP_BIT  = 3'b011;
  
  reg          o_Tx_Serial   = 0;
  reg [2:0]    r_SM_Main     = 0;
  reg [20:0]   r_Clock_Count = 0;
  reg [3:0]    r_Bit_Index   = 0;
  reg          flag          = 1;
  
  assign w_o_Tx_Serial = o_Tx_Serial;
  assign end_of_transmit = flag;
  
  always @(posedge i_Clock)
    begin
      case (r_SM_Main)
        s_IDLE :
          begin
            o_Tx_Serial   <= 1'b1;         // Drive Line High for Idle
            r_Clock_Count <= 0;
            r_Bit_Index   <= 0;
            if (start) r_SM_Main <= s_TX_START_BIT;
          end // case: s_IDLE
         
         
        // Send out Start Bit. Start bit = 0
        s_TX_START_BIT :
          begin
            o_Tx_Serial <= 1'b0;
             
            // Wait CLKS_PER_BIT-1 clock cycles for start bit to finish
            if (r_Clock_Count < CLKS_PER_BIT-1)
              begin
                r_Clock_Count <= r_Clock_Count + 1;
              end
            else
              begin
                r_Clock_Count <= 0;
                r_SM_Main     <= s_TX_DATA_BITS;
		flag = !flag;
              end
          end // case: s_TX_START_BIT
         
         
        // Wait CLKS_PER_BIT-1 clock cycles for data bits to finish         
        s_TX_DATA_BITS :
          begin
            o_Tx_Serial <= data[r_Bit_Index];
             
            if (r_Clock_Count < CLKS_PER_BIT-1)
              begin
                r_Clock_Count <= r_Clock_Count + 1;
              end
            else
              begin
                r_Clock_Count <= 0;
                 
                // Check if we have sent out all bits
                if (r_Bit_Index < 7)
                  begin
                    r_Bit_Index <= r_Bit_Index + 1;
                  end
                else
                  begin
						  r_Bit_Index <= 0;
                    r_SM_Main   <= s_TX_STOP_BIT;
                  end
              end
          end // case: s_TX_DATA_BITS
         
         
        // Send out Stop bit.  Stop bit = 1
        s_TX_STOP_BIT :
          begin
            o_Tx_Serial <= 1'b1;
             
            // Wait CLKS_PER_BIT-1 clock cycles for Stop bit to finish
            if (r_Clock_Count < CLKS_PER_BIT-1)
              begin
                r_Clock_Count <= r_Clock_Count + 1;
              end
            else
              begin
                r_Clock_Count <= 0;
                r_SM_Main     <= s_IDLE;
		flag = !flag;
              end
          end // case: s_Tx_STOP_BIT
             
        default :
          r_SM_Main <= s_TX_START_BIT;
         
      endcase
    end
 
   
endmodule

module adxl
  (
   input  i_Clock,
   output o_Tx_Serial,
	output miso_l,	
	output mosi_l,
	output clk_l,
	
	
	input miso,
	output wire mosi,
	output wire spi_clk,
	output wire cs
   );
	
	wire end_of_transmit;
	wire[7:0] spi_out;
	reg[1:0] start_spi = 0;
	reg[15:0] adder = 0;
	wire[7:0] uart_data;
	reg[7:0] r_uart_data;

	reg r_start_uart = 0;
	wire start_uart;	
	assign start_uart = r_start_uart;
	
	parameter idle = 0, spi1 = 1, spi_wait1 = 2, spi_wait0 = 3, 
			spi2 = 4, spi_wait2 = 5,
			uart = 6, uart_wait1 = 7, uart_wait2 = 8,
			control = 9, control_wait1 = 10, control_wait2 = 11, spi2_wait = 12;
	reg[4:0] state = 0; 
	
	always @(posedge i_Clock) begin
		case (state)
		idle:
		begin
			r_uart_data <= spi_out;
			r_start_uart <= 0;
			start_spi <= 2'b00;
			state <= spi1;
			if (adder == 16'h2d08) adder <= 16'h310b;
			else                   adder <= 16'h2d08;
		end
		spi1:
		begin
			r_uart_data <= spi_out;
			start_spi <= 2'b10;
			state <= spi_wait0;
		end
		spi_wait0:
		begin
			r_uart_data <= spi_out;
			if (!cs) state <= spi_wait1;
		end
		spi_wait1:
		begin
			r_uart_data <= spi_out;
			if (cs) begin
				start_spi <= 2'b00;
				if (adder == 16'h2d08) state <= idle;	
				else begin
					adder <= 8'hb2;
					state <= spi2_wait;
				end
			end
		end
		spi2_wait:
		begin
			state <= spi2;
		end
		spi2:
		begin
			r_uart_data <= spi_out;
			start_spi <= 2'b01;
			state <= spi_wait2;
		end
		spi_wait2:
		begin
			r_uart_data <= spi_out;
			if (cs == 0) begin
				start_spi <= 2'b00;
				state <= uart;
			end	
		end
		uart:
		begin
			r_uart_data <= spi_out;
			if (cs) begin
				state <= uart_wait1;
				r_start_uart <= 1;
			end
		end
		uart_wait1:
			if (!end_of_transmit) begin
				r_start_uart <= 0;
				state <= uart_wait2;
			end
		uart_wait2:
			if (end_of_transmit) begin
				if (adder == 8'hb7) begin adder <= 8'hb2; state <= control; end
				else begin adder <= adder + 1; state <= spi2; end
			end
		control:
		begin
			r_uart_data <= 8'hCC;
			r_start_uart <= 1;
			state <= control_wait1;
		end
		control_wait1:
		begin
			r_uart_data <= 8'hCC;
			if (!end_of_transmit) begin
				r_start_uart <= 0;
				state <= control_wait2;
			end
		end
		control_wait2:
		begin
			r_uart_data <= 8'hCC;
			if (end_of_transmit) state <= spi2;
		end
		default:
			state <= state;
		endcase
	end
	
	assign uart_data = r_uart_data; 
	
	uart1 uartik(
		.i_Clock(i_Clock), 
		.start(start_uart),
		.w_o_Tx_Serial(o_Tx_Serial), 
		.data(uart_data), 
		.end_of_transmit(end_of_transmit)
		);

	spi ewfsdg
	(
		.clk(i_Clock),
		.go(start_spi),
		.data(adder),
		.out(spi_out),
		.cs(cs),
		.spi_clk(spi_clk),
		.miso(miso),
		.mosi(mosi)
	);

	//assign miso_l = miso;
	//assign mosi_l = mosi;
	//assign clk_l = spi_clk;
	
endmodule


module spi
(
	input clk,
	input[1:0] go,
	input[0:15] data,
	output[7:0] out,

	input miso,
	output mosi,
	output wire cs,
	output spi_clk
);
reg[7:0] r_out = 0;
reg[3:0] index = 4'b1111;
reg[3:0] buff = 0;

wire sys_clk;
reg r_sys_clk = 0;
reg[12:0] clk_i = 0; 
always @(posedge clk) begin
	clk_i <= clk_i + 1;
	if (clk_i == 13'b1111100000000) begin
		r_sys_clk <= !r_sys_clk;
		clk_i <= 0;
	end
end
assign sys_clk = (r_sys_clk == 0);


parameter idle = 0, write_load = 1, write = 2, wait1 = 3, wait2 = 4, read = 5,
		    write_load_1 = 6, write_1 = 7, wait1_1 = 8, wait1_2 = 9;
reg[3:0] state = 0; 

always @(negedge spi_clk)
	case (state)
	write:
		if (index == 4'b0111) index <= 4'b0000;
		else index <= index + 1;
	read:
		if (index == 4'b0111) index <= 4'b0000;
		else index <= index + 1;
	write_1:
		index <= index + 1;
	wait1_1:
		index <= index + 1;
	wait1_2:
		index <= 4'b1111;
	default:
		index <= 4'b1111;
	endcase

always @(posedge sys_clk) begin
	case (state)
	idle:
	begin
		if (go == 2'b01) begin state <= write_load;   buff <= 4'b1000; end
		if (go == 2'b10) begin state <= write_load_1; buff <= 4'b0000; end
	end
	write_load:
	begin
		state <= write;
	end
	write:
	begin
		if (index == 4'b0111) state <= wait1;
	end
	wait1:
	begin
		 state <= read;
		 r_out[index] <= miso;
	end
	read:
	begin
		r_out[index] <= miso;
		if (index == 4'b0111) state <= idle;
	end	
	write_load_1:
	begin
		state <= write_1;
	end
	write_1:
	begin
		if (index == 4'b1110) state <= wait1_1;
	end
	wait1_1:
		state <= wait1_2;
	default:
		state <= idle;
	endcase
end

assign out = r_out;
assign cs = state == idle ? 1 : 0;
assign spi_clk = (state == write || state == read || state == write_1 || state == wait1_1) ? sys_clk  : 1'b1;
assign mosi = (state == write_load_1 || state == write_1 || state == wait1_1 || state == write_load || state == write || state == wait1 || state == wait1_1 || state == wait1_2) ? data[index + buff] : 1'bz;
endmodule
