!! Copyright (C) 2004 E.S. Kadantsev, M. Marques
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
!! $Id: linear_response_inc.F90 15624 2016-09-28 10:01:51Z irina $


! ---------------------------------------------------------
!> Orthogonalizes vec against all the occupied states.
!! For details on the metallic part, take a look at
!! de Gironcoli, PRB 51, 6773 (1995).
!!
!! min_proj:
!! Let Pc = projector onto unoccupied states, Pn` = projector that removes states degenerate with n
!! For an SCF run, we will apply Pn` for the last step always, since the whole wavefunction is useful for some
!! things and the extra cost here is small. If occ_response, previous steps will also use Pn`. If !occ_response,
!! previous steps will use Pc, which generally reduces the number of linear-solver iterations needed. Only the
!! wavefunctions in the unoccupied subspace are needed to construct the first-order density.
!! I am not sure what the generalization of this scheme is for metals, so we will just use Pc if there is smearing.
! ---------------------------------------------------------
subroutine X(lr_orth_vector) (mesh, st, vec, ist, ik, omega, min_proj)
  type(mesh_t),        intent(in)    :: mesh
  type(states_t),      intent(in)    :: st
  R_TYPE,              intent(inout) :: vec(:,:)
  integer,             intent(in)    :: ist, ik
  R_TYPE,              intent(in)    :: omega
  logical, optional,   intent(in)    :: min_proj

  integer :: jst
  FLOAT :: xx, yy, theta, theta_ij, theta_ji, alpha_j, dsmear, delta
  R_TYPE :: delta_e
  FLOAT, allocatable :: theta_Fi(:)
  R_TYPE, allocatable :: beta_ij(:)

  PUSH_SUB(X(lr_orth_vector))

  dsmear = max(CNST(1e-14), st%smear%dsmear)

  SAFE_ALLOCATE(beta_ij(1:st%nst))

  if(smear_is_semiconducting(st%smear) .or. st%smear%integral_occs) then
    theta = st%occ(ist, ik) / st%smear%el_per_state

    if(optional_default(min_proj, .false.)) then
      do jst = 1, st%nst
        if(abs(st%eigenval(ist, ik) - st%eigenval(jst, ik)) < CNST(1e-6)) then
          ! degenerate
          beta_ij(jst) = st%occ(jst, ik) / st%smear%el_per_state
        else
          beta_ij(jst) = M_ZERO
        end if
      end do
    else
      do jst = 1, st%nst
        if(abs(st%occ(ist, ik) * st%occ(jst, ik)) > M_EPSILON) then
          beta_ij(jst) = st%occ(jst, ik) / st%smear%el_per_state
        else
          beta_ij(jst) = M_ZERO
        end if
      end do
    end if
  else
    SAFE_ALLOCATE(theta_Fi(1:st%nst))
    theta_Fi(1:st%nst) = st%occ(1:st%nst, ik) / st%smear%el_per_state

    do jst = 1, st%nst
      if(st%smear%method  ==  SMEAR_FIXED_OCC .or. st%smear%method  ==  SMEAR_COLD) then
        if(theta_Fi(ist) + theta_Fi(jst) > M_EPSILON) then
          theta_ij = theta_Fi(jst) / (theta_Fi(ist) + theta_Fi(jst))
          theta_ji = theta_Fi(ist) / (theta_Fi(ist) + theta_Fi(jst))
        else
          ! avoid dividing by zero
          theta_ij = M_ZERO
          theta_ji = M_ZERO
        end if
      else
        xx = (st%eigenval(ist, ik) - st%eigenval(jst, ik))/dsmear
        theta_ij = smear_step_function(st%smear,  xx)
        theta_ji = smear_step_function(st%smear, -xx)
      end if
      
      beta_ij(jst) = theta_Fi(ist)*Theta_ij + Theta_Fi(jst)*Theta_ji
          
      alpha_j = lr_alpha_j(st, jst, ik)
      delta_e = st%eigenval(ist, ik) - st%eigenval(jst, ik) - omega
        
      if(abs(delta_e) >= CNST(1e-5)) then
        beta_ij(jst) = beta_ij(jst) + alpha_j*Theta_ji*(Theta_Fi(ist) - Theta_Fi(jst))/delta_e
      else
        ! cannot calculate for fixed occ, ignore
        ! the kernel is supposed to kill off these KS resonances anyway
        ! in dynamic case, need to add 'self term' without omega, for variation of occupations
        if(st%smear%method /= SMEAR_FIXED_OCC) then 
          xx = (st%smear%e_fermi - st%eigenval(ist, ik) + CNST(1e-14))/dsmear
          yy = (st%smear%e_fermi - st%eigenval(jst, ik) + CNST(1e-14))/dsmear
          ! average for better numerics, as in ABINIT
          delta = M_HALF * (smear_delta_function(st%smear, xx) + smear_delta_function(st%smear, yy))
          beta_ij(jst) = beta_ij(jst) + alpha_j*Theta_ji*(delta/dsmear)
        end if
      end if

    end do

    theta = theta_Fi(ist)
    SAFE_DEALLOCATE_A(theta_Fi)
  end if

  call X(states_orthogonalize_single)(st, mesh, st%nst, ik, vec(:, :), theta_fi = theta, beta_ij = beta_ij)

  SAFE_DEALLOCATE_A(beta_ij)

  POP_SUB(X(lr_orth_vector))

end subroutine X(lr_orth_vector)


! --------------------------------------------------------------------
subroutine X(lr_build_dl_rho) (mesh, st, lr, nsigma)
  type(mesh_t),   intent(in)    :: mesh
  type(states_t), intent(in)    :: st
  type(lr_t),     intent(inout) :: lr(:)
  integer,        intent(in)    :: nsigma

  integer :: ip, ist, ik, ispin, isigma
  FLOAT   :: weight, xx, dsmear, dos_ef, ef_shift
  R_TYPE  :: cc, dd, avg_dl_rho
  logical :: is_ef_shift
  R_TYPE, allocatable :: psi(:, :)

  PUSH_SUB(X(lr_build_dl_rho))

  if(st%d%ispin == SPINORS) then
    call messages_not_implemented('linear response density for spinors')
  end if

  ! correction to density response due to shift in Fermi level
  ! it is zero without smearing since there is no Fermi level
  ! it is zero if the occupations are fixed since there is no Fermi level
  ! see Baroni et al. eqs. 68, 75, 79; Quantum ESPRESSO PH/ef_shift.f90, localdos.f90
  ! generalized to TDDFT. Note that their \Delta n_ext = 0 unless the perturbation explicitly
  ! changes the charge of the system, as in "computational alchemy" (PRL 66 2116 (1991)).
  ! n(r,E_F) * dV_SCF = dl_rho, before correction.
  is_ef_shift = .not. smear_is_semiconducting(st%smear) .and. st%smear%method /= SMEAR_FIXED_OCC
  
  ! initialize density
  do isigma = 1, nsigma
    lr(isigma)%X(dl_rho)(:, :) = M_ZERO
  end do

  dos_ef = M_ZERO
  dsmear = max(CNST(1e-14), st%smear%dsmear)

  SAFE_ALLOCATE(psi(1:mesh%np, 1:st%d%dim))
  
  ! calculate density
  do ik = st%d%kpt%start, st%d%kpt%end
    ispin = states_dim_get_spin_index(st%d, ik)
    do ist  = st%st_start, st%st_end

      call states_get_state(st, mesh, ist, ik, psi)
      
      weight = st%d%kweights(ik)*st%smear%el_per_state
      
      if(nsigma == 1) then  ! either omega purely real or purely imaginary
        do ip = 1, mesh%np
          dd = weight*psi(ip, 1)*R_CONJ(lr(1)%X(dl_psi)(ip, 1, ist, ik))
          lr(1)%X(dl_rho)(ip, ispin) = lr(1)%X(dl_rho)(ip, ispin) + dd + R_CONJ(dd)
        end do
      else
        do ip = 1, mesh%np
          cc = weight*(R_CONJ(psi(ip, 1))*lr(1)%X(dl_psi)(ip, 1, ist, ik) + &
            psi(ip, 1)*R_CONJ(lr(2)%X(dl_psi)(ip, 1, ist, ik)))
          lr(1)%X(dl_rho)(ip, ispin) = lr(1)%X(dl_rho)(ip, ispin) + cc
          lr(2)%X(dl_rho)(ip, ispin) = lr(2)%X(dl_rho)(ip, ispin) + R_CONJ(cc)
        end do
      end if

      if(is_ef_shift) then
        xx = (st%smear%e_fermi - st%eigenval(ist, ik) + CNST(1e-14))/dsmear
        dos_ef = dos_ef + weight * smear_delta_function(st%smear, dsmear)
      end if

    end do
  end do

  ! reduce
  if(st%parallel_in_states .or. st%d%kpt%parallel) then
    do isigma = 1, nsigma
      call comm_allreduce(st%st_kpt_mpi_grp%comm, lr(isigma)%X(dl_rho))
    end do
  end if

  if(is_ef_shift) then
    do isigma = 1, nsigma
      avg_dl_rho = M_ZERO
      do ispin = 1, st%d%nspin
        avg_dl_rho = avg_dl_rho + X(mf_integrate)(mesh, lr(isigma)%X(dl_rho)(:, ispin))
      end do
      ef_shift = -TOFLOAT(avg_dl_rho) / dos_ef
      do ik = st%d%kpt%start, st%d%kpt%end
        ispin = states_dim_get_spin_index(st%d, ik)
        do ist  = st%st_start, st%st_end
          xx = (st%smear%e_fermi - st%eigenval(ist, ik) + CNST(1e-14))/dsmear

          call states_get_state(st, mesh, ist, ik, psi)
          
          do ip = 1, mesh%np
            lr(isigma)%X(dl_rho)(ip, ispin) = lr(isigma)%X(dl_rho)(ip, ispin) + abs(psi(ip, 1))**2 &
              *ef_shift*st%d%kweights(ik)*smear_delta_function(st%smear, xx)*st%smear%el_per_state
          end do
          
        end do
      end do
    end do
  end if

  SAFE_DEALLOCATE_A(psi)  
      
  POP_SUB(X(lr_build_dl_rho))
end subroutine X(lr_build_dl_rho)


! ---------------------------------------------------------
! Orthogonalizes response of \alpha KS orbital to all occupied
! \alpha KS orbitals.
! ---------------------------------------------------------
subroutine X(lr_orth_response)(mesh, st, lr, omega)
  type(mesh_t),   intent(in)    :: mesh
  type(states_t), intent(in)    :: st
  type(lr_t),     intent(inout) :: lr
  R_TYPE,         intent(in)    :: omega
  
  integer :: ist, ik
  PUSH_SUB(X(lr_orth_response))
  
  do ik = st%d%kpt%start, st%d%kpt%end
    do ist = 1, st%nst
      call X(lr_orth_vector) (mesh, st, lr%X(dl_psi)(:,:, ist, ik), ist, ik, omega)
    end do
  end do
  
  POP_SUB(X(lr_orth_response))
end subroutine X(lr_orth_response)


! ---------------------------------------------------------
subroutine X(lr_swap_sigma)(st, mesh, plus, minus)
  type(states_t), intent(in)    :: st
  type(mesh_t),   intent(in)    :: mesh
  type(lr_t),     intent(inout) :: plus
  type(lr_t),     intent(inout) :: minus

  integer :: ik, idim, ist
  R_TYPE, allocatable :: tmp(:)

  PUSH_SUB(X(lr_swap_sigma))

  SAFE_ALLOCATE(tmp(1:mesh%np))

  do ik = 1, st%d%nspin
    call lalg_copy(mesh%np, plus%X(dl_rho)(:, ik), tmp(:))
    call lalg_copy(mesh%np, minus%X(dl_rho)(:, ik), plus%X(dl_rho)(:, ik))
    call lalg_copy(mesh%np, tmp(:), minus%X(dl_rho)(:, ik))
  end do

  do ik = st%d%kpt%start, st%d%kpt%end
    do ist = 1, st%nst
      do idim = 1, st%d%dim
        call lalg_copy(mesh%np_part, plus%X(dl_psi)(:, idim, ist, ik), tmp(:))
        call lalg_copy(mesh%np_part, minus%X(dl_psi)(:, idim, ist, ik), plus%X(dl_psi)(:, idim, ist, ik))
        call lalg_copy(mesh%np_part, tmp(:), minus%X(dl_psi)(:, idim, ist, ik))
      end do
    end do
  end do

  SAFE_DEALLOCATE_A(tmp)
  POP_SUB(X(lr_swap_sigma))

end subroutine X(lr_swap_sigma)


! ---------------------------------------------------------
subroutine X(lr_dump_rho)(lr, mesh, nspin, restart, rho_tag, ierr)
  type(lr_t),        intent(in)  :: lr
  type(mesh_t),      intent(in)  :: mesh
  integer,           intent(in)  :: nspin
  type(restart_t),   intent(in)  :: restart
  character(len=*),  intent(in)  :: rho_tag
  integer,           intent(out) :: ierr

  character(len=100) :: fname
  integer :: is, err, err2

  PUSH_SUB(X(lr_dump_rho))

  ierr = 0
  if (restart_skip(restart)) then
    POP_SUB(X(lr_dump_rho))
    return
  end if

  if (debug%info) then
    message(1) = "Debug: Writing linear-response density restart."
    call messages_info(1)
  end if

  err2 = 0
  do is = 1, nspin
    write(fname, '(a,i1,a)') trim(rho_tag)//'_', is
    call X(restart_write_mesh_function)(restart, fname, mesh, lr%X(dl_rho)(:, is), err)
    if (err /= 0) err2 = err2 + 1
  end do
  if (err2 /= 0) ierr = ierr + 1

  if (debug%info) then
    message(1) = "Debug: Writing linear-response density restart done."
    call messages_info(1)
  end if

  POP_SUB(X(lr_dump_rho))
end subroutine X(lr_dump_rho)


! ---------------------------------------------------------
subroutine X(lr_load_rho)(dl_rho, mesh, nspin, restart, rho_tag, ierr)
  R_TYPE,            intent(inout) :: dl_rho(:,:) !< (mesh%np, nspin)
  type(mesh_t),      intent(in)    :: mesh
  integer,           intent(in)    :: nspin
  type(restart_t),   intent(in)    :: restart
  character(len=*),  intent(in)    :: rho_tag
  integer,           intent(out)   :: ierr

  character(len=80) :: fname
  integer :: is, err, err2

  PUSH_SUB(X(lr_load_rho))

  ierr = 0

  if (restart_skip(restart)) then
    POP_SUB(X(lr_load_rho))
    ierr = -1
    return
  end if

  if (debug%info) then
    message(1) = "Debug: Reading linear-response density restart."
    call messages_info(1)
  end if

  ASSERT(ubound(dl_rho, 1) >= mesh%np)
  ASSERT(ubound(dl_rho, 2) >= nspin)

  err2 = 0
  do is = 1, nspin
    write(fname, '(a, i1,a)') trim(rho_tag)//'_', is
    call X(restart_read_mesh_function)(restart, fname, mesh, dl_rho(:, is), err)
    if (err /= 0) err2 = err2 + 1
  end do
  if (err2 /= 0) ierr = ierr + 1

  if (debug%info) then
    message(1) = "Debug: Reading linear-response density restart done."
    call messages_info(1)
  end if

  POP_SUB(X(lr_load_rho))
end subroutine X(lr_load_rho)

!! Local Variables:
!! mode: f90
!! coding: utf-8
!! End:
