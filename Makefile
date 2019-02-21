################################################################################
##
## Filename: 	Makefile
##
## Project:	wbuart32, a full featured UART with simulator
##
## Purpose:	This is the master Makefile for the project.  It coordinates
##		the build of a Verilator test, "proving" that this core works
##	(to the extent that any simulated test "proves" anything).  This
##	make file depends upon the proper setup of Verilator.
##
## Creator:	Dan Gisselquist, Ph.D.
##		Gisselquist Technology, LLC
##
################################################################################
##
## Copyright (C) 2015-2019, Gisselquist Technology, LLC
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
##
################################################################################
##
##
all: rtl bench test

.PHONY: doc
doc:
	cd doc ; $(MAKE) --no-print-directory

.PHONY: rtl
rtl:
	cd rtl ; $(MAKE) --no-print-directory

.PHONY: bench
bench: rtl
	cd bench/verilog ; $(MAKE) --no-print-directory
	cd bench/cpp     ; $(MAKE) --no-print-directory

.PHONY: test
test: bench
	bench/cpp/linetest
	# bench/cpp/speechtest bench/cpp/speech.txt

.PHONY: clean
clean:
	cd rtl ; $(MAKE) --no-print-directory clean
	cd bench/verilog ; $(MAKE) --no-print-directory clean
	cd bench/cpp     ; $(MAKE) --no-print-directory clean
	cd doc           ; $(MAKE) --no-print-directory clean


