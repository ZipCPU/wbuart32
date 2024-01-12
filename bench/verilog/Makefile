################################################################################
##
## Filename:	Makefile
## {{{
## Project:	wbuart32, a full featured UART with simulator
##
## Purpose:	To direct the Verilator build of the Verilog portion of the
##		bench test.  The result is C++ code (built by Verilator), that
##	is then built (herein) into a library.
##
## ALTERNATE_PURPOSE:
##	All of the Verilog files within this directory may be made top level
##	files in their own right for the purpose of testing the UART capability
##	of your board.  Should you wish to test these as toplevel files, you
##	will need to remove the i_setup from the input, and set it to something
##	like:
##		wire	[29:0]	i_setup;
##
##		// If we have a 100MHz clock, then we can set up for a 115,200
##		// baud clock by setting i_setup to (100MHz / 115200) ~= 868.
##		// The upper bits of this number also set the protocol to
##		// one stop bit, no parity, and 8 data  bits.
##		assign	i_setup = 30'd868; 	// 115,200 Baud 8N1
##
##	Using this purpose, the UART ports of a new piece of hardware may be
##	proven.  To do this,
##		1. get BLINKY working first--to prove that the clock works like
##			you think it does.  Then, once BLINKY is running,
##		2. get helloworld working.  This requires only the clock and
##			the output UART pin to work.
##		(Aside) 3. Once helloworld works, you should be able to get
##			speechfifo to work with no further hassles.
##		4. After helloworld works, switch to getting linetest running on
##			your hardware.  This will prove that you have not only
##			the clock and output UART pin working, but that you also
##			have the input UART pin working as well.
##
## Targets:	The default target of this makefile, all, builds the target
##		test, which includes the linetest Verilator library, the
##	helloworld Verilator library, and the speechfifo Verilator library--all
##	necessary for bench testing using the C++ files in bench/cpp.
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
## with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
## target there if the PDF file isn't present.)  If not, see
## <http://www.gnu.org/licenses/> for a copy.
##
## License:	GPL, v3, as defined and found on www.gnu.org,
##		http://www.gnu.org/licenses/gpl.html
##
################################################################################
##
.PHONY: all
.DELETE_ON_ERROR:
## }}}
all:	test
## {{{
YYMMDD=`date +%Y%m%d`
CXX   := g++
FBDIR := .
VDIRFB:= $(FBDIR)/obj_dir
RTLDR := ../../rtl
VERILATOR := verilator
VFLAGS := -Wall --MMD --trace -y $(RTLDR) -cc

.PHONY: test testline testhello speechfifo
## }}}
test: testline testlinelite testhello testhellolite speechfifo speechfifolite
## Dependencies
## {{{
testline:       $(VDIRFB)/Vlinetest__ALL.a
testlinelite:   $(VDIRFB)/Vlinetestlite__ALL.a
testhello:      $(VDIRFB)/Vhelloworld__ALL.a
testhellolite:  $(VDIRFB)/Vhelloworldlite__ALL.a
speechfifo:     $(VDIRFB)/Vspeechfifo__ALL.a
speechfifolite: $(VDIRFB)/Vspeechfifolite__ALL.a

$(VDIRFB)/Vlinetest__ALL.a:       $(VDIRFB)/Vlinetest.cpp
$(VDIRFB)/Vlinetestlite__ALL.a:   $(VDIRFB)/Vlinetestlite.cpp
$(VDIRFB)/Vhelloworld__ALL.a:     $(VDIRFB)/Vhelloworld.cpp
$(VDIRFB)/Vhelloworldlite__ALL.a: $(VDIRFB)/Vhelloworldlite.cpp
$(VDIRFB)/Vspeechfifo__ALL.a:     $(VDIRFB)/Vspeechfifo.cpp
$(VDIRFB)/Vspeechfifolite__ALL.a: $(VDIRFB)/Vspeechfifolite.cpp
## }}}

## Verilate build instructions
## {{{
$(VDIRFB)/V%.mk:  $(VDIRFB)/V%.h
$(VDIRFB)/V%.h:   $(VDIRFB)/V%.cpp
$(VDIRFB)/V%.cpp: $(FBDIR)/%.v
	$(VERILATOR) $(VFLAGS) $*.v

$(VDIRFB)/Vlinetestlite.cpp: $(FBDIR)/linetest.v
	$(VERILATOR) $(VFLAGS) -DUSE_UART_LITE --prefix Vlinetestlite linetest.v
$(VDIRFB)/Vhelloworldlite.cpp: $(FBDIR)/helloworld.v
	$(VERILATOR) $(VFLAGS) -DUSE_UART_LITE --prefix Vhelloworldlite helloworld.v
$(VDIRFB)/Vspeechfifolite.cpp: $(FBDIR)/speechfifo.v
	$(VERILATOR) $(VFLAGS) -DUSE_UART_LITE --prefix Vspeechfifolite speechfifo.v
## }}}

## Turn C++ to libraries
## {{{
$(VDIRFB)/V%__ALL.a: $(VDIRFB)/V%.cpp
	cd $(VDIRFB); make -f V$*.mk
## }}}

## TAGS
## {{{
tags: $(wildcard *.v) $(wildcard $(RTLDR)/*.v)
	ctags *.v $(RTLDR)/*.v
## }}}

## Clean
## {{{
.PHONY: clean
clean:
	rm -rf tags $(VDIRFB)/
## }}}

## Automatic dependency handling
## {{{
DEPS := $(wildcard $(VDIRFB)/*.d)

ifneq ($(MAKECMDGOALS),clean)
ifneq ($(DEPS),)
include $(DEPS)
endif
endif
## }}}
