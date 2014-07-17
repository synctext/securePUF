`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    09:03:50 07/09/2014 
// Design Name: 
// Module Name:    testUF 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: In test mode trigger is given as negative test fsm clock
// so that we get data on every clock cycle.
//
//////////////////////////////////////////////////////////////////////////////////
module testPUF #(
	parameter N_CB = 32,
	parameter CHALLENGE_WIDTH = 32,
	parameter PDL_CONFIG_WIDTH = 128,
	parameter RESPONSE_WIDTH = 6)(
	//Siam's ports
	input wire clk_1, // main clock for FSM
	input wire clk_2, // its freq is half that of clk_1, for the test 1.2 and 1.3 testing block will receive one input bit for two resonse bits from PUF
	input wire clk_RNG, // its freq is 8 times that of clk_1, challenge bits are generated at a higher rate
	input wire rst,
	input wire start, // connect this to a push button
	input wire sw,
	output reg mem_we, // write enable for memory
	output reg [12:0] mem_waddr, // write address for memory
	output reg [7:0] mem_din, // data in for memory
	//output wire [7:0] test_result,
	 
	 //Praveen's ports
	input wire clk,
	input wire reset,
	input wire calb_trigger,
	input wire [CHALLENGE_WIDTH-1:0] pc_challenge,
	input wire [PDL_CONFIG_WIDTH-1:0] pdl_config,
	output wire done,
	output wire [RESPONSE_WIDTH-1:0] raw_response,
	//output wire xor_response,
	
	// Other ports for integration
	input wire calibrate,  //Puf mode - calib or test
	input wire test_start, // To start the test FSM.
	output reg test_done,  //To tell SIRC FSM, test is done. They are using different clocks. 
   output reg [7:0] LED
	 );
	 
	 wire [N_CB-1:0] C;
	 reg [N_CB-1:0] gen_challenge;
	 wire [CHALLENGE_WIDTH-1:0] puf_challenge;
	 wire trigger;
	 wire test_trigger;
	 
	 
	 (* KEEP = "TRUE" *) (* S = "TRUE" *) wire xor_response;
	 
// Choose challenge source based on mode

	assign puf_challenge[CHALLENGE_WIDTH-1:0] = (calibrate==1) ? pc_challenge : gen_challenge[CHALLENGE_WIDTH-1:0];

///////////		Challenge generator		////////////
	 challenge_gen #(N_CB) challenge_gen(
    .clk(clk_RNG),
	 .rst(rst),
    .C(C)
    );

//////////			Core PUF 			/////////////////
mapping #(
		.CHALLENGE_WIDTH(32),
		.PDL_CONFIG_WIDTH(128),
		.RESPONSE_WIDTH(6)
	) puf_map (
		.clk(clk),
		.reset(reset),
		.trigger(trigger),
		.pdl_config(pdl_config),
		.challenge(puf_challenge),
		.done(done),
		.raw_response(raw_response),
		.xor_response(xor_response)
	);
	 
///////////		trigger generator		////////////	

	assign trigger = (calibrate == 1)?calb_trigger:test_trigger;

	/*
	BUFGMUX_CTRL mux_trigger (
	.O(trigger), // 1-bit output: Clock output
	.I0(test_trigger), // 1-bit input: Clock input (S=0)
	.I1(calb_trigger), // 1-bit input: Clock input (S=1)
	.S(calibrate) // 1-bit input: Clock select
	);*/
	 
	wire clk_test;
	reg sel_clk_test;
	
///////////		Clocks generator		////////////	
	BUFGMUX_CTRL mux_clk_test (
	.O(clk_test), // 1-bit output: Clock output
	.I0(clk_1), // 1-bit input: Clock input (S=0)
	.I1(clk_2), // 1-bit input: Clock input (S=1)
	.S(sel_clk_test) // 1-bit input: Clock select
	);
	 
	reg test_data;
	wire response;
	reg tempCount;
	wire [7:0] test_result;
	
///////////			NIST			////////////
	NIST NIST(
	.clk(clk_test),
	.rst(rst),
	.rand(test_data),
	.test_result(test_result)
	);
	
	reg [14:0] resp_bit_count; // count no of bits for tests; 
	reg [7:0] test_count; // no of testing rounds
	reg [7:0] test1, test2, test3, test4, test5, test6, test7, test8; // count how many times each test passes
	reg [4:0] test_index;
	
	reg [4:0] state;
	reg [3:0] clockCount;
	
	 assign test_trigger = ~clk_1;
	 /*
	 always @(posedge clk_1) begin		
			test_trigger <= ~test_trigger;
	 end
	 */
	 
	 always @(posedge clk_1) begin 
	 
		 if (rst) begin
			state <= 0;
		 end
		 else begin
			case (state)
			
			0:	begin		
				mem_we <= 1; 
				mem_waddr <= 0;
				test_done <= 0; // Edit
				clockCount <= 0;
				
				if (test_start) begin // push button // Edit
					state <= 1;
					//LED <= 8'b00000000;
					//if(sw) state <= 1; // dip switch
					//else state <= 5; // calibration starts at this state 
				end
				else state <= 0;
				end
			
			1:	begin
				// init
				resp_bit_count<= 0; 
				test_count <= 0; 
				test1 <= 0; 
				test2 <= 0; 
				test3 <= 0; 
				test4 <= 0;
				test5 <= 0; 
				test6 <= 0; 
				test7 <= 0; 
				test8 <= 0; 
				test_index <= 0;
							
				sel_clk_test <= 0; // for test 1.1 one response bit is generated per challenge, testing block operates at the same freq as the FSM
				
				gen_challenge <= C; // feed challenge
				
				LED <= 8'b10101010;
				
				state <= 2;
				clockCount <= 0;
				end
				
			2:	begin			
				gen_challenge <= C; // feed challenge
				test_data <= xor_response; // read response and feed that to testing block
				resp_bit_count <= resp_bit_count+1; // count response bits
				LED <= 8'b00110011;
				
				if (resp_bit_count == 19999) state <= 3; // one round of testing is done, go to next state and read test results
				else state <= 2;
				
				end
				
			3: begin
				gen_challenge <= C; // feed challenge, while we are reading the test results, we should keep on testing
				test_data <= xor_response; // read response and feed that to testing block
				resp_bit_count <= 0; // reset bit count for next round of testing
				
				LED <= test_result;
				
				
				// add the results
				test1 <= test1 + test_result[0];
				test2 <= test2 + test_result[1];
				test3 <= test3 + test_result[2];
				test4 <= test4 + test_result[3];
				test5 <= test5 + test_result[4];
				test6 <= test6 + test_result[5];
				test7 <= test7 + test_result[6];
				test8 <= test8 + test_result[7];
				
				test_count <= test_count + 1;	// count the no of testing rounds		
				if (test_count==254) state <= 4;  // testing done for the first phase, go to next state to store the test results
				else state <= 2; // keep on testing
				end
				
			4:	begin
				gen_challenge <= C; // feed challenge
				test_data <= xor_response; // read response and feed that to testing block
				
				mem_waddr <= mem_waddr + 1;
				test_index <= test_index + 1;
				if (test_index == 0) mem_din <= test1;
				else if (test_index == 1) mem_din <= test2;
				else if (test_index == 2) mem_din <= test3;
				else if (test_index == 3) mem_din <= test4;
				else if (test_index == 4) mem_din <= test5;
				else if (test_index == 5) mem_din <= test6;
				else if (test_index == 6) mem_din <= test7;
				else if (test_index == 7) mem_din <= test8;
				
				if (test_index == 7) state <= 15; // storing test results is done, go to last state 
				else state <= 4; // keep on stroing test results
				
				end
				
			15:begin
				gen_challenge <= C; // feed challenge
				test_data <= xor_response; // read response and feed that to testing block
				
				mem_we <= 0; // now we read the results from memory
				state <= 15;	
				test_done <= 1; // To tell SircHandler to start writing to PC.
				end
			
			endcase
		 end
		
	end


endmodule
