////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	rxuartlite.v
//
// Project:	wbuart32, a full featured UART with simulator
//
// Purpose:	Receive and decode inputs from a single UART line.
//
//
//	To interface with this module, connect it to your system clock,
//	and a UART input.  Set the parameter to the number of clocks per
//	baud.  When data becomes available, the o_wr line will be asserted
//	for one clock cycle.
//
//	This interface only handles 8N1 serial port communications.  It does
//	not handle the break, parity, or frame error conditions.
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2017, Gisselquist Technology, LLC
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
// with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
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
`default_nettype	none
//
`define	RXUL_BIT_ZERO		4'h0
`define	RXUL_BIT_ONE		4'h1
`define	RXUL_BIT_TWO		4'h2
`define	RXUL_BIT_THREE		4'h3
`define	RXUL_BIT_FOUR		4'h4
`define	RXUL_BIT_FIVE		4'h5
`define	RXUL_BIT_SIX		4'h6
`define	RXUL_BIT_SEVEN		4'h7
`define	RXUL_STOP		4'h8
`define	RXUL_IDLE		4'hf

module rxuartlite(i_clk, i_uart_rx, o_wr, o_data);
	parameter [23:0] CLOCKS_PER_BAUD = 24'd868;
	input	wire		i_clk;
	input	wire		i_uart_rx;
	output	reg		o_wr;
	output	reg	[7:0]	o_data;


	wire	[23:0]	half_baud;
	reg	[3:0]	state;

	assign	half_baud = { 1'b0, CLOCKS_PER_BAUD[23:1] } - 24'h1;
	reg	[23:0]	baud_counter;
	reg		zero_baud_counter;


	// Since this is an asynchronous receiver, we need to register our
	// input a couple of clocks over to avoid any problems with 
	// metastability.  We do that here, and then ignore all but the
	// ck_uart wire.
	reg	q_uart, qq_uart, ck_uart;
	initial	q_uart  = 1'b0;
	initial	qq_uart = 1'b0;
	initial	ck_uart = 1'b0;
	always @(posedge i_clk)
	begin
		q_uart <= i_uart_rx;
		qq_uart <= q_uart;
		ck_uart <= qq_uart;
	end

	// Keep track of the number of clocks since the last change.
	//
	// This is used to determine if we are in either a break or an idle
	// condition, as discussed further below.
	reg	[23:0]	chg_counter;
	initial	chg_counter = 24'h00;
	always @(posedge i_clk)
		if (qq_uart != ck_uart)
			chg_counter <= 24'h00;
		else
			chg_counter <= chg_counter + 1;

	// Are we in the middle of a baud iterval?  Specifically, are we
	// in the middle of a start bit?  Set this to high if so.  We'll use
	// this within our state machine to transition out of the IDLE
	// state.
	reg	half_baud_time;
	initial	half_baud_time = 0;
	always @(posedge i_clk)
		half_baud_time <= (~ck_uart)&&(chg_counter >= half_baud);


	initial	state = `RXUL_IDLE;
	always @(posedge i_clk)
	begin
		if (state == `RXUL_IDLE)
		begin // Idle state, independent of baud counter
			// By default, just stay in the IDLE state
			state <= `RXUL_IDLE;
			if ((~ck_uart)&&(half_baud_time))
				// UNLESS: We are in the center of a valid
				// start bit
				state <= `RXUL_BIT_ZERO;
		end else if (zero_baud_counter)
		begin
			if (state < `RXUL_STOP)
				// Data arrives least significant bit first.
				// By the time this is clocked in, it's what
				// you'll have.
				state <= state + 1;
			else // Wait for the next character
				state <= `RXUL_IDLE;
		end
	end

	// Data bit capture logic.
	//
	// This is drastically simplified from the state machine above, based
	// upon: 1) it doesn't matter what it is until the end of a captured
	// byte, and 2) the data register will flush itself of any invalid
	// data in all other cases.  Hence, let's keep it real simple.
	reg	[7:0]	data_reg;
	always @(posedge i_clk)
		if (zero_baud_counter)
			data_reg <= { ck_uart, data_reg[7:1] };

	// Our data bit logic doesn't need nearly the complexity of all that
	// work above.  Indeed, we only need to know if we are at the end of
	// a stop bit, in which case we copy the data_reg into our output
	// data register, o_data, and tell others (for one clock) that data is
	// available.
	//
	initial	o_data = 8'h00;
	always @(posedge i_clk)
		if ((zero_baud_counter)&&(state == `RXUL_STOP))
		begin
			o_wr   <= 1'b1;
			o_data <= data_reg;
		end else
			o_wr   <= 1'b0;

	// The baud counter
	//
	// This is used as a "clock divider" if you will, but the clock needs
	// to be reset before any byte can be decoded.  In all other respects,
	// we set ourselves up for CLOCKS_PER_BAUD counts between baud
	// intervals.
	always @(posedge i_clk)
		if ((zero_baud_counter)|||(state == `RXUL_IDLE))
			baud_counter <= CLOCKS_PER_BAUD-1'b1;
		else
			baud_counter <= baud_counter-1'b1;

	// zero_baud_counter
	//
	// Rather than testing whether or not (baud_counter == 0) within our
	// (already too complicated) state transition tables, we use
	// zero_baud_counter to pre-charge that test on the clock
	// before--cleaning up some otherwise difficult timing dependencies.
	initial	zero_baud_counter = 1'b0;
	always @(posedge i_clk)
		if (state == `RXUL_IDLE)
			zero_baud_counter <= 1'b0;
		else
			zero_baud_counter <= (baud_counter == 24'h01);


endmodule


