////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	linetest.v
//
// Project:	wbuart32, a full featured UART with simulator
//
// Purpose:	To test that the txuart and rxuart modules work properly, by
//		buffering one line's worth of input, and then piping that line
//	to the transmitter while (possibly) receiving a new line.
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
// Uncomment the next line if you want this program to work as a standalone
// (not verilated) RTL "program" to test your UART.  You'll also need to set
// your setup condition properly, though.  I recommend setting it to the 
// ratio of your onboard clock to your desired baud rate.  For more information
// about how to set this, please see the specification.
//
//`define OPT_STANDALONE
//
module	linetest(i_clk,
`ifndef	OPT_STANDALONE
			i_setup,
`endif
			i_uart, o_uart);
	input		i_clk;
`ifndef	OPT_STANDALONE
	input	[29:0]	i_setup;
`endif
	input		i_uart;
	output	wire	o_uart;

	// If i_setup isnt set up as an input parameter, it needs to be set.
	// We do so here, to a setting appropriate to create a 115200 Baud
	// comms system from a 100MHz clock.  This also sets us to an 8-bit
	// data word, 1-stop bit, and no parity.
`ifdef	OPT_STANDALONE
	wire	[29:0]	i_setup;
	assign		i_setup = 30'd868;	// 115200 Baud, if clk @ 100MHz
`endif

	reg	[7:0]	buffer	[0:255];
	reg	[7:0]	head, tail;

	reg	pwr_reset;
	initial	pwr_reset = 1'b1;
	always @(posedge i_clk)
		pwr_reset = 1'b0;

	wire	rx_stb, rx_break, rx_perr, rx_ferr, rx_ignored;
	wire	[7:0]	rx_data;

	rxuart	receiver(i_clk, pwr_reset, i_setup, i_uart, rx_stb, rx_data,
			rx_break, rx_perr, rx_ferr, rx_ignored);


	wire	[7:0]	nxt_head;
	assign	nxt_head = head + 8'h01;	
	always @(posedge i_clk)
		buffer[head] <= rx_data;
	initial	head= 8'h00;
	always @(posedge i_clk)
		if (pwr_reset)
			head <= 8'h00;
		else if ((rx_stb)&&(!rx_break)&&(!rx_perr)&&(!rx_ferr)&&(nxt_head != tail))
			head <= nxt_head;

	wire	[7:0]	nused;
	reg	[7:0]	lineend;
	reg		run_tx;

	assign	nused = head-tail;

	initial	run_tx = 0;
	initial	lineend = 0;
	always @(posedge i_clk)
		if (pwr_reset)
		begin
			run_tx <= 1'b0;
			lineend <= 8'h00;
		end else if ((rx_data == 8'h0a)&&(rx_stb))
		begin
			lineend <= head+8'h1;
			run_tx <= 1'b1;
		end else if ((!run_tx)&&(nused>8'd80)&&(head != tail))
		begin
			lineend <= head;
			run_tx <= 1'b1;
		end else if (tail == lineend)
			run_tx <= 1'b0;

	wire	tx_break, tx_busy;
	assign	tx_break = 1'b0;
	reg	[7:0]	tx_data;
	reg		tx_stb;

	always @(posedge i_clk)
		tx_data <= buffer[tail];
	initial	tx_stb = 1'b0;
	always @(posedge i_clk)
		tx_stb <= run_tx;
	initial	tail = 8'h00;
	always @(posedge i_clk)
		if(pwr_reset)
			tail <= 8'h00;
		else if ((tx_stb)&&(!tx_busy))
			tail <= tail + 8'h01;
			
	txuart	transmitter(i_clk, pwr_reset, i_setup, tx_break,
			tx_stb, tx_data, o_uart, tx_busy);

endmodule
