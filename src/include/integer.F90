!! Copyright (C) 2002-2006 M. Marques, A. Castro, A. Rubio, G. Bertsch
!!
!! This program is free software; you can redistribute it and/or modify
!! it under the terms of the GNU General Public License as published by
!! the Free Software Foundation; either version 2, or (at your option)
!! any later version.
!!
!! This program is distributed in the hope that it will be useful,
!! but WITHOUT ANY WARRANTY; without even the implied warranty of
!! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!! GNU General Public License for more details.
!!
!! You should have received a copy of the GNU General Public License
!! along with this program; if not, write to the Free Software
!! Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
!! 02110-1301, USA.
!!
!! $Id: integer.F90 12882 2015-02-07 03:54:06Z xavier $

#define R_TINTEGER  1

#define X(x)        i ## x

#define R_TYPE      integer
#define R_BASE      integer
#define R_TYPE_VAL  TYPE_INTEGER
#define R_MPITYPE   MPI_INTEGER
#define R_TYPE_IOBINARY TYPE_INT_32
#define R_TOTYPE(x) (x)

#define R_ABS(x)    abs(x)
#define R_CONJ(x)   (x)
#define R_REAL(x)   (x)
#define R_AIMAG(x)  (M_ZERO)
#define R_SIZEOF    4

#if defined(DISABLE_DEBUG)
#define TS(x)       x
#else
#define TS(x)       TSI_ ## x
#endif

!! Local Variables:
!! mode: f90
!! coding: utf-8
!! End:
