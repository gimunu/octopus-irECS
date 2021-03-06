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
!! $Id: states_group.F90 15357 2016-05-11 16:53:13Z huebener $

#include "global.h"

module states_group_oct_m
  use batch_oct_m
  use batch_ops_oct_m
  use global_oct_m
  use loct_pointer_oct_m
  use messages_oct_m
  use mpi_oct_m
  use profiling_oct_m
  use states_dim_oct_m

  implicit none

  private

  public ::                           &
    states_group_t,                   &
    states_group_null,                &
    states_group_copy

  type states_group_t
    type(batch_t), pointer   :: psib(:, :)            !< A set of wave-functions blocks
    integer                  :: nblocks               !< The number of blocks
    integer                  :: block_start           !< The lowest index of local blocks
    integer                  :: block_end             !< The highest index of local blocks
    integer, pointer         :: iblock(:, :)          !< A map, that for each state index, returns the index of block containing it
    integer, pointer         :: block_range(:, :)     !< Each block contains states from block_range(:, 1) to block_range(:, 2)
    integer, pointer         :: block_size(:)         !< The number of states in each block.
    logical, pointer         :: block_is_local(:, :)  !< It is true if the block is in this node.
    integer, allocatable     :: block_node(:)         !< The node that contains each block
    integer, allocatable     :: rma_win(:, :)         !< The MPI window for one side communication
    logical                  :: block_initialized     !< For keeping track of the blocks to avoid memory leaks
  end type states_group_t

contains

  ! ---------------------------------------------------------
  subroutine states_group_null(this)
    type(states_group_t), intent(out)   :: this

    PUSH_SUB(states_group_null)

    nullify(this%psib)
    nullify(this%iblock)
    nullify(this%block_range)
    nullify(this%block_size)
    nullify(this%block_is_local)

    this%block_initialized = .false.

    POP_SUB(states_group_null)
  end subroutine states_group_null

  !---------------------------------------------------------

  subroutine states_group_copy(d,group_in, group_out)
    type(states_dim_t) :: d
    type(states_group_t), intent(in)    :: group_in
    type(states_group_t), intent(out)   :: group_out

    integer :: qn_start, qn_end, ib, iqn
    
    PUSH_SUB(states_group_copy)

    call states_group_null(group_out)

    
    group_out%nblocks           = group_in%nblocks
    group_out%block_start       = group_in%block_start
    group_out%block_end         = group_in%block_end
    group_out%block_initialized = group_in%block_initialized

    if(group_out%block_initialized) then

      ASSERT(associated(group_in%psib))

      qn_start = d%kpt%start 
      qn_end   = d%kpt%end 

      SAFE_ALLOCATE(group_out%psib(1:group_out%nblocks, qn_start:qn_end))

      do iqn = qn_start, qn_end
        do ib = group_out%block_start, group_out%block_end
          call batch_copy(group_in%psib(ib, iqn), group_out%psib(ib, iqn), copy_data = .true.)
        end do
      end do
      
      call loct_pointer_copy(group_out%iblock, group_in%iblock)
      call loct_pointer_copy(group_out%block_range, group_in%block_range)
      call loct_pointer_copy(group_out%block_size, group_in%block_size)
      call loct_pointer_copy(group_out%block_is_local, group_in%block_is_local)
      call loct_allocatable_copy(group_out%block_node, group_in%block_node)
      call loct_allocatable_copy(group_out%rma_win, group_in%rma_win)
    
    end if

    POP_SUB(states_group_copy)
  end subroutine states_group_copy
  
end module states_group_oct_m


!! Local Variables:
!! mode: f90
!! coding: utf-8
!! End:
