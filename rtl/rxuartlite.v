////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	rxuartlite.v
//
// Project:	wbuart32, a full featured UART with simulator
//
// Purpose:	Receive and decode inputs from a single UART line.
//
//
//	To interface with this module, connect it to your system clock,
//	and a UART input.  Set the parameter to the number of clocks per
//	baud.  When data becomes available, the o_wr line will be asserted
//	for one clock cycle.
//
//	This interface only handles 8N1 serial port communications.  It does
//	not handle the break, parity, or frame error conditions.
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2018, Gisselquist Technology, LLC
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
// with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
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
`default_nettype	none
//
`define	RXUL_BIT_ZERO		4'h0
`define	RXUL_BIT_ONE		4'h1
`define	RXUL_BIT_TWO		4'h2
`define	RXUL_BIT_THREE		4'h3
`define	RXUL_BIT_FOUR		4'h4
`define	RXUL_BIT_FIVE		4'h5
`define	RXUL_BIT_SIX		4'h6
`define	RXUL_BIT_SEVEN		4'h7
`define	RXUL_STOP		4'h8
`define	RXUL_WAIT		4'h9
`define	RXUL_IDLE		4'hf

module rxuartlite(i_clk, i_uart_rx, o_wr, o_data);
	parameter			TIMER_BITS = 10;
	parameter  [(TIMER_BITS-1):0]	CLOCKS_PER_BAUD = 868;	// 115200 MBaud at 100MHz
	localparam			TB = TIMER_BITS;
	input	wire		i_clk;
	input	wire		i_uart_rx;
	output	reg		o_wr;
	output	reg	[7:0]	o_data;


	wire	[(TB-1):0]	half_baud;
	reg	[3:0]		state;

	assign	half_baud = { 1'b0, CLOCKS_PER_BAUD[(TB-1):1] };
	reg	[(TB-1):0]	baud_counter;
	reg			zero_baud_counter;


	// Since this is an asynchronous receiver, we need to register our
	// input a couple of clocks over to avoid any problems with 
	// metastability.  We do that here, and then ignore all but the
	// ck_uart wire.
	reg	q_uart, qq_uart, ck_uart;
	initial	q_uart  = 1'b1;
	initial	qq_uart = 1'b1;
	initial	ck_uart = 1'b1;
	always @(posedge i_clk)
		{ ck_uart, qq_uart, q_uart } <= { qq_uart, q_uart, i_uart_rx };

	// Keep track of the number of clocks since the last change.
	//
	// This is used to determine if we are in either a break or an idle
	// condition, as discussed further below.
	reg	[(TB-1):0]	chg_counter;
	initial	chg_counter = {(TB){1'b1}};
	always @(posedge i_clk)
		if (qq_uart != ck_uart)
			chg_counter <= 0;
		else if (chg_counter != { (TB){1'b1} })
			chg_counter <= chg_counter + 1;

	// Are we in the middle of a baud iterval?  Specifically, are we
	// in the middle of a start bit?  Set this to high if so.  We'll use
	// this within our state machine to transition out of the IDLE
	// state.
	reg	half_baud_time;
	initial	half_baud_time = 0;
	always @(posedge i_clk)
		half_baud_time <= (!ck_uart)&&(chg_counter >= half_baud-1'b1-1'b1);


	initial	state = `RXUL_IDLE;
	always @(posedge i_clk)
	begin
		if (state == `RXUL_IDLE)
		begin // Idle state, independent of baud counter
			// By default, just stay in the IDLE state
			state <= `RXUL_IDLE;
			if ((!ck_uart)&&(half_baud_time))
				// UNLESS: We are in the center of a valid
				// start bit
				state <= `RXUL_BIT_ZERO;
		end else if ((state >= `RXUL_WAIT)&&(ck_uart))
			state <= `RXUL_IDLE;
		else if (zero_baud_counter)
		begin
			if (state <= `RXUL_STOP)
				// Data arrives least significant bit first.
				// By the time this is clocked in, it's what
				// you'll have.
				state <= state + 1;
		end
	end

	// Data bit capture logic.
	//
	// This is drastically simplified from the state machine above, based
	// upon: 1) it doesn't matter what it is until the end of a captured
	// byte, and 2) the data register will flush itself of any invalid
	// data in all other cases.  Hence, let's keep it real simple.
	reg	[7:0]	data_reg;
	always @(posedge i_clk)
		if ((zero_baud_counter)&&(state != `RXUL_STOP))
			data_reg <= { qq_uart, data_reg[7:1] };

	// Our data bit logic doesn't need nearly the complexity of all that
	// work above.  Indeed, we only need to know if we are at the end of
	// a stop bit, in which case we copy the data_reg into our output
	// data register, o_data, and tell others (for one clock) that data is
	// available.
	//
	initial	o_wr = 1'b0;
	initial	o_data = 8'h00;
	always @(posedge i_clk)
		if ((zero_baud_counter)&&(state == `RXUL_STOP)&&(ck_uart))
		begin
			o_wr   <= 1'b1;
			o_data <= data_reg;
		end else
			o_wr   <= 1'b0;

	// The baud counter
	//
	// This is used as a "clock divider" if you will, but the clock needs
	// to be reset before any byte can be decoded.  In all other respects,
	// we set ourselves up for CLOCKS_PER_BAUD counts between baud
	// intervals.
	initial	baud_counter = 0;
	always @(posedge i_clk)
		if (((state==`RXUL_IDLE))&&(!ck_uart)&&(half_baud_time))
			baud_counter <= CLOCKS_PER_BAUD-1'b1;
		else if (state == `RXUL_WAIT)
			baud_counter <= 0;
		else if ((zero_baud_counter)&&(state < `RXUL_STOP))
			baud_counter <= CLOCKS_PER_BAUD-1'b1;
		else if (!zero_baud_counter)
			baud_counter <= baud_counter-1'b1;

	// zero_baud_counter
	//
	// Rather than testing whether or not (baud_counter == 0) within our
	// (already too complicated) state transition tables, we use
	// zero_baud_counter to pre-charge that test on the clock
	// before--cleaning up some otherwise difficult timing dependencies.
	initial	zero_baud_counter = 1'b1;
	always @(posedge i_clk)
		if ((state == `RXUL_IDLE)&&(!ck_uart)&&(half_baud_time))
			zero_baud_counter <= 1'b0;
		else if (state == `RXUL_WAIT)
			zero_baud_counter <= 1'b1;
		else if ((zero_baud_counter)&&(state < `RXUL_STOP))
			zero_baud_counter <= 1'b0;
		else if (baud_counter == 1)
			zero_baud_counter <= 1'b1;

`ifdef	FORMAL
`define	FORMAL_VERILATOR
`else
`ifdef	VERILATOR
`define	FORMAL_VERILATOR
`endif
`endif

`ifdef	FORMAL

`define ASSUME	assume

`define	PHASE_ONE_ASSERT	assert
`define	PHASE_TWO_ASSERT	assert

`ifdef	PHASE_TWO
`undef	PHASE_ONE_ASSERT
`define	PHASE_ONE_ASSERT	assume
`endif

	localparam	F_CKRES = 10;

	wire			f_tx_start, f_tx_busy;
	wire	[(F_CKRES-1):0]	f_tx_step;
	reg			f_tx_zclk;
	reg	[(TB-1):0]	f_tx_timer;
	wire	[7:0]		f_rx_newdata;
	reg	[(TB-1):0]	f_tx_baud;
	wire			f_tx_zbaud;

	wire	[(TB-1):0]	f_max_baud_difference;
	reg	[(TB-1):0]	f_baud_difference;
	reg	[(TB+3):0]	f_tx_count, f_rx_count;
	wire	[7:0]		f_tx_data;



	wire			f_txclk;
	reg	[1:0]		f_rx_clock;
	reg	[(F_CKRES-1):0]	f_tx_clock;
	reg			f_past_valid, f_past_valid_tx;

	initial	f_past_valid = 1'b0;
	always @(posedge i_clk)
		f_past_valid <= 1'b1;

`ifdef	F_OPT_CLK2FFLOGIC
	initial	f_rx_clock = 3'h0;
	always @($global_clock)
		f_rx_clock <= f_rx_clock + 1'b1;

	always @(*)
		assume(i_clk == f_rx_clock[1]);
`endif



	///////////////////////////////////////////////////////////
	//
	//
	// Generate a transmitted signal
	//
	//
	///////////////////////////////////////////////////////////


	// First, calculate the transmit clock
	localparam [(F_CKRES-1):0] F_MIDSTEP = { 2'b01, {(F_CKRES-2){1'b0}} };
	//
	// Need to allow us to slip by half a baud clock over 10 baud intervals
	//
	// (F_STEP / (2^F_CKRES)) * (CLOCKS_PER_BAUD)*10 < CLOCKS_PER_BAUD/2
	// F_STEP * 2 * 10 < 2^F_CKRES
	localparam [(F_CKRES-1):0] F_HALFSTEP= F_MIDSTEP/32;
	localparam [(F_CKRES-1):0] F_MINSTEP = F_MIDSTEP - F_HALFSTEP + 1;
	localparam [(F_CKRES-1):0] F_MAXSTEP = F_MIDSTEP + F_HALFSTEP - 1;

	initial assert(F_MINSTEP <= F_MIDSTEP);
	initial assert(F_MIDSTEP <= F_MAXSTEP);

`ifdef	F_OPT_CLK2FFLOGIC
	assign	f_tx_step = $anyconst;
	//	assume((f_tx_step >= F_MINSTEP)&&(f_tx_step <= F_MAXSTEP));
	//
	//
	always @(*) assume((f_tx_step == F_MINSTEP)
			||(f_tx_step == F_MIDSTEP)
			||(f_tx_step == F_MAXSTEP));

	// initial	rx_clock = $anyseq;
	always @($global_clock)
		f_tx_clock <= f_tx_clock + f_tx_step;

	assign	f_txclk = f_tx_clock[F_CKRES-1];
`else
	assign	f_tx_clk = i_clk;
`endif
	// 
	initial	f_past_valid_tx = 1'b0;
	always @(posedge f_txclk)
		f_past_valid_tx <= 1'b1;

	initial	assume(i_uart_rx);


	//////////////////////////////////////////////
	//
	//
	// Build a simulated transmitter
	//
	//
	//////////////////////////////////////////////
	//
	// First, the simulated timing generator

	// parameter	TIMER_BITS = 10;
	// parameter [(TIMER_BITS-1):0] CLOCKS_PER_BAUD = 868;
	// localparam	TB = TIMER_BITS;

	assign	f_tx_start = $anyseq;
	always @(*)
	if (f_tx_busy)
		assume(!f_tx_start);

	initial	f_tx_baud = 0;
	always @(posedge f_txclk)
	if ((f_tx_zbaud)&&((f_tx_busy)||(f_tx_start)))
		f_tx_baud <= CLOCKS_PER_BAUD-1'b1;
	else if (!f_tx_zbaud)
		f_tx_baud <= f_tx_baud - 1'b1;

	always @(*)
		`PHASE_ONE_ASSERT(f_tx_baud < CLOCKS_PER_BAUD);

	always @(*)
	if (!f_tx_busy)
		`PHASE_ONE_ASSERT(f_tx_baud == 0);

	assign	f_tx_zbaud = (f_tx_baud == 0);

	// Pick some data to transmit
	assign	f_tx_data = $anyseq;

	// But only if we aren't busy
	initial	assume(f_tx_data == 0);
	always @(posedge f_txclk)
	if ((!f_tx_zbaud)||(f_tx_busy)||(!f_tx_start))
		assume(f_tx_data == $past(f_tx_data));

	// Force the data to change on a clock only
	always @($global_clock)
	if ((f_past_valid)&&(!$rose(f_txclk)))
		assume($stable(f_tx_data));
	else if (f_tx_busy)
		assume($stable(f_tx_data));

	//
	always @($global_clock)
	if ((!f_past_valid)||(!$rose(f_txclk)))
	begin
		assume($stable(f_tx_start));
		assume($stable(f_tx_data));
	end

	//
	//
	//

	reg	[9:0]	f_tx_reg;
	reg		f_tx_busy;

	// Here's the transmitter itself (roughly)
	initial	f_tx_busy   = 1'b0;
	initial	f_tx_reg    = 0;
	always @(posedge f_txclk)
	if (!f_tx_zbaud)
	begin
		`PHASE_ONE_ASSERT(f_tx_busy);
	end else begin
		f_tx_reg  <= { 1'b0, f_tx_reg[9:1] };
		if (f_tx_start)
			f_tx_reg <= { 1'b1, f_tx_data, 1'b0 };
	end

	// Create a busy flag that we'll use
	always @(*)
	if (!f_tx_zbaud)
		f_tx_busy <= 1'b1;
	else if (|f_tx_reg)
		f_tx_busy <= 1'b1;
	else
		f_tx_busy <= 1'b0;

	//
	// Tie the TX register to the TX data
	always @(posedge f_txclk)
	if (f_tx_reg[9])
		`PHASE_ONE_ASSERT(f_tx_reg[8:0] == { f_tx_data, 1'b0 });
	else if (f_tx_reg[8])
		`PHASE_ONE_ASSERT(f_tx_reg[7:0] == f_tx_data[7:0] );
	else if (f_tx_reg[7])
		`PHASE_ONE_ASSERT(f_tx_reg[6:0] == f_tx_data[7:1] );
	else if (f_tx_reg[6])
		`PHASE_ONE_ASSERT(f_tx_reg[5:0] == f_tx_data[7:2] );
	else if (f_tx_reg[5])
		`PHASE_ONE_ASSERT(f_tx_reg[4:0] == f_tx_data[7:3] );
	else if (f_tx_reg[4])
		`PHASE_ONE_ASSERT(f_tx_reg[3:0] == f_tx_data[7:4] );
	else if (f_tx_reg[3])
		`PHASE_ONE_ASSERT(f_tx_reg[2:0] == f_tx_data[7:5] );
	else if (f_tx_reg[2])
		`PHASE_ONE_ASSERT(f_tx_reg[1:0] == f_tx_data[7:6] );
	else if (f_tx_reg[1])
		`PHASE_ONE_ASSERT(f_tx_reg[0] == f_tx_data[7]);

	// Our counter since we start
	initial	f_tx_count = 0;
	always @(posedge f_txclk)
	if (!f_tx_busy)
		f_tx_count <= 0;
	else
		f_tx_count <= f_tx_count + 1'b1;

	always @(*)
	if (f_tx_reg == 10'h0)
		assume(i_uart_rx);
	else
		assume(i_uart_rx == f_tx_reg[0]);

	//
	// Make sure the absolute transmit clock timer matches our state
	//
	always @(posedge f_txclk)
	if (!f_tx_busy)
	begin
		if ((!f_past_valid_tx)||(!$past(f_tx_busy)))
			`PHASE_ONE_ASSERT(f_tx_count == 0);
	end else if (f_tx_reg[9])
		`PHASE_ONE_ASSERT(f_tx_count ==
				    CLOCKS_PER_BAUD -1 -f_tx_baud);
	else if (f_tx_reg[8])
		`PHASE_ONE_ASSERT(f_tx_count ==
				2 * CLOCKS_PER_BAUD -1 -f_tx_baud);
	else if (f_tx_reg[7])
		`PHASE_ONE_ASSERT(f_tx_count ==
				3 * CLOCKS_PER_BAUD -1 -f_tx_baud);
	else if (f_tx_reg[6])
		`PHASE_ONE_ASSERT(f_tx_count ==
				4 * CLOCKS_PER_BAUD -1 -f_tx_baud);
	else if (f_tx_reg[5])
		`PHASE_ONE_ASSERT(f_tx_count ==
				5 * CLOCKS_PER_BAUD -1 -f_tx_baud);
	else if (f_tx_reg[4])
		`PHASE_ONE_ASSERT(f_tx_count ==
				6 * CLOCKS_PER_BAUD -1 -f_tx_baud);
	else if (f_tx_reg[3])
		`PHASE_ONE_ASSERT(f_tx_count ==
				7 * CLOCKS_PER_BAUD -1 -f_tx_baud);
	else if (f_tx_reg[2])
		`PHASE_ONE_ASSERT(f_tx_count ==
				8 * CLOCKS_PER_BAUD -1 -f_tx_baud);
	else if (f_tx_reg[1])
		`PHASE_ONE_ASSERT(f_tx_count ==
				9 * CLOCKS_PER_BAUD -1 -f_tx_baud);
	else if (f_tx_reg[0])
		`PHASE_ONE_ASSERT(f_tx_count ==
				10 * CLOCKS_PER_BAUD -1 -f_tx_baud);
	else
		`PHASE_ONE_ASSERT(f_tx_count ==
				11 * CLOCKS_PER_BAUD -1 -f_tx_baud);


	///////////////////////////////////////
	//
	// Receiver
	//
	///////////////////////////////////////
	//
	// Count RX clocks since the start of the first stop bit, measured in
	// rx clocks
	initial	f_rx_count = 0;
	always @(posedge i_clk)
	if (state == `RXUL_IDLE)
		f_rx_count = (!ck_uart) ? (chg_counter+2) : 0;
	else
		f_rx_count <= f_rx_count + 1'b1;
	always @(posedge i_clk)
	if (state == 0)
		`PHASE_ONE_ASSERT(f_rx_count
				== half_baud + (CLOCKS_PER_BAUD-baud_counter));
	else if (state == 1)
		`PHASE_ONE_ASSERT(f_rx_count == half_baud + 2 * CLOCKS_PER_BAUD
					- baud_counter);
	else if (state == 2)
		`PHASE_ONE_ASSERT(f_rx_count == half_baud + 3 * CLOCKS_PER_BAUD
					- baud_counter);
	else if (state == 3)
		`PHASE_ONE_ASSERT(f_rx_count == half_baud + 4 * CLOCKS_PER_BAUD
					- baud_counter);
	else if (state == 4)
		`PHASE_ONE_ASSERT(f_rx_count == half_baud + 5 * CLOCKS_PER_BAUD
					- baud_counter);
	else if (state == 5)
		`PHASE_ONE_ASSERT(f_rx_count == half_baud + 6 * CLOCKS_PER_BAUD
					- baud_counter);
	else if (state == 6)
		`PHASE_ONE_ASSERT(f_rx_count == half_baud + 7 * CLOCKS_PER_BAUD
					- baud_counter);
	else if (state == 7)
		`PHASE_ONE_ASSERT(f_rx_count == half_baud + 8 * CLOCKS_PER_BAUD
					- baud_counter);
	else if (state == 8)
		`PHASE_ONE_ASSERT((f_rx_count == half_baud + 9 * CLOCKS_PER_BAUD
					- baud_counter)
			||(f_rx_count == half_baud + 10 * CLOCKS_PER_BAUD
					- baud_counter));

	always @(*)
		`PHASE_ONE_ASSERT( ((!zero_baud_counter)
				&&(state == `RXUL_IDLE)
				&&(baud_counter == 0))
			||((zero_baud_counter)&&(baud_counter == 0))
			||((!zero_baud_counter)&&(baud_counter != 0)));

	always @(posedge i_clk)
	if (!f_past_valid)
		`PHASE_ONE_ASSERT((state == `RXUL_IDLE)&&(baud_counter == 0)
			&&(zero_baud_counter));

	always @(*)
	begin
		`PHASE_ONE_ASSERT({ ck_uart,qq_uart,q_uart,i_uart_rx } != 4'h2);
		`PHASE_ONE_ASSERT({ ck_uart,qq_uart,q_uart,i_uart_rx } != 4'h4);
		`PHASE_ONE_ASSERT({ ck_uart,qq_uart,q_uart,i_uart_rx } != 4'h5);
		`PHASE_ONE_ASSERT({ ck_uart,qq_uart,q_uart,i_uart_rx } != 4'h6);
		`PHASE_ONE_ASSERT({ ck_uart,qq_uart,q_uart,i_uart_rx } != 4'h9);
		`PHASE_ONE_ASSERT({ ck_uart,qq_uart,q_uart,i_uart_rx } != 4'ha);
		`PHASE_ONE_ASSERT({ ck_uart,qq_uart,q_uart,i_uart_rx } != 4'hb);
		`PHASE_ONE_ASSERT({ ck_uart,qq_uart,q_uart,i_uart_rx } != 4'hd);
	end

	always @(posedge i_clk)
	if ((f_past_valid)&&($past(state) >= `RXUL_WAIT)&&($past(ck_uart)))
		`PHASE_ONE_ASSERT(state == `RXUL_IDLE);

	always @(posedge i_clk)
	if ((f_past_valid)&&($past(state) >= `RXUL_WAIT)
			&&(($past(state) != `RXUL_IDLE)||(state == `RXUL_IDLE)))
		`PHASE_ONE_ASSERT(zero_baud_counter);

	// Calculate an absolute value of the difference between the two baud
	// clocks
`ifdef	PHASE_TWO
	always @(posedge i_clk)
	if ((f_past_valid)&&($past(state)==`RXUL_IDLE)&&(state == `RXUL_IDLE))
	begin
		`PHASE_TWO_ASSERT(($past(ck_uart))
			||(chg_counter <=
				{ 1'b0, CLOCKS_PER_BAUD[(TB-1):1] }));
	end

	always @(posedge f_txclk)
	if (!f_past_valid_tx)
		`PHASE_TWO_ASSERT((state == `RXUL_IDLE)&&(baud_counter == 0)
			&&(zero_baud_counter)&&(!f_tx_busy));

	wire	[(TB+3):0]	f_tx_count_two_clocks_ago;
	assign	f_tx_count_two_clocks_ago = f_tx_count - 2;
	always @(*)
	if (f_tx_count >= f_rx_count + 2)
		f_baud_difference = f_tx_count_two_clocks_ago - f_rx_count;
	else
		f_baud_difference = f_rx_count - f_tx_count_two_clocks_ago;

	localparam	F_SYNC_DLY = 8;

	wire	[(TB+4+F_CKRES-1):0]	f_sub_baud_difference;
	reg	[F_CKRES-1:0]	ck_tx_clock;
	reg	[((F_SYNC_DLY-1)*F_CKRES)-1:0]	q_tx_clock;
	reg	[TB+3:0]	ck_tx_count;
	reg	[(F_SYNC_DLY-1)*(TB+4)-1:0]	q_tx_count;
	initial	q_tx_count = 0;
	initial	ck_tx_count = 0;
	initial	q_tx_clock = 0;
	initial	ck_tx_clock = 0;
	always @($global_clock)
		{ ck_tx_clock, q_tx_clock } <= { q_tx_clock, f_tx_clock };
	always @($global_clock)
		{ ck_tx_count, q_tx_count } <= { q_tx_count, f_tx_count };


	wire	[TB+4+F_CKRES-1:0]	f_ck_tx_time, f_rx_time;
	always @(*)
		f_ck_tx_time = { ck_tx_count, !ck_tx_clock[F_CKRES-1],
						ck_tx_clock[F_CKRES-2:0] };
	always @(*)
		f_rx_time = { f_rx_count, !f_rx_clock[1], f_rx_clock[0],
						{(F_CKRES-2){1'b0}} };

	wire	[TB+4+F_CKRES-1:0]	f_signed_difference;
	always @(*)
		f_signed_difference = f_ck_tx_time - f_rx_time;

	always @(*)
	if (f_signed_difference[TB+4+F_CKRES-1])
		f_sub_baud_difference = -f_signed_difference;
	else
		f_sub_baud_difference =  f_signed_difference;

	always @($global_clock)
	if (state == `RXUL_WAIT)
		`PHASE_TWO_ASSERT((!f_tx_busy)||(f_tx_reg[9:1] == 0));

	always @($global_clock)
	if (state == `RXUL_IDLE)
	begin
		`PHASE_TWO_ASSERT((!f_tx_busy)||(f_tx_reg[9])||(f_tx_reg[9:1]==0));
		if (!ck_uart)
			;//`PHASE_TWO_ASSERT((f_rx_count < 4)||(f_sub_baud_difference <= ((CLOCKS_PER_BAUD<<F_CKRES)/20)));
		else
			`PHASE_TWO_ASSERT((f_tx_reg[9:1]==0)||(f_tx_count < (3 + CLOCKS_PER_BAUD/2)));
	end else if (state == 0)
		`PHASE_TWO_ASSERT(f_sub_baud_difference
				<=  2 * ((CLOCKS_PER_BAUD<<F_CKRES)/20));
	else if (state == 1)
		`PHASE_TWO_ASSERT(f_sub_baud_difference
				<=  3 * ((CLOCKS_PER_BAUD<<F_CKRES)/20));
	else if (state == 2)
		`PHASE_TWO_ASSERT(f_sub_baud_difference
				<=  4 * ((CLOCKS_PER_BAUD<<F_CKRES)/20));
	else if (state == 3)
		`PHASE_TWO_ASSERT(f_sub_baud_difference
				<=  5 * ((CLOCKS_PER_BAUD<<F_CKRES)/20));
	else if (state == 4)
		`PHASE_TWO_ASSERT(f_sub_baud_difference
				<=  6 * ((CLOCKS_PER_BAUD<<F_CKRES)/20));
	else if (state == 5)
		`PHASE_TWO_ASSERT(f_sub_baud_difference
				<=  7 * ((CLOCKS_PER_BAUD<<F_CKRES)/20));
	else if (state == 6)
		`PHASE_TWO_ASSERT(f_sub_baud_difference
				<=  8 * ((CLOCKS_PER_BAUD<<F_CKRES)/20));
	else if (state == 7)
		`PHASE_TWO_ASSERT(f_sub_baud_difference
				<=  9 * ((CLOCKS_PER_BAUD<<F_CKRES)/20));
	else if (state == 8)
		`PHASE_TWO_ASSERT(f_sub_baud_difference
				<= 10 * ((CLOCKS_PER_BAUD<<F_CKRES)/20));

	always @(posedge i_clk)
	if (o_wr)
		`PHASE_TWO_ASSERT(o_data == $past(f_tx_data,4));

	// always @(posedge i_clk)
	// if ((zero_baud_counter)&&(state != 4'hf)&&(CLOCKS_PER_BAUD > 6))
		// assert(i_uart_rx == ck_uart);

	// Make sure the data register matches
	always @(posedge i_clk)
	// if ((f_past_valid)&&(state != $past(state)))
	begin
		if (state == 4'h0)
			`PHASE_TWO_ASSERT(!data_reg[7]);

		if (state == 4'h1)
			`PHASE_TWO_ASSERT((data_reg[7]
				== $past(f_tx_data[0]))&&(!data_reg[6]));

		if (state == 4'h2)
			`PHASE_TWO_ASSERT(data_reg[7:6]
					== $past(f_tx_data[1:0]));

		if (state == 4'h3)
			`PHASE_TWO_ASSERT(data_reg[7:5] == $past(f_tx_data[2:0]));

		if (state == 4'h4)
			`PHASE_TWO_ASSERT(data_reg[7:4] == $past(f_tx_data[3:0]));

		if (state == 4'h5)
			`PHASE_TWO_ASSERT(data_reg[7:3] == $past(f_tx_data[4:0]));

		if (state == 4'h6)
			`PHASE_TWO_ASSERT(data_reg[7:2] == $past(f_tx_data[5:0]));

		if (state == 4'h7)
			`PHASE_TWO_ASSERT(data_reg[7:1] == $past(f_tx_data[6:0]));

		if (state == 4'h8)
			`PHASE_TWO_ASSERT(data_reg[7:0] == $past(f_tx_data[7:0]));
	end

	always @(posedge i_clk)
		cover(o_wr);
`endif
`endif
`ifdef	FORMAL_VERILATOR
	// FORMAL properties which can be tested via Verilator as well as
	// Yosys FORMAL
	always @(*)
		assert((state == 4'hf)||(state <= `RXUL_WAIT));
	always @(*)
		assert(zero_baud_counter == (baud_counter == 0)? 1'b1:1'b0);
	always @(*)
		assert(baud_counter <= CLOCKS_PER_BAUD-1'b1);

`endif

endmodule


