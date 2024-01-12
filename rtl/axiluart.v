////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	axiluart
// {{{
// Project:	wbuart32, a full featured UART with simulator
//
// Purpose:	A basic AXI-Lite serial port controller.  It has the same
//		interface as the WBUART core in the same directory.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2020-2024, Gisselquist Technology, LLC
// {{{
//
// This program is free software (firmware): you can redistribute it and/or
// modify it under the terms of the GNU General Public License as published
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
// }}}
//
`default_nettype none
//
module	axiluart #(
		// {{{
		// 4MB 8N1, when using 100MHz clock
		parameter [30:0] INITIAL_SETUP = 31'd25,
		//
		// LGFLEN: The log (based two) of our FIFOs size.  Maxes out
		// at 10, representing a FIFO length of 1024.
		parameter [3:0]	LGFLEN = 4,
		//
		// HARDWARE_FLOW_CONTROL_PRESET controls whether or not we
		// ignore the RTS/CTS signaling.  If present, we only start
		// transmitting if 
		parameter [0:0]	HARDWARE_FLOW_CONTROL_PRESENT = 1'b1,
		// Perform a simple/quick bounds check on the log FIFO length,
		// to make sure its within the bounds we can support with our
		// current interface.
		localparam [3:0]	LCLLGFLEN = (LGFLEN > 4'ha)? 4'ha
					: ((LGFLEN < 4'h2) ? 4'h2 : LGFLEN),
		//
		// Size of the AXI-lite bus.  These are fixed, since 1) AXI-lite
		// is fixed at a width of 32-bits by Xilinx def'n, and 2) since
		// we only ever have 4 configuration words.
		parameter	C_AXI_ADDR_WIDTH = 4,
		localparam	C_AXI_DATA_WIDTH = 32,
		parameter [0:0]	OPT_SKIDBUFFER = 1'b0,
		parameter [0:0]	OPT_LOWPOWER = 0,
		localparam	ADDRLSB = $clog2(C_AXI_DATA_WIDTH)-3
		// }}}
	) (
		// AXI-lite signaling
		// {{{
		input	wire					S_AXI_ACLK,
		input	wire					S_AXI_ARESETN,
		//
		input	wire					S_AXI_AWVALID,
		output	wire					S_AXI_AWREADY,
		input	wire	[C_AXI_ADDR_WIDTH-1:0]		S_AXI_AWADDR,
		input	wire	[2:0]				S_AXI_AWPROT,
		//
		input	wire					S_AXI_WVALID,
		output	wire					S_AXI_WREADY,
		input	wire	[C_AXI_DATA_WIDTH-1:0]		S_AXI_WDATA,
		input	wire	[C_AXI_DATA_WIDTH/8-1:0]	S_AXI_WSTRB,
		//
		output	wire					S_AXI_BVALID,
		input	wire					S_AXI_BREADY,
		output	wire	[1:0]				S_AXI_BRESP,
		//
		input	wire					S_AXI_ARVALID,
		output	wire					S_AXI_ARREADY,
		input	wire	[C_AXI_ADDR_WIDTH-1:0]		S_AXI_ARADDR,
		input	wire	[2:0]				S_AXI_ARPROT,
		//
		output	wire					S_AXI_RVALID,
		input	wire					S_AXI_RREADY,
		output	wire	[C_AXI_DATA_WIDTH-1:0]		S_AXI_RDATA,
		output	wire	[1:0]				S_AXI_RRESP,
		// }}}
		// UART signals
		// {{{
		input	wire		i_uart_rx,
		output	wire		o_uart_tx,
		//
		// CTS is the "Clear-to-send" hardware flow control signal.  We
		// set it anytime our FIFO isn't full.  Feel free to ignore
		// this output if you do not wish to use flow control.
		input	wire		i_cts_n,
		//
		// RTS is used for hardware flow control.  According to
		// Wikipedia, it should probably be renamed RTR for "ready to
		// receive".  It tell us whether or not the receiving hardware
		// is ready to accept another byte.  If low, the transmitter
		// will pause.
		//
		// If you don't wish to use hardware flow control, just set
		// HARDWARE_FLOW_CONTROL_PRESENT to 1'b0 and let the optimizer
		// simply remove this logic.
		output	reg		o_rts_n,
		// }}}
		// A series of outgoing interrupts to select from among
		// {{{
		output	wire	o_uart_rx_int,
		output	wire	o_uart_tx_int,
		output	wire	o_uart_rxfifo_int,
		output	wire	o_uart_txfifo_int
		// }}}
	);

	////////////////////////////////////////////////////////////////////////
	//
	// Register/wire signal declarations
	//
	////////////////////////////////////////////////////////////////////////
	//
	// {{{
	wire	i_reset = !S_AXI_ARESETN;

	wire				axil_write_ready;
	wire	[C_AXI_ADDR_WIDTH-ADDRLSB-1:0]	awskd_addr;
	//
	wire	[C_AXI_DATA_WIDTH-1:0]	wskd_data;
	wire [C_AXI_DATA_WIDTH/8-1:0]	wskd_strb;
	reg				axil_bvalid;
	//
	wire				axil_read_ready;
	wire	[C_AXI_ADDR_WIDTH-ADDRLSB-1:0]	arskd_addr;
	reg	[C_AXI_DATA_WIDTH-1:0]	axil_read_data;
	reg				axil_read_valid;
	//
	//
	wire		tx_busy;
	//
	reg	[30:0]	uart_setup;
	//
	wire		rx_stb, rx_break, rx_perr, rx_ferr, ck_uart;
	wire	[7:0]	rx_uart_data;
	reg		rx_uart_reset;
	//
	wire		rx_empty_n, rx_fifo_err;
	wire	[7:0]	rxf_axil_data;
	wire	[15:0]	rxf_status;
	reg		rxf_axil_read;
	reg		r_rx_perr, r_rx_ferr;
	//
	wire	[(LCLLGFLEN-1):0]	check_cutoff;
	wire	[31:0]	axil_rx_data;
	//
	wire		tx_empty_n, txf_err, tx_break;
	wire	[7:0]	tx_data;
	wire	[15:0]	txf_status;
	reg		txf_axil_write, tx_uart_reset;
	reg	[7:0]	txf_axil_data;
	wire	[31:0]	axil_tx_data;
	wire	[31:0]	axil_fifo_data;
	//
	reg	[1:0]	r_axil_addr;
	reg		r_preread;

	reg	[31:0]	new_setup;

	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// AXI-lite signaling
	//
	////////////////////////////////////////////////////////////////////////
	//
	// {{{

	//
	// Write signaling
	//
	// {{{

	generate if (OPT_SKIDBUFFER)
	begin : SKIDBUFFER_WRITE

		wire	awskd_valid, wskd_valid;

		skidbuffer #(.OPT_OUTREG(0),
				.OPT_LOWPOWER(OPT_LOWPOWER),
				.DW(C_AXI_ADDR_WIDTH-ADDRLSB))
		axilawskid(//
			.i_clk(S_AXI_ACLK), .i_reset(i_reset),
			.i_valid(S_AXI_AWVALID), .o_ready(S_AXI_AWREADY),
			.i_data(S_AXI_AWADDR[C_AXI_ADDR_WIDTH-1:ADDRLSB]),
			.o_valid(awskd_valid), .i_ready(axil_write_ready),
			.o_data(awskd_addr));

		skidbuffer #(.OPT_OUTREG(0),
				.OPT_LOWPOWER(OPT_LOWPOWER),
				.DW(C_AXI_DATA_WIDTH+C_AXI_DATA_WIDTH/8))
		axilwskid(//
			.i_clk(S_AXI_ACLK), .i_reset(i_reset),
			.i_valid(S_AXI_WVALID), .o_ready(S_AXI_WREADY),
			.i_data({ S_AXI_WDATA, S_AXI_WSTRB }),
			.o_valid(wskd_valid), .i_ready(axil_write_ready),
			.o_data({ wskd_data, wskd_strb }));

		assign	axil_write_ready = awskd_valid && wskd_valid
				&& (!S_AXI_BVALID || S_AXI_BREADY);

	end else begin : SIMPLE_WRITES

		reg	axil_awready;

		initial	axil_awready = 1'b0;
		always @(posedge S_AXI_ACLK)
		if (!S_AXI_ARESETN)
			axil_awready <= 1'b0;
		else
			axil_awready <= !axil_awready
				&& (S_AXI_AWVALID && S_AXI_WVALID)
				&& (!S_AXI_BVALID || S_AXI_BREADY);

		assign	S_AXI_AWREADY = axil_awready;
		assign	S_AXI_WREADY  = axil_awready;

		assign 	awskd_addr = S_AXI_AWADDR[C_AXI_ADDR_WIDTH-1:ADDRLSB];
		assign	wskd_data  = S_AXI_WDATA;
		assign	wskd_strb  = S_AXI_WSTRB;

		assign	axil_write_ready = axil_awready;

	end endgenerate

	initial	axil_bvalid = 0;
	always @(posedge S_AXI_ACLK)
	if (i_reset)
		axil_bvalid <= 0;
	else if (axil_write_ready)
		axil_bvalid <= 1;
	else if (S_AXI_BREADY)
		axil_bvalid <= 0;

	assign	S_AXI_BVALID = axil_bvalid;
	assign	S_AXI_BRESP = 2'b00;
	// }}}

	//
	// Read signaling
	//
	// {{{

	generate if (OPT_SKIDBUFFER)
	begin : SKIDBUFFER_READ

		wire	arskd_valid;

		skidbuffer #(.OPT_OUTREG(0),
				.OPT_LOWPOWER(OPT_LOWPOWER),
				.DW(C_AXI_ADDR_WIDTH-ADDRLSB))
		axilarskid(//
			.i_clk(S_AXI_ACLK), .i_reset(i_reset),
			.i_valid(S_AXI_ARVALID), .o_ready(S_AXI_ARREADY),
			.i_data(S_AXI_ARADDR[C_AXI_ADDR_WIDTH-1:ADDRLSB]),
			.o_valid(arskd_valid), .i_ready(axil_read_ready),
			.o_data(arskd_addr));

		// High bandwidth reads
		assign	axil_read_ready = arskd_valid
				&& (!r_preread || !axil_read_valid
							|| S_AXI_RREADY);

	end else begin : SIMPLE_READS

		reg	axil_arready;

		initial	axil_arready = 1;
		always @(posedge S_AXI_ACLK)
		if (!S_AXI_ARESETN)
			axil_arready <= 1;
		else if (S_AXI_ARVALID && S_AXI_ARREADY)
			axil_arready <= 0;
		else if (S_AXI_RVALID && S_AXI_RREADY)
			axil_arready <= 1;

		assign	arskd_addr = S_AXI_ARADDR[C_AXI_ADDR_WIDTH-1:ADDRLSB];
		assign	S_AXI_ARREADY = axil_arready;
		assign	axil_read_ready = (S_AXI_ARVALID && S_AXI_ARREADY);

	end endgenerate

	initial	axil_read_valid = 1'b0;
	always @(posedge S_AXI_ACLK)
	if (i_reset)
		axil_read_valid <= 1'b0;
	else if (r_preread)
		axil_read_valid <= 1'b1;
	else if (S_AXI_RREADY)
		axil_read_valid <= 1'b0;

	assign	S_AXI_RVALID = axil_read_valid;
	assign	S_AXI_RDATA  = axil_read_data;
	assign	S_AXI_RRESP = 2'b00;
	// }}}

	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// AXI-lite register logic
	//
	////////////////////////////////////////////////////////////////////////
	//
	// {{{

	localparam	[1:0]	UART_SETUP = 2'b00,
				UART_FIFO  = 2'b01,
				UART_RXREG = 2'b10,
				UART_TXREG = 2'b11;

	always @(*)
		new_setup = apply_wstrb({1'b0,uart_setup},wskd_data,wskd_strb);
	
	//
	// The UART setup parameters: bits per byte, stop bits, parity, and
	// baud rate are all captured within this uart_setup register.
	//
	initial	uart_setup = INITIAL_SETUP
		| ((HARDWARE_FLOW_CONTROL_PRESENT==1'b0)? 31'h40000000 : 0);
	always @(posedge S_AXI_ACLK)
	if ((axil_write_ready)&&(awskd_addr == UART_SETUP))
	begin
		uart_setup <= new_setup[30:0];

		if (!HARDWARE_FLOW_CONTROL_PRESENT)
			uart_setup[30] <= 1'b1;
	end

	/////////////////////////////////////////
	//
	// First, the UART receiver
	// {{{
	/////////////////////////////////////////
	//
	//


	// Here's our UART receiver.  Basically, it accepts our setup wires, 
	// the UART input, a clock, and a reset line, and produces outputs:
	// a stb (true when new data is ready), and an 8-bit data out value
	// valid when stb is high.
`ifdef	FORMAL
	(* anyseq *) reg	w_rx_break, w_rx_perr, w_rx_ferr, w_ck_uart;
	assign		rx_break  = w_rx_break;
	assign		w_rx_perr = w_rx_perr;
	assign		w_rx_ferr = w_rx_ferr;
	assign		ck_uart  = w_ck_uart;
