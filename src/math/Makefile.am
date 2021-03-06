## Process this file with automake to produce Makefile.in

## Copyright (C) 2002-2014 M. Marques, A. Castro, A. Rubio, G. Bertsch, M. Oliveira
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
## $Id: Makefile.am 15563 2016-08-03 08:07:02Z xavier $

noinst_LIBRARIES = libmath.a

libmath_a_SOURCES =                      \
	blas.F90                         \
	checksum.c                       \
	checksum_interface.F90           \
	dablas.c                         \
	fft.F90                          \
	fftw.F90                         \
	spline_filter.F90                \
	gauss_legendre.F90               \
	loct_math.F90                    \
	lalg_basic.F90                   \
	math.F90                         \
	metis.F90                        \
	metis_f.c                        \
	lalg_adv.F90                     \
	lapack.F90                       \
	oct_gsl_f.c                      \
	minimizer_low.c                  \
	ode_solver.F90                   \
	permutations.F90                 \
	pfft.F90			 \
	root_solver.F90                  \
	solvers.F90                      \
	splines.F90                      \
	sparskit.F90                     \
	symm_op.F90                      \
	tdfunction.F90                   \
	ylm.c                            \
	young.F90                        \
	scalapack.F90                    \
	nfft.F90    			 \
	nfft_f.c                         \
	pblas.F90                        \
	sgfft.F90                        \
	matrix.F90                       \
	matrix_ops.F90                   \
	compressed_sensing.F90           \
	fftw_low.c                       \
	minimizer.F90                    \
        pnfft.F90                        \
	qshep.F90                        \
	spline_low.cc                    \
	quickrnd.F90                     \
	accel_blas.F90                   \
	cufft.cc

noinst_HEADERS =                         \
	fft_inc.F90                      \
	lalg_basic_blas_inc.F90          \
	lalg_adv_lapack_inc.F90          \
	math_inc.F90                     \
	ode_solver_inc.F90               \
	root_solver_inc.F90              \
	solvers_inc.F90                  \
	sparskit_inc.F90                 \
	symm_op_inc.F90                  \
	matrix_inc.F90                   \
	matrix_ops_inc.F90               \
	nfft_inc.F90                     \
	pnfft_inc.F90                    \
	accel_blas_inc.F90

include $(srcdir)/../common-rules.make

depend:
	@makedepf90 $(libmath_a_SOURCES)

blas.o : blas.F90 
checksum.o : checksum.c
checksum_interface.o : checksum_interface.F90
dablas.o : dablas.c 
fft.o : fft.F90 fft_inc.F90 fftw.o pfft.o pnfft.o nfft.o lalg_basic.o loct_math.o math.o
fftw.o : fftw.F90
pfft.o : pfft.F90 fftw.o math.o
pnfft.o : pnfft.F90 pnfft_inc.F90 pfft.o fftw.o math.o
nfft_f.o : nfft_f.c
nfft.o : nfft.F90 nfft_inc.F90 nfft_f.o fftw.o loct_math.o
spline_filter.o: spline_filter.F90 splines.o
gauss_legendre.o : gauss_legendre.F90 
lalg_basic.o : lalg_basic.F90 lalg_basic_blas_inc.F90 blas.o 
lalg_adv.o : lalg_adv.F90 lalg_adv_lapack_inc.F90 lapack.o scalapack.o
lapack.o : lapack.F90
loct_math.o : loct_math.F90
math.o : math.F90 math_inc.F90 lalg_basic.o loct_math.o blas.o
metis.o : metis.F90
metis_f.o : metis_f.c
oct_gsl_f.o : oct_gsl_f.c
ode_solver.o : ode_solver.F90 ode_solver_inc.F90 
permutations.o : permutations.F90 math.o
root_solver.o : root_solver.F90 root_solver_inc.F90 ode_solver.o lalg_adv.o 
solvers.o : solvers.F90 solvers_inc.F90 lalg_adv.o lalg_basic.o blas.o loct_math.o
splines.o : splines.F90 loct_math.o
sparskit.o : sparskit.F90 sparskit_inc.F90 blas.o
symm_op.o : symm_op.F90 symm_op_inc.F90
tdfunction.o : tdfunction.F90 splines.o fft.o math.o
ylm.o : ylm.c
young.o : young.F90 math.o
scalapack.o : scalapack.F90
pblas.o : pblas.F90
matrix.o : matrix.F90 matrix_inc.F90
matrix_ops.o : matrix_ops.F90 matrix_ops_inc.F90 matrix.o lapack.o
compressed_sensing.o : compressed_sensing.F90 blas.o
minimizer.o : minimizer.F90 lalg_basic.o
qshep.o : qshep.F90
spline_low.o : spline_low.cc
quickrnd.o : quickrnd.F90 
accel_blas.o : accel_blas.F90 accel_blas_inc.F90
