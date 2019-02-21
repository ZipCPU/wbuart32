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
## Copyright (C) 2017-2019, Gisselquist Technology, LLC
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
TESTS := ufifo txuartlite rxuartlite txuart
.PHONY: $(TESTS)
all: $(TESTS)
RTL := ../../rtl

FIFO  := ufifo
TX    := txuart
TXLITE:= txuartlite
RX    := rxuartlite

.PHONY: $(FIFO) $(TX) $(RX) $(TXLITE)
$(FIFO): $(FIFO)/PASS
$(TX): $(TX)/PASS
$(RX): $(RX)_prf/PASS $(RX)_cvr/PASS
$(TXLITE): $(TXLITE)_cvr/PASS $(TXLITE)_prf/PASS

$(TX)/PASS:     $(TX).sby $(RTL)/$(TX).v
	sby -f $(TX).sby

$(RX)_prf/PASS:     $(RX).sby $(RTL)/$(RX).v
	sby -f $(RX).sby prf
$(RX)_cvr/PASS:     $(RX).sby $(RTL)/$(RX).v
	sby -f $(RX).sby cvr

$(TXLITE)_cvr/PASS:     $(TXLITE).sby $(RTL)/$(TXLITE).v
	sby -f $(TXLITE).sby cvr
$(TXLITE)_prf/PASS:     $(TXLITE).sby $(RTL)/$(TXLITE).v
	sby -f $(TXLITE).sby prf

$(FIFO)/PASS:   $(FIFO).sby $(RTL)/$(FIFO).v
	sby -f $(FIFO).sby

.PHONY: clean
clean:
	rm -rf $(FIFO)/ $(RX)_*/ $(TX)/ $(TXLITE)_cvr/ $(TXLITE)_prf/
