// PZC with the pedestal tracking and accumulator correction
module pzc_ped_track
#(
	parameter NBITS_IN  = 12,           // Bits of the input signal
	parameter NBITS_OUT = 28,           // Bits of the pzc output
	parameter M_FACTOR  = 454,          // M factor of the PZC
	parameter K_CORR = 2**4,		    // Defines how many negative values will enter before corrects the accumulator
	parameter PED_CORR = 13,		    // Defines when to check if the pedestal compensation will be checked
	//parameter PED_CORR = 2**4,    	// Defines when to check if the pedestal compensation will be checked
	parameter BT_NUM = 16,              // Number of bt masks zeros to identify the long gap
	parameter SHIFT_PZC = 9,             // Shift to convert PZC to 13 bits
	parameter NBITS_SUM = 28
)
(
	//Clock and reset signals
	input                              clk, rst,
	//Mask of the Bunch Train pattern
	input					bt_mask_out,
	//Input (shaper)
	input   signed    [NBITS_IN  -1:0] in,
	//Pedestal compensation
	output reg signed [NBITS_IN  -1:0] pedestal = 0,
	//PZC output
//	output signed    [NBITS_OUT -1:0] io_out,
	//PZC output 13b
	output signed [NBITS_OUT-1:0] pzc_out
);

// io_out used as wire now, to avoid bit error
wire signed    [NBITS_SUM -1:0] io_out;

reg enable_acc_corr = 1'd1; //Enable the accumulator correction
reg enable_ped = 1'd1;      //Enable the pedestal compensation correction 
reg enable_diverge = 1'd1;  //Flag to define if diverges

reg signed [NBITS_SUM -1:0] out_delay = 0;// accumulator;

reg [20:0] cont1 = 0;  // number of negative samples
reg [20:0] cont2 = 0;  // number of postitive samples
reg [20:0] cont_bt = 0;// number of zero samples of the bunch train pattern mask


reg signed [NBITS_SUM+K_CORR - 1:0] soma = 0;       //sum of positive values
reg signed [NBITS_SUM+PED_CORR- 1:0] soma2 = 0;     //sum of values to correct the accumulator of pedestal compensation
reg signed [NBITS_SUM -1:0] m_out = 0;              //accumulator correction for negative values
//********I THINK IT IS NOT USED ANYMORE*****
reg signed [NBITS_SUM -1:0] ped_reg_out = 0;        //Value to corrects the accumulator when the pedestal compensation changes
//*******************************************
reg signed [NBITS_SUM -1:0] ped_reg_out_corr = 0;   //Value to corrects the accumulator when the pedestal compensation changes
reg signed [NBITS_SUM -1:0] io_out_delay = 0;       //save the previous output
//Signals used to check if there is a ramp at the PZC output
reg signed [NBITS_SUM -1:0] first_sample = 0;       //First sample in the long gap
reg signed [NBITS_SUM+6 -1:0] diff_last = 0;        //Difference between future and first sample of long gap


//********I THINK IT IS NOT USED ANYMORE*****
wire [NBITS_SUM-1:0] diff;
assign diff = (cont_bt > BT_NUM) ? io_out - io_out_delay : 0;
//*******************************************


