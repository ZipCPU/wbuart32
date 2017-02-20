This directory contains three basic configurations for testing your UART
and proving that it works:
- [helloworld](helloworld.v): Displays the familiar "Hello, World!" message over and over.  Tests the transmit UART port.
- [echotest](echotest.v): Echoes any characters received directly back to the transmit port.  Two versions of this exist: one that processes characters and regenerates them, and another that just connects the input port to the output port.  These are good tests to be applied if you already know your transmit UART works.  If the transmitter works, then this will help to verify that your receiver works.  It's one fault is that it tends to support single character UART tests, hence the test below.
- [linetest](linetest.v): Reads a line of text, then parrots it back.  Tests both receive and transmit UART.
- [speechfifo](speechfifo.v): Recites the [Gettysburg address](../cpp/speech.txt) over and over again.  This can be used to test the transmit UART port, and particularly to test receivers to see if they can receive 1400+ characters at full speed without any problems.

Each of these configurations has a commented line defining OPT_STANDALONE within
it.  This option will automatically be defined if built within Verilator, 
allowing the Verilator simulation to set the serial port parameters.  Otherwise,
you should be able to run these files as direct top level design files.  (You
will probably want to adjust the baud clock divider if so, so that you can set
to the baud rate you wish to generate as well as the clock rate you will be
generating this from.)

