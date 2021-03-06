## Process this file with automake to produce Makefile.in

## Copyright (C) 2002 M. Marques, A. Castro, A. Rubio, G. Bertsch
##
## This program is free software; you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation; either version 2, or (at your option)
## any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program; if not, write to the Free Software
## Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
## 02110-1301, USA.
##
## $Id: Makefile.am 15514 2016-07-22 06:10:20Z xavier $

noinst_LIBRARIES = libbasic.a

libbasic_a_SOURCES =     \
	io_csv.c         \
	loct.F90         \
	loct_pointer.F90 \
	string.F90       \
	varinfo.F90      \
	mpi.F90          \
	global.F90       \
	parser.F90       \
	messages.F90     \
	io.F90           \
	io_binary.c      \
	kinds.F90        \
	path.F90         \
	json.F90         \
	json_parser.F90  \
	mpi_lib.F90      \
	unit.F90         \
	unit_system.F90  \
	mpi_debug.F90    \
	profiling.F90    \
	utils.F90        \
	topology.F90     \
	multicomm.F90    \
	getopt_f.c       \
	command_line.F90 \
	distributed.F90  \
	hardware.F90     \
	ialist.F90       \
	iihash.F90       \
	calc_mode_par.F90 \
	recipes.c        \
	varia.c          \
	oct_f.c          \
	oct_gdlib_f.c    \
	write_iter.F90   \
	write_iter_low.cc \
	varinfo_low.c    \
	signals.c        \
	io_binary_f.F90  \
	io_csv_f.F90     \
	lookup.F90       \
	types.F90        \
	accel.F90       \
	space.F90        \
	blacs.F90        \
	blacs_proc_grid.F90  \
	comm.F90             \
	openscad.F90         \
	polyhedron.F90       \
	xml.F90              \
	xml_low.c            \
	test_parameters.F90  \
	sort.F90             \
	sort_low.cc          \
	debug.F90            \
	cuda.cc              \
	cublas.cc

noinst_HEADERS =               \
	mpi_debug_inc.F90      \
	mpi_lib_inc.F90        \
	loct_pointer_inc.F90   \
	varia.h                \
	io_binary.h            \
	comm_inc.F90           \
	accel_inc.F90         \
        io_binary_f_inc.F90    \
	sort_inc.F90

include $(srcdir)/../common-rules.make


# This is to generate the dependencies. It makes use of the makedepf90
# program of Erik Edelmann
# (http://www.helsinki.fi/~eedelman/makedepf90.html). It should be run
# from time to time (just typing make depend within the src
# directory), substituting the dependencies below by the resulting new
# dependencies. (For normal compilation of octopus, there is
# absolutely no need of installing makedepf90).
depend:
	@makedepf90 $(libbasic_a_SOURCES)

test_parameters.o : global.o
xml.o: xml.F90
types.o : types.F90
blacs.o : blacs.F90
mpi.o : mpi.F90 blacs.o
hardware.o : hardware.F90
varinfo.o : varinfo.F90 string.o
string.o : string.F90 loct.o
loct.o : loct.F90
loct_pointer.o : loct_pointer.F90 loct_pointer_inc.F90 global.o messages.o profiling.o
global.o : global.F90 mpi.o loct.o hardware.o varinfo.o Makefile
debug.o : debug.F90 global.o parser.o
unit.o : unit.F90 global.o
parser.o : parser.F90 mpi.o loct.o global.o unit.o varinfo.F90
messages.o : messages.F90 varinfo.o string.o mpi.o parser.o loct.o global.o unit.o debug.o
sort.o : sort.F90 sort_inc.F90 messages.o global.o
profiling.o : profiling.F90 mpi.o messages.o loct.o io.o global.o types.o sort.o

command_line.o : command_line.F90 messages.o profiling.o
io.o : io.F90 mpi.o messages.o parser.o loct.o global.o  
unit_system.o : unit_system.F90 unit.o io.o messages.o parser.o global.o   varinfo.o
write_iter.o : write_iter.F90
io_binary_f.o : io_binary_f.F90 io_binary_f_inc.F90 io_binary.h profiling.o messages.o
io_csv_f.o : io_csv_f.F90 io_binary.h messages.o
kinds.o : kinds.F90
path.o : path.F90 loct.o messages.o profiling.o global.o
json.o : json.F90 kinds.o io.o messages.o profiling.o global.o
json_parser.o : json_parser.F90 json.o kinds.o io.o messages.o profiling.o global.o

accel.o : accel.F90 accel_inc.F90 global.o types.o profiling.o messages.o parser.o mpi.o io.o unit_system.o
mpi_debug.o : mpi_debug.F90 mpi_debug_inc.F90 mpi.o messages.o loct.o global.o 
mpi_lib.o : mpi_lib.F90 mpi_lib_inc.F90 mpi_debug.o mpi.o messages.o global.o profiling.o
topology.o : topology.F90 utils.o mpi.o messages.o parser.o io.o global.o  profiling.o
multicomm.o : multicomm.F90 varinfo.o utils.o mpi.o messages.o parser.o io.o global.o  profiling.o
distributed.o: distributed.F90 multicomm.o profiling.o
calc_mode_par.o : calc_mode_par.F90 multicomm.o messages.o
blacs_proc_grid.o : blacs_proc_grid.F90 blacs.o mpi.o profiling.o messages.o global.o
comm.o : comm.F90 comm_inc.F90 mpi.o messages.o global.o profiling.o types.o

ialist.o : ialist.F90 global.o messages.o profiling.o
iihash.o : iihash.F90 ialist.o global.o
lookup.o : lookup.F90 global.o messages.o profiling.o loct_pointer.o
utils.o : utils.F90 messages.o global.o unit.o unit_system.o string.o mpi.o loct.o

space.o : space.F90 json.o parser.o messages.o

openscad.o : openscad.F90 io.o messages.o profiling.o global.o polyhedron.o
polyhedron.o : messages.o profiling.o global.o
