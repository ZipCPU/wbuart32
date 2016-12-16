////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	helloworld.v
//
// Project:	wbuart32, a full featured UART with simulator
//
// Purpose:	To create a *very* simple UART test program, which can be used
//		as the top level design file of any FPGA program.
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
module	helloworld(i_clk, i_setup, o_uart);
	input		i_clk;
	input	[29:0]	i_setup;
	output	wire	o_uart;

	reg	pwr_reset;
	initial	pwr_reset = 1'b1;
	always @(posedge i_clk)
		pwr_reset <= 1'b0;

	reg	[7:0]	message	[0:15];
	initial	message[0] = "H";
	initial	message[1] = "e";
	initial	message[2] = "l";
	initial	message[3] = "l";
	initial	message[4] = "o";
	initial	message[5] = ",";
	initial	message[6] = " ";
	initial	message[7] = "W";
	initial	message[8] = "o";
	initial	message[9] = "r";
	initial	message[10] = "l";
	initial	message[11] = "d";
	initial	message[12] = "!";
	initial	message[13] = " ";
	initial	message[14] = "\r";
	initial	message[15] = "\n";

	reg	[27:0]	counter;
	initial	counter = 28'hffffff0;
	always @(posedge i_clk)
		counter <= counter + 1'b1;

	wire		tx_break, tx_busy;
	reg		tx_stb;
	reg	[3:0]	tx_index;
	reg	[7:0]	tx_data;

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

	txuart	transmitter(i_clk, pwr_reset, i_setup, tx_break,
			tx_stb, tx_data, o_uart, tx_busy);

endmodule
