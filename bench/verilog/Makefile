################################################################################
##
## Filename:	Makefile
##
## Project:	wbuart32, a full featured UART with simulator
##
## Purpose:	To direct the Verilator build of the Verilog portion of the
##		bench test.  The result is C++ code (built by Verilator), that
##	is then built (herein) into a library.
##
## Targets:	The default target, all, builds the target test, which includes
##		the linetest Verilator library necessary for testing.
##
## Creator:	Dan Gisselquist, Ph.D.
##		Gisselquist Technology, LLC
##
################################################################################
##
## Copyright (C) 2015-2016, Gisselquist Technology, LLC
##
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
################################################################################
##
##
all:	test
YYMMDD=`date +%Y%m%d`
CXX   := g++
FBDIR := .
VDIRFB:= $(FBDIR)/obj_dir
RTLDR := ../../rtl

.PHONY: test testline testhello
test: testline testhello
testline:  $(VDIRFB)/Vlinetest__ALL.a
testhello: $(VDIRFB)/Vhelloworld__ALL.a

$(VDIRFB)/Vlinetest__ALL.a: $(VDIRFB)/Vlinetest.h $(VDIRFB)/Vlinetest.cpp
$(VDIRFB)/Vlinetest__ALL.a: $(VDIRFB)/Vlinetest.mk
$(VDIRFB)/Vlinetest.h $(VDIRFB)/Vlinetest.cpp $(VDIRFB)/Vlinetest.mk: linetest.v
$(VDIRFB)/Vlinetest.h $(VDIRFB)/Vlinetest.cpp $(VDIRFB)/Vlinetest.mk: $(RTLDR)/rxuart.v $(RTLDR)/txuart.v

$(VDIRFB)/Vhelloworld__ALL.a: $(VDIRFB)/Vhelloworld.h $(VDIRFB)/Vhelloworld.cpp
$(VDIRFB)/Vhelloworld__ALL.a: $(VDIRFB)/Vhelloworld.mk
$(VDIRFB)/Vhelloworld.h $(VDIRFB)/Vhelloworld.cpp $(VDIRFB)/Vhelloworld.mk: helloworld.v
$(VDIRFB)/Vhelloworld.h $(VDIRFB)/Vhelloworld.cpp $(VDIRFB)/Vhelloworld.mk: $(RTLDR)/rxuart.v $(RTLDR)/txuart.v

$(VDIRFB)/V%.cpp $(VDIRFB)/V%.h $(VDIRFB)/V%.mk: $(FBDIR)/%.v
	verilator -cc -y ../../rtl $*.v 

$(VDIRFB)/V%__ALL.a: $(VDIRFB)/V%.mk
	cd $(VDIRFB); make -f V$*.mk

.PHONY: clean
clean:
	rm -rf $(VDIRFB)/*.mk
	rm -rf $(VDIRFB)/*.cpp
	rm -rf $(VDIRFB)/*.h
	rm -rf $(VDIRFB)/

