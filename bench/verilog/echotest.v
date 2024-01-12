////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	echotest.v
// {{{
// Project:	wbuart32, a full featured UART with simulator
//
// Purpose:	To test that the txuart and rxuart modules work properly, by
//		echoing the input directly to the output.
//
//	This module may be run as either a DUMBECHO, simply forwarding the input
//	wire to the output with a touch of clock in between, or it can run as
//	a smarter echo routine that decodes text before returning it.  The
//	difference depends upon whether or not OPT_DUMBECHO is defined, as 
//	discussed below.
//
//	With some modifications (discussed below), this RTL should be able to
//	run as a top-level testing file, requiring only the transmit and receive
//	UART pins and the clock to work.
//
//	DON'T FORGET TO TURN OFF HARDWARE FLOW CONTROL!  ... or this'll never
//	work.  If you want to run with hardware flow control on, add another
//	wire to this module in order to set o_cts to 1'b1.
//
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
// Uncomment the next line defining OPT_DUMBECHO in order to test the wires
// and external functionality of any UART, independent of the UART protocol.
// }}}
`define	OPT_DUMBECHO
// {{{
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
//
module	echotest(
		// {{{
		input		i_clk,
`ifndef	OPT_STANDALONE
		input	[30:0]	i_setup,
`endif
		input		i_uart_rx,
		output	wire	o_uart_tx
		// }}}
	);

`ifdef	OPT_DUMBECHO
	// {{{
	reg	r_uart_tx;

	initial	r_uart_tx = 1'b1;
	always @(posedge i_clk)
		r_uart_tx <= i_uart_rx;
	assign	o_uart_tx = r_uart_tx;
	// }}}
`else
	// {{{
	// This is the "smart" echo verion--one that decodes, and then
	// re-encodes, values over the UART.  There is a risk, though, doing
	// things in this manner that the receive UART might run *just* a touch
	// faster than the transmitter, and hence drop a bit every now and
	// then.  Hence, it works nicely for hand-testing, but not as nicely
	// for high-speed UART testing.


	// i_setup
	// {{{
	// If i_setup isnt set up as an input parameter, it needs to be set.
	// We do so here, to a setting appropriate to create a 115200 Baud
	// comms system from a 100MHz clock.  This also sets us to an 8-bit
	// data word, 1-stop bit, and no parity.
	//
	// This code only applies if OPT_DUMBECHO is not defined.
`ifdef	OPT_STANDALONE
	wire	[30:0]	i_setup;
	assign		i_setup = 31'd868;	// 115200 Baud, if clk @ 100MHz
`endif
	// }}}

	// pwr_reset
	// {{{
	// Create a reset line that will always be true on a power on reset
	reg	pwr_reset;
	initial	pwr_reset = 1'b1;
	always @(posedge i_clk)
		pwr_reset = 1'b0;
	// }}}

	// The UART Receiver
	// {{{
	// This is where everything begins, by reading data from the UART.
	//
	// Data (rx_data) is present when rx_stb is true.  Any parity or
	// frame errors will also be valid at that time.  Finally, we'll ignore
	// errors, and even the clocked uart input distributed from here.
	//
	// This code only applies if OPT_DUMBECHO is not defined.
	wire	rx_stb, rx_break, rx_perr, rx_ferr, rx_ignored;
	wire	[7:0]	rx_data;

`ifdef	USE_LITE_UART
	//
	// NOTE: this depends upon the Verilator implementation using a setup
	// of 868, since we cannot change the setup of the RXUARTLITE module.
	//
	rxuartlite	#(24'd868)
		receiver(i_clk, i_uart_rx, rx_stb, rx_data);
`else
	rxuart	receiver(i_clk, pwr_reset, i_setup, i_uart_rx, rx_stb, rx_data,
			rx_break, rx_perr, rx_ferr, rx_ignored);
`endif
	// }}}

	// The UART return transmitter
	// {{{
	// Bypass any transmit hardware flow control.
	wire	cts_n;
	assign cts_n = 1'b0;

	wire	tx_busy;
`ifdef	USE_LITE_UART
	//
	// NOTE: this depends upon the Verilator implementation using a setup
	// of 868, since we cannot change the setup of the TXUARTLITE module.
	//
	txuartlite #(24'd868)
		transmitter(i_clk, rx_stb, rx_data, o_uart_tx, tx_busy);
`else
	txuart	transmitter(i_clk, pwr_reset, i_setup, rx_break,
			rx_stb, rx_data, rts, o_uart_tx, tx_busy);
`endif
	// }}}
	// }}}
`endif	// OPT_DUMBECHO
endmodule

