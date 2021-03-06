!! Copyright (C) 2008 X. Andrade
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
!! $Id: batch.F90 15474 2016-07-12 04:33:08Z xavier $

#include "global.h"

module batch_oct_m
  use accel_oct_m
  use blas_oct_m
  use iso_c_binding
  use global_oct_m
  use hardware_oct_m
  use lalg_adv_oct_m
  use lalg_basic_oct_m
  use parser_oct_m
  use math_oct_m
  use messages_oct_m
  use mpi_oct_m
  use profiling_oct_m
  use types_oct_m
  use varinfo_oct_m

  implicit none

  private
  public ::                         &
    batch_state_t,                  &
    batch_state_l_t,                &
    batch_pack_t,                   &
    batch_t,                        &
    batch_init,                     &
    batch_copy,                     &
    batch_copy_data,                &
    batch_end,                      &
    batch_add_state,                &
    dbatch_allocate,                &
    zbatch_allocate,                &
    sbatch_allocate,                &
    cbatch_allocate,                &
    batch_deallocate,               &
    batch_is_packed,                &
    batch_pack_was_modified,        &
    batch_is_ok,                    &
    batch_pack,                     &
    batch_unpack,                   &
    batch_sync,                     &
    batch_status,                   &
    batch_type,                     &
    batch_inv_index,                &
    batch_ist_idim_to_linear,       &
    batch_linear_to_ist,            &
    batch_linear_to_idim,           &
    batch_pack_size,                &
    batch_is_sync,                  &
    batch_remote_access_start,      &
    batch_remote_access_stop
  
  !--------------------------------------------------------------
  type batch_state_t
    FLOAT,      pointer :: dpsi(:, :)
    CMPLX,      pointer :: zpsi(:, :)
    real(4),    pointer :: spsi(:, :)
    complex(4), pointer :: cpsi(:, :)
    integer        :: ist
  end type batch_state_t

  type batch_state_l_t
    FLOAT,      pointer :: dpsi(:)
    CMPLX,      pointer :: zpsi(:)
    real(4),    pointer :: spsi(:)
    complex(4), pointer :: cpsi(:)
  end type batch_state_l_t
  
  type batch_pack_t
    integer                        :: size(1:2)
    integer                        :: size_real(1:2)
    FLOAT,      allocatable        :: dpsi(:, :)
    CMPLX,      allocatable        :: zpsi(:, :)
    real(4),    allocatable        :: spsi(:, :)
    complex(4), allocatable        :: cpsi(:, :)
    type(accel_mem_t)             :: buffer
  end type batch_pack_t
  
  type batch_t
    type(batch_state_t), pointer   :: states(:)
    integer                        :: nst
    integer                        :: current
    integer                        :: dim

    integer                        :: ndims
    integer,             pointer   :: ist_idim_index(:, :)

    logical                        :: is_allocated

    !> We also need a linear array with the states in order to calculate derivatives, etc.
    integer                        :: nst_linear
    type(batch_state_l_t), pointer :: states_linear(:)

    !> If the memory is contiguous, we can perform some operations faster.
    FLOAT,               pointer   :: dpsicont(:, :, :)
    CMPLX,               pointer   :: zpsicont(:, :, :)
    real(4),             pointer   :: spsicont(:, :, :)
    complex(4),          pointer   :: cpsicont(:, :, :)
    integer                        :: status
    integer                        :: in_buffer_count !< whether there is a copy in the opencl buffer
    logical                        :: dirty     !< if this is true, the buffer has different data
    type(batch_pack_t)             :: pack
  end type batch_t

  !--------------------------------------------------------------
  interface batch_init
    module procedure  batch_init_empty
    module procedure  batch_init_empty_linear
    module procedure dbatch_init_contiguous
    module procedure zbatch_init_contiguous
    module procedure sbatch_init_contiguous
    module procedure cbatch_init_contiguous
  end interface batch_init

  interface batch_add_state
    module procedure dbatch_add_state
    module procedure zbatch_add_state
    module procedure sbatch_add_state
    module procedure cbatch_add_state
    module procedure dbatch_add_state_linear
    module procedure zbatch_add_state_linear
    module procedure sbatch_add_state_linear
    module procedure cbatch_add_state_linear
  end interface batch_add_state

  integer, public, parameter :: &
    BATCH_NOT_PACKED = 0,       &
    BATCH_PACKED     = 1,       &
    BATCH_CL_PACKED  = 2

  integer, parameter :: CL_PACK_MAX_BUFFER_SIZE = 4 !< this value controls the size (in number of wave-functions)
                                                    !! of the buffer used to copy states to the opencl device.

contains

  !--------------------------------------------------------------
  subroutine batch_end(this, copy)
    type(batch_t),           intent(inout) :: this
    logical,       optional, intent(in)    :: copy

    PUSH_SUB(batch_end)

    if(batch_is_packed(this)) then
      call batch_unpack(this, copy, force = .true.)
    end if

    if(this%is_allocated) then
      call batch_deallocate(this)
    end if

    nullify(this%dpsicont)
    nullify(this%zpsicont)
    nullify(this%spsicont)
    nullify(this%cpsicont)

    SAFE_DEALLOCATE_P(this%states)
    SAFE_DEALLOCATE_P(this%states_linear)
    
    SAFE_DEALLOCATE_P(this%ist_idim_index)

    POP_SUB(batch_end)
  end subroutine batch_end

  !--------------------------------------------------------------
  subroutine batch_deallocate(this)
    type(batch_t),  intent(inout) :: this
    
    integer :: ii
    
    PUSH_SUB(batch_deallocate)

    this%is_allocated = .false.

    do ii = 1, this%nst
      nullify(this%states(ii)%dpsi)
      nullify(this%states(ii)%zpsi)
      nullify(this%states(ii)%spsi)
      nullify(this%states(ii)%cpsi)
    end do
    
    do ii = 1, this%nst_linear
      nullify(this%states_linear(ii)%dpsi)
      nullify(this%states_linear(ii)%zpsi)
      nullify(this%states_linear(ii)%spsi)
      nullify(this%states_linear(ii)%cpsi)
    end do
    
    this%current = 1
    
    SAFE_DEALLOCATE_P(this%dpsicont)
    SAFE_DEALLOCATE_P(this%zpsicont)
    SAFE_DEALLOCATE_P(this%spsicont)
    SAFE_DEALLOCATE_P(this%cpsicont)
    
    POP_SUB(batch_deallocate)
  end subroutine batch_deallocate
  
  !--------------------------------------------------------------

  subroutine batch_init_empty (this, dim, nst)
    type(batch_t), intent(out)   :: this
    integer,       intent(in)    :: dim
    integer,       intent(in)    :: nst
    
    integer :: ist

    PUSH_SUB(batch_init_empty)

    this%is_allocated = .false.
    this%nst = nst
    this%dim = dim
    this%current = 1
    nullify(this%dpsicont, this%zpsicont, this%spsicont, this%cpsicont)
    
    SAFE_ALLOCATE(this%states(1:nst))
    do ist = 1, nst
      nullify(this%states(ist)%dpsi)
      nullify(this%states(ist)%zpsi)
      nullify(this%states(ist)%spsi)
      nullify(this%states(ist)%cpsi)
    end do
    
    this%nst_linear = nst*dim
    SAFE_ALLOCATE(this%states_linear(1:this%nst_linear))
    do ist = 1, this%nst_linear
      nullify(this%states_linear(ist)%dpsi)
      nullify(this%states_linear(ist)%zpsi)
      nullify(this%states_linear(ist)%spsi)
      nullify(this%states_linear(ist)%cpsi)
    end do
    
    this%in_buffer_count = 0
    this%status = BATCH_NOT_PACKED

    this%ndims = 2
    SAFE_ALLOCATE(this%ist_idim_index(1:this%nst_linear, 1:this%ndims))

    POP_SUB(batch_init_empty)
  end subroutine batch_init_empty


  !--------------------------------------------------------------
  !> When we are interested in batches of 1D functions
  subroutine batch_init_empty_linear(this, nst)
    type(batch_t), intent(out)   :: this
    integer,       intent(in)    :: nst
    
    integer :: ist

    PUSH_SUB(batch_init_empty_linear)

    this%is_allocated = .false.
    this%nst = 0
    this%dim = 0
    this%current = 1
    nullify(this%dpsicont, this%zpsicont, this%spsicont, this%cpsicont)
    nullify(this%states)

    this%nst_linear = nst
    SAFE_ALLOCATE(this%states_linear(1:this%nst_linear))
    do ist = 1, this%nst_linear
      nullify(this%states_linear(ist)%dpsi)
      nullify(this%states_linear(ist)%zpsi)
      nullify(this%states_linear(ist)%spsi)
      nullify(this%states_linear(ist)%cpsi)
    end do

    this%in_buffer_count = 0
    this%status = BATCH_NOT_PACKED

    this%ndims = 1
    SAFE_ALLOCATE(this%ist_idim_index(1:this%nst_linear, 1:this%ndims))

    POP_SUB(batch_init_empty_linear)
  end subroutine batch_init_empty_linear


  !--------------------------------------------------------------
  logical function batch_is_ok(this) result(ok)
    type(batch_t), intent(in)   :: this

    integer :: ist
    logical :: all_assoc(1:4)
    
    ! no push_sub, called too frequently
    
    ok = (this%nst_linear >= 1) .and. associated(this%states_linear)
    ok = ubound(this%states_linear, dim = 1) == this%nst_linear
    if(ok) then
      ! ensure that either all real are associated, or all cplx are associated
      all_assoc = .true.
      do ist = 1, this%nst_linear
        all_assoc(1) = all_assoc(1) .and. associated(this%states_linear(ist)%dpsi)
        all_assoc(2) = all_assoc(2) .and. associated(this%states_linear(ist)%zpsi)
        all_assoc(3) = all_assoc(3) .and. associated(this%states_linear(ist)%spsi)
        all_assoc(4) = all_assoc(4) .and. associated(this%states_linear(ist)%cpsi)
      end do

      ok = ok .and. (count(all_assoc, dim = 1) == 1)
   end if

  end function batch_is_ok

  !--------------------------------------------------------------

  subroutine batch_copy(bin, bout, pack, copy_data)
    type(batch_t), target,   intent(in)    :: bin
    type(batch_t),           intent(out)   :: bout
    logical,       optional, intent(in)    :: pack      !< If .false. the new batch will not be packed
    logical,       optional, intent(in)    :: copy_data
    !! If .true. the new batch will be packed
    !! The default is to do the same as bin.

    integer :: ii, np
    logical :: pack_

    PUSH_SUB(batch_copy)

    call batch_init_empty(bout, bin%dim, bin%nst)

    if(batch_type(bin) == TYPE_FLOAT) then

      np = 0
      do ii = 1, bin%nst_linear
        np = max(np, ubound(bin%states_linear(ii)%dpsi, dim = 1))
      end do

      call dbatch_allocate(bout, 1, bin%nst, np)

    else if(batch_type(bin) == TYPE_CMPLX) then
      np = 0
      do ii = 1, bin%nst_linear
        np = max(np, ubound(bin%states_linear(ii)%zpsi, dim = 1))
      end do

      call zbatch_allocate(bout, 1, bin%nst, np)

    else if(batch_type(bin) == TYPE_FLOAT_SINGLE) then

      np = 0
      do ii = 1, bin%nst_linear
        np = max(np, ubound(bin%states_linear(ii)%spsi, dim = 1))
      end do

      call sbatch_allocate(bout, 1, bin%nst, np)

    else if(batch_type(bin) == TYPE_CMPLX_SINGLE) then

      np = 0
      do ii = 1, bin%nst_linear
        np = max(np, ubound(bin%states_linear(ii)%cpsi, dim = 1))
      end do

      call cbatch_allocate(bout, 1, bin%nst, np)

    end if

    pack_ = batch_is_packed(bin)
    if(present(pack)) pack_ = pack
    if(pack_) call batch_pack(bout, copy = .false.)

    do ii = 1, bout%nst
      bout%states(ii)%ist = bin%states(ii)%ist
    end do

    bout%ist_idim_index(1:bin%nst_linear, 1:bin%ndims) = bin%ist_idim_index(1:bin%nst_linear, 1:bin%ndims)

    if(optional_default(copy_data, .false.)) call batch_copy_data(np, bin, bout)
    
    POP_SUB(batch_copy)
  end subroutine batch_copy

  ! ----------------------------------------------------
  !> THREADSAFE
  type(type_t) pure function batch_type(this) result(btype)
    type(batch_t),      intent(in)    :: this

    if(associated(this%states_linear(1)%dpsi)) btype = TYPE_FLOAT
    if(associated(this%states_linear(1)%zpsi)) btype = TYPE_CMPLX
    if(associated(this%states_linear(1)%spsi)) btype = TYPE_FLOAT_SINGLE
    if(associated(this%states_linear(1)%cpsi)) btype = TYPE_CMPLX_SINGLE
    
  end function batch_type

  ! ----------------------------------------------------
  !> THREADSAFE
  integer pure function batch_status(this) result(bstatus)
    type(batch_t),      intent(in)    :: this

    bstatus = this%status
  end function batch_status
  
  ! ----------------------------------------------------

  logical pure function batch_is_packed(this) result(in_buffer)
    type(batch_t),      intent(in)    :: this

    in_buffer = this%in_buffer_count > 0
  end function batch_is_packed

  ! ----------------------------------------------------

  integer pure function batch_max_size(this) result(size)
    type(batch_t),      intent(in)    :: this

    integer :: ist

    size = 0
    do ist = 1, this%nst_linear
      if(associated(this%states_linear(ist)%dpsi)) then
        size = max(size, ubound(this%states_linear(ist)%dpsi, dim = 1))
      else if(associated(this%states_linear(ist)%zpsi)) then
        size = max(size, ubound(this%states_linear(ist)%zpsi, dim = 1))
      else if(associated(this%states_linear(ist)%spsi)) then
        size = max(size, ubound(this%states_linear(ist)%spsi, dim = 1))
      else if(associated(this%states_linear(ist)%cpsi)) then
        size = max(size, ubound(this%states_linear(ist)%cpsi, dim = 1))
      end if
    end do

  end function batch_max_size

  ! ----------------------------------------------------

  subroutine batch_pack_was_modified(this)
    type(batch_t),      intent(inout) :: this

    this%dirty = .true.
  end subroutine batch_pack_was_modified

  ! ----------------------------------------------------

  integer function batch_pack_size(this) result(size)
    type(batch_t),      intent(inout) :: this

    size = batch_max_size(this)
    if(accel_is_enabled()) size = accel_padded_size(size)
    size = size*pad_pow2(this%nst_linear)*types_get_size(batch_type(this))

  end function batch_pack_size

  ! ----------------------------------------------------

  subroutine batch_pack(this, copy)
    type(batch_t),      intent(inout) :: this
    logical, optional,  intent(in)    :: copy

    logical :: copy_
    type(profile_t), save :: prof, prof_copy

    ! no push_sub, called too frequently

    call profiling_in(prof, "BATCH_PACK")
    ASSERT(batch_is_ok(this))

    copy_ = .true.
    if(present(copy)) copy_ = copy

    if(.not. batch_is_packed(this)) then
      this%pack%size(1) = pad_pow2(this%nst_linear)
      this%pack%size(2) = batch_max_size(this)

      if(accel_is_enabled()) this%pack%size(2) = accel_padded_size(this%pack%size(2))

      this%pack%size_real = this%pack%size
      if(type_is_complex(batch_type(this))) this%pack%size_real(1) = 2*this%pack%size_real(1)

      if(accel_is_enabled()) then
        this%status = BATCH_CL_PACKED
        call accel_create_buffer(this%pack%buffer, ACCEL_MEM_READ_WRITE, batch_type(this), product(this%pack%size))
      else
        this%status = BATCH_PACKED
        if(batch_type(this) == TYPE_FLOAT) then
          SAFE_ALLOCATE(this%pack%dpsi(1:this%pack%size(1), 1:this%pack%size(2)))
        else if(batch_type(this) == TYPE_CMPLX) then
          SAFE_ALLOCATE(this%pack%zpsi(1:this%pack%size(1), 1:this%pack%size(2)))
        else if(batch_type(this) == TYPE_FLOAT_SINGLE) then
          SAFE_ALLOCATE(this%pack%spsi(1:this%pack%size(1), 1:this%pack%size(2)))
        else if(batch_type(this) == TYPE_CMPLX_SINGLE) then
          SAFE_ALLOCATE(this%pack%cpsi(1:this%pack%size(1), 1:this%pack%size(2)))
        end if
      end if
      
      if(copy_) then
        call profiling_in(prof_copy, "BATCH_PACK_COPY")

        this%dirty = .false.
        if(accel_is_enabled()) then

          call batch_write_to_opencl_buffer(this)

        else
          call pack_copy()
        end if

        call profiling_out(prof_copy)
      else
        this%dirty = .true.
      end if
    end if

    INCR(this%in_buffer_count, 1)

    call profiling_out(prof)

  contains

    subroutine pack_copy()
      integer :: ist, ip, sp, ep, bsize
      
 
      if(batch_type(this) == TYPE_FLOAT) then

        bsize = hardware%dblock_size
      
        !$omp parallel do private(ep, ist, ip)
        do sp = 1, this%pack%size(2), bsize
          ep = min(sp + bsize - 1, this%pack%size(2))
          forall(ist = 1:this%nst_linear)
            forall(ip = sp:ep)
              this%pack%dpsi(ist, ip) = this%states_linear(ist)%dpsi(ip)
            end forall
          end forall
        end do

      else if(batch_type(this) == TYPE_CMPLX) then

        bsize = hardware%zblock_size

        !$omp parallel do private(ep, ist, ip)
        do sp = 1, this%pack%size(2), bsize
          ep = min(sp + bsize - 1, this%pack%size(2))
          forall(ist = 1:this%nst_linear)
            forall(ip = sp:ep)
              this%pack%zpsi(ist, ip) = this%states_linear(ist)%zpsi(ip)
            end forall
          end forall
        end do

      else if(batch_type(this) == TYPE_FLOAT_SINGLE) then

        bsize = hardware%zblock_size

        !$omp parallel do private(ep, ist, ip)
        do sp = 1, this%pack%size(2), bsize
          ep = min(sp + bsize - 1, this%pack%size(2))
          forall(ist = 1:this%nst_linear)
            forall(ip = sp:ep)
              this%pack%spsi(ist, ip) = this%states_linear(ist)%spsi(ip)
            end forall
          end forall
        end do

      else if(batch_type(this) == TYPE_CMPLX_SINGLE) then

        bsize = hardware%zblock_size

        !$omp parallel do private(ep, ist, ip)
        do sp = 1, this%pack%size(2), bsize
          ep = min(sp + bsize - 1, this%pack%size(2))
          forall(ist = 1:this%nst_linear)
            forall(ip = sp:ep)
              this%pack%cpsi(ist, ip) = this%states_linear(ist)%cpsi(ip)
            end forall
          end forall
        end do

      end if

      call profiling_count_transfers(this%nst_linear*this%pack%size(2), batch_type(this))
      
    end subroutine pack_copy

  end subroutine batch_pack

  ! ----------------------------------------------------

  subroutine batch_unpack(this, copy, force)
    type(batch_t),      intent(inout) :: this
    logical, optional,  intent(in)    :: copy
    logical, optional,  intent(in)    :: force  !< if force = .true., unpack independently of the counter

    logical :: copy_
    type(profile_t), save :: prof

    PUSH_SUB(batch_unpack)

    call profiling_in(prof, "BATCH_UNPACK")

    if(batch_is_packed(this)) then

      if(this%in_buffer_count == 1 .or. optional_default(force, .false.)) then
        copy_ = .true.
        if(present(copy)) copy_ = copy
        
        if(copy_) call batch_sync(this)
        
        ! now deallocate
        this%status = BATCH_NOT_PACKED
        this%in_buffer_count = 1

        if(accel_is_enabled()) then
          call accel_release_buffer(this%pack%buffer)
        else
          SAFE_DEALLOCATE_A(this%pack%dpsi)
          SAFE_DEALLOCATE_A(this%pack%zpsi)
          SAFE_DEALLOCATE_A(this%pack%spsi)
          SAFE_DEALLOCATE_A(this%pack%cpsi)
        end if
      end if
      
      INCR(this%in_buffer_count, -1)
    end if

    call profiling_out(prof)

    POP_SUB(batch_unpack)

  end subroutine batch_unpack

  ! ----------------------------------------------------

  subroutine batch_sync(this)
    type(batch_t),      intent(inout) :: this
    
    type(profile_t), save :: prof

    PUSH_SUB(batch_sync)

    if(batch_is_packed(this) .and. this%dirty) then
      call profiling_in(prof, "BATCH_UNPACK_COPY")
      
      if(accel_is_enabled()) then
        call batch_read_from_opencl_buffer(this)
      else
        call unpack_copy()
      end if
      
      call profiling_out(prof)
      this%dirty = .false.
    end if
    
    POP_SUB(batch_sync)
    
  contains

    subroutine unpack_copy()
      integer :: ist, ip

      if(batch_type(this) == TYPE_FLOAT) then

         !$omp parallel do private(ist)
         do ip = 1, this%pack%size(2)
           forall(ist = 1:this%nst_linear)
             this%states_linear(ist)%dpsi(ip) = this%pack%dpsi(ist, ip) 
           end forall
         end do

      else if(batch_type(this) == TYPE_CMPLX) then
         
        !$omp parallel do private(ist)
        do ip = 1, this%pack%size(2)
          forall(ist = 1:this%nst_linear)
            this%states_linear(ist)%zpsi(ip) = this%pack%zpsi(ist, ip) 
          end forall
        end do

      else if(batch_type(this) == TYPE_FLOAT_SINGLE) then
        
        !$omp parallel do private(ist)
        do ip = 1, this%pack%size(2)
          forall(ist = 1:this%nst_linear)
            this%states_linear(ist)%spsi(ip) = this%pack%spsi(ist, ip) 
          end forall
        end do
        
      else if(batch_type(this) == TYPE_CMPLX_SINGLE) then
        
        !$omp parallel do private(ist)
        do ip = 1, this%pack%size(2)
          forall(ist = 1:this%nst_linear)
            this%states_linear(ist)%cpsi(ip) = this%pack%cpsi(ist, ip) 
          end forall
        end do
        
      end if
      
      call profiling_count_transfers(this%nst_linear*this%pack%size(2), batch_type(this))
      
    end subroutine unpack_copy

  end subroutine batch_sync

  ! ----------------------------------------------------

  subroutine batch_write_to_opencl_buffer(this)
    type(batch_t),      intent(inout)  :: this
    integer :: ist, ist2, unroll
    type(accel_mem_t) :: tmp
    type(profile_t), save :: prof_pack
    type(accel_kernel_t), pointer :: kernel

    PUSH_SUB(batch_write_to_opencl_buffer)

    ASSERT(batch_is_ok(this))

    if(this%nst_linear == 1) then
      ! we can copy directly
      if(batch_type(this) == TYPE_FLOAT) then
        call accel_write_buffer(this%pack%buffer, ubound(this%states_linear(1)%dpsi, dim = 1), this%states_linear(1)%dpsi)
      else if(batch_type(this) == TYPE_CMPLX) then
        call accel_write_buffer(this%pack%buffer, ubound(this%states_linear(1)%zpsi, dim = 1), this%states_linear(1)%zpsi)
      else
        ASSERT(.false.)
      end if

    else
      ! we copy to a temporary array and then we re-arrange data

      if(batch_type(this) == TYPE_FLOAT) then
        kernel => dpack
      else
        kernel => zpack
      end if
      
      unroll = min(CL_PACK_MAX_BUFFER_SIZE, this%pack%size(1))

      call accel_create_buffer(tmp, ACCEL_MEM_READ_ONLY, batch_type(this), unroll*this%pack%size(2))
      
      do ist = 1, this%nst_linear, unroll
        
        ! copy a number 'unroll' of states to the buffer
        do ist2 = ist, min(ist + unroll - 1, this%nst_linear)

          if(batch_type(this) == TYPE_FLOAT) then
            call accel_write_buffer(tmp, ubound(this%states_linear(ist2)%dpsi, dim = 1), this%states_linear(ist2)%dpsi, &
              offset = (ist2 - ist)*this%pack%size(2))
          else
            call accel_write_buffer(tmp, ubound(this%states_linear(ist2)%zpsi, dim = 1), this%states_linear(ist2)%zpsi, &
              offset = (ist2 - ist)*this%pack%size(2))
          end if
        end do

        ! now call an opencl kernel to rearrange the data
        call accel_set_kernel_arg(kernel, 0, this%pack%size(1))
        call accel_set_kernel_arg(kernel, 1, ist - 1)
        call accel_set_kernel_arg(kernel, 2, tmp)
        call accel_set_kernel_arg(kernel, 3, this%pack%buffer)

        call profiling_in(prof_pack, "CL_PACK")
        call accel_kernel_run(kernel, (/this%pack%size(2), unroll/), (/accel_max_workgroup_size()/unroll, unroll/))

        if(batch_type(this) == TYPE_FLOAT) then
          call profiling_count_transfers(unroll*this%pack%size(2), M_ONE)
        else
          call profiling_count_transfers(unroll*this%pack%size(2), M_ZI)
        end if

        call accel_finish()
        call profiling_out(prof_pack)

      end do

      call accel_release_buffer(tmp)

    end if

    POP_SUB(batch_write_to_opencl_buffer)
  end subroutine batch_write_to_opencl_buffer

  ! ------------------------------------------------------------------

  subroutine batch_read_from_opencl_buffer(this)
    type(batch_t),      intent(inout) :: this

    integer :: ist, ist2, unroll
    type(accel_mem_t) :: tmp
    type(accel_kernel_t), pointer :: kernel
    type(profile_t), save :: prof_unpack

    PUSH_SUB(batch_read_from_opencl_buffer)

    ASSERT(batch_is_ok(this))

    if(this%nst_linear == 1) then
      ! we can copy directly
      if(batch_type(this) == TYPE_FLOAT) then
        call accel_read_buffer(this%pack%buffer, ubound(this%states_linear(1)%dpsi, dim = 1), this%states_linear(1)%dpsi)
      else
        call accel_read_buffer(this%pack%buffer, ubound(this%states_linear(1)%zpsi, dim = 1), this%states_linear(1)%zpsi)
      end if
    else

      unroll = min(CL_PACK_MAX_BUFFER_SIZE, this%pack%size(1))

      ! we use a kernel to move to a temporary array and then we read
      call accel_create_buffer(tmp, ACCEL_MEM_WRITE_ONLY, batch_type(this), unroll*this%pack%size(2))

      if(batch_type(this) == TYPE_FLOAT) then
        kernel => dunpack
      else
        kernel => zunpack
      end if

      do ist = 1, this%nst_linear, unroll
        call accel_set_kernel_arg(kernel, 0, this%pack%size(1))
        call accel_set_kernel_arg(kernel, 1, ist - 1)
        call accel_set_kernel_arg(kernel, 2, this%pack%buffer)
        call accel_set_kernel_arg(kernel, 3, tmp)

        call profiling_in(prof_unpack, "CL_UNPACK")
        call accel_kernel_run(kernel, (/unroll, this%pack%size(2)/), (/unroll, accel_max_workgroup_size()/unroll/))

        if(batch_type(this) == TYPE_FLOAT) then
          call profiling_count_transfers(unroll*this%pack%size(2), M_ONE)
        else
          call profiling_count_transfers(unroll*this%pack%size(2), M_ZI)
        end if

        call accel_finish()
        call profiling_out(prof_unpack)

        ! copy a number 'unroll' of states from the buffer
        do ist2 = ist, min(ist + unroll - 1, this%nst_linear)
          
          if(batch_type(this) == TYPE_FLOAT) then
            call accel_read_buffer(tmp, ubound(this%states_linear(ist2)%dpsi, dim = 1), this%states_linear(ist2)%dpsi, &
              offset = (ist2 - ist)*this%pack%size(2))
          else
            call accel_read_buffer(tmp, ubound(this%states_linear(ist2)%zpsi, dim = 1), this%states_linear(ist2)%zpsi, &
              offset = (ist2 - ist)*this%pack%size(2))
          end if
        end do

      end do

      call accel_release_buffer(tmp)
    end if

    POP_SUB(batch_read_from_opencl_buffer)
  end subroutine batch_read_from_opencl_buffer

