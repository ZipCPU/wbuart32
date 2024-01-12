////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	helloworld.v
// {{{
// Project:	wbuart32, a full featured UART with simulator
//
// Purpose:	To create a *very* simple UART test program, which can be used
//		as the top level design file of any FPGA program.
//
//	With some modifications (discussed below), this RTL should be able to
//	run as a top-level testing file, requiring only the UART and clock pin
//	to work.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2015-2024, Gisselquist Technology, LLC
// {{{
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
// One issue with the design is how to set the values of the setup register.
// (*This is a comment, not a verilator attribute ... )  Verilator needs to
// know/set those values in order to work.  However, this design can also be
// used as a stand-alone top level configuration file.  In this latter case,
// the setup register needs to be set internal to the file.  Here, we use
// OPT_STANDALONE to distinguish between the two.  If set, the file runs under
// (* Another comment still ...) Verilator and we need to get i_setup from the
// external environment.  If not, it must be set internally.
// }}}
`ifndef	VERILATOR
`define OPT_STANDALONE
`endif
// {{{
//
// Two versions of the UART can be found in the rtl directory: a full featured
// UART, and a LITE UART that only handles 8N1 -- no break sending, break
// detection, parity error detection, etc.  If we set USE_LITE_UART here, those
// simplified UART modules will be used.
// }}}
// `define	USE_LITE_UART
//
`default_nettype none
//
module	helloworld #(
		// {{{
		// Here we set i_setup to something appropriate to create a
		// 115200 Baud UART system from a 100MHz clock.  This also sets
		// us to an 8-bit data word, 1-stop bit, and no parity.  This
		// will be overwritten by i_setup, but at least it gives us
		// something to start with/from.
		// Verilator lint_off UNUSED
		parameter	INITIAL_UART_SETUP = 31'd868
		// Verilator lint_on  UNUSED
		// }}}
	) (
		// {{{
		input	wire		i_clk,
`ifndef	OPT_STANDALONE
		input	wire	[30:0]	i_setup,
`endif
		output	wire		o_uart_tx
		// }}}
	);

	// Signal declarations
	// {{{
	reg	[7:0]	message	[0:15];
	reg		pwr_reset;

	reg	[27:0]	counter;
	wire		tx_break, tx_busy;
	reg		tx_stb;
	reg	[3:0]	tx_index;
	reg	[7:0]	tx_data;

	wire		cts_n;
	// }}}

	// i_setup
	// {{{
`ifdef	OPT_STANDALONE
	// The i_setup wires are input when run under Verilator, but need to
	// be set internally if this is going to run as a standalone top level
	// test configuration.
	assign	i_setup = INITIAL_UART_SETUP;
`endif
	// }}}

	// pwr_reset
	// {{{
	initial	pwr_reset = 1'b1;
	always @(posedge i_clk)
		pwr_reset <= 1'b0;
	// }}}

	// Initialize the message
	// {{{
	initial begin
		message[ 0] = "H";
		message[ 1] = "e";
		message[ 2] = "l";
		message[ 3] = "l";
		message[ 4] = "o";
		message[ 5] = ",";
		message[ 6] = " ";
		message[ 7] = "W";
		message[ 8] = "o";
		message[ 9] = "r";
		message[10] = "l";
		message[11] = "d";
		message[12] = "!";
		message[13] = " ";
		message[14] = "\r";
		message[15] = "\n";
	end
	// }}}

	// Send a Hello World message to the transmitter
	// {{{
	initial	counter = 28'hffffff0;
	always @(posedge i_clk)
		counter <= counter + 1'b1;

	assign	tx_break = 1'b0;

	initial	tx_index = 4'h0;
	always @(posedge i_clk)
	if ((tx_stb)&&(!tx_busy))
		tx_index <= tx_index + 1'b1;

	always @(posedge i_clk)
		tx_data <= message[tx_index];

	initial	tx_stb = 1'b0;
	always @(posedge i_clk)
	if (&counter)
		tx_stb <= 1'b1;
	else if ((tx_stb)&&(!tx_busy)&&(tx_index==4'hf))
		tx_stb <= 1'b0;
	// }}}

	// The UART transmitter
	// {{{
	// Bypass any hardware flow control
	assign	cts_n = 1'b0;

`ifdef	USE_LITE_UART
	txuartlite
		#(24'd868)
		transmitter(i_clk, tx_stb, tx_data, o_uart_tx, tx_busy);
`else
	txuart	transmitter(i_clk, pwr_reset, i_setup, tx_break,
			tx_stb, tx_data, cts_n, o_uart_tx, tx_busy);
`endif
	// }}}
endmodule
