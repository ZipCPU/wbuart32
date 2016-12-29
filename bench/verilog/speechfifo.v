////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	speechfifo.v
//
// Project:	wbuart32, a full featured UART with simulator
//
// Purpose:	To test/demonstrate/prove the wishbone access to the FIFO'd
//		UART via sending more information than the FIFO can hold,
//	and then verifying that this was the value received.
//
//	To do this, we "borrow" a copy of Lincolns Gettysburg address, make
//	certain that the FIFO isn't large enough to hold it, and then try
//	to send this address every couple of minutes.
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
module	speechfifo(i_clk, i_setup, o_uart);
	input		i_clk;
	input	[29:0]	i_setup;
	output	wire	o_uart;

	reg		wb_stb;
	reg	[1:0]	wb_addr;
	reg	[31:0]	wb_data;

	wire		uart_stall, uart_ack;
	wire	[31:0]	uart_data;

	wire		tx_empty_n, txfifo_int;

	reg	pwr_reset;
	initial	pwr_reset = 1'b1;
	always @(posedge i_clk)
		pwr_reset <= 1'b0;

	integer	i;
	reg	[7:0]	message [0:2047];
	initial begin
		for(i=0; i<2048; i=i+1)
			message[i] = 8'h20;
		$readmemh("speech.hex",message);
	end

	reg	[30:0]	restart_counter;
	initial	restart_counter = -31'hd16;
	always @(posedge i_clk)
		restart_counter <= restart_counter+1'b1;

	reg	[2:0]	restart;
	initial	restart = 3'b0;
	always @(posedge i_clk)
	begin
		restart[2:1] <= restart[1:0];
		restart[0] <= (restart_counter == 0);
	end

	reg	[10:0]	msg_index;
	initial	msg_index = 11'd2040;
	always @(posedge i_clk)
	begin
		if (restart[0])
			msg_index <= 0;
		else if ((wb_stb)&&(!uart_stall)&&(restart[0]==1'b0))
			msg_index <= msg_index + 1'b1;
	end

	always @(posedge i_clk)
		if (restart[0])
			wb_data <= { 2'b00, i_setup };
		else if ((wb_stb)&&(!uart_stall))
			wb_data <= { 24'h00, message[msg_index] };

	always @(posedge i_clk)
		if (restart[0])
			wb_addr <= 2'b00;
		else
			wb_addr <= 2'b11;

	initial	wb_stb = 1'b0;
	always @(posedge i_clk)
		if (restart[0])
			wb_stb <= 1'b1;
		else if (restart[1])
			wb_stb <= 1'b0;
		else if (restart[2])
			wb_stb <= 1'b1;
		else if (msg_index >= 1497)
			wb_stb <= 1'b0;
		else if (!tx_empty_n)
			wb_stb <= 1'b1;
		else if (txfifo_int)
			wb_stb <= wb_stb;
		else
			wb_stb <= 1'b0;


	wire	ignored_rx_int, ignored_rxfifo_int;

	wbuart	#(30'h25)
		wbuarti(i_clk, pwr_reset,
			wb_stb, wb_stb, 1'b1, wb_addr, wb_data,
			uart_stall, uart_ack, uart_data,
			1'b1, o_uart,
			ignored_rx_int, tx_empty_n,
			ignored_rxfifo_int, txfifo_int);

endmodule