! ------------------------------------------------------
integer function batch_inv_index(this, cind) result(index)
  type(batch_t),     intent(in)    :: this
  integer,           intent(in)    :: cind(:)

  do index = 1, this%nst_linear
    if(all(cind(1:this%ndims) == this%ist_idim_index(index, 1:this%ndims))) exit
  end do

  ASSERT(index <= this%nst_linear)

end function batch_inv_index

! ------------------------------------------------------

integer pure function batch_ist_idim_to_linear(this, cind) result(index)
  type(batch_t),     intent(in)    :: this
  integer,           intent(in)    :: cind(:)
  
  if(ubound(cind, dim = 1) == 1) then
    index = cind(1)
  else
    index = (cind(1) - 1)*this%dim + cind(2)
  end if

end function batch_ist_idim_to_linear

! ------------------------------------------------------

integer pure function batch_linear_to_ist(this, linear_index) result(ist)
  type(batch_t),     intent(in)    :: this
  integer,           intent(in)    :: linear_index
  
  ist = this%ist_idim_index(linear_index, 1)

end function batch_linear_to_ist

! ------------------------------------------------------

integer pure function batch_linear_to_idim(this, linear_index) result(idim)
  type(batch_t),     intent(in)    :: this
  integer,           intent(in)    :: linear_index
  
  idim = this%ist_idim_index(linear_index, 2)
  
