////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	echotest.v
//
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
// Uncomment the next line defining OPT_DUMBECHO in order to test the wires
// and external functionality of any UART, independent of the UART protocol.
//
`define	OPT_DUMBECHO
//
//
// Uncomment the next line if you want this program to work as a standalone
// (not verilated) RTL "program" to test your UART.  You'll also need to set
// your setup condition properly, though.  I recommend setting it to the 
// ratio of your onboard clock to your desired baud rate.  For more information
// about how to set this, please see the specification.
//
`define OPT_STANDALONE
//
module	echotest(i_clk,
`ifndef	OPT_STANDALONE
			i_setup,
`endif
			i_uart_rx, o_uart_tx);
	input		i_clk;
`ifndef	OPT_STANDALONE
	input	[29:0]	i_setup;
`endif
	input		i_uart_rx;
	output	wire	o_uart_tx;

`ifdef	OPT_DUMBECHO
	reg	r_uart_tx;

	initial	r_uart_tx = 1'b1;
	always @(posedge i_clk)
		r_uart_tx <= i_uart_rx;
	assign	o_uart_tx = r_uart_tx;
`else
	// This is the "smart" echo verion--one that decodes, and then
	// re-encodes, values over the UART.  There is a risk, though, doing
	// things in this manner that the receive UART might run *just* a touch
	// faster than the transmitter, and hence drop a bit every now and
	// then.  Hence, it works nicely for hand-testing, but not as nicely
	// for high-speed UART testing.



	// If i_setup isnt set up as an input parameter, it needs to be set.
	// We do so here, to a setting appropriate to create a 115200 Baud
	// comms system from a 100MHz clock.  This also sets us to an 8-bit
	// data word, 1-stop bit, and no parity.
	//
	// This code only applies if OPT_DUMBECHO is not defined.
`ifdef	OPT_STANDALONE
	wire	[29:0]	i_setup;
	assign		i_setup = 30'd868;	// 115200 Baud, if clk @ 100MHz
`endif

	// Create a reset line that will always be true on a power on reset
	reg	pwr_reset;
	initial	pwr_reset = 1'b1;
	always @(posedge i_clk)
		pwr_reset = 1'b0;



	// The UART Receiver
	//
	// This is where everything begins, by reading data from the UART.
	//
	// Data (rx_data) is present when rx_stb is true.  Any parity or
	// frame errors will also be valid at that time.  Finally, we'll ignore
	// errors, and even the clocked uart input distributed from here.
	//
	// This code only applies if OPT_DUMBECHO is not defined.
	wire	rx_stb, rx_break, rx_perr, rx_ferr, rx_ignored;
	wire	[7:0]	rx_data;

	rxuart	receiver(i_clk, pwr_reset, i_setup, i_uart_rx, rx_stb, rx_data,
			rx_break, rx_perr, rx_ferr, rx_ignored);

	wire	tx_busy;
	txuart	transmitter(i_clk, pwr_reset, i_setup, rx_break,
			rx_stb, rx_data, o_uart_tx, tx_busy);

`endif

endmodule