`else
`ifdef	USE_LITE_UART
	rxuartlite	#(.CLOCKS_PER_BAUD(INITIAL_SETUP[23:0]))
		rx(S_AXI_ACLK, i_uart_rx, rx_stb, rx_uart_data);
	assign	rx_break = 1'b0;
	assign	rx_perr  = 1'b0;
	assign	rx_ferr  = 1'b0;
	assign	ck_uart  = 1'b0;
`else
	// The full receiver also produces a break value (true during a break
	// cond.), and parity/framing error flags--also valid when stb is true.
	rxuart	#(.INITIAL_SETUP(INITIAL_SETUP)) rx(S_AXI_ACLK, (!S_AXI_ARESETN)||(rx_uart_reset),
			uart_setup, i_uart_rx,
			rx_stb, rx_uart_data, rx_break,
			rx_perr, rx_ferr, ck_uart);
	// The real trick is ... now that we have this extra data, what do we do
	// with it?
`endif
`endif	// FORMAL

	// We place it into a receiver FIFO.
	//
	// Note that the FIFO will be cleared upon any reset: either if there's
	// a UART break condition on the line, the receiver is in reset, or an
	// external reset is issued.
	//
	// The FIFO accepts strobe and data from the receiver.
	// We issue another wire to it (rxf_axil_read), true when we wish to
	// read from the FIFO, and we get our data in rxf_axil_data.  The FIFO
	// outputs four status-type values: 1) is it non-empty, 2) is the FIFO
	// over half full, 3) a 16-bit status register, containing info
	// regarding how full the FIFO truly is, and 4) an error indicator.
	ufifo	#(.LGFLEN(LCLLGFLEN), .RXFIFO(1))
		rxfifo(S_AXI_ACLK, (!S_AXI_ARESETN)||(rx_break)||(rx_uart_reset),
			rx_stb, rx_uart_data,
			rx_empty_n,
			rxf_axil_read, rxf_axil_data,
			rxf_status, rx_fifo_err);
	assign	o_uart_rxfifo_int = rxf_status[1];

	// We produce four interrupts.  One of the receive interrupts indicates
	// whether or not the receive FIFO is non-empty.  This should wake up
	// the CPU.
	assign	o_uart_rx_int = rxf_status[0];

	// The clear to send line, which may be ignored, but which we set here
	// to be true any time the FIFO has fewer than N-2 items in it.
	// Why not N-1?  Because at N-1 we are totally full, but already so full
	// that if the transmit end starts sending we won't have a location to
	// receive it.  (Transmit might've started on the next character by the
	// time we set this--thus we need to set it to one, one character before
	// necessary).
	assign	check_cutoff = -3;
	always @(posedge S_AXI_ACLK)
		o_rts_n <= ((HARDWARE_FLOW_CONTROL_PRESENT)
			&&(!uart_setup[30])
			&&(rxf_status[(LCLLGFLEN+1):2] > check_cutoff));

	// If the bus requests that we read from the receive FIFO, we need to
	// tell this to the receive FIFO.  Note that because we are using a 
	// clock here, the output from the receive FIFO will necessarily be
	// delayed by an extra clock.
	initial	rxf_axil_read = 1'b0;
	always @(posedge S_AXI_ACLK)
		rxf_axil_read<=(axil_read_ready)&&(arskd_addr[1:0]==UART_RXREG);

	// Now, let's deal with those RX UART errors: both the parity and frame
	// errors.  As you may recall, these are valid only when rx_stb is
	// valid, so we need to hold on to them until the user reads them via
	// a UART read request..
	initial	r_rx_perr = 1'b0;
	initial	r_rx_ferr = 1'b0;
	always @(posedge S_AXI_ACLK)
	if ((rx_uart_reset)||(rx_break))
	begin
		// Clear the error
		r_rx_perr <= 1'b0;
		r_rx_ferr <= 1'b0;
	end else if (axil_write_ready&&awskd_addr == UART_RXREG && wskd_strb[1])
	begin
		// Reset the error lines if a '1' is ever written to
		// them, otherwise leave them alone.
		//
		r_rx_perr <= (r_rx_perr)&&(!wskd_data[9]);
		r_rx_ferr <= (r_rx_ferr)&&(!wskd_data[10]);
	end else if (rx_stb)
	begin
		// On an rx_stb, capture any parity or framing error
		// indications.  These aren't kept with the data rcvd,
		// but rather kept external to the FIFO.  As a result,
		// if you get a parity or framing error, you will never
		// know which data byte it was associated with.
		// For now ... that'll work.
		r_rx_perr <= (r_rx_perr)||(rx_perr);
		r_rx_ferr <= (r_rx_ferr)||(rx_ferr);
	end

	initial	rx_uart_reset = 1'b1;
	always @(posedge S_AXI_ACLK)
	if ((!S_AXI_ARESETN)||((axil_write_ready)&&(awskd_addr[1:0]== UART_SETUP) && (&wskd_strb)))
		// The receiver reset, always set on a master reset
		// request.
		rx_uart_reset <= 1'b1;
	else if (axil_write_ready&&(awskd_addr[1:0]==UART_RXREG)&&wskd_strb[1])
		// Writes to the receive register will command a receive
		// reset anytime bit[12] is set.
		rx_uart_reset <= wskd_data[12];
	else
		rx_uart_reset <= 1'b0;

	// Finally, we'll construct a 32-bit value from these various wires,
	// to be returned over the bus on any read.  These include the data
	// that would be read from the FIFO, an error indicator set upon
	// reading from an empty FIFO, a break indicator, and the frame and
	// parity error signals.
	assign	axil_rx_data = { 16'h00,
				3'h0, rx_fifo_err,
				rx_break, rx_ferr, r_rx_perr, !rx_empty_n,
				rxf_axil_data};

	// }}}
	/////////////////////////////////////////
	//
	// Then the UART transmitter
	// {{{
	/////////////////////////////////////////
	//
	// Unlike the receiver which goes from RXUART -> UFIFO -> WB, the
	// transmitter basically goes WB -> UFIFO -> TXUART.  Hence, to build
	// support for the transmitter, we start with the command to write data
	// into the FIFO.  In this case, we use the act of writing to the 
	// UART_TXREG address as our indication that we wish to write to the 
	// FIFO.  Here, we create a write command line, and latch the data for
	// the extra clock that it'll take so that the command and data can be
	// both true on the same clock.
	initial	txf_axil_write = 1'b0;
	always @(posedge S_AXI_ACLK)
	begin
		txf_axil_write <= (axil_write_ready)&&(awskd_addr == UART_TXREG)
			&& wskd_strb[0];
		txf_axil_data  <= wskd_data[7:0];
	end

	// Transmit FIFO
	//
	// Most of this is just wire management.  The TX FIFO is identical in
	// implementation to the RX FIFO (theyre both UFIFOs), but the TX
	// FIFO is fed from the WB and read by the transmitter.  Some key
	// differences to note: we reset the transmitter on any request for a
	// break.  We read from the FIFO any time the UART transmitter is idle.
	// and ... we just set the values (above) for controlling writing into
	// this.
	ufifo	#(.LGFLEN(LGFLEN), .RXFIFO(0))
		txfifo(S_AXI_ACLK, (tx_break)||(tx_uart_reset),
			txf_axil_write, txf_axil_data,
			tx_empty_n,
			(!tx_busy)&&(tx_empty_n), tx_data,
			txf_status, txf_err);
	// Let's create two transmit based interrupts from the FIFO for the CPU.
	//	The first will be true any time the FIFO has at least one open
	//	position within it.
	assign	o_uart_tx_int = txf_status[0];
	//	The second will be true any time the FIFO is less than half
	//	full, allowing us a change to always keep it (near) fully 
	//	charged.
	assign	o_uart_txfifo_int = txf_status[1];

`ifndef	USE_LITE_UART
	// Break logic
	//
	// A break in a UART controller is any time the UART holds the line
	// low for an extended period of time.  Here, we capture the
	// wskd_data[9] wire, on writes, as an indication we wish to break.
	// As long as you write unsigned characters to the interface, this
	// will never be true unless you wish it to be true.  Be aware, though,
	// writing a valid value to the interface will bring it out of the
	// break condition.
	reg	r_tx_break;
	initial	r_tx_break = 1'b0;
	always @(posedge S_AXI_ACLK)
	if (!S_AXI_ARESETN)
		r_tx_break <= 1'b0;
	else if (axil_write_ready &&(awskd_addr[1:0]== UART_TXREG) &&
			wskd_strb[1])
		r_tx_break <= wskd_data[9];
	assign	tx_break = r_tx_break;
