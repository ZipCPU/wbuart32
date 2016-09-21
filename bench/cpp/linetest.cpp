////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	linetest.cpp
//
// Project:	wbuart32, a full featured UART with simulator
//
// Purpose:	To create a pass-through test of the receiver and transmitter
//		which can be exercised/proven via Verilator.
//
//	If you run this program with no arguments, it will run an automatic
//	test, returning "SUCCESS" on success, or "FAIL" on failure as a last
//	output line--hence it should support automated testing.
//
//	If you run with a '-i' argument, the program will run interactively.
//	It will then be up to you to determine if it works (or not).  As
//	always, it may be killed with a control C.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2016, Gisselquist Technology, LLC
//
// This program is free software (firmware): you can redistribute it and/or
// modify it under the terms of  the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or (at
// your option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program.  (It's in the $(ROOT)/doc directory, run make with no
// target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
//
// License:	GPL, v3, as defined and found on www.gnu.org,
//		http://www.gnu.org/licenses/gpl.html
//
//
////////////////////////////////////////////////////////////////////////////////
//
//
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <time.h>
#include <sys/types.h>
#include <signal.h>
#include "verilated.h"
#include "Vlinetest.h"
#include "uartsim.h"

int	main(int argc, char **argv) {
	Verilated::commandArgs(argc, argv);
	Vlinetest	tb;
	UARTSIM		*uart;
	bool		run_interactively = false;
	int		port = 0;
	unsigned	setup = 25;

	for(int argn=1; argn<argc; argn++) {
		if (argv[argn][0] == '-') for(int j=1; (j<1000)&&(argv[argn][j]); j++)
		switch(argv[argn][j]) {
			case 'i':
				run_interactively = true;
				break;
			case 'p':
				port = atoi(argv[argn++]); j+= 4000;
				run_interactively = true;
				break;
			case 's':
				setup= strtoul(argv[++argn], NULL, 0); j+= 4000;
				break;
			default:
				printf("Undefined option, -%c\n", argv[argn][j]);
				break;
		}
	}

	tb.i_setup = setup;
	tb.i_uart = 1;
	if (run_interactively) {
		uart = new UARTSIM(port);
		uart->setup(tb.i_setup);

		while(1) {

			tb.i_clk = 1;
			tb.eval();
			tb.i_clk = 0;
			tb.eval();

			tb.i_uart = (*uart)(tb.o_uart);
		}

	} else {
		int	childs_stdin[2], childs_stdout[2];

		if ((pipe(childs_stdin)!=0)||(pipe(childs_stdout) != 0)) {
			fprintf(stderr, "ERR setting up child pipes\n");
			perror("O/S ERR");
			printf("TEST FAILURE\n");
			exit(EXIT_FAILURE);
		}

		pid_t pid = fork();

		if (pid < 0) {
			fprintf(stderr, "ERR setting up child process\n");
			perror("O/S ERR");
			printf("TEST FAILURE\n");
			exit(EXIT_FAILURE);
		}

		if (pid) {
			int	nr=-2, nw;

			// We are the parent
			close(childs_stdin[ 0]); // Close the read end
			close(childs_stdout[1]); // Close the write end

			char string[] = "This is a UART testing string\r\n";
			char test[256];

			nw = write(childs_stdin[1], string, strlen(string));
			if (nw == (int)strlen(string)) {
				int	rpos = 0;
				test[0] = '\0';
				while((rpos<nw)
					&&(0<(nr=read(childs_stdout[0],
						&test[rpos], strlen(string)-rpos))))
					rpos += nr;
				
				nr = rpos;
				if (rpos > 0)
					test[rpos] = '\0';
				printf("Successfully read %d characters: %s\n", nr, test);
			}

			// We are done, kill our child if not already dead
			kill(pid, SIGTERM);

			if ((nr == nw)&&(nw == (int)strlen(string))
					&&(strcmp(test, string) == 0))
				printf("SUCCESS!\n");
			else
				printf("TEST FAILED\n");
		} else {
			close(childs_stdin[ 1]);
			close(childs_stdout[0]);
			close(STDIN_FILENO);
			if (dup(childs_stdin[0]) < 0) {
				fprintf(stderr, "ERR setting up child FD\n");
				perror("O/S ERR");
				exit(EXIT_FAILURE);
			}
			close(STDOUT_FILENO); 
			if (dup(childs_stdout[1]) < 0) {
				fprintf(stderr, "ERR setting up child FD\n");
				perror("O/S ERR");
				exit(EXIT_FAILURE);
			}

			// UARTSIM(0) uses stdin and stdout for its FD's
			uart = new UARTSIM(0);
			uart->setup(tb.i_setup);

			// Make sure we don't run longer than 4 seconds ...
			time_t	start = time(NULL);
			int	iterations_before_check = 2048;
			bool	done = false;

			for(int i=0; i<200000; i++) {
				// Clear any initial break condition
				tb.i_clk = 1;
				tb.eval();
				tb.i_clk = 0;
				tb.eval();

				tb.i_uart = 1;
			}

			while(!done) {
				tb.i_clk = 1;
				tb.eval();
				tb.i_clk = 0;
				tb.eval();

				tb.i_uart = (*uart)(tb.o_uart);

				if (false) {
					static long counts = 0;
					static int lasti = 1, lasto = 1;
					bool	writeout = false;

					counts++;
					if (lasti != tb.i_uart) {
						writeout = true;
						lasti = tb.i_uart;
					} if (lasto != tb.o_uart) {
						writeout = true;
						lasto = tb.o_uart;
					}

					if (writeout) {
					fprintf(stderr, "%08lx : [%d -> %d] %02x:%02x (%02x/%d) %d,%d->%02x [%2d/%d/%08x]\n",
						counts, tb.i_uart, tb.o_uart,
						tb.v__DOT__head,
						tb.v__DOT__tail,
						tb.v__DOT__lineend,
						tb.v__DOT__run_tx,
						tb.v__DOT__tx_stb,
						tb.v__DOT__transmitter__DOT__r_busy,
						tb.v__DOT__tx_data & 0x0ff,
						tb.v__DOT__transmitter__DOT__state,
						tb.v__DOT__transmitter__DOT__zero_baud_counter,
						tb.v__DOT__transmitter__DOT__baud_counter);
					}
				}

				if (iterations_before_check-- <= 0) {
					iterations_before_check = 2048;
					done = ((time(NULL)-start)>60);
					if (done)
					fprintf(stderr, "CHILD-TIMEOUT\n");
				}
			}
		} 
	}
}
