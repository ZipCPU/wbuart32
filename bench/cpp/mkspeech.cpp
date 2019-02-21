////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	mkspeech.cpp
//
// Project:	wbuart32, a full featured UART with simulator
//
// Purpose:	To turn a text file (i.e. the Gettysburg address) into a 
//		hex file that can be included via readmemh.
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
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

/*
* endswith
*
* Real simple: returns true if the given string ends with the given ending.
* Useful for determining if a file ends with the extension .txt.
*
*/
bool	endswith(const char *str, const char *ending) {
	int	slen = strlen(str), send = strlen(ending);
	if (slen < send)
		return false;
	if (strcmp(&str[slen-send], ".txt")!=0)
		return false;
	return true;
}

/*
* usage()
*
* Tell the user the calling conventions of this program, and what the program
* can be used to accomplish.
*/
void	usage(void) {
	fprintf(stderr, "USAGE:\tmkspeech [-x] <filename>.txt [-o <outfile>]\n");
	fprintf(stderr, "\n"
"\tConverts a text file to a file such as can be included in a Verilog\n"
"\tprogram.  Without the -x argument, the mkspeech program defaults\n"
"\tto converting the text file to a hex file, whose output name defaults\n"
"\tto \'speech.hex\'.  With the -x argument, mkspeech converts the file\n"
"\tinto an include file such as might be used in a Verilog program\n"
"\tif and when the synthesis tool doesn\'t support hex files (Xilinx\'s\n"
"\tISE).  In this case, the output filename defaults to \'speech.inc\'.\n"
"\n\n");
}

int main(int argc, char **argv) {
	FILE	*fp, *fout;
	const	char	*input_filename = NULL, *output_filename = NULL;
	bool	xise_file = false;

	for(int argn=1; argn < argc; argn++) {
		if (argv[argn][0] == '-') {
			if (argv[argn][2] == '\0') {
				if (argv[argn][1] == 'x')
					xise_file = true;
				else if (argv[argn][1] == 'o') {
					if (argn+1<argc)
						output_filename = argv[++argn];
					else  {
					fprintf(stderr, "ERR: -o given, but no filename given");
						usage();
						exit(EXIT_FAILURE);
					}
				} else {
					fprintf(stderr, "ERR: Unknown argument, %s\n", argv[argn]);
					usage();
					exit(EXIT_FAILURE);
				}
			} else {
				fprintf(stderr, "ERR: Unknown argument, %s\n", argv[argn]);
				usage();
				exit(EXIT_FAILURE);
			}
		} else if (input_filename == NULL) {
			input_filename = argv[argn];
		} else {
			fprintf(stderr, "ERR: Too many file names given, %s when I already have %s\n", argv[argn], input_filename);
			usage();
			exit(EXIT_FAILURE);
		}
	}

	if (input_filename== NULL) {
		fprintf(stderr, "No filename given\n");
		usage();
		exit(EXIT_FAILURE);
	}

	if (!endswith(input_filename, ".txt")) {
		fprintf(stderr, "Err: %s is an invalid text file name\n", input_filename);
		exit(EXIT_FAILURE);
	}

	if (access(input_filename, F_OK)!=0) {
		fprintf(stderr, "Err: %s is not a file\n", input_filename);
		exit(EXIT_FAILURE);
	} else if (access(input_filename, R_OK)!=0) {
		fprintf(stderr, "Err: Cannot read %s\n", input_filename);
		exit(EXIT_FAILURE);
	}

	fp = fopen(input_filename, "r");
	if (fp == NULL) {
		fprintf(stderr, "Err: Cannot read %s\n", input_filename);
		exit(EXIT_FAILURE);
	}

	if (output_filename == NULL)
		output_filename = (xise_file) ? "speech.inc" : "speech.hex";

	fout = fopen(output_filename, "w");
	if (fout == NULL) {
		fprintf(stderr, "Err: Cannot write %s\n", output_filename);
		exit(EXIT_FAILURE);
	}

	if (xise_file) {
		// Build an include file
		int	ch, addr = 0;
		while((ch = fgetc(fp))!=EOF) {
			if (ch == '\n')
				fprintf(fout, "\t\tmessage[%4d] = 8\'h%02x;\n",
					addr++, '\n');
			fprintf(fout, "\t\tmessage[%4d] = 8\'h%02x;\n",
				addr++, ch);
		}

		for(; addr<2048; addr++)
			fprintf(fout, "\t\tmessage[%4d] = 8'h%02x;\n", addr, ' ');
	} else {
		// Bulid a proper hex file
		int	linelen = 0;
		int	ch, addr = 0;

		fprintf(fout, "@%08x ", addr); linelen += 4+6;
		while((ch = fgetc(fp))!=EOF) {
			if (ch == '\n') {
				fprintf(fout, "%02x ", '\r' & 0x0ff); linelen += 3; addr++;
				if (linelen >= 77) {
					fprintf(fout, "\n");
					linelen = 0;
					fprintf(fout, "@%08x ", addr); linelen += 4+6;
				}
			}
			fprintf(fout, "%02x ", ch & 0x0ff); linelen += 3; addr++;

			if (linelen >= 77) {
				fprintf(fout, "\n");
				linelen = 0;
				fprintf(fout, "@%08x ", addr); linelen += 4+6;
			}
		} fprintf(fout, "\n");
	}
	fclose(fp);
	fclose(fout);
}
