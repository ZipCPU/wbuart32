# Another Wishbone Controlled UART

_Forasmuch as many have taken in hand to set forth_ a UART core, ... _It seemed
good to me also, having had ~perfect~_ (a good) _understanding of ~all~ things
from the very first, to write_ ... my own UART core.

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

The only real drawback to this core is that it doesn't include a FIFO.  A
second, lesser, drawback is that it doesn't support any hardware flow control.
Both drawbacks are easy to rectify, I just ... haven't had any need to (yet).
In all other respects, this is a very simple and easy to use controller.


