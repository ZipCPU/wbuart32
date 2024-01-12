################################################################################
##
## Filename:	Makefile
## {{{
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
## }}}
## Copyright (C) 2015-2024, Gisselquist Technology, LLC
## {{{
## This program is free software (firmware): you can redistribute it and/or
## modify it under the terms of the GNU General Public License as published
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
## }}}
## License:	GPL, v3, as defined and found on www.gnu.org,
## {{{
##		http://www.gnu.org/licenses/gpl.html
##
################################################################################
##
.DELETE_ON_ERROR:
## }}}
.PHONY: all
all:	test
## {{{
.DELETE_ON_ERROR:
YYMMDD=`date +%Y%m%d`
CXX   := g++
FBDIR := .
VDIRFB:= $(FBDIR)/obj_dir
VERILATOR := verilator
## }}}

.PHONY: test
## {{{
test: $(VDIRFB)/Vtxuart__ALL.a
test: $(VDIRFB)/Vrxuart__ALL.a
test: $(VDIRFB)/Vwbuart__ALL.a
test: $(VDIRFB)/Vtxuartlite__ALL.a
test: $(VDIRFB)/Vrxuartlite__ALL.a
## }}}

$(VDIRFB)/Vrxuart__ALL.a:     $(VDIRFB)/Vrxuart.cpp
$(VDIRFB)/Vtxuart__ALL.a:     $(VDIRFB)/Vtxuart.cpp
$(VDIRFB)/Vrxuartlite__ALL.a: $(VDIRFB)/Vrxuartlite.cpp
$(VDIRFB)/Vtxuartlite__ALL.a: $(VDIRFB)/Vtxuartlite.cpp
$(VDIRFB)/Vwbuart__ALL.a:     $(VDIRFB)/Vwbuart.cpp

$(VDIRFB)/V%.mk:  $(VDIRFB)/%.h
$(VDIRFB)/V%.h:   $(VDIRFB)/%.cpp
$(VDIRFB)/V%.cpp: $(FBDIR)/%.v
	$(VERILATOR) --trace -MMD -Wall -cc $*.v

$(VDIRFB)/V%__ALL.a: $(VDIRFB)/V%.mk
	cd $(VDIRFB); make -f V$*.mk

tags: $(wildcard *.v)
	ctags *.v

.PHONY: clean
clean:
	rm -rf tags $(VDIRFB)/

DEPS := $(wildcard $(VDIRFB)/*.d)

ifneq ($(MAKECMDGOALS),clean)
ifneq ($(DEPS),)
include $(DEPS)
endif
endif
