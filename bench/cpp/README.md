+ C++ source files

Items within this directory include:

- uartsim defines a C++ class that can be used for simulating a UART within 
Verilator.  This class can be used both to generate valid UART signaling,
to determine if your configuration can receive it properly, as well as to decode
valid UART signaling to determine if your configuration is properly setting the
UART signaling wire.

- speech.txt, and the associated speech.hex file, is the text that speechfifo
will transmit.  It is currently set to the Gettysburg Address.  While you are welcome to change this, the length of this file is hard coded within the verilog file that references it.

- mkspeech, a Verilog hex file generator--although it also converts newlines to
carriage-return newline pairs

- Demonstration projects using these:
-- helloworld, exercises and tests the helloworld.v test bench
-- linetest, exercises and tests the linetest.v test bench.  This also creates a .VCD file which can be viewed via GTKwave
-- speechtest, exercises and tests the speechfifo test bench.  When run with the -i option, speechtest will also generate a .VCD file for use with GTKwave.

