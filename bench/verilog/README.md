This directory contains three basic configurations for testing your UART
and proving that it works:
- helloworld: Displays the familiar "Hello, World!" message over and over.  Tests the transmit UART port.
- linetest: Reads a line of text, then parrots it back.  Tests both receive and transmit UART.
- speechfifo: Recites the Gettysburg address over and over again.  This can be used to test the transmit UART port, and particularly to test receivers to see if they can receive 1400+ characters at full speed without any problems.

Each of these configurations has a commented line defining OPT_STANDALONE within
it.  If you uncomment this line, the configurations may be run as stand alone
configurations.  (You will probably want to adjust the baud clock divider, to
be specific to the baud rate you wish to generate as well as the clock rate
you will be generating this from.)

If you leave OPT_STANDALONE commented, these demo programs should work quite
nicely with a Verilator based simulation.
