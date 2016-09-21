////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	rxuart.v
//
// Project:	FPGA library
//
// Purpose:	Receive and decode inputs from a single UART line.
//
//
//	To interface with this module, connect it to your system clock,
//	pass it the 32 bit setup register (defined below) and the UART
//	input.  When data becomes available, the o_wr line will be asserted
//	for one clock cycle.  On parity or frame errors, the o_parity_err
//	or o_frame_err lines will be asserted.  Likewise, on a break 
//	condition, o_break will be asserted.  These lines are self clearing.
//
//	There is a synchronous reset line, logic high.
//
//	Now for the setup register.  The register is 32 bits, so that this
//	UART may be set up over a 32-bit bus.
//
//	i_setup[29:28]	Indicates the number of data bits per word.  This will
//	either be 2'b00 for an 8-bit word, 2'b01 for a 7-bit word, 2'b10
//	for a six bit word, or 2'b11 for a five bit word.
//
//	i_setup[27]	Indicates whether or not to use one or two stop bits.
//		Set this to one to expect two stop bits, zero for one.
//
//	i_setup[26]	Indicates whether or not a parity bit exists.  Set this
//		to 1'b1 to include parity.
//
//	i_setup[25]	Indicates whether or not the parity bit is fixed.  Set
//		to 1'b1 to include a fixed bit of parity, 1'b0 to allow the
//		parity to be set based upon data.  (Both assume the parity
//		enable value is set.)
//
//	i_setup[24]	This bit is ignored if parity is not used.  Otherwise,
//		in the case of a fixed parity bit, this bit indicates whether
//		mark (1'b1) or space (1'b0) parity is used.  Likewise if the
//		parity is not fixed, a 1'b1 selects even parity, and 1'b0
//		selects odd.
//
//	i_setup[23:0]	Indicates the speed of the UART in terms of clocks.
//		So, for example, if you have a 200 MHz clock and wish to
//		run your UART at 9600 baud, you would take 200 MHz and divide
//		by 9600 to set this value to 24'd20834.  Likewise if you wished
//		to run this serial port at 115200 baud from a 200 MHz clock,
//		you would set the value to 24'd1736
//
//	Thus, to set the UART for the common setting of an 8-bit word, 
//	one stop bit, no parity, and 115200 baud over a 200 MHz clock, you
//	would want to set the setup value to:
//
//	32'h0006c8		// For 115,200 baud, 8 bit, no parity
//	32'h005161		// For 9600 baud, 8 bit, no parity
//	
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2016, Gisselquist Technology, LLC
//
// This program is free software (firmware): you can redistribute it and/or
// modify it under the terms of  the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or (at
// your option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program.  (It's in the $(ROOT)/doc directory, run make with no
// target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
//
// License:	GPL, v3, as defined and found on www.gnu.org,
//		http://www.gnu.org/licenses/gpl.html
//
//
////////////////////////////////////////////////////////////////////////////////
//
//
// States: (@ baud counter == 0)
//	0	First bit arrives
//	..7	Bits arrive
//	8	Stop bit (x1)
//	9	Stop bit (x2)
///	c	break condition
//	d	Waiting for the channel to go high
//	e	Waiting for the reset to complete
//	f	Idle state
`define	RXU_BIT_ZERO		4'h0
`define	RXU_BIT_ONE		4'h1
`define	RXU_BIT_TWO		4'h2
`define	RXU_BIT_THREE		4'h3
`define	RXU_BIT_FOUR		4'h4
`define	RXU_BIT_FIVE		4'h5
`define	RXU_BIT_SIX		4'h6
`define	RXU_BIT_SEVEN		4'h7
`define	RXU_PARITY		4'h8
`define	RXU_STOP		4'h9
`define	RXU_SECOND_STOP		4'ha
// Unused 4'hb
// Unused 4'hc
`define	RXU_BREAK		4'hd
`define	RXU_RESET_IDLE		4'he
`define	RXU_IDLE		4'hf

module rxuart(i_clk, i_reset, i_setup, i_uart, o_wr, o_data, o_break,
			o_parity_err, o_frame_err, o_ck_uart);
	//  parameter // CLOCKS_PER_BAUD = 25'd004340,
			//  BREAK_CONDITION = CLOCKS_PER_BAUD * 12,
			//  CLOCKS_PER_HALF_BAUD = CLOCKS_PER_BAUD/2;
	// 8 data bits, no parity, (at least 1) stop bit
	input			i_clk, i_reset;
	input		[29:0]	i_setup;
	input			i_uart;
	output	reg		o_wr;
	output	reg	[7:0]	o_data;
	output	reg		o_break;
	output	reg		o_parity_err, o_frame_err;
	output	wire		o_ck_uart;


	wire	[27:0]	clocks_per_baud, break_condition, half_baud;
	wire	[1:0]	data_bits;
	wire		use_parity, parity_even, dblstop, fixd_parity;
	reg	[29:0]	r_setup;
	assign	clocks_per_baud = { 4'h0, r_setup[23:0] };
	assign	data_bits   = r_setup[29:28];
	assign	dblstop     = r_setup[27];
	assign	use_parity  = r_setup[26];
	assign	fixd_parity = r_setup[25];
	assign	parity_even = r_setup[24];
	assign	break_condition = { r_setup[23:0], 4'h0 };
	assign	half_baud = { 5'h00, r_setup[23:1] };

	reg	q_uart, qq_uart, ck_uart;
	initial	q_uart  = 1'b0;
	initial	qq_uart = 1'b0;
	initial	ck_uart = 1'b0;
	always @(posedge i_clk)
	begin
		q_uart <= i_uart;
		qq_uart <= q_uart;
		ck_uart <= qq_uart;
	end
	assign	o_ck_uart = ck_uart;

	reg	[27:0]	chg_counter;
	initial	chg_counter = 28'h00;
	always @(posedge i_clk)
		if (i_reset)
			chg_counter <= 28'h00;
		else if (qq_uart != ck_uart)
			chg_counter <= 28'h00;
		else if (chg_counter < break_condition)
			chg_counter <= chg_counter + 1;

	reg	line_synch;
	initial	line_synch = 1'b0;
	initial	o_break    = 1'b0;
	always @(posedge i_clk)
		o_break <= ((chg_counter >= break_condition)&&(~ck_uart))? 1'b1:1'b0;
	always @(posedge i_clk)
		line_synch <= ((chg_counter >= break_condition)&&(ck_uart));

	reg	[3:0]	state;
	reg	[27:0]	baud_counter;
	reg	[7:0]	data_reg;
	reg		calc_parity, zero_baud_counter, half_baud_time;
	initial	o_wr = 1'b0;
	initial	state = `RXU_RESET_IDLE;
	initial	o_parity_err = 1'b0;
	initial	o_frame_err  = 1'b0;
	// initial	baud_counter = clocks_per_baud;
	always @(posedge i_clk)
	begin
		if (i_reset)
		begin
			o_wr <= 1'b0;
			o_data <= 8'h00;
			state <= `RXU_RESET_IDLE;
			baud_counter <= clocks_per_baud-28'h01;// Set, not reset
			data_reg <= 8'h00;
			calc_parity <= 1'b0;
			o_parity_err <= 1'b0;
			o_frame_err <= 1'b0;
		end else if (state == `RXU_RESET_IDLE)
		begin
			r_setup <= i_setup;
			data_reg <= 8'h00; o_data <= 8'h00; o_wr <= 1'b0;
			baud_counter <= clocks_per_baud-28'h01;// Set, not reset
			if (line_synch)
				// Goto idle state from a reset
				state <= `RXU_IDLE;
			else // Otherwise, stay in this condition 'til reset
				state <= `RXU_RESET_IDLE;
			calc_parity <= 1'b0;
			o_parity_err <= 1'b0;
			o_frame_err <= 1'b0;
		end else if (o_break)
		begin // We are in a break condition
			state <= `RXU_BREAK;
			o_wr <= 1'b0;
			o_data <= 8'h00;
			baud_counter <= clocks_per_baud-28'h01;// Set, not reset
			data_reg <= 8'h00;
			calc_parity <= 1'b0;
			o_parity_err <= 1'b0;
			o_frame_err <= 1'b0;
			r_setup <= i_setup;
		end else if (state == `RXU_BREAK)
		begin // Goto idle state following return ck_uart going high
			data_reg <= 8'h00; o_data <= 8'h00; o_wr <= 1'b0;
			baud_counter <= clocks_per_baud - 28'h01;
			if (ck_uart)
				state <= `RXU_IDLE;
			else
				state <= `RXU_BREAK;
			calc_parity <= 1'b0;
			o_parity_err <= 1'b0;
			o_frame_err <= 1'b0;
			r_setup <= i_setup;
		end else if (state == `RXU_IDLE)
		begin // Idle state, independent of baud counter
			r_setup <= i_setup;
			data_reg <= 8'h00; o_data <= 8'h00; o_wr <= 1'b0;
			baud_counter <= clocks_per_baud - 28'h01;
			if ((~ck_uart)&&(half_baud_time))
			begin
				// We are in the center of a valid start bit
				case (data_bits)
				2'b00: state <= `RXU_BIT_ZERO;
				2'b01: state <= `RXU_BIT_ONE;
				2'b10: state <= `RXU_BIT_TWO;
				2'b11: state <= `RXU_BIT_THREE;
				endcase
			end else // Otherwise, just stay here in idle
				state <= `RXU_IDLE;
			calc_parity <= 1'b0;
			o_parity_err <= 1'b0;
			o_frame_err <= 1'b0;
		end else if (zero_baud_counter)
		begin
			baud_counter <= clocks_per_baud-28'h1;
			if (state < `RXU_BIT_SEVEN)
			begin
				// Data arrives least significant bit first.
				// By the time this is clocked in, it's what
				// you'll have.
				data_reg <= { ck_uart, data_reg[7:1] };
				calc_parity <= calc_parity ^ ck_uart;
				o_data <= 8'h00;
				o_wr <= 1'b0;
				state <= state + 1;
				o_parity_err <= 1'b0;
				o_frame_err <= 1'b0;
			end else if (state == `RXU_BIT_SEVEN)
			begin
				data_reg <= { ck_uart, data_reg[7:1] };
				calc_parity <= calc_parity ^ ck_uart;
				o_data <= 8'h00;
				o_wr <= 1'b0;
				state <= (use_parity) ? `RXU_PARITY:`RXU_STOP;
				o_parity_err <= 1'b0;
				o_frame_err <= 1'b0;
			end else if (state == `RXU_PARITY)
			begin
				if (fixd_parity)
					o_parity_err <= (ck_uart ^ parity_even);
				else
					o_parity_err <= ((parity_even && (calc_parity != ck_uart))
						||((~parity_even)&&(calc_parity==ck_uart)));
				state <= `RXU_STOP;
				o_frame_err <= 1'b0;
			end else if (state == `RXU_STOP)
			begin // Stop (or parity) bit(s)
				case (data_bits)
				2'b00: o_data <= data_reg;
				2'b01: o_data <= { 1'b0, data_reg[7:1] };
				2'b10: o_data <= { 2'b0, data_reg[7:2] };
				2'b11: o_data <= { 3'b0, data_reg[7:3] };
				endcase
				o_wr <= 1'b1; // Pulse the write
				o_frame_err <= (~ck_uart);
				if (~ck_uart)
					state <= `RXU_RESET_IDLE;
				else if (dblstop)
					state <= `RXU_SECOND_STOP;
				else
					state <= `RXU_IDLE;
				// o_parity_err <= 1'b0;
			end else // state must equal RX_SECOND_STOP
			begin
				if (~ck_uart)
				begin
					o_frame_err <= 1'b1;
					state <= `RXU_RESET_IDLE;
				end else begin
					state <= `RXU_IDLE;
					o_frame_err  <= 1'b0;
				end
				o_parity_err <= 1'b0;
			end
		end else begin
			o_wr <= 1'b0;	// data_reg = data_reg
			baud_counter <= baud_counter - 28'd1;
			o_parity_err <= 1'b0;
			o_frame_err  <= 1'b0;
		end
	end

	initial	zero_baud_counter = 1'b0;
	always @(posedge i_clk)
		zero_baud_counter <= (baud_counter == 28'h01);

	initial	half_baud_time = 0;
	always @(posedge i_clk)
		half_baud_time <= (~ck_uart)&&(chg_counter >= half_baud);


endmodule


