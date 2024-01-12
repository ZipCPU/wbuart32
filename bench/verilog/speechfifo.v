////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	speechfifo.v
// {{{
// Project:	wbuart32, a full featured UART with simulator
//
// Purpose:	To test/demonstrate/prove the wishbone access to the FIFO'd
//		UART via sending more information than the FIFO can hold,
//	and then verifying that this was the value received.
//
//	To do this, we "borrow" a copy of Abraham Lincolns Gettysburg address,
//	make that the FIFO isn't large enough to hold it, and then try
//	to send this address every couple of minutes.
//
//	With some minor modifications (discussed below), this RTL should be
//	able to be run as a top-level testing file, requiring only that the
//	clock and the transmit UART pins be working.
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
//
`ifndef	VERILATOR
`define OPT_STANDALONE
`endif
// }}}
module	speechfifo #(
		// {{{
		// Here we set i_setup to something appropriate to create a
		// 115200 Baud UART system from a 100MHz clock.  This also sets
		// us to an 8-bit data word, 1-stop bit, and no parity (for the
		// non-LITE UART).  This will be overwritten by i_setup (if
		// present), but at least it gives us something to start
		// with/from.
		parameter	INITIAL_UART_SETUP = 31'd868,

		// Let's set our message length, in case we ever wish to change
		// it in the future
		localparam	MSGLEN=2203
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
	reg		restart;
	reg		wb_stb;
	reg	[1:0]	wb_addr;
	reg	[31:0]	wb_data;

	wire		uart_stall;

	// We aren't using the receive interrupts, or the received data, or the
	// ready to send line, so we'll just mark them all here as ignored.

	/* verilator lint_off UNUSED */
	wire		uart_ack, tx_int;
	wire	[31:0]	uart_data;
	wire		ignored_rx_int, ignored_rxfifo_int;
	wire		rts_n_ignored;
	/* verilator lint_on UNUSED */

	reg		pwr_reset;
	reg	[7:0]	message [0:4095];
	reg	[30:0]	restart_counter;
	reg	[11:0]	msg_index;
	reg		end_of_message;

	wire	cts_n;
	wire		txfifo_int;
	// }}}

	// i_setup
	// {{{
	// The i_setup wires are input when run under Verilator, but need to
	// be set internally if this is going to run as a standalone top level
	// test configuration.
`ifdef	OPT_STANDALONE
	wire	[30:0]	i_setup;
	assign	i_setup = INITIAL_UART_SETUP;