end function batch_linear_to_idim

! ------------------------------------------------------

logical pure function batch_is_sync(this) result(sync)
  type(batch_t),     intent(in)    :: this

  sync = .not. this%dirty

end function batch_is_sync

! ------------------------------------------------------

subroutine batch_remote_access_start(this, mpi_grp, rma_win)
  type(batch_t),   intent(inout) :: this
  type(mpi_grp_t), intent(in)    :: mpi_grp
  integer,         intent(out)   :: rma_win

  PUSH_SUB(batch_remote_access_start)

  if(mpi_grp%size > 1) then
    call batch_pack(this)
    
    if(batch_type(this) == TYPE_CMPLX) then
#ifdef HAVE_MPI2
      call MPI_Win_create(this%pack%zpsi(1, 1), int(product(this%pack%size)*types_get_size(batch_type(this)), MPI_ADDRESS_KIND), &
        types_get_size(batch_type(this)), MPI_INFO_NULL, mpi_grp%comm, rma_win, mpi_err)
#endif
    end if
    
    if(batch_type(this) == TYPE_FLOAT) then
#ifdef HAVE_MPI2
      call MPI_Win_create(this%pack%dpsi(1, 1), int(product(this%pack%size)*types_get_size(batch_type(this)), MPI_ADDRESS_KIND), &
        types_get_size(batch_type(this)), MPI_INFO_NULL, mpi_grp%comm, rma_win, mpi_err)
