////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	wbuart.v
//
// Project:	wbuart32, a full featured UART with simulator
//
// Purpose:	Unlilke wbuart-insert.v, this is a full blown wishbone core
//		with integrated FIFO support to support the UART transmitter
//	and receiver found within here.  As a result, it's usage may be
//	heavier on the bus than the insert, but it may also be more useful.
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
`define	UART_SETUP	2'b00
`define	UART_FIFO	2'b01
`define	UART_RXREG	2'b10
`define	UART_TXREG	2'b11
module	wbuart(i_clk, i_rst,
		//
		i_wb_cyc, i_wb_stb, i_wb_we, i_wb_addr, i_wb_data,
			o_wb_stall, o_wb_ack, o_wb_data,
		//
		i_uart_rx, o_uart_tx,
		// i_uart_rts, o_uart_cts, i_uart_dtr, o_uart_dts
		//
		o_uart_rx_int, o_uart_tx_int,
		o_uart_rxfifo_int, o_uart_txfifo_int);
	parameter	UART_SETUP = 30'd25, // 4MB 8N1, when using 100MHz clock
			LGFLEN = 4;
	//
	input	i_clk, i_rst;
	// Wishbone inputs
	input			i_wb_cyc, i_wb_stb, i_wb_we;
	input		[1:0]	i_wb_addr;
	input		[31:0]	i_wb_data;
	output	wire		o_wb_stall;
	output	reg		o_wb_ack;
	output	reg	[31:0]	o_wb_data;
	//
	input			i_uart_rx;
	output	wire		o_uart_tx;
	output	wire		o_uart_rx_int, o_uart_tx_int,
				o_uart_rxfifo_int, o_uart_txfifo_int;

	//
	// The UART setup parameters: bits per byte, stop bits, parity, and
	// baud rate are all captured within this uart_setup register.
	//
	reg	uart_reset;
	reg	[29:0]	uart_setup;
	initial	uart_setup = UART_SETUP;
	initial	uart_reset = 1'b1;
	always @(posedge i_clk)
		if ((i_wb_stb)&&(i_wb_addr == `UART_SETUP))
		begin
			uart_setup[29:0] <= i_wb_data[29:0];
			uart_reset <= 1'b1;
		end else
			uart_reset <= 1'b0;

	reg	tx_uart_reset;

	//
	// First the UART receiver
	//
	wire		rx_stb, rx_break, rx_perr, rx_ferr, ck_uart;
	wire	[7:0]	rx_uart_data;
	reg		rx_uart_reset;
	rxuart	#(UART_SETUP) rx(i_clk, (i_rst)||(rx_uart_reset),
			uart_setup, i_uart_rx,
			rx_stb, rx_uart_data, rx_break,
			rx_perr, rx_ferr, ck_uart);

	wire		rx_empty_n, rx_fifo_err;
	wire	[7:0]	rxf_wb_data;
	wire	[15:0]	rxf_status;
	reg		rxf_wb_read;
	// which leads right into it's attached FIFO
	ufifo	#(.LGFLEN(LGFLEN))
		rxfifo(i_clk, (i_rst)||(rx_break)||(rx_uart_reset),
			rx_stb, rx_uart_data,
			rxf_wb_read, rxf_wb_data,
			(rx_empty_n), (o_uart_rxfifo_int),
			rxf_status, rx_fifo_err);
	assign	o_uart_rx_int = !rx_empty_n;

	initial	rxf_wb_read = 1'b0;
	always @(posedge i_clk)
		rxf_wb_read <= (i_wb_stb)&&(i_wb_addr[1:0]==`UART_RXREG)&&(!i_wb_we);

	reg	r_rx_perr, r_rx_ferr;
	initial	r_rx_perr = 1'b0;
	initial	r_rx_ferr = 1'b0;
	always @(posedge i_clk)
		if ((rx_uart_reset)||(rx_break))
		begin
			r_rx_perr <= 1'b0;
			r_rx_ferr <= 1'b0;
		end else if ((i_wb_stb)&&(i_wb_addr[1:0]==`UART_RXREG)&&(i_wb_we))
		begin
			r_rx_perr <= (r_rx_perr)&&(~i_wb_data[9]);
			r_rx_ferr <= (r_rx_ferr)&&(~i_wb_data[10]);
		end else if (rx_stb)
		begin
			r_rx_perr <= (r_rx_perr)||(rx_perr);
			r_rx_ferr <= (r_rx_ferr)||(rx_ferr);
		end

	initial	rx_uart_reset = 1'b1;
	always @(posedge i_clk)
		if (uart_reset)
			rx_uart_reset <= 1'b1;
		else if ((i_wb_stb)&&(i_wb_addr[1:0]==`UART_RXREG)&&(i_wb_we))
			rx_uart_reset <= i_wb_data[12];
		else
			rx_uart_reset <= 1'b0;

	wire	[31:0]	wb_rx_data;
	assign	wb_rx_data = { 16'h00,
				3'h0, rx_fifo_err,
				rx_break, rx_ferr, r_rx_perr, !rx_empty_n,
				rxf_wb_data};

	//
	// Then the UART transmitter
	//
	wire		tx_empty_n, txf_half_full, txf_err;
	wire	[7:0]	tx_data;
	wire	[15:0]	txf_status;
	reg		r_tx_break, txf_wb_write;
	reg	[7:0]	txf_wb_data;

	initial	txf_wb_write = 1'b0;
	always @(posedge i_clk)
	begin
		txf_wb_write <= (i_wb_stb)&&(i_wb_addr == `UART_TXREG)&&(i_wb_we);
		txf_wb_data  <= i_wb_data[7:0];
	end

	ufifo	#(.LGFLEN(LGFLEN))
		txfifo(i_clk, (i_rst)||(r_tx_break)||(tx_uart_reset),
			txf_wb_write, txf_wb_data,
				(~tx_busy)&&(tx_empty_n), tx_data,
			tx_empty_n, txf_half_full, txf_status, txf_err);
	assign	o_uart_tx_int = tx_empty_n;
	assign	o_uart_txfifo_int = !txf_half_full;

	initial	r_tx_break = 1'b0;
	always @(posedge i_clk)
		if (i_rst)
			r_tx_break <= 1'b0;
		else if ((i_wb_stb)&&(i_wb_addr[1:0]==`UART_TXREG)&&(i_wb_we))
			r_tx_break <= i_wb_data[9];

	initial	tx_uart_reset = 1'b1;
	always @(posedge i_clk)
		if (uart_reset)
			tx_uart_reset <= 1'b1;
		else if ((i_wb_stb)&&(i_wb_addr[1:0]==`UART_TXREG)&&(i_wb_we))
			tx_uart_reset <= i_wb_data[12];
		else
			tx_uart_reset <= 1'b0;

	wire	tx_busy;
	txuart	#(UART_SETUP) tx(i_clk, 1'b0, uart_setup,
			r_tx_break, (tx_empty_n), tx_data,
			o_uart_tx, tx_busy);

	wire	[31:0]	wb_tx_data;
	assign	wb_tx_data = { 16'h00, 
				1'h0, txf_err, txf_half_full, tx_empty_n,
				ck_uart, o_uart_tx, r_tx_break, tx_busy,
				txf_wb_data};

	wire	[31:0]	wb_fifo_data;
	assign	wb_fifo_data = { txf_status, rxf_status };

	always @(posedge i_clk)
		casez(i_wb_addr)
		`UART_SETUP: o_wb_data <= { 2'b00, uart_setup };
		`UART_FIFO:  o_wb_data <= wb_fifo_data;
		`UART_RXREG: o_wb_data <= wb_rx_data;
		`UART_TXREG: o_wb_data <= wb_tx_data;
		endcase

	assign	o_wb_stall = 1'b0;

endmodule
