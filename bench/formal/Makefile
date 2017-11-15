################################################################################
##
## Filename:	Makefile
##
## Project:	wbuart32, a full featured UART with simulator
##
## Purpose:	To direct the formal verification of the UART (and FIFO)
##		sources.
##
## Targets:	The default target, all, tests all of the components defined
##		within this module.
##
## Creator:	Dan Gisselquist, Ph.D.
##		Gisselquist Technology, LLC
##
################################################################################
##
## Copyright (C) 2017, Gisselquist Technology, LLC
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
## with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
## target there if the PDF file isn't present.)  If not, see
## <http://www.gnu.org/licenses/> for a copy.
##
## License:	GPL, v3, as defined and found on www.gnu.org,
##		http://www.gnu.org/licenses/gpl.html
##
################################################################################
##
##
TESTS := ufifo
.PHONY: $(TESTS)
all: $(TESTS)
RTL := ../../rtl
SMTBMC  := yosys-smtbmc
# SOLVER  := -s z3
SOLVER  := -s yices
# BMCARGS := --presat $(SOLVER)
BMCARGS := $(SOLVER)
INDARGS := $(SOLVER) -i

FIFO  := ufifo
TX    := txuartlite

$(FIFO).smt2: $(RTL)/$(FIFO).v
	yosys -ql $(FIFO).yslog -s $(FIFO).ys

$(TX).smt2: $(RTL)/$(TX).v
	yosys -ql $(TX).yslog -s $(TX).ys

$(FIFO) : $(FIFO).check
$(FIFO).check: $(FIFO).smt2
	$(SMTBMC) --presat $(BMCARGS) -t 24 --dump-vcd $(FIFO).vcd $(FIFO).smt2
	$(SMTBMC)          $(INDARGS) -t 24 --dump-vcd $(FIFO).vcd $(FIFO).smt2
	touch $@

$(TX) : $(TX).check
$(TX).check: $(TX).smt2
	$(SMTBMC) --presat $(BMCARGS) -t 200 --dump-vcd $(TX).vcd $(TX).smt2
	$(SMTBMC)          $(INDARGS) -t 200 --dump-vcd $(TX).vcd $(TX).smt2
	touch $@


.PHONY: clean
clean:
	rm -f  $(FIFO).smt2 $(FIFO)*.vcd
	rm -f  $(TX).smt2   $(TX)*.vcd
	rm -f *.check
