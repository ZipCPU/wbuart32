################################################################################
##
## Filename:	Makefile
## {{{
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
## }}}
## Copyright (C) 2017-2024, Gisselquist Technology, LLC
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
## }}}
## License:	GPL, v3, as defined and found on www.gnu.org,
## {{{
##		http://www.gnu.org/licenses/gpl.html
##
################################################################################
##
## }}}
TESTS := ufifo txuartlite rxuartlite txuart axiluart
.PHONY: $(TESTS)
all: $(TESTS)
RTL := ../../rtl

FIFO  := ufifo
TX    := txuart
TXLITE:= txuartlite
RX    := rxuartlite
AXIL  := axiluart

## Dependencies
## {{{
.PHONY: $(FIFO) $(TX) $(RX) $(TXLITE)
$(FIFO): $(FIFO)_prf/PASS $(FIFO)_cvr/PASS
$(TX): $(TX)/PASS
$(RX): $(RX)_prf/PASS $(RX)_cvr/PASS
$(TXLITE): $(TXLITE)_cvr/PASS $(TXLITE)_prf/PASS
$(AXIL): $(AXIL)_cvr/PASS $(AXIL)_prf/PASS $(AXIL)_cvrs/PASS $(AXIL)_prfs/PASS
## }}}

## TX = txuart
## {{{
$(TX)/PASS:     $(TX).sby $(RTL)/$(TX).v
	sby -f $(TX).sby
## }}}

## RX = rxuartlite
## {{{
$(RX)_prf/PASS:     $(RX).sby $(RTL)/$(RX).v
	sby -f $(RX).sby prf
$(RX)_cvr/PASS:     $(RX).sby $(RTL)/$(RX).v
	sby -f $(RX).sby cvr
## }}}

## TXLITE = txuartlite
## {{{
$(TXLITE)_cvr/PASS:     $(TXLITE).sby $(RTL)/$(TXLITE).v
	sby -f $(TXLITE).sby cvr
$(TXLITE)_prf/PASS:     $(TXLITE).sby $(RTL)/$(TXLITE).v
	sby -f $(TXLITE).sby prf
## }}}

## FIFO == ufifo
## {{{
$(FIFO)_prf/PASS:   $(FIFO).sby $(RTL)/$(FIFO).v
	sby -f $(FIFO).sby prf
$(FIFO)_cvr/PASS:   $(FIFO).sby $(RTL)/$(FIFO).v
	sby -f $(FIFO).sby cvr
## }}}

## AXIL
## {{{
AXILDEPS := $(AXIL).sby $(RTL)/$(AXIL).v $(RTL)/$(FIFO).v $(RTL)/skidbuffer.v faxil_slave.v
$(AXIL)_prf/PASS:   $(AXILDEPS)
	sby -f $(AXIL).sby prf
$(AXIL)_cvr/PASS:   $(AXILDEPS)
	sby -f $(AXIL).sby cvr
$(AXIL)_prfs/PASS:   $(AXILDEPS)
	sby -f $(AXIL).sby prfs
$(AXIL)_cvrs/PASS:   $(AXILDEPS)
	sby -f $(AXIL).sby cvrs
## }}}

.PHONY: report
report:
	+perl genreport.pl > report.html
## Clean
## {{{
.PHONY: clean
clean:
	rm -rf $(FIFO)_prf/ $(FIFO)_cvr/
	rm -rf $(RX)_*/  $(TX)/ $(TXLITE)_cvr/ $(TXLITE)_prf/
	rm -rf $(AXIL)_*/
## }}}
