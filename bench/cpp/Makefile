################################################################################
##
## Filename: 	Makefile
## {{{
## Project:	wbuart32, a full featured UART with simulator
##
## Purpose:	To test a group of Verilator modules: txuart (UART transmitter),
##		rxuart (UART receiver/sink) and wbuart (UART module, containing
##	both receiver and transmitter, with FIFOs, controlled via wishbone).
##
##
## Targets:
##	test
##		Perform both tests.  The end result should be either a PASS
##		or a FAIL.
##
##	helloworld
##		A non-automated, and less interactive test than the others.  In
##		this test, the UART simply produces a Hello World message to the
##		screen over and over again.
##
##	linetest
##		An automated test of both txuart and rxuart.  The test works
##		by sending a message through the rxuart, and receiving the
##		message via the txuart.  This depends upon a Verilog test
##		infrastructure, linetest.v.
##
##		This test may be ran in an interactive mode.  In this mode,
##		characters written to the UART will be reflected back upon
##		the entrance of a return character.
##
##	speechtest
##		An automated test of the wbuart, txuart, and fifo.  In this
##		case, the test RTL produces a copy of the Gettysburg address,
##		filling the FIFO at 12/16 at a time.  In automated mode, the
##		speechtest will compare the output against against a text copy
##		of the speech, and report upon any success or failure.
##
##		In interactive mode, the test will repeatedly print out the
##		Gettysburg address until stopped.  (It may take a significant
##		amount of time between copies of the Gettysburg address ...)
##
##
## Creator:	Dan Gisselquist, Ph.D.
##		Gisselquist Technology, LLC
##
################################################################################
## }}}
## Copyright (C) 2015-2024, Gisselquist Technology, LLC
## {{{
## This program is free software (firmware): you can redistribute it and/or
## modify it under the terms of  the GNU General Public License as published
## by the Free Software Foundation, either version 3 of the License, or (at
## your option) any later version.
##
## This program is distributed in the hope that it will be useful, but WITHOUT
## ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
## FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
## for more details.
##
## You should have received a copy of the GNU General Public License along
## with this program.  (It's in the $(ROOT)/doc directory, run make with no
## target there if the PDF file isn't present.)  If not, see
## <http://www.gnu.org/licenses/> for a copy.
##
## License:	GPL, v3, as defined and found on www.gnu.org,
##		http://www.gnu.org/licenses/gpl.html
##
##
################################################################################
##
##
CXX	:= g++
FLAGS	:= -Wall -Og -g
OBJDIR  := obj-pc
RTLD	:= ../verilog
VERILATOR_ROOT ?= $(shell bash -c 'verilator -V|grep VERILATOR_ROOT | head -1 | sed -e " s/^.*=\s*//"')
VROOT   := $(VERILATOR_ROOT)
INCS	:= -I$(RTLD)/obj_dir/ -I$(VROOT)/include
SOURCES := helloworld.cpp linetest.cpp uartsim.cpp uartsim.h
VOBJDR	:= $(RTLD)/obj_dir
SYSVDR	:= $(VROOT)/include
## }}}
all:	$(OBJDIR)/ linetest linetestlite helloworld helloworldlite speechtest speechtestlite test

# Verilator's generated Makefile sets VM_*
-include $(VOBJDR)/Vlinetest_classes.mk
VSRC	:= $(addsuffix .cpp, $(VM_GLOBAL_FAST) $(VM_GLOBAL_SLOW))
VLIB	:= $(addprefix $(OBJDIR)/,$(subst .cpp,.o,$(VSRC)))

$(OBJDIR)/uartsim.o: uartsim.cpp uartsim.h

$(OBJDIR)/%.o: %.cpp
	$(mk-objdir)
	$(CXX) $(FLAGS) $(INCS) -c $< -o $@

$(OBJDIR)/%.o: $(SYSVDR)/%.cpp
	$(mk-objdir)
	$(CXX) $(FLAGS) $(INCS) -c $< -o $@

## linetest
## {{{
# Sources necessary to build the linetest program (rxuart-txuart test)
LINSRCS := linetest.cpp uartsim.cpp
LINOBJ := $(subst .cpp,.o,$(LINSRCS))
LINOBJS:= $(addprefix $(OBJDIR)/,$(LINOBJ)) $(VLIB)
linetest: $(LINOBJS) $(VOBJDR)/Vlinetest__ALL.a
	$(CXX) $(FLAGS) $(INCS) $^ -lpthread -o $@
## }}}

## linetestlite
## {{{
$(OBJDIR)/linetestlite.o: linetest.cpp
	$(mk-objdir)
	$(CXX) $(FLAGS) $(INCS) -DUSE_UART_LITE -c $< -lpthread -o $@


LINLTSRCS := linetest.cpp uartsim.cpp
LINLTOBJ := linetestlite.o uartsim.o
LINLTOBJS:= $(addprefix $(OBJDIR)/,$(LINLTOBJ)) $(VLIB)
linetestlite: $(LINLTOBJS) $(VOBJDR)/Vlinetestlite__ALL.a
	$(CXX) $(FLAGS) $(INCS) $^ -lpthread -o $@
## }}}

## Hello World
## {{{
# Sources necessary to build the helloworld test (txuart test)
HLOSRCS := helloworld.cpp uartsim.cpp
HLOOBJ := $(subst .cpp,.o,$(HLOSRCS))
HLOOBJS:= $(addprefix $(OBJDIR)/,$(HLOOBJ)) $(VLIB)
helloworld: $(HLOOBJS) $(VOBJDR)/Vhelloworld__ALL.a
	$(CXX) $(FLAGS) $(INCS) $^ -lpthread -o $@
