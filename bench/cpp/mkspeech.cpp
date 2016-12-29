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
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

int main(int argc, char **argv) {
	FILE	*fp, *fout;

	if (argc != 2) {
		fprintf(stderr, "Err: USAGE is mkspeech <filename>.txt\n");
		exit(EXIT_FAILURE);
	} else if ((!argv[1])||(strlen(argv[1])<5)
		||(strcmp(&argv[1][strlen(argv[1])-4], ".txt")!=0)) {
		fprintf(stderr, "Err: %s is an invalid text file name\n", argv[1]);
		exit(EXIT_FAILURE);
	} else if (access(argv[1], F_OK)!=0) {
		fprintf(stderr, "Err: %s is not a file\n", argv[1]);
		exit(EXIT_FAILURE);
	} else if (access(argv[1], R_OK)!=0) {
		fprintf(stderr, "Err: Cannot read %s\n", argv[1]);
		exit(EXIT_FAILURE);
	}

	fp = fopen(argv[1], "r");
	if (fp == NULL) {
		fprintf(stderr, "Err: Cannot read %s\n", argv[1]);
		exit(EXIT_FAILURE);
	}

	fout = fopen("speech.hex", "w");
	if (fout == NULL) {
		fprintf(stderr, "Err: Cannot write %s\n", "speech.hex");
		exit(EXIT_FAILURE);
	}

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

	fclose(fp);
	fclose(fout);
}