#endif
    end if
    
   if(batch_type(this) == TYPE_CMPLX_SINGLE) then
#ifdef HAVE_MPI2
      call MPI_Win_create(this%pack%cpsi(1, 1), int(product(this%pack%size)*types_get_size(batch_type(this)), MPI_ADDRESS_KIND), &
        types_get_size(batch_type(this)), MPI_INFO_NULL, mpi_grp%comm, rma_win, mpi_err)
#endif
    end if

    if(batch_type(this) == TYPE_FLOAT_SINGLE) then
#ifdef HAVE_MPI2
      call MPI_Win_create(this%pack%spsi(1, 1), int(product(this%pack%size)*types_get_size(batch_type(this)), MPI_ADDRESS_KIND), &
        types_get_size(batch_type(this)), MPI_INFO_NULL, mpi_grp%comm, rma_win, mpi_err)
#endif
    end if

  else
    rma_win = -1
  end if
  
  POP_SUB(batch_remote_access_start)
end subroutine batch_remote_access_start

! ------------------------------------------------------

subroutine batch_remote_access_stop(this, rma_win)
  type(batch_t),     intent(inout) :: this
  integer,           intent(inout) :: rma_win
  
  PUSH_SUB(batch_remote_access_stop)

  if(rma_win /= -1) then
