# Another Wishbone Controlled UART

_Forasmuch as many have taken in hand to set forth_ a UART core, ... _It seemed
good to me also, having had ~~perfect~~_ (a good) _understanding of ~~all~~
things from the very first, to write_ ... my own UART core.

One unique feature to this core is the ability of the Verilator test bench
support code to forward the simulated UART connection over a TCP/IP link.  This
capability was first used in the XuLA2-LX25 SoC core, has since been ported to
the OpenArty project, and is now extracted from those two projects here in the
hopes that it may be useful to the projects of others.

A second unique feature, and one that I find rather surprising in its uniqueness, is the ease of configuring this core.  I guess I thought every core would be
so easy to configure.  Not so.  Unlike the UART 16550-core, this one is completely configured by setting just a single register.  When using the sample
Wishbone configuration, reading from teh core is as simple as reading from a 
register, and transmitting from the UART is as simple as writing to a register.
The core does not have an interrupt controller, yet still produces both transmit
idle and receive ready interrupt lines--to be connected to whatever interrupt
controller you might have.

A third feature, perhaps not nearly so unique but quite valuable, is that the
RTL in bench/verilog can be used as part of a series of tests when bringing up
a board.  Once the clock has been validated, then helloworld can be used to
validate the UART output, and linetest can then be used to validate both the
UART output and input.

At one time, the biggest drawback to the files in these directories was that
there wasn't a version of this UART interface containing a FIFO.  Well, no
more.  Now there is a wbuart.v file that can be interacted with from a
wishbone/B4/pipeline bus, and it contains a FIFO of a parameterizable length.

Thus this is a very simple and easy to use controller.
