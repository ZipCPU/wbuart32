////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	wbuart-insert.v
// {{{
// Project:	wbuart32, a full featured UART with simulator
//
// Purpose:	This is not a module file.  It is an example of the types of
//		lines and connections which can be used to connect this UART
//	to a local wishbone bus.  It was drawn from a working file, and
//	modified here for show, so ... let me know if I messed anything up
//	along the way.
//
//	Why isn't this a full module file?  Because I tend to lump all of my
//	single cycle I/O peripherals into one module file.  It makes the logic
//	simpler.  This particular file was extracted from the fastio.v file
//	within the openarty project.
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
// }}}


	// Ideally, UART_SETUP is defined somewhere.  I commonly like to define
	// it to CLKRATE / BAUDRATE, to give me 8N1 performance.  4MB is useful
	// to me, so 100MHz / 4M = 25 could be the setup.  You can also use
	// 200MHz / 4MB = 50 ... it all depends upon your clock.
`define	UART_SETUP	31'd25
	reg	[30:0]	uart_setup;
	initial	uart_setup = `UART_SETUP;
	always @(posedge i_clk)
		if ((i_wb_stb)&&(i_wb_addr == `UART_SETUP_ADDR))
			uart_setup[30:0] <= i_wb_data[30:0];

	//
	// First the UART receiver
	//
	wire	rx_stb, rx_break, rx_perr, rx_ferr, ck_uart;
	wire	[7:0]	rx_data_port;
	rxuart	#(UART_SETUP) rx(i_clk, 1'b0, uart_setup, i_rx,
			rx_stb, rx_data_port, rx_break,
			rx_perr, rx_ferr, ck_uart);

	wire	[31:0]	rx_data;
	reg	[11:0]	r_rx_data;
	always @(posedge i_clk)
		if (rx_stb)
		begin
			r_rx_data[11] <= (r_rx_data[11])||(rx_break);
			r_rx_data[10] <= (r_rx_data[10])||(rx_ferr);
			r_rx_data[ 9] <= (r_rx_data[ 9])||(rx_perr);
			r_rx_data[7:0]<= rx_data_port;
		end else if ((i_wb_stb)&&(i_wb_we)
					&&(i_wb_addr == `UART_RX_ADDR))
		begin
			r_rx_data[11] <= (rx_break)&& (!i_wb_data[11]);
			r_rx_data[10] <= (rx_ferr) && (!i_wb_data[10]);
			r_rx_data[ 9] <= (rx_perr) && (!i_wb_data[ 9]);
		end
	always @(posedge i_clk)
		if(((i_wb_stb)&&(!i_wb_we)&&(i_wb_addr == `UART_RX_ADDR))
				||(rx_stb))
			r_rx_data[8] <= !rx_stb;
	assign	o_rts_n = r_rx_data[8];
	assign	rx_data = { 20'h00, r_rx_data };
	assign	rx_int = !r_rx_data[8];

	// Transmit hardware flow control, the cts line
	wire	cts_n;
	// Set this cts value to zero if you aren't ever going to use H/W flow
	// control, otherwise set it to the value coming in from the external
	// i_cts_n pin.
	assign	cts_n = i_cts_n;

	//
	// Then the UART transmitter
	//
	//
	//
	// Now onto the transmitter itself
	wire	tx_busy;
	reg	[7:0]	r_tx_data;
	reg		r_tx_stb, r_tx_break;
	wire	[31:0]	tx_data;
	txuart	#(UART_SETUP) tx(i_clk, 1'b0, uart_setup,
			r_tx_break, r_tx_stb, r_tx_data,
			cts_n, o_tx, tx_busy);
	always @(posedge i_clk)
		if ((i_wb_stb)&&(i_wb_addr == 5'h0f))
		begin
			r_tx_stb  <= (!r_tx_break)&&(!i_wb_data[8]);
			r_tx_data <= i_wb_data[7:0];
			r_tx_break<= i_wb_data[9];
		end else if (!tx_busy)
		begin
			r_tx_stb <= 1'b0;
			r_tx_data <= 8'h0;
		end
	assign	tx_data = { 16'h00, cts_n, 3'h0,
		ck_uart, o_tx, r_tx_break, tx_busy,
		r_tx_data };
	assign	tx_int = ~tx_busy;

	always @(posedge i_clk)
		case(i_wb_addr)
		`UART_SETUP_ADDR: o_wb_data <= { 1'b0, uart_setup };
		`UART_RX_ADDR   : o_wb_data <= rx_data;
		`UART_TX_ADDR   : o_wb_data <= tx_data;
		// 
		// The rest of these address slots are left open here for
		// whatever else you might wish to connect to this bus/STB
		// line
		default: o_wb_data <= 32'h00;
		endcase

	assign	o_wb_stall = 1'b0;
	always @(posedge i_clk)
		o_wb_ack <= (i_wb_stb);

	// Interrupts sent to the board from here
	assign	o_board_ints = { rx_int, tx_int /* any other from this module */};

