////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	linetest.v
// {{{
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
// }}}
// License:	GPL, v3, as defined and found on www.gnu.org,
// {{{
//		http://www.gnu.org/licenses/gpl.html
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
module	linetest(
		// {{{
		input	wire	i_clk,
`ifndef	OPT_STANDALONE
		input	wire	[30:0]	i_setup,
`endif
		input		i_uart_rx,
		output	wire	o_uart_tx
		// }}}
	);

	// Signal declarations
	// {{{
	reg	[7:0]	buffer	[0:255];
	reg	[7:0]	head, tail;
	reg		pwr_reset;
	wire		rx_stb, rx_break, rx_perr, rx_ferr;
	/* verilator lint_off UNUSED */
	wire		rx_ignored;
	/* verilator lint_on UNUSED */
	wire	[7:0]	rx_data;
	wire	[7:0]	nxt_head;
	wire	[7:0]	nused;
	reg	[7:0]	lineend;
	reg		run_tx;
	wire		tx_break, tx_busy;
	reg	[7:0]	tx_data;
	reg		tx_stb;
	wire		cts_n;
	// }}}

	// i_setup
	// {{{
	// If i_setup isnt set up as an input parameter, it needs to be set.
	// We do so here, to a setting appropriate to create a 115200 Baud
	// comms system from a 100MHz clock.  This also sets us to an 8-bit
	// data word, 1-stop bit, and no parity.
`ifdef	OPT_STANDALONE
	wire	[30:0]	i_setup;
	assign		i_setup = 31'd868;	// 115200 Baud, if clk @ 100MHz
`endif
	// }}}

	// pwr_reset
	// {{{
	// Create a reset line that will always be true on a power on reset
	initial	pwr_reset = 1'b1;
	always @(posedge i_clk)
		pwr_reset <= 1'b0;
	// }}}

	// The UART Receiver
	// {{{
	// This is where everything begins, by reading data from the UART.
	//
	// Data (rx_data) is present when rx_stb is true.  Any parity or
	// frame errors will also be valid at that time.  Finally, we'll ignore
	// errors, and even the clocked uart input distributed from here.
`ifdef	USE_LITE_UART
	rxuartlite #(24'd868)
		receiver(i_clk, i_uart_rx, rx_stb, rx_data);
`else
	rxuart	receiver(i_clk, pwr_reset, i_setup, i_uart_rx, rx_stb, rx_data,
			rx_break, rx_perr, rx_ferr, rx_ignored);
`endif
	// }}}

	// nxt_head, and write to the buffer
	// {{{
	// The next step in this process is to dump everything we read into a 
	// FIFO.  First step: writing into the FIFO.  Always write into FIFO
	// memory.  (The next step will step the memory address if rx_stb was
	// true ...)
	assign	nxt_head = head + 8'h01;	
	always @(posedge i_clk)
		buffer[head] <= rx_data;
	// }}}

	// head
	// {{{
	// Select where in our FIFO memory to write.  On reset, we clear the 
	// memory.  In all other cases/respects, we step the memory forward.
	//
	// However ... we won't step it forward IF ...
	//	rx_break	- we are in a BREAK condition on the line
	//		(i.e. ... it's disconnected)
	//	rx_perr		- We've seen a parity error
	//	rx_ferr		- Same thing for a frame error
	//	nxt_head != tail - If the FIFO is already full, we'll just drop
	//		this new value, rather than dumping random garbage
	//		from the FIFO until we go round again ...  i.e., we
	//		don't write on potential overflow.
	//
	// Adjusting this address will make certain that the next write to the
	// FIFO goes to the next address--since we've already written the FIFO
	// memory at this address.
	initial	head= 8'h00;
	always @(posedge i_clk)
	if (pwr_reset)
		head <= 8'h00;
	else if ((rx_stb)&&(!rx_break)&&(!rx_perr)&&(!rx_ferr)&&(nxt_head != tail))
		head <= nxt_head;
	// }}}

	// How much of the FIFO is in use?  head - tail.  What if they wrap
	// around?  Still: head-tail, but this time truncated to the number of
	// bits of interest.  It can never be negative ... so ... we're good,
	// this just measures that number.
	assign	nused = head-tail;

	// run_tx, lineend
	// {{{
	// Here's the guts of the algorithm--setting run_tx.  Once set, the
	// buffer will flush.  Here, we set it on one of two conditions: 1)
	// a newline is received, or 2) the line is now longer than 80
	// characters.
	//
	// Once the line has ben transmitted (separate from emptying the buffer)
	// we stop transmitting.
	initial	run_tx = 0;
	initial	lineend = 0;
	always @(posedge i_clk)
	if (pwr_reset)
	begin
		run_tx <= 1'b0;
		lineend <= 8'h00;
	end else if(((rx_data == 8'h0a)||(rx_data == 8'hd))&&(rx_stb))
	begin
		// Start transmitting once we get to either a newline
		// or a carriage return character
		lineend <= head+8'h1;
		run_tx <= 1'b1;
	end else if ((!run_tx)&&(nused>8'd80))
	begin
		// Start transmitting once we get to 80 chars
		lineend <= head;
		run_tx <= 1'b1;
	end else if (tail == lineend)
		// Line buffer has been emptied
		run_tx <= 1'b0;
	// }}}

	// UART transmitter
	// {{{
	// Now ... let's deal with the transmitter
	assign	tx_break = 1'b0;

	// When do we wish to transmit?
	//
	// Any time run_tx is true--but we'll give it an extra clock.
	initial	tx_stb = 1'b0;
	always @(posedge i_clk)
		tx_stb <= run_tx;

	// We'll transmit the data from our FIFO from ... wherever our tail
	// is pointed.
	always @(posedge i_clk)
		tx_data <= buffer[tail];

	// We increment the pointer to where we read from any time 1) we are
	// requesting to transmit a character, and 2) the transmitter was not
	// busy and thus accepted our request.  At that time, increment the
	// pointer, and we'll be ready for another round.
	initial	tail = 8'h00;
	always @(posedge i_clk)
		if(pwr_reset)
			tail <= 8'h00;
		else if ((tx_stb)&&(!tx_busy))
			tail <= tail + 8'h01;

	// Bypass any hardwaare flow control
	assign	cts_n = 1'b0;

`ifdef	USE_LITE_UART
	txuartlite #(24'd868)
		transmitter(i_clk, tx_stb, tx_data, o_uart_tx, tx_busy);
`else
	txuart	transmitter(i_clk, pwr_reset, i_setup, tx_break,
			tx_stb, tx_data, cts_n, o_uart_tx, tx_busy);
`endif
	// }}}
endmodule