`else
	assign	tx_break = 1'b0;
`endif

	// TX-Reset logic
	//
	// This is nearly identical to the RX reset logic above.  Basically,
	// any time someone writes to bit [12] the transmitter will go through
	// a reset cycle.  Keep bit [12] low, and everything will proceed as
	// normal.
	initial	tx_uart_reset = 1'b1;
	always @(posedge S_AXI_ACLK)
	if ((!S_AXI_ARESETN)||((axil_write_ready)&&(awskd_addr == UART_SETUP)))
		tx_uart_reset <= 1'b1;
	else if ((axil_write_ready)&&(awskd_addr[1:0]== UART_TXREG) && wskd_strb[1])
		tx_uart_reset <= wskd_data[12];
	else
		tx_uart_reset <= 1'b0;

`ifdef	FORMAL
	(* anyseq *) reg w_uart_tx, w_tx_busy;
	assign	tx_busy   = w_uart_tx;
	assign	o_uart_tx = w_uart_tx;
`else
`ifdef	USE_LITE_UART
	txuartlite #(.CLOCKS_PER_BAUD(INITIAL_SETUP[23:0])) tx(S_AXI_ACLK, (tx_empty_n), tx_data,
			o_uart_tx, tx_busy);
`else
	wire	cts_n;
	assign	cts_n = (HARDWARE_FLOW_CONTROL_PRESENT)&&(i_cts_n);

	// Finally, the UART transmitter module itself.  Note that we haven't
	// connected the reset wire.  Transmitting is as simple as setting
	// the stb value (here set to tx_empty_n) and the data.  When these
	// are both set on the same clock that tx_busy is low, the transmitter
	// will move on to the next data byte.  Really, the only thing magical
	// here is that tx_empty_n wire--thus, if there's anything in the FIFO,
	// we read it here.  (You might notice above, we register a read any
	// time (tx_empty_n) and (!tx_busy) are both true---the condition for
	// starting to transmit a new byte.)
	txuart	#(.INITIAL_SETUP(INITIAL_SETUP)) tx(S_AXI_ACLK, 1'b0, uart_setup,
			r_tx_break, (tx_empty_n), tx_data,
			cts_n, o_uart_tx, tx_busy);
