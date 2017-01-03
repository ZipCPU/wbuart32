# Another Wishbone Controlled UART

_Forasmuch as many have taken in hand to set forth_ a UART core, ... _It seemed
good to me also, having had ~~perfect~~_ (a good) _understanding of ~~all~~
things from the very first, to write_ ... my own UART core.

- This Verilog core contains two UART modules, one for transmit and one for receive.  Each can be configured via one 32-bit word for just about any baud rate, one or two stop bits, five through eight data bits, and odd, even, mark, or space parity.  If you are looking for an example Verilog UART module containing all these features, then you've just found it.

- The module goes beyond simple transmit and receive, however, to also include a fairly generic synchronous FIFO.  For those looking for a fairly simple FIFO, you've also just found it.

- If you are looking for a wishbone--enabled peripheral, this module offers two configuration methods: one that can be included in another, larger, wishbone module, and another wish is complete in its own right--together with FIFO and a FIFO status register.

- If you are familiar with other UART setup protocols, you'll find this one even easier to setup.  Unlike the 16550 serial port, this serial port can be set up by just writing to and setting a single 32--bit register.  Once set, either at startup or by writing the the port, and your UART is fully configured.  Changes will take place on the next byte to be transmitted.

- If you would rather test your own UART transmitter and/or receiver, this core contains within it a Verilator enabled UART simulator which can be used in test-benches of your own UART implementation to know if you've done it right or not.

- Finally, the test benches within bench/verilog of this directory can be used as very simple test benches to test for UART functionality on a board with only two pins (clock and output UART), or three pins (adding the input UART).  Thus, if you are just trying to start up a project and need a demonstration that will prove if your UART will work, you can find such a demonstration project in this code.  Further, two of those test benches will also create VCD files that can be inspected via gtkwave, so you can get a feel for how the whole works.

At one time, the biggest drawback to the files in these directories was that
there wasn't a version of this UART interface containing a FIFO.  Well, no
more.  Now there is a wbuart.v file that can be interacted with from a
wishbone/B4/pipeline bus, and it contains a FIFO with a parameterized length
that can extend up to 1023 entries.

Thus this is a very simple and easy to use controller.