always @(posedge clk or posedge rst) 
begin
	if(rst) begin //starting all registers
		out_delay <= 0;
		cont1 <= 0;
		cont2 <= 0;
		cont_bt <= 0;
		pedestal <= 0;
		ped_reg_out <= 0;
		ped_reg_out_corr <= 0;
		enable_acc_corr <= 1'd1;
		io_out_delay <= 0;
		soma2 <= 0;
		enable_ped <= 1;
		first_sample <= 0;
		diff_last <= 0;
		enable_diverge <= 1'd1;
	end
	else
	begin
		//Accumulator
		out_delay <= (in-pedestal) + out_delay - m_out - ped_reg_out_corr;
		
		//Check if the mask is zero
		if (bt_mask_out == 0) begin         
			cont_bt <= cont_bt + 1'd1;       // increment the counter to identify the long gap
		end
		else begin
			cont_bt <= 0;                    // start over the counter to identify the long gap
		end
		
		
		if(cont_bt >= BT_NUM) begin                  //Check if is in a long gap
			//********I THINK IT IS NOT USED ANYMORE*****
			if(cont_bt == BT_NUM + K_CORR + 6) begin
				io_out_delay <= io_out;
				
				
				if (enable_diverge && (io_out - io_out_delay) > 1000) begin
					ped_reg_out <= in + out_delay - m_out;
					out_delay <= -(in-pedestal)*M_FACTOR;
					enable_diverge <= 1'd0;
				end
				else begin
					ped_reg_out <= 0;
					enable_diverge <= 1'd1;
				end
				
			end
			//*******************************************
			
			
			//Check if is the first sample of long gap
			if(cont2 == 0) begin
				first_sample <= io_out; //save the sample
			end
			
			
			//Check if the output is negative
			if (io_out < 0) begin
				cont1 <= cont1 + 1'd1; //increment the register of number of negative values
				soma <= soma + io_out; //used to correct the accumulator
			end
			
			//Check if the pedestal correction is activated in the process
			if (enable_ped) begin
				cont2 <= cont2 + 1'd1;   //increment the register of number of values of pedestal correction
				soma2 <= soma2 + io_out; //used to correct the accumulator
			end
			else begin //reset values if is not activated
				soma2 <= 0;
				cont2 <= 0;
			end
			
			//Check if the accumulator correction with negative values of pzc output is activated
			if (enable_acc_corr) begin
				//Check if it is time to correct the accumulator
				if (cont1 == K_CORR) begin           
					m_out <= soma >>> $clog2(K_CORR); //corrects the accumulator
					//Zeroing the signals
					cont1 <= 0;
					soma <= 0;
					enable_ped <= 0;
					enable_diverge <= 0;
				end
				else begin
					m_out <= 0; //zeroing to the process continues
					enable_diverge <= 1'd1;
				end
			end
			else begin
				m_out <= 0; //zeroing to the process continues
			end
			
			//Check if it is time to verify if there is a ramp
			if (cont2 == PED_CORR) begin
				//Difference between the present sample and the first sample of long gap
				diff_last <= io_out - first_sample;
			end
			else begin
				diff_last <= 0; //reset the diffence to continue the process
			end
			
			//Check if there is a raising ramp
			if (diff_last > PED_CORR*5 && soma2 > 0) begin
				//Blocks others corrections
				enable_acc_corr <= 0;
				enable_ped <= 0;
				enable_diverge <= 0;
				//Increment pedestal compensation
				pedestal <= pedestal + 1'd1;
				//Zeroing signals to the process
				diff_last <= 0;
				first_sample <= 0;
				//Corrects the accumulator to not diverge
				ped_reg_out_corr <= soma2 >>> $clog2(K_CORR);
				
			end
			else begin
				//Check if there is a falling ramp
				if (diff_last < -PED_CORR*5 && soma2 < 0) begin
					//Blocks others corrections
					enable_acc_corr <= 0;
					enable_ped <= 0;
					enable_diverge <= 0;
					//Decrement pedestal compensation
					pedestal <= pedestal - 1'd1;
					//Zeroing signals to the process
					diff_last <= 0;
					first_sample <= 0;
					//Corrects the accumulator to not diverge
					ped_reg_out_corr <= soma2 >>> $clog2(K_CORR);
				end
				//Almost flat ramp
				else begin
					ped_reg_out_corr <= 0;
					enable_diverge <= 1'd1;
				end

			end
			
			

		end
		//Zeroing all signals to continue the process
		else begin
			cont1 <= 0;
			cont2 <= 0;
			soma <= 0;
			m_out <= 0;
			ped_reg_out <= 0;
			enable_acc_corr <= 1'd1;
			ped_reg_out_corr <= 0;
			soma2 <= 0;
			enable_ped <= 1'd1;
			first_sample <= 0;
			diff_last <= 0;
			enable_diverge <= 1'd1;
		end
		
	end
end

//PZC output
assign io_out = (in - pedestal) + out_delay + M_FACTOR * (in - pedestal);

//PZC 13 bits output
assign pzc_out = io_out >>> SHIFT_PZC;

endmodule