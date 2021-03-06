/*
 Copyright (C) 2011 X. Andrade

 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2, or (at your option)
 any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
 02110-1301, USA.

 $Id: trsm.cl 14305 2015-06-22 15:56:28Z dstrubbe $
*/

#include <cl_global.h>
#include <cl_complex.h>

__kernel void dtrsm(const int nst,
		    __global double const * restrict ss, const int ldss,
		    __global double * restrict psi, const int ldpsi){

  const int ip = get_global_id(0);
  
  for(int ist = 0; ist < nst; ist++){
    double a0 = 0.0;
    for(int jst = 0; jst < ist; jst++){
      a0 -= ss[ist*ldss + jst]*psi[ip*ldpsi + jst];
    }
    psi[ip*ldpsi + ist] = (psi[ip*ldpsi + ist] + a0)/ss[ist*ldss + ist];
  }

}

__kernel void ztrsm(const int nst,
		    __global double2 const * restrict ss, const int ldss,
		    __global double2 * restrict psi, const int ldpsi){

  const int ip = get_global_id(0);
  
  for(int ist = 0; ist < nst; ist++){
    double2 a0 = (double2) (0.0);
    for(int jst = 0; jst < ist; jst++){
      a0 -= complex_mul(ss[ist*ldss + jst], psi[ip*ldpsi + jst]);
    }
    psi[ip*ldpsi + ist] = complex_div(psi[ip*ldpsi + ist] + a0, ss[ist*ldss + ist]);
  }

}

/*
 Local Variables:
 mode: c
 coding: utf-8
 End:
*/