`endif
	// }}}

	// pwr_reset
	// {{{
	// The next four lines create a strobe signal that is true on the first
	// clock, but never after.  This makes for a decent power-on reset
	// signal.
	initial	pwr_reset = 1'b1;
	always @(posedge i_clk)
		pwr_reset <= 1'b0;
	// }}}

	// initializing the memory
	// {{{
	// The message we wish to transmit is kept in "message".  It needs to be
	// set initially.  Do so here.
	//
	// Since the message has fewer than 2048 elements in it, we preset every
	// element to a space so that if (for some reason) we broadcast past the
	// end of our message, we'll at least be sending something useful.
	integer	i;
	initial begin
		// xx Verilator needs this file to be in the directory the file
		// is run from.  For that reason, the project builds, makes,
		// and keeps speech.hex in bench/cpp.  
		//
		// Vivado, however, wants speech.hex to be in a project file
		// directory, such as bench/verilog.  For that reason, the
		// build function in bench/cpp also copies speech.hex to the
		// bench/verilog directory.  You may need to make certain the
		// file is both built, and copied into a directory where your
		// synthesis tool can find it.
		//
		$readmemh("speech.hex", message);
		for(i=MSGLEN; i<4095; i=i+1)
			message[i] = 8'h20;

		//
		// The problem with the above approach is Xilinx's ISE program.
		// It's broken.  It can't handle HEX files well (at all?) and
		// has more problems with HEX's defining ROM's.  For that
		// reason, the mkspeech program can be tuned to create an
		// include file, speech.inc.  We include that program here.
		// It is rather ugly, though, and not a very elegant solution,
		// since it walks through every value in our speech, byte by
		// byte, with an initial line for each byte declaring what it
		// is to be.
		//
		// If you (need to) use this route, comment out both the 
		// readmemh, the for loop, and the message[i] = 8'h20 lines
		// above and uncomment the include line below.
		//
		// `include "speech.inc"
	end
	// }}}

	// restart_counter
	// {{{
	// Let's keep track of time, and send our message over and over again.
	// To do this, we'll keep track of a restart counter.  When this counter
	// rolls over, we restart our message.
	//
	// Since we want to start our message just a couple clocks after power
	// up, we'll set the reset counter just a couple clocks shy of a roll
	// over.
	initial	restart_counter = -31'd16;
	always @(posedge i_clk)
		restart_counter <= restart_counter+1'b1;
	// }}}

	// restart
	// {{{
	// Ok, now that we have a counter that tells us when to start over,
	// let's build a set of signals that we can use to get things started
	// again.  This will be the restart signal.  On this signal, we just
	// restart everything.
	initial	restart = 0;
	always @(posedge i_clk)
		restart <= (restart_counter == 0);
	// }}}

	// msg_index
	// {{{
	// Our message index.  This is the address of the character we wish to
	// transmit next.  Note, there's a clock delay between setting this 
	// index and when the wb_data is valid.  Hence, we set the index on
	// restart[0] to zero.
	initial	msg_index = 12'h000 - 12'h8;
	always @(posedge i_clk)
	if (restart)
		msg_index <= 0;
	else if ((wb_stb)&&(!uart_stall))
		// We only advance the index if a port operation on the
		// wbuart has taken place.  That's what the
		// (wb_stb)&&(!uart_stall) is about.  (wb_stb) is the
		// request for a transaction on the bus, uart_stall
		// tells us to wait 'cause the peripheral isn't ready. 
		// In our case, it's always ready, uart_stall == 0, but
		// we keep/maintain this logic for good form.
		//
		// Note also, we only advance when restart[0] is zero.
		// This keeps us from advancing prior to the setup
		// word.
		msg_index <= msg_index + 1'b1;
	// }}}

	// wb_data -- What data will we be sending to the port?
	// {{{
	always @(posedge i_clk)
	if (restart)
		// The first thing we do is set the baud rate, and
		// serial port configuration parameters.  Ideally,
		// we'd only set this once.  But rather than complicate
		// the logic, we set it everytime we start over.
		wb_data <= { 1'b0, i_setup };
	else if ((wb_stb)&&(!uart_stall))
		// Then, if the last thing was received over the bus,
		// we move to the next data item.
		wb_data <= { 24'h00, message[msg_index] };
	// }}}

	// wb_addr
	// {{{
	// We send our first value to the SETUP address (all zeros), all other
	// values we send to the transmitters address.  We should really be
	// double checking that stall remains low, but its not required here.
	always @(posedge i_clk)
	if (restart)
		wb_addr <= 2'b00;
	else // if (!uart_stall)??
		wb_addr <= 2'b11;
	// }}}

	// end_of_message
	// {{{
	// Knowing when to stop sending the speech is important, but depends
	// upon an 11 bit comparison.  Since FPGA logic is best measured by the
	// number of inputs to an always block, we pull those 11-bits out of
	// the always block for wb_stb, and place them here on the clock prior.
	// If end_of_message is true, then we need to stop transmitting, and
	// wait for the next (restart) to get us started again.  We set that
	// flag hee.
	initial	end_of_message = 1'b1;
	always @(posedge i_clk)
	if (restart)
		end_of_message <= 1'b0;
	else
		end_of_message <= (msg_index >= MSGLEN);
	// }}}

	// wb_stb
	// {{{
	// The wb_stb signal indicates that we wish to write, using the wishbone
	// to our peripheral.  We have two separate types of writes.  First,
	// we wish to write our setup.  Then we want to drop STB and write
	// our data.  Once we've filled half of the FIFO, we wait for the FIFO
	// to empty before issuing a STB again and then fill up half the FIFO
	// again.
	initial	wb_stb = 1'b0;
	always @(posedge i_clk)
	if (restart)
		// Start sending to the UART on a reset.  The first
		// thing we'll send will be the configuration, but
		// that's done elsewhere.  This just starts up the
		// writes to the peripheral wbuart.
		wb_stb <= 1'b1;
	else if (end_of_message)
		// Stop transmitting when we get to the end of our
		// message.
		wb_stb <= 1'b0;
	else if (txfifo_int)
		// If the FIFO is less than half full, then write to
		// it.
		wb_stb <= 1'b1;
	else
		// But once the FIFO gets to half full, stop.
		wb_stb <= 1'b0;
	// }}}

	// cts_n
	// {{{
	// The WBUART can handle hardware flow control signals.  This test,
	// however, cannot.  The reason?  Simply just to keep things simple.
	// If you want to add hardware flow control to your design, simply
	// make rts an input to this module.
	//
	// Since this is an output only module demonstrator, what would be the
	// cts output is unused.
	assign	cts_n = 1'b0;
	// }}}

	// Finally--the unit under test--now that we've set up all the wires
	// to run/test it.
	wbuart	#(INITIAL_UART_SETUP)
	wbuarti(i_clk, pwr_reset,
		wb_stb, wb_stb, 1'b1, wb_addr, wb_data, 4'hf,
		uart_stall, uart_ack, uart_data,
		1'b1, o_uart_tx, cts_n, rts_n_ignored,
		ignored_rx_int, tx_int,
		ignored_rxfifo_int, txfifo_int);

endmodule