`endif
`endif	// FORMAL

	// Now that we are done with the chain, pick some wires for the user
	// to read on any read of the transmit port.
	//
	// This port is different from reading from the receive port, since
	// there are no side effects.  (Reading from the receive port advances
	// the receive FIFO, here only writing to the transmit port advances the
	// transmit FIFO--hence the read values are free for ... whatever.)  
	// We choose here to provide information about the transmit FIFO
	// (txf_err, txf_half_full, txf_full_n), information about the current
	// voltage on the line (o_uart_tx)--and even the voltage on the receive
	// line (ck_uart), as well as our current setting of the break and
	// whether or not we are actively transmitting.
	assign	axil_tx_data = { 16'h00, 
			i_cts_n, txf_status[1:0], txf_err,
			ck_uart, o_uart_tx, tx_break, (tx_busy|txf_status[0]),
			(tx_busy|txf_status[0])?txf_axil_data:8'b00};
	// }}}

	/////////////////////////////////////////
	//
	// FIFO return
	// {{{
	/////////////////////////////////////////
	//
	// Each of the FIFO's returns a 16 bit status value.  This value tells
	// us both how big the FIFO is, as well as how much of the FIFO is in 
	// use.  Let's merge those two status words together into a word we
	// can use when reading about the FIFO.
	assign	axil_fifo_data = { txf_status, rxf_status };

	// }}}
	/////////////////////////////////////////
	//
	// Final read register
	// {{{
	/////////////////////////////////////////
	//
	// You may recall from above that reads take two clocks.  Hence, we
	// need to delay the address decoding for a clock until the data is 
	// ready.  We do that here.
	initial	r_preread = 0;
	always @(posedge S_AXI_ACLK)
	if (!S_AXI_ARESETN)
		r_preread <= 0;
	else if (axil_read_ready)
		r_preread   <= 1;
	else if (!S_AXI_RVALID || S_AXI_RREADY)
		r_preread   <= 0;

	always @(posedge S_AXI_ACLK)
	if (axil_read_ready)
		r_axil_addr <= arskd_addr;

	// Finally, set the return data.  This data must be valid on the same
	// clock S_AXI_RVALID is high.  On all other clocks, it is
	// irrelelant--since no one cares, no one is reading it, it gets lost
	// in the mux in the interconnect, etc.  For this reason, we can just
	// simplify our logic.
	always @(posedge S_AXI_ACLK)
	if (!S_AXI_RVALID || S_AXI_RREADY)
	begin
		casez(r_axil_addr)
		UART_SETUP: axil_read_data <= { 1'b0, uart_setup };
		UART_FIFO:  axil_read_data <= axil_fifo_data;
		UART_RXREG: axil_read_data <= axil_rx_data;
		UART_TXREG: axil_read_data <= axil_tx_data;
		endcase

		if (OPT_LOWPOWER && !r_preread)
			axil_read_data <= 0;
	end
	// }}}

	function [C_AXI_DATA_WIDTH-1:0]	apply_wstrb;
		input	[C_AXI_DATA_WIDTH-1:0]		prior_data;
		input	[C_AXI_DATA_WIDTH-1:0]		new_data;
		input	[C_AXI_DATA_WIDTH/8-1:0]	wstrb;

		integer	k;
		for(k=0; k<C_AXI_DATA_WIDTH/8; k=k+1)
		begin
			apply_wstrb[k*8 +: 8]
				= wstrb[k] ? new_data[k*8 +: 8] : prior_data[k*8 +: 8];
		end
	endfunction
	// }}}

	////////////////////////////////////////////////////////////////////////
	//
	// Veri1ator lint-check
	// {{{
	// Verilator lint_off UNUSED
	wire	unused;
	assign	unused = &{ 1'b0, S_AXI_AWPROT, S_AXI_ARPROT,
			S_AXI_ARADDR[ADDRLSB-1:0],
			S_AXI_AWADDR[ADDRLSB-1:0], new_setup[31] };
	// Verilator lint_on  UNUSED
	// }}}
`ifdef	FORMAL
	////////////////////////////////////////////////////////////////////////
	//
	// Formal properties used in verfiying this core
	//
	////////////////////////////////////////////////////////////////////////
	//
	// {{{
	reg	f_past_valid;
	initial	f_past_valid = 0;
	always @(posedge S_AXI_ACLK)
		f_past_valid <= 1;

	////////////////////////////////////////////////////////////////////////
	//
	// The AXI-lite control interface
	//
	////////////////////////////////////////////////////////////////////////
	//
	// {{{
	localparam	F_AXIL_LGDEPTH = 4;
	wire	[F_AXIL_LGDEPTH-1:0]	faxil_rd_outstanding,
					faxil_wr_outstanding,
					faxil_awr_outstanding;

	faxil_slave #(
		// {{{
		.C_AXI_DATA_WIDTH(C_AXI_DATA_WIDTH),
		.C_AXI_ADDR_WIDTH(C_AXI_ADDR_WIDTH),
		.F_LGDEPTH(F_AXIL_LGDEPTH),
		.F_AXI_MAXWAIT(4),
		.F_AXI_MAXDELAY(4),
		.F_AXI_MAXRSTALL(3),
		.F_OPT_COVER_BURST(4)
		// }}}
	) faxil(
		// {{{
		.i_clk(S_AXI_ACLK), .i_axi_reset_n(S_AXI_ARESETN),
		//
		.i_axi_awvalid(S_AXI_AWVALID),
		.i_axi_awready(S_AXI_AWREADY),
		.i_axi_awaddr( S_AXI_AWADDR),
		.i_axi_awprot( S_AXI_AWPROT),
		//
		.i_axi_wvalid(S_AXI_WVALID),
		.i_axi_wready(S_AXI_WREADY),
		.i_axi_wdata( S_AXI_WDATA),
		.i_axi_wstrb( S_AXI_WSTRB),
		//
		.i_axi_bvalid(S_AXI_BVALID),
		.i_axi_bready(S_AXI_BREADY),
		.i_axi_bresp( S_AXI_BRESP),
		//
		.i_axi_arvalid(S_AXI_ARVALID),
		.i_axi_arready(S_AXI_ARREADY),
		.i_axi_araddr( S_AXI_ARADDR),
		.i_axi_arprot( S_AXI_ARPROT),
		//
		.i_axi_rvalid(S_AXI_RVALID),
		.i_axi_rready(S_AXI_RREADY),
		.i_axi_rdata( S_AXI_RDATA),
		.i_axi_rresp( S_AXI_RRESP),
		//
		.f_axi_rd_outstanding(faxil_rd_outstanding),
		.f_axi_wr_outstanding(faxil_wr_outstanding),
		.f_axi_awr_outstanding(faxil_awr_outstanding)
		// }}}
		);

	always @(*)
	if (OPT_SKIDBUFFER)
	begin
		assert(faxil_awr_outstanding== (S_AXI_BVALID ? 1:0)
			+(S_AXI_AWREADY ? 0:1));
		assert(faxil_wr_outstanding == (S_AXI_BVALID ? 1:0)
			+(S_AXI_WREADY ? 0:1));

		assert(faxil_rd_outstanding == (S_AXI_RVALID ? 1:0)
			+ (r_preread ? 1:0) +(S_AXI_ARREADY ? 0:1));
	end else begin
		assert(faxil_wr_outstanding == (S_AXI_BVALID ? 1:0));
		assert(faxil_awr_outstanding == faxil_wr_outstanding);

		assert(faxil_rd_outstanding == (S_AXI_RVALID ? 1:0)
			+ (r_preread ? 1:0));

		assert(S_AXI_ARREADY == (!S_AXI_RVALID && !r_preread));
	end

`ifdef	VERIFIC
	assert property (@(posedge S_AXI_ACLK)
		disable iff (!S_AXI_ARESETN || (S_AXI_RVALID && !S_AXI_RREADY))
		S_AXI_ARVALID && S_AXI_ARREADY && S_AXI_ARADDR[3:2]== UART_SETUP
		|=> r_preread && r_axil_addr == UART_SETUP
		##1 S_AXI_RVALID && axil_read_data
						== { 1'b0, $past(uart_setup) });
			
	assert property (@(posedge S_AXI_ACLK)
		disable iff (!S_AXI_ARESETN || (S_AXI_RVALID && !S_AXI_RREADY))
		S_AXI_ARVALID && S_AXI_ARREADY && S_AXI_ARADDR[3:2] == UART_FIFO
		|=> r_preread && r_axil_addr == UART_FIFO
		##1 S_AXI_RVALID && axil_read_data == $past(axil_fifo_data));
			
	assert property (@(posedge S_AXI_ACLK)
		disable iff (!S_AXI_ARESETN || (S_AXI_RVALID && !S_AXI_RREADY))
		S_AXI_ARVALID && S_AXI_ARREADY && S_AXI_ARADDR[3:2]== UART_RXREG
		|=> r_preread && r_axil_addr == UART_RXREG
		##1 S_AXI_RVALID && axil_read_data == $past(axil_rx_data));

	assert property (@(posedge S_AXI_ACLK)
		disable iff (!S_AXI_ARESETN || (S_AXI_RVALID && !S_AXI_RREADY))
		S_AXI_ARVALID && S_AXI_ARREADY && S_AXI_ARADDR[3:2]== UART_TXREG
		|=> r_preread && r_axil_addr == UART_TXREG
		##1 S_AXI_RVALID && axil_read_data == $past(axil_tx_data));

`endif
	//
	// Check that our low-power only logic works by verifying that anytime
	// S_AXI_RVALID is inactive, then the outgoing data is also zero.
	//
	always @(*)
	if (OPT_LOWPOWER && !S_AXI_RVALID)
		assert(S_AXI_RDATA == 0);

	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Cover checks
	//
	////////////////////////////////////////////////////////////////////////
	//
	// {{{

	// While there are already cover properties in the formal property
	// set above, you'll probably still want to cover something
	// application specific here

	// }}}
	// }}}
`endif
endmodule
