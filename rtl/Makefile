################################################################################
##
## Filename:	Makefile
##
## Project:	wbuart32, a full featured UART with simulator
##
## Purpose:	To direct the Verilator build of the SoC sources.  The result
##		is C++ code (built by Verilator), that is then built (herein)
##	into a library.
##
## Targets:	The default target, all, builds the target test, which includes
##		the libraries necessary for Verilator testing.
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

.PHONY: test
test: $(VDIRFB)/Vtxuart__ALL.a
test: $(VDIRFB)/Vrxuart__ALL.a

$(VDIRFB)/Vrxuart__ALL.a: $(VDIRFB)/Vrxuart.h $(VDIRFB)/Vrxuart.cpp
$(VDIRFB)/Vrxuart__ALL.a: $(VDIRFB)/Vrxuart.mk
$(VDIRFB)/Vrxuart.h $(VDIRFB)/Vrxuart.cpp $(VDIRFB)/Vrxuart.mk: rxuart.v

$(VDIRFB)/Vtxuart__ALL.a: $(VDIRFB)/Vtxuart.h $(VDIRFB)/Vtxuart.cpp
$(VDIRFB)/Vtxuart__ALL.a: $(VDIRFB)/Vtxuart.mk
$(VDIRFB)/Vtxuart.h $(VDIRFB)/Vtxuart.cpp $(VDIRFB)/Vtxuart.mk: txuart.v

$(VDIRFB)/V%.cpp $(VDIRFB)/V%.h $(VDIRFB)/V%.mk: $(FBDIR)/%.v
	verilator -cc $*.v 

$(VDIRFB)/V%__ALL.a: $(VDIRFB)/V%.mk
	cd $(VDIRFB); make -f V$*.mk

.PHONY: clean
clean:
	rm -rf $(VDIRFB)/*.mk
	rm -rf $(VDIRFB)/*.cpp
	rm -rf $(VDIRFB)/*.h
	rm -rf $(VDIRFB)/