## }}}

## helloworldlite
## {{{
$(OBJDIR)/helloworldlite.o: helloworld.cpp
	$(mk-objdir)
	$(CXX) $(FLAGS) $(INCS) -DUSE_UART_LITE -c $< -lpthread -o $@

HLOLTOBJ := helloworldlite.o uartsim.o
HLOLTOBJS:= $(addprefix $(OBJDIR)/,$(HLOLTOBJ)) $(VLIB)
helloworldlite: $(HLOLTOBJS) $(VOBJDR)/Vhelloworldlite__ALL.a
	$(CXX) $(FLAGS) $(INCS) $^ -lpthread -o $@
## }}}

#
# The speech test program depends upon a copy of the Gettysburg Address,
# turned into a hex file format which will be read by the Verilog/RTL
# $readmemh function.  However, we need to create that hex file that will 
# written.  That's the purpose of mkspeech--to make a file that can be read
# by $readmemh.
#
mkspeech: mkspeech.cpp
	$(CXX) mkspeech.cpp -o $@

# Now that mkspeech is available, use it to produce a speech.hex file from
# the speech.txt file.  Be careful if you adjust this speech: the speechfifo.v
# verilog file depends upon the exact number of characters--its not a portable
# dependency, but ... it is what it is.
speech.hex: mkspeech speech.txt
	./mkspeech speech.txt
	bash -c "if [ -d ../verilog/ ]; then cp speech.hex ../verilog/; fi"

## speechtest
## {{{
# Now, if the speech.hex file is available, then we can perform our final build.
# Actually, we could've done this without the speech file being available, but
# this works.
# Sources necessary to build the speech test (wbuart test)
SPCHSRCS:= speechtest.cpp uartsim.cpp
SPCHOBJ := $(subst .cpp,.o,$(SPCHSRCS))
SPCHOBJS:= $(addprefix $(OBJDIR)/,$(SPCHOBJ)) $(VLIB)
speechtest: speech.hex $(SPCHOBJS) $(VOBJDR)/Vspeechfifo__ALL.a 
	$(CXX) $(FLAGS) $(INCS) $(SPCHOBJS) $(VOBJDR)/Vspeechfifo__ALL.a -lpthread -o $@
## }}}

## speechtestlite
## {{{
$(OBJDIR)/speechtestlite.o: speechtest.cpp
	$(mk-objdir)
	$(CXX) $(FLAGS) $(INCS) -DUSE_UART_LITE -c $< -o $@

SPCHLTOBJ := speechtestlite.o uartsim.o
SPCHLTOBJS:= $(addprefix $(OBJDIR)/,$(SPCHLTOBJ)) $(VLIB)
speechtestlite: speech.hex $(SPCHLTOBJS) $(VOBJDR)/Vspeechfifolite__ALL.a 
	$(CXX) $(FLAGS) $(INCS) $(SPCHLTOBJS) $(VOBJDR)/Vspeechfifolite__ALL.a -lpthread -o $@
## }}}

## test
## {{{

test:
#
#
# The "test" target, attempts to check if our core does what it should
# without any user interaction
test: linetest linetestlite helloworld helloworldlite speechtest speechtestlite
	./linetest
	./linetestlite
	./helloworld
	./helloworldlite
	./speechtest
	./speechtestlite
## }}}

#
# The "depends" target, to know what files things depend upon.  The depends
# file itself is kept in $(OBJDIR)/depends.txt
#
define	build-depends
	$(mk-objdir)
	@echo "Building dependency file"
	@$(CXX) $(FLAGS) $(INCS) -MM $(SOURCES) > $(OBJDIR)/xdepends.txt
	@sed -e 's/^.*.o: /$(OBJDIR)\/&/' < $(OBJDIR)/xdepends.txt > $(OBJDIR)/depends.txt
	@rm $(OBJDIR)/xdepends.txt
endef

.PHONY: depends
depends:
	$(build-depends)

$(OBJDIR)/depends.txt: depends

#
# Make sure the $(OBJDIR)/ directory exists.  This has taken some work to get
# right.  While "mkdir -p $(OBJDIR)" could be used to do this as well, it
# always bothered me that it seemed to be perpetually running.  Hence, we'll
# first check if the directory exists, and only create it if it does not.
# Finally, by adding the @ in front of the bash command, it won't get printed
# to the screen.  That way ... I can run it as often as I want without getting
# annoyed by it.  ;)
define	mk-objdir
	@bash -c "if [ ! -e $(OBJDIR) ]; then mkdir -p $(OBJDIR); fi"
endef

#
# The "tags" target
#
tags:	$(SOURCES) $(HEADERS)
	@echo "Generating tags"
	@ctags $(SOURCES) $(HEADERS)

#
# The "clean" target, removing any and all remaining build (and test) products
#
.PHONY: clean
clean:
	rm -f ./mkspeech   ./speech.hex
	rm -f ./linetest   ./linetestlite
	rm -f ./helloworld ./helloworldlite
	rm -f ./speechtest ./speechtestlite
	rm -rf $(OBJDIR)/

# Include our generated dependency file.  The "-" in front of the include
# basically tells "make" to include it if it can, and ignore it if it cannot
# be included (i.e. if it doesn't exist)
ifneq ($(MAKECMDGOALS),clean)
-include $(OBJDIR)/depends.txt
endif