#ifdef HAVE_MPI2
    call MPI_Win_free(rma_win, mpi_err)
#endif
    call batch_unpack(this)
  end if
  
  POP_SUB(batch_remote_access_stop)
end subroutine batch_remote_access_stop

! --------------------------------------------------------------

subroutine batch_copy_data(np, xx, yy)
  integer,           intent(in)    :: np
  type(batch_t),     intent(in)    :: xx
  type(batch_t),     intent(inout) :: yy

  integer :: ist
  type(profile_t), save :: prof
  integer :: localsize

  PUSH_SUB(batch_copy_data)
  call profiling_in(prof, "BATCH_COPY_DATA")

  ASSERT(batch_type(yy) == batch_type(xx))
  ASSERT(xx%nst_linear == yy%nst_linear)
  ASSERT(batch_status(xx) == batch_status(yy))

  select case(batch_status(xx))
  case(BATCH_CL_PACKED)
    call accel_set_kernel_arg(kernel_copy, 0, xx%pack%buffer)
    call accel_set_kernel_arg(kernel_copy, 1, log2(xx%pack%size_real(1)))
    call accel_set_kernel_arg(kernel_copy, 2, yy%pack%buffer)
    call accel_set_kernel_arg(kernel_copy, 3, log2(yy%pack%size_real(1)))
    
    localsize = accel_max_workgroup_size()/yy%pack%size_real(1)
    call accel_kernel_run(kernel_copy, (/yy%pack%size_real(1), pad(np, localsize)/), (/yy%pack%size_real(1), localsize/))
    
    call accel_finish()

  case(BATCH_PACKED)
    if(batch_type(yy) == TYPE_FLOAT) then
      call blas_copy(np*xx%pack%size(1), xx%pack%dpsi(1, 1), 1, yy%pack%dpsi(1, 1), 1)
    else
      call blas_copy(np*xx%pack%size(1), xx%pack%zpsi(1, 1), 1, yy%pack%zpsi(1, 1), 1)
    end if

  case(BATCH_NOT_PACKED)
    !$omp parallel do private(ist)
    do ist = 1, yy%nst_linear
      if(batch_type(yy) == TYPE_CMPLX) then
        call blas_copy(np, xx%states_linear(ist)%zpsi(1), 1, yy%states_linear(ist)%zpsi(1), 1)
      else
        call blas_copy(np, xx%states_linear(ist)%dpsi(1), 1, yy%states_linear(ist)%dpsi(1), 1)
      end if
    end do

  end select

  call batch_pack_was_modified(yy)

  call profiling_out(prof)
  POP_SUB(batch_copy_data)
end subroutine batch_copy_data

#include "real.F90"
#include "batch_inc.F90"
#include "undef.F90"

#include "complex.F90"
#include "batch_inc.F90"
#include "undef.F90"

#include "real_single.F90"
#include "batch_inc.F90"
#include "undef.F90"

#include "complex_single.F90"
#include "batch_inc.F90"
#include "undef.F90"


end module batch_oct_m

!! Local Variables:
!! mode: f90
!! coding: utf-8
!! End:
