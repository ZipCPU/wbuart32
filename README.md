# Another Wishbone Controlled UART

_Forasmuch as many have taken in hand to set forth_ a UART core, ... _It seemed
good to me also, having had ~~perfect~~_ (a good) _understanding of ~~all~~
things from the very first, to write_ ... my own UART core.

- This Verilog core contains two UART modules, [one for transmit](rtl/txuart.v) and [one for receive](rtl/rxuart.v).  Each can be configured via one 32-bit word for just about any baud rate, one or two stop bits, five through eight data bits, and odd, even, mark, or space parity.  If you are looking for an example Verilog UART module containing all these features, then you have just found it.

- The module goes beyond simple transmit and receive, however, to also include a fairly generic [synchronous FIFO](rtl/ufifo.v).  For those looking for a fairly simple FIFO, whether for your UART capability or something else, you've also just found it.

- If you are looking for a wishbone--enabled peripheral, this module offers two configuration methods: [one](rtl/wbuart-insert.v) that can be included in another, larger, wishbone module, and [another](rtl/wbuart.v) which is complete in its own right--together with an integrated FIFO and a FIFO status register.

- If you are familiar with other UART setup protocols, you'll find this one even easier to setup.  For example, unlike the 16550 serial port, this serial port can be set up by just writing to and setting a single 32--bit register.  Once set, either at startup or by writing the the port afterwards, and your UART is fully configured.  Changes will take place on the next byte to be transmitted (or received).

- If you would rather test your own UART transmitter and/or receiver, this core contains within it a Verilator enabled [UART simulator](bench/cpp/uartsim.cpp) which can be used in test-benches of your own UART implementation to know if you've done it right or not.

- Finally, the test benches within [bench/verilog](bench/verilog) of this directory can be used as very simple test benches to test for UART functionality on a board with only two pins (clock and output UART), or three pins (adding the input UART).  Thus, if you are just trying to start up a project and need a demonstration that will prove if your UART will work, you can find several such a demonstration projects in this code.  Further, two of those test benches will also create VCD files that can be inspected via gtkwave, so you can get a feel for how the whole thing works.

At one time, the biggest drawback to the files in these directories was that
there wasn't a version of this UART interface containing a FIFO.  Well, no
more.  Now there is a [wbuart.v](rtl/wbuart.v) file that can be
integrated into a wishbone/B4/pipeline bus.  As mentioned above, this module
contains a FIFO with a parameterized length that can extend up to 1023 entries.
Indeed, recent changes have even added in optional hardware flow control, should
you wish to use it.

Thus this is a very simple and easy to use controller.

# Commercial Applications

Should you find the GPLv3 license insufficient for your needs, other licenses
can be purchased from Gisselquist Technology, LLC.
