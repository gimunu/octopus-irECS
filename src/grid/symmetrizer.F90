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
!! $Id: symmetrizer.F90 15203 2016-03-19 13:15:05Z xavier $

#include "global.h"

module symmetrizer_oct_m
  use global_oct_m
  use messages_oct_m
  use mesh_oct_m
  use mpi_oct_m
  use par_vec_oct_m
  use profiling_oct_m
  use simul_box_oct_m
  use symm_op_oct_m
  use symmetries_oct_m

  implicit none

  private
  public ::                             &
    symmetrizer_t,                      &
    symmetrizer_init,                   &
    symmetrizer_end,                    &
    dsymmetrizer_apply,                 &
    zsymmetrizer_apply,                 &
    dsymmetrize_tensor,                 &
    zsymmetrize_tensor,                 &
    dsymmetrize_magneto_optics,         &
    zsymmetrize_magneto_optics

  type symmetrizer_t
    type(mesh_t), pointer :: mesh
  end type symmetrizer_t

contains

  ! ---------------------------------------------------------
  subroutine symmetrizer_init(this, mesh)
    type(symmetrizer_t),         intent(out) :: this
    type(mesh_t),        target, intent(in)  :: mesh

    PUSH_SUB(symmetrizer_init)
    
    this%mesh => mesh

    POP_SUB(symmetrizer_init)
  end subroutine symmetrizer_init

  ! ---------------------------------------------------------

  subroutine symmetrizer_end(this)
    type(symmetrizer_t), intent(inout) :: this

    PUSH_SUB(symmetrizer_end)
    nullify(this%mesh)

    POP_SUB(symmetrizer_end)
  end subroutine symmetrizer_end

  ! ---------------------------------------------------------
  
#include "undef.F90"
#include "real.F90"
#include "symmetrizer_inc.F90"

#include "undef.F90"
#include "complex.F90"
#include "symmetrizer_inc.F90"

end module symmetrizer_oct_m

!! Local Variables:
!! mode: f90
!! coding: utf-8
!! End:
