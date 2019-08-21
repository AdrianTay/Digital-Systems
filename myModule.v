module myModule (clk, reset,
							red_input, green_input, blue_input, 
							x_pos, y_pos, 
							f_val, d_val,
							data_out1, data_out2, hist_out, cumhist_out,
							grey_check, grey_delayed, 
							yLine25, yLine50, yLine75);
	
	
	input clk, f_val, d_val, reset;
	input	[11:0] red_input, green_input, blue_input;
	input [15:0] x_pos;
	input [15:0] y_pos;
	
	output [15:0] data_out1, data_out2;
	output [19:0] hist_out, cumhist_out; 
	output reg [11:0] grey_check;
	output reg [11:0] grey_delayed;
	output reg [7:0] yLine25, yLine50, yLine75;
	reg [11:0] grey, dgrey;

	always @(posedge clk) begin
		grey <= (red_input + green_input + blue_input)/3;
		grey_check <= grey;
		dgrey <= grey;
		grey_delayed <= dgrey;
	end
	
	assign data_out1 = {grey[11:7],grey[11:2]};
	assign data_out2 = {grey[6:2],grey[11:2]}; 
	
	reg [2:0] state;
	wire [19:0] count_read1;
	reg [19:0] count_write1, count_write2, count_write3, count_write_reg,count_write3_prev;
	reg [10:0] iter;
	reg [7:0] write_add1, write_add2, read_add1, write_add_reg;

	reg hist1_write, hist2_write;

	ram_hist1 calc(.data(count_write1), .read_addr(read_add1), .write_addr(write_add1), .we(hist1_write), .clk(clk), .q(count_read1));
	ram_hist1 disp(.data(count_write2), .read_addr(y_pos), .write_addr(write_add2), .we(hist2_write), .clk(clk), .q(hist_out));
	ram_hist1 cumu(.data(count_write3), .read_addr(y_pos), .write_addr(write_add2), .we(hist2_write), .clk(clk), .q(cumhist_out));
	
	always@(posedge clk)
	begin
		if(!reset)begin
			hist1_write <= 0;
			hist2_write <= 0;
			count_write1 <= 0;
			count_write2 <= 0;
			count_write3 <= 0;
			write_add1 <= 0;
			write_add2 <= 0;
			read_add1 <= 0;
			iter <= 0;
			count_write_reg <= 0;
			write_add_reg <= 0;
			count_write3_prev <= 0;
			state <= 0;
		end
		else begin
			case(state)
				0: begin
						// Clearing Histogram
						hist1_write <= 1;
						hist2_write <= 0;
						write_add1 <= iter;
						count_write1 <= 0;
			
						if(iter == 256) iter <= 0;
						else iter <= iter+1;
						
						if(f_val) begin
							state <= 1;
							iter <= 0;
						end
						else state <= 0;
					end
					
				1: begin
						// Building the Histogram
						hist1_write <= d_val;
						
						write_add1 <= write_add_reg;
						
						if (d_val)begin
							count_write1 <= count_read1 + 1;
							read_add1 <= grey[11:4];
							write_add_reg <= read_add1;		
							if ((write_add1 == write_add_reg))begin
								count_write1 <= count_write1 + 1;
							end
							else if (write_add1 == read_add1) count_write_reg <= count_write1;
							  
							if (count_write_reg != 0)begin
								count_write1 <= count_write_reg + 1;
								if (write_add1 != read_add1) count_write_reg <= 0;   
							end
							
						end
						else begin
							count_write1 <= 0;
							write_add1 <= 0;
							write_add_reg <= 0;
						end

						// Go to the next state
						if(f_val) state <= 1;
						else begin
							state <= 2;
							hist1_write <= 0;
							read_add1 <= 0;
						end
						
					end
					
				2: begin
						// Output all data
						hist1_write <= 0;
						hist2_write <= 1;  //hist2_write = hist3_write
						count_write2 <= count_read1;
						
						if(iter <256)
						begin
							write_add2 <= iter;
							count_write2 <= 0;
							count_write3 <= 0;	
						end
						else begin
						  write_add2 <= read_add1; // write_add3 = write_add2
							read_add1 <= iter-256;
						end
						
						// Incrementing iter, if iter is max then it exits to the next state
						if(iter == 514) begin
							state <= 0;
							iter <= 0;
							hist2_write <= 0;
							
						end
						else iter <= iter+1;
						
						// Cummulative Histogram
						if (hist2_write && iter > 258)begin
						  count_write3 <= count_write3 + count_read1;
						  count_write3_prev <= count_write3;
							// Drawing 25, 50, 75 percentile lines
							if (count_write3_prev < 288000 && count_write3> 288000) yLine75 <= iter - 258;
							else if (count_write3_prev < 192000 && count_write3> 192000) yLine50 <= iter - 258;
							else if (count_write3_prev < 96000 && count_write3> 96000) yLine25 <= iter - 258;							
							else begin
								yLine25 <= yLine25;
								yLine50 <= yLine50;
								yLine75 <= yLine75;
							end
						end
						else count_write3 <= 0;

					end
					
			endcase
		end
	end
			
endmodule



// Quartus II Verilog Template
// Simple Dual Port RAM with separate read/write addresses and
// single read/write clock
module ram_hist1
#(parameter DATA_WIDTH=20, parameter ADDR_WIDTH=8)
(
	input [(DATA_WIDTH-1):0] data,
	input [(ADDR_WIDTH-1):0] read_addr, write_addr,
	input we, clk,
	output reg [(DATA_WIDTH-1):0] q
);


	// Declare the RAM variable
	reg [DATA_WIDTH-1:0] ram[2**ADDR_WIDTH-1:0];

	always @ (posedge clk)
	begin
		// Write
		if (we)
			ram[write_addr] = data;

		// Read (if read_addr == write_addr, return OLD data).	To return
		// NEW data, use = (blocking write) rather than <= (non-blocking write)
		// in the write assignment.	 NOTE: NEW data may require extra bypass
		// logic around the RAM.
		q = ram[read_addr];
	end

endmodule