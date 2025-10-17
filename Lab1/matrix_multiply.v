`timescale 1ns / 1ps

/* 
----------------------------------------------------------------------------------
--	(c) Rajesh C Panicker, NUS
--  Description : Template for the Matrix Multiply unit for the AXI Stream Coprocessor
--	License terms :
--	You are free to use this code as long as you
--		(i) DO NOT post a modified version of this on any public repository;
--		(ii) use it only for educational purposes;
--		(iii) accept the responsibility to ensure that your implementation does not violate any intellectual property of any entity.
--		(iv) accept that the program is provided "as is" without warranty of any kind or assurance regarding its suitability for any particular purpose;
--		(v) send an email to rajesh.panicker@ieee.org briefly mentioning its use (except when used for the course EE4218 at the National University of Singapore);
--		(vi) retain this notice in this file or any files derived from this.
----------------------------------------------------------------------------------
*/

// those outputs which are assigned in an always block of matrix_multiply shoud be changes to reg (such as output reg Done).
// A: M x N, B: N x P, RES: M x P
module matrix_multiply
	#(	parameter width = 8, 			// width is the number of bits per location
		parameter M = 2,	// number of rows in A and RES
		parameter N = 4,	// number of columns in A and number of rows in B
		parameter P = 1		// number of columns in B and RES
	) 
	(
		input clk,										
		input Start,									// myip_v1_0 -> matrix_multiply_0.
		output reg Done = 0,									// matrix_multiply_0 -> myip_v1_0. Possibly reg.
		
		output reg A_read_en = 0,  								// matrix_multiply_0 -> A_RAM. Possibly reg.
		output [$clog2(M*N)-1:0] A_read_address, 		// matrix_multiply_0 -> A_RAM. Possibly reg.
		input [width-1:0] A_read_data_out,				// A_RAM -> matrix_multiply_0.
		
		output reg B_read_en = 0, 								// matrix_multiply_0 -> B_RAM. Possibly reg.
		output [$clog2(N*P)-1:0] B_read_address, 		// matrix_multiply_0 -> B_RAM. Possibly reg.
		input [width-1:0] B_read_data_out,				// B_RAM -> matrix_multiply_0.
		
		output reg RES_write_en = 0, 							// matrix_multiply_0 -> RES_RAM. Possibly reg.
		output [$clog2(M*P)-1:0] RES_write_address, 	// matrix_multiply_0 -> RES_RAM. Possibly reg.
		output [width-1:0] RES_write_data_in 			// matrix_multiply_0 -> RES_RAM. Possibly reg.
	);
	
	// implement the logic to read A_RAM, read B_RAM, do the multiplication and write the results to RES_RAM
	// Note: A_RAM and B_RAM are to be read synchronously. Read the wiki for more details.
	// Initialize Registers for row and column indices
	reg [$clog2(M)-1:0] A_row_idx = 0;
	reg [$clog2(N)-1:0] A_col_idx = 0;
	reg [$clog2(N)-1:0] B_row_idx = 0;
	reg [$clog2(P)-1:0] B_col_idx = 0;

	// Calculate read / write addresses
	assign A_read_address = A_row_idx * N + A_col_idx;
	assign B_read_address = B_row_idx * P + B_col_idx;
	assign RES_write_address = A_row_idx * P + B_col_idx;

	reg [2:0] state = 0;
	reg [2*width-1:0] acc = 0; // accumulator for the dot product
	assign RES_write_data_in = acc;
	localparam IDLE = 0, READ = 1, READ_WAIT = 2, MULT = 3, WRITE = 4, DONE = 5;

always @(posedge clk) begin
	// if (Start) begin
	// 	$display("State: %d, A_row: %d, A_col: %d, B_row: %d, B_col: %d, Acc: %d", state, A_row_idx, A_col_idx, B_row_idx, B_col_idx, acc);
	// end
	case (state)
        IDLE: begin
            if (Start) begin
                A_row_idx <= 0;
                B_col_idx <= 0;
                A_col_idx <= 0;
                B_row_idx <= 0;
                acc <= 0;
                state <= READ;
				RES_write_en <= 0;
				A_read_en <= 0;
				B_read_en <= 0;
            end
            Done <= 0;
        end
        
        READ: begin
			RES_write_en <= 0;
            // set addresses
            A_read_en <= 1;
            B_read_en <= 1;
            // A_read_address <= A_row_idx*N + A_col_idx;
            // B_read_address <= B_row_idx*P + B_col_idx;
            state <= READ_WAIT;  // wait one cycle for data to be valid
        end

		READ_WAIT: begin
            // turn off read enables (optional)
            A_read_en <= 0;
            B_read_en <= 0;
            state <= MULT; // now data_out is valid
        end
        
        MULT: begin
			// $display("A_read_data_out: %d, B_read_data_out: %d", A_read_data_out, B_read_data_out);
			A_read_en <= 0;
			B_read_en <= 0;
            // now multiply valid data
            acc <= acc + (A_read_data_out * B_read_data_out);
			
            if (A_col_idx == N-1) begin
                state <= WRITE;
            end else begin
                A_col_idx <= A_col_idx + 1;
                B_row_idx <= B_row_idx + 1;
                state <= READ; // next pair
            end
        end

        WRITE: begin
            RES_write_en <= 1;
            // RES_write_data_in <= acc;
            // RES_write_address <= A_row_idx * P + B_col_idx;
            acc <= 0;
            // RES_write_en <= 0;
			$display("Writing %d to RES address %d", RES_write_data_in, RES_write_address);
            if (B_col_idx == P-1 && A_row_idx == M-1)
                state <= DONE;
            else if (B_col_idx == P-1) begin // move to next row
                A_row_idx <= A_row_idx + 1;
				A_col_idx <= 0;
				B_row_idx <= 0;
				B_col_idx <= 0;
                state <= READ;
            end else begin // move to next column
                B_col_idx <= B_col_idx + 1;
				A_col_idx <= 0;
				B_row_idx <= 0;
                state <= READ;
            end
        end

        DONE: begin
			RES_write_en <= 0;
            Done <= 1;
            if (!Start) state <= IDLE;
        end
    endcase
end



endmodule


