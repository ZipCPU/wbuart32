////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	speechtest.cpp
//
// Project:	wbuart32, a full featured UART with simulator
//
// Purpose:	To demonstrate a useful Verilog file which could be used as a
//		toplevel program later, to demo the transmit UART as it might
//	be commanded from a WB bus, and having a FIFO.
//
//	If all goes well, the program will write out the words of the Gettysburg
//	address in interactive mode.  In non-interactive mode, the program will
//	read its own output and report on whether or not it worked well.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2019, Gisselquist Technology, LLC
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
#include <verilatedos.h>
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <time.h>
#include <sys/types.h>
#include <signal.h>
#include <ctype.h>
#include "verilated.h"
#include "Vspeechfifo.h"
#include "uartsim.h"
#include "verilated_vcd_c.h"

void	usage(void) {
	fprintf(stderr, "USAGE: speechtest [-i] [<matchfile>.txt]\n");
	fprintf(stderr, "\n"
"\tWhere ... \n"
"\t-i\tis an optional argument, instructing speechtest to run\n"
"\t\tinteractively.  This mode offers no checkin against any possible\n"
"\t\ttruth or match file.\n"
"\n"
"\t<matchfile.txt>\t is the name of a file which will be compared against\n"
"\t\tthe output of the simulation.  If the output matches the match\n"
"\t\tfile, the simulation will exit with success.  Only the number of\n"
"\t\tcharacters in the match file will be tested.\n\n");
};

