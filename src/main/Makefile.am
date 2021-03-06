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
## $Id: Makefile.am 15211 2016-03-20 23:36:57Z xavier $

include $(srcdir)/../common-rules.make

bin_PROGRAMS = octopus oct-test octopus_mpi

octopus_SOURCES =                       \
	invert_ks.F90                   \
	memory.F90                      \
	unocc.F90                       \
	static_pol.F90                  \
	geom_opt.F90                    \
	phonons_fd.F90                  \
	casida.F90                      \
	pulpo.F90                       \
	run.F90                         \
	main.F90

octopus_LDADD = $(all_LIBS)

oct_test_SOURCES = test.F90
oct_test_LDADD = \
        $(top_builddir)/src/system/libsystem.a           \
        $(top_builddir)/src/hamiltonian/libhamiltonian.a \
        $(top_builddir)/src/poisson/libpoisson.a         \
        $(top_builddir)/src/states/libstates.a           \
        $(top_builddir)/src/frozen/libfrozen.a           \
        $(top_builddir)/src/grid/libgrid.a               \
        $(top_builddir)/src/ions/libions.a               \
        $(top_builddir)/src/species/libspecies.a         \
        $(top_builddir)/src/math/libmath.a               \
        $(top_builddir)/src/basic/libbasic.a \
        $(other_LIBS)

noinst_HEADERS = \
	casida_inc.F90

octopus_mpi_SOURCES = octopus_mpi.F90

octopus_mpi_LDADD = \
	$(top_builddir)/src/basic/libbasic.a \
	$(other_LIBS)

CLEANFILES += octopus oct-test

# debug files from MacOS gcc with -g
clean-local :
	rm -rf *.dSYM

depend:
	@makedepf90 $(octopus_SOURCES) $(oct_test_sources)

unocc.o : unocc.F90
static_pol.o : static_pol.F90 
geom_opt.o : geom_opt.F90 
phonons_fd.o : phonons_fd.F90 
casida.o : casida.F90 casida_inc.F90 
pulpo.o : pulpo.F90 
run.o : run.F90 unocc.o static_pol.o pulpo.o phonons_fd.o geom_opt.o casida.o memory.o invert_ks.o
main.o : main.F90 run.o 
memory.o : memory.F90