int	main(int argc, char **argv) {
	Verilated::commandArgs(argc, argv);
	Vspeechfifo	tb;
	UARTSIM		*uart;
	int		port = 0;
	unsigned	setup = 25, testcount = 0, baudclocks;
	const char	*matchfile = "speech.txt";
	bool		run_interactively = false;

	for(int argn=1; argn<argc; argn++) {
		if (argv[argn][0]=='-') for(int j=1; (j<1000)&&(argv[argn][j]); j++)
		switch(argv[argn][j]) {
			case 'i': run_interactively = true;
				break;
			default:
				printf("Undefined option, -%c\n", argv[argn][j]);
				usage();
				exit(EXIT_FAILURE);
		} else {
			matchfile = argv[argn];
		}
	}

	tb.i_setup = setup;
	baudclocks = setup & 0x0ffffff;

	if (run_interactively) {
		//
		// The difference between the non-interactive mode and the
		// interactive mode is that in the interactive mode we don't
		// get to observe the speech being output to stdout.  Thus,
		// we blindly run for a period of clocks, and then stop.
		//
		// The cool part of the interactive mode is that we can
		// output internals from the simulation, for the purpose of
		// debug by printf.  We can also dump things to a VCD file,
		// should you wish to run GTKwave.
		//
		uart = new UARTSIM(port);
		uart->setup(tb.i_setup);

		Verilated::traceEverOn(true);
		VerilatedVcdC* tfp = new VerilatedVcdC;
		tb.trace(tfp, 99);
		tfp->open("speechtrace.vcd");

		testcount = 0;
		while(testcount < baudclocks * 16 * 4096) {
			// Run one tick of the clock.

			tb.i_clk = 1;	// Positive edge
			tb.eval();
			tfp->dump(5*(2*testcount));
			tb.i_clk = 0;	// Negative edge
			tb.eval();

			// Now, evaluate the UART, throwing away the received
			// value since the SpeechTest doesnt use it.
			(*uart)(tb.o_uart_tx);

			tfp->dump(5*(2*testcount+1));
			testcount++;

// #define	DEBUG
#ifdef	DEBUG
		//
		// Here are my notes from my last attempt at debug by printf.
		printf("%08x ", 
			tb.v__DOT__restart_counter);
		printf("%s %s@%d<-%08x[%c/%4d] (%s%s,%08x,%2d,%2d,%2d,%c,%s) %s,%02x >%d\n",
			(tb.v__DOT__restart)?"RST":"   ",
			(tb.v__DOT__wb_stb)?"STB":"   ",
			(tb.v__DOT__wb_addr),
			(tb.v__DOT__wb_data),
				isgraph(tb.v__DOT__wb_data&0x0ff)?
					(tb.v__DOT__wb_data&0x0ff) : '.',
			(tb.v__DOT__msg_index),
			(tb.v__DOT__wbuarti__DOT____Vcellinp__txfifo____pinNumber2)?"RST":"   ",
			(tb.v__DOT__wbuarti__DOT__txf_wb_write)?"WR":"  ",
			(tb.v__DOT__wbuarti__DOT__txfifo__DOT__r_fill),
			(tb.v__DOT__wbuarti__DOT__txfifo__DOT__r_first),
			(tb.v__DOT__wbuarti__DOT__txfifo__DOT__w_first_plus_one),
			(tb.v__DOT__wbuarti__DOT__txfifo__DOT__r_last),
			isgraph(tb.v__DOT__wbuarti__DOT__tx_data&0x0ff)?
					(tb.v__DOT__wbuarti__DOT__tx_data&0x0ff) : '.',
			(tb.v__DOT__wbuarti__DOT____Vcellinp__txfifo____pinNumber5)?"RD":"  ",
			(tb.v__DOT__wbuarti__DOT__tx_empty_n)?"TXI":"EMP",
			(tb.v__DOT__wbuarti__DOT__tx_data),
			(tb.o_uart_tx));
#endif
		}

		tfp->close();

		//
		// *IF* we ever get here, then at least explain to the user
		// why we stopped.
		//
		printf("\n\nSimulation complete\n");
	} else {
		//
		// Non-interactive mode is more difficult.  In this case, we
		// must figure out how to determine if the test was successful
		// or not.  Since uartsim dumps the UART output to standard
		// out, we then need to do a bit of work to capture that.
		//
		// In particular, we are going to fork ourselves and set up our
		// child process so that we can read from its standard out
		// (and write to its standard in--although we don't).
		int	childs_stdin[2], childs_stdout[2];
		FILE	*fp = fopen(matchfile, "r");
		long	flen = 0;

		//
		// Before forking (and getting complicated), let's read the
		// file describing the data we are supposed to read.  Our goal
		// will basically be to do an strncmp with the data in this
		// file, and then to check for zero (equality).
		//
		if (fp == NULL) {
			fprintf(stderr, "ERR - could not open %s\n", matchfile);
			perror("O/S Err:");
			printf("FAIL\n");
			exit(EXIT_FAILURE);
		}

		// Quick, look up how long this file is.
		fseek(fp, 0l, SEEK_END);
		flen = ftell(fp);
		fseek(fp, 0l, SEEK_SET);

		if (flen <= 0) {
			if (flen == 0)
				fprintf(stderr, "ERR - zero length match file!\n");
			else {
				fprintf(stderr, "ERR - getting file length\n");
				perror("O/S Err:");
			}
			printf("FAIL\n");
			exit(EXIT_FAILURE);
		}


		// We are ready to do our forking magic.  So, let's allocate
		// pipes for the childs standard input and output streams.
		if ((pipe(childs_stdin)!=0)||(pipe(childs_stdout) != 0)) {
			fprintf(stderr, "ERR setting up child pipes\n");
			perror("O/S Err:");
			printf("FAIL\n");
			exit(EXIT_FAILURE);
		}

	
		//
		//	FORK	!!!!!
		//
		// After this line, there are two threads running--a parent and
		// a child.  The childs child_pid will be zero, the parents
		// child_pid will be the pid of the child.
		pid_t	child_pid = fork();

		// Make sure the fork worked ...
		if (child_pid < 0) {
			fprintf(stderr, "ERR setting up child process fork\n");
			perror("O/S Err:");
			printf("FAIL\n");
			exit(EXIT_FAILURE);
		}

		if (child_pid) {
			int	nr = -2, rd, fail;

			// We are the parent
			// Adjust our pipe file descriptors so that they are
			// useful.
			close(childs_stdin[ 0]); // Close the read end
			close(childs_stdout[1]); // Close the write end

			// Let's allocate some buffers to contain both our
			// match file (string), and what we read from the 
			// UART.  Nominally, we would only need flen+1
			// characters, but this number doesn't quite work--since
			// mkspeech turned all of the the LFs into CR/LF pairs.
			// In the worst case, this would double the number of
			// characters we would need.  Hence, we read allocate
			// enough for the worst case.
			char	*string = (char *)malloc((size_t)(2*flen+2)),
				*rdbuf  = (char *)malloc((size_t)(2*flen+2));

			// If this doesn't work, admit to a failure
			if ((string == NULL)||(rdbuf == NULL)) {
				fprintf(stderr, "ERR Malloc failure --- cannot allocate space to read match file\n");
				perror("O/S Err:");
				printf("FAIL\n");
				exit(EXIT_FAILURE);
			}

			// Read the string we are going to match against from
			// the matchfile.  Expand NLs into CR,NL pairs.  Also
			// keep track of the resulting length (in flen), and
			// terminate the string with a null character.
			//
			{
				// Read string, and expand newlines into 
				// CR LF pairs
				char	*dp = string;
				int	ch;
				while((ch =fgetc(fp))!=EOF) {
					if (ch == '\n')
						*dp++ = '\r';
					*dp++ = ch;
				}
				*dp++ = '\0';
				flen = strlen(string);
			}

			//
			// Enough setup, let's do our work: Read a character
			// from the pipe and compare it against what we are
			// expecting.  Break out on any comparison failure.
			//
			nr = 0;
			rd = 0;
			fail = -1;
			while((nr<flen)
				&&((rd = read(childs_stdout[0],
					&rdbuf[nr], 1))>0)) {
				for(int i=0; i<rd; i++)
					if (rdbuf[nr+i] != string[nr+i]) {
						fail = nr+i;
						break;
					}
				if (fail>=0)
					break;
				rdbuf[rd+nr] = 0;
				nr += rd;
			}

			// Tell the user how many (of how many) characters we
			// compared (that matched), for debugging purposes.
			//
			printf("MATCH COMPLETE, nr = %d (/ %ld)\n", nr, flen);
				fflush(stdout);

			kill(child_pid, SIGKILL);

			free(string);
			free(rdbuf);

			// Report on the results, either PASS or FAIL
			if (nr == flen) {
				printf("PASS\n");
				exit(EXIT_SUCCESS);
			} else {
				printf("%s\n\nDoes not match.  MISMATCH: ch[%d]=%c != %c (%02x)\nFAIL\n", rdbuf, fail, rdbuf[fail], string[fail], string[fail]);
				exit(EXIT_FAILURE);
			}
			//
			// At this point, the parent is complete, and can
			// exit.
		} else {
			//
			// If childs_pid == 0, then we are the child
			//
			// The child reports the uart result via stdout, so
			// let's make certain it points to STDOUT_FILENO.
			//
			close(childs_stdin[ 1]); // Close the write end
			close(childs_stdout[0]); // Close the read end

			// Now, adjust our stdin/stdout file numbers
			// Stdin first.  (Yes, I know we arent use stdin, this
			// is more for form than anything else.)
			close(STDIN_FILENO);
			if (dup(childs_stdin[0]) != STDIN_FILENO) {
				fprintf(stderr, "Could not create childs stdin\n");
				perror("O/S ERR");
				exit(EXIT_FAILURE);
			}

			// Set up the standard out file descriptor so that it
			// points to our pipe
			close(STDOUT_FILENO);
			if (dup(childs_stdout[1]) != STDOUT_FILENO) {
				fprintf(stderr, "Could not create childs stdout\n");
				perror("O/S ERR");
				exit(EXIT_FAILURE);
			}

			// Set the UARTSIM up to producing an output to the
			// STDOUT, rather than a TCP/IP port
			uart = new UARTSIM(0);
			// Set up our baud rate, stop bits, parity, etc.
			// properly
			uart->setup(tb.i_setup);

			//
			// Now ... we're finally ready to run our simulation.
			//
			// while(testcount < baudclocks * 16 * 2048)
			while(testcount++ < 0x7f000000) {
				// Rising edge of the clock
				tb.i_clk = 1;
				tb.eval();
				// Negative edge of the clock
				tb.i_clk = 0;
				tb.eval();

				// Advance the UART based upon the output
				// o_uart_tx value
				(*uart)(tb.o_uart_tx);
			}

			// We will never get here.  If all goes well, we will be
			// killed as soon as we produce the speech.txt file
			// output--many clocks before this.
	
			//
			// If we do get here, something is terribly wrong.
			//
			fprintf(stderr, "Child was never killed, did it produce any output?\n");
			fprintf(stderr, "FAIL\n");
			exit(EXIT_FAILURE);
		}
	}
}

