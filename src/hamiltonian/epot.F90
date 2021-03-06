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
!! $Id: epot.F90 15387 2016-05-27 11:28:05Z micael $

#include "global.h"

module epot_oct_m
  use atom_oct_m
  use base_hamiltonian_oct_m
  use base_potential_oct_m
  use base_term_oct_m
  use comm_oct_m
  use derivatives_oct_m
  use double_grid_oct_m
  use gauge_field_oct_m
  use geometry_oct_m
  use global_oct_m
  use grid_oct_m
  use index_oct_m
  use io_oct_m
  use ion_interaction_oct_m
  use kick_oct_m
  use lalg_adv_oct_m
  use lalg_basic_oct_m
  use lasers_oct_m
  use linear_response_oct_m
  use loct_math_oct_m
  use logrid_oct_m
  use mesh_oct_m
  use mesh_function_oct_m
  use messages_oct_m
  use mpi_oct_m
  use multigrid_oct_m
  use parser_oct_m
  use periodic_copy_oct_m
  use poisson_oct_m
  use poisson_cutoff_oct_m
  use profiling_oct_m
  use projector_oct_m
  use ps_oct_m
  use simul_box_oct_m
  use species_oct_m
  use species_pot_oct_m
  use splines_oct_m
  use spline_filter_oct_m
  use ssys_external_oct_m
  use states_oct_m
  use states_dim_oct_m
  use submesh_oct_m
  use tdfunction_oct_m
  use unit_oct_m
  use unit_system_oct_m
  use varinfo_oct_m

  implicit none

  private
  public ::                        &
    epot_t,                        &
    epot_init,                     &
    epot_end,                      &
    epot_generate,                 &
    epot_local_potential,          &
    epot_precalc_local_potential,  &
    epot_global_force

  integer, public, parameter :: &
    CLASSICAL_NONE     = 0, & !< no classical charges
    CLASSICAL_POINT    = 1, & !< classical charges treated as point charges
    CLASSICAL_GAUSSIAN = 2    !< classical charges treated as Gaussian distributions
     
  integer, public, parameter :: &
    NOREL      = 0,             &
    SPIN_ORBIT = 1

  type epot_t
    ! Classical charges:
    integer        :: classical_pot !< how to include the classical charges
    FLOAT, pointer :: Vclassical(:) !< We use it to store the potential of the classical charges

    ! Subsystems external potential.
    type(base_potential_t), pointer :: subsys_external

    ! Ions
    FLOAT,             pointer :: vpsl(:)       !< the local part of the pseudopotentials
                                                !< plus the potential from static electric fields
    FLOAT,             pointer :: Imvpsl(:)     !< cmplxscl: imaginary part of vpsl
    type(projector_t), pointer :: proj(:)       !< non-local projectors
    logical                    :: non_local
    integer                    :: natoms

    ! External e-m fields
    integer                :: no_lasers            !< number of laser pulses used
    type(laser_t), pointer :: lasers(:)            !< lasers stuff
    FLOAT,         pointer :: E_field(:)           !< static electric field
    FLOAT, pointer         :: v_static(:)          !< static scalar potential
    FLOAT, pointer         :: B_field(:)           !< static magnetic field
    FLOAT, pointer         :: A_static(:,:)        !< static vector potential
    type(gauge_field_t)    :: gfield               !< the time-dependent gauge field
    integer                :: reltype              !< type of relativistic correction to use

    !> The possible kick
    type(kick_t) :: kick

    !> The gyromagnetic ratio (-2.0 for the electron, but different if we treat
    !! *effective* electrons in a quantum dot. It affects the spin Zeeman term.)
    FLOAT :: gyromagnetic_ratio

    !> SO prefactor (1.0 = normal SO, 0.0 = no SO)
    FLOAT :: so_strength
    
    !> the ion-ion energy and force
    FLOAT          :: eii
    FLOAT, pointer :: fii(:, :)
    FLOAT, allocatable :: vdw_forces(:, :)
    
    real(4), pointer :: local_potential(:,:)
    real(4), pointer :: Imlocal_potential(:,:) !cmplxscl
    logical          :: local_potential_precalculated

    logical          :: ignore_external_ions
    logical                  :: have_density
    type(poisson_t), pointer :: poisson_solver

    logical :: force_total_enforce

    type(ion_interaction_t) :: ion_interaction

    !> variables for external forces over the ions
    logical     :: global_force
    type(tdf_t) :: global_force_function
  end type epot_t

contains

  ! ---------------------------------------------------------
  subroutine epot_init( ep, gr, geo, ispin, nik, cmplxscl, subsys_hm)
    type(epot_t),                       intent(out)   :: ep
    type(grid_t),                       intent(in)    :: gr
    type(geometry_t),                   intent(inout) :: geo
    integer,                            intent(in)    :: ispin
    integer,                            intent(in)    :: nik
    logical,                            intent(in)    :: cmplxscl
    type(base_hamiltonian_t), optional, intent(in)    :: subsys_hm


    type(base_term_t), pointer :: subsys_ionic
    integer :: ispec, ip, idir, ia, gauge_2d, ierr
    type(block_t) :: blk
    FLOAT, allocatable :: grx(:)
    integer :: filter
    character(len=100)  :: function_name

    PUSH_SUB(epot_init)

    !%Variable FilterPotentials
    !%Type integer
    !%Default filter_ts
    !%Section Hamiltonian
    !%Description
    !% <tt>Octopus</tt> can filter the pseudopotentials so that they no
    !% longer contain Fourier components larger than the mesh itself. This is
    !% very useful to decrease the egg-box effect, and so should be used in
    !% all instances where atoms move (<i>e.g.</i> geometry optimization,
    !% molecular dynamics, and vibrational modes).
    !%Option filter_none 0
    !% Do not filter.
    !%Option filter_TS 2
    !% The filter of M. Tafipolsky and R. Schmid, <i>J. Chem. Phys.</i> <b>124</b>, 174102 (2006).
    !%Option filter_BSB 3
    !% The filter of E. L. Briggs, D. J. Sullivan, and J. Bernholc, <i>Phys. Rev. B</i> <b>54</b>, 14362 (1996).
    !%End
    call parse_variable('FilterPotentials', PS_FILTER_TS, filter)
    if(.not.varinfo_valid_option('FilterPotentials', filter)) call messages_input_error('FilterPotentials')
    call messages_print_var_option(stdout, "FilterPotentials", filter)

    if(filter == PS_FILTER_TS) call spline_filter_mask_init()
    do ispec = 1, geo%nspecies
      call species_pot_init(geo%species(ispec), mesh_gcutoff(gr%mesh), filter)
    end do

    ! Sets the pointer to the subsystem.
    nullify(ep%subsys_external)
    if(present(subsys_hm))then
      ASSERT(.not.cmplxscl)
      call base_hamiltonian_get(subsys_hm, "external", ep%subsys_external)
      ASSERT(associated(ep%subsys_external))
    end if

    ! Local part of the pseudopotentials
    if(associated(ep%subsys_external))then
      ! Sets the pointer to the subsystems total potential.
      call base_potential_get(ep%subsys_external, ep%vpsl)
      ASSERT(associated(ep%vpsl))
    else
      SAFE_ALLOCATE(ep%vpsl(1:gr%mesh%np))
    end if
    ep%vpsl(1:gr%mesh%np) = M_ZERO

    nullify(ep%Imvpsl)

    if(cmplxscl) then
      SAFE_ALLOCATE(ep%Imvpsl(1:gr%mesh%np))
      ep%Imvpsl(1:gr%mesh%np) = M_ZERO
    end if
    
    ep%classical_pot = 0
    nullify(ep%Vclassical)
    if(geo%ncatoms > 0) then

      if(simul_box_is_periodic(gr%mesh%sb)) &
        call messages_not_implemented("classical atoms in periodic systems")
      
      !%Variable ClassicalPotential
      !%Type integer
      !%Default no
      !%Section Hamiltonian
      !%Description
      !% Whether and how to add to the external potential the potential generated by 
      !% the classical charges read from block <tt>PDBClassical</tt>, for QM/MM calculations.
      !% Not available in periodic systems.
      !%Option no 0
      !%  No classical charges.
      !%Option point_charges 1
      !%  Classical charges are treated as point charges.
      !%Option gaussian_smeared 2
      !%  Classical charges are treated as Gaussian distributions. 
      !%  Smearing widths are hard-coded by species (experimental).
      !%End
      call parse_variable('ClassicalPotential', 0, ep%classical_pot)
      if(ep%classical_pot  ==  CLASSICAL_GAUSSIAN) then
        call messages_experimental("Gaussian smeared classical charges")
        ! This method probably works but definitely needs to be made user-friendly:
        ! i.e. telling the user what widths are used and letting them be set somehow.
      end if

      if(ep%classical_pot > 0) then
        message(1) = 'Info: generating classical external potential.'
        call messages_info(1)

        SAFE_ALLOCATE(ep%Vclassical(1:gr%mesh%np))
        call epot_generate_classical(ep, gr%mesh, geo)
      end if
    end if

    ! lasers
    call laser_init(ep%no_lasers, ep%lasers, gr%mesh)

    call kick_init(ep%kick, ispin, gr%mesh%sb%dim, gr%mesh%sb%periodic_dim)

    ! No more "UserDefinedTDPotential" from this version on.
    call messages_obsolete_variable('UserDefinedTDPotential', 'TDExternalFields')

    !%Variable StaticElectricField
    !%Type block
    !%Default 0
    !%Section Hamiltonian
    !%Description
    !% A static constant electric field may be added to the usual Hamiltonian,
    !% by setting the block <tt>StaticElectricField</tt>.
    !% The three possible components of the block (which should only have one
    !% line) are the three components of the electric field vector.
    !% It can be applied in a periodic direction of a large supercell via
    !% the single-point Berry phase.
    !%End
    nullify(ep%E_field, ep%v_static)
    if(parse_block('StaticElectricField', blk)==0) then
      SAFE_ALLOCATE(ep%E_field(1:gr%sb%dim))
      do idir = 1, gr%sb%dim
        call parse_block_float(blk, 0, idir - 1, ep%E_field(idir), units_inp%energy / units_inp%length)

        if(idir <= gr%sb%periodic_dim .and. abs(ep%E_field(idir)) > M_EPSILON) then
          message(1) = "Applying StaticElectricField in a periodic direction is only accurate for large supercells."
          if(nik == 1) then
            call messages_warning(1)
          else
            message(2) = "Single-point Berry phase is not appropriate when k-point sampling is needed."
            call messages_warning(2)
          end if
        end if
      end do
      call parse_block_end(blk)

      if(gr%sb%periodic_dim < gr%sb%dim) then
        ! Compute the scalar potential
        !
        ! Note that the -1 sign is missing. This is because we
        ! consider the electrons with +1 charge. The electric field
        ! however retains the sign because we also consider protons to
        ! have +1 charge when calculating the force.
        SAFE_ALLOCATE(ep%v_static(1:gr%mesh%np))
        forall(ip = 1:gr%mesh%np)
          ep%v_static(ip) = sum(gr%mesh%x(ip, gr%sb%periodic_dim + 1:gr%sb%dim) * ep%E_field(gr%sb%periodic_dim + 1:gr%sb%dim))
        end forall
      end if
    end if


    !%Variable StaticMagneticField
    !%Type block
    !%Section Hamiltonian
    !%Description
    !% A static constant magnetic field may be added to the usual Hamiltonian,
    !% by setting the block <tt>StaticMagneticField</tt>.
    !% The three possible components of the block (which should only have one
    !% line) are the three components of the magnetic field vector. Note that
    !% if you are running the code in 1D mode, this will not work, and if you
    !% are running the code in 2D mode the magnetic field will have to be in
    !% the <i>z</i>-direction, so that the first two columns should be zero.
    !% Possible in periodic system only in these cases: 2D system, 1D periodic,
    !% with <tt>StaticMagneticField2DGauge = linear_y</tt>;
    !% 3D system, 1D periodic, field is zero in <i>y</i>- and <i>z</i>-directions (given
    !% currently implemented gauges).
    !%
    !% The magnetic field should always be entered in atomic units, regardless
    !% of the <tt>Units</tt> variable. Note that we use the "Gaussian" system
    !% meaning 1 au[B] = <math>1.7152553 \times 10^7</math> Gauss, which corresponds to
    !% <math>1.7152553 \times 10^3</math> Tesla.
    !%End
    nullify(ep%B_field, ep%A_static)
    if(parse_block('StaticMagneticField', blk) == 0) then

      !%Variable StaticMagneticField2DGauge
      !%Type integer
      !%Default linear_xy
      !%Section Hamiltonian
      !%Description
      !% The gauge of the static vector potential <math>A</math> when a magnetic field
      !% <math>B = \left( 0, 0, B_z \right)</math> is applied to a 2D-system.
      !%Option linear_xy 0
      !% Linear gauge with <math>A = \frac{1}{2c} \left( -y, x \right) B_z</math>. (Cannot be used for periodic systems.)
      !%Option linear_y 1
      !% Linear gauge with <math>A = \frac{1}{c} \left( -y, 0 \right) B_z</math>. Can be used for <tt>PeriodicDimensions = 1</tt>
      !% but not <tt>PeriodicDimensions = 2</tt>.
      !%End
      call parse_variable('StaticMagneticField2DGauge', 0, gauge_2d)
      if(.not.varinfo_valid_option('StaticMagneticField2DGauge', gauge_2d)) &
        call messages_input_error('StaticMagneticField2DGauge')

      SAFE_ALLOCATE(ep%B_field(1:3))
      do idir = 1, 3
        call parse_block_float(blk, 0, idir - 1, ep%B_field(idir))
      end do
      select case(gr%sb%dim)
      case(1)
        call messages_input_error('StaticMagneticField')
      case(2)
        if(gr%sb%periodic_dim == 2) then
          message(1) = "StaticMagneticField cannot be applied in a 2D, 2D-periodic system."
          call messages_fatal(1)
        end if
        if(ep%B_field(1)**2 + ep%B_field(2)**2 > M_ZERO) call messages_input_error('StaticMagneticField')
      case(3)
        ! Consider cross-product below: if grx(1:sb%periodic_dim) is used, it is not ok.
        ! Therefore, if idir is periodic, B_field for all other directions must be zero.
        ! 1D-periodic: only Bx. 2D-periodic or 3D-periodic: not allowed. Other gauges could allow 2D-periodic case.
        if(gr%sb%periodic_dim >= 2) then
          message(1) = "In 3D, StaticMagneticField cannot be applied when the system is 2D- or 3D-periodic."
          call messages_fatal(1)
        else if(gr%sb%periodic_dim == 1 .and. any(abs(ep%B_field(2:3)) > M_ZERO)) then
          message(1) = "In 3D, 1D-periodic, StaticMagneticField must be zero in the y- and z-directions."
          call messages_fatal(1)
        end if
      end select
      call parse_block_end(blk)

      if(gr%sb%dim > 3) call messages_not_implemented('Magnetic field for dim > 3')

      ! Compute the vector potential
      SAFE_ALLOCATE(ep%A_static(1:gr%mesh%np, 1:gr%sb%dim))
      SAFE_ALLOCATE(grx(1:gr%sb%dim))

      select case(gr%sb%dim)
      case(2)
        select case(gauge_2d)
        case(0) ! linear_xy
          if(gr%sb%periodic_dim == 1) then
            message(1) = "For 2D system, 1D-periodic, StaticMagneticField can only be "
            message(2) = "applied for StaticMagneticField2DGauge = linear_y."
            call messages_fatal(2)
          end if
          do ip = 1, gr%mesh%np
            grx(1:gr%sb%dim) = gr%mesh%x(ip, 1:gr%sb%dim)
            ep%A_static(ip, :) = M_HALF/P_C*(/grx(2), -grx(1)/) * ep%B_field(3)
          end do
        case(1) ! linear y
          do ip = 1, gr%mesh%np
            grx(1:gr%sb%dim) = gr%mesh%x(ip, 1:gr%sb%dim)
            ep%A_static(ip, :) = M_ONE/P_C*(/grx(2), M_ZERO/) * ep%B_field(3)
          end do
        end select
      case(3)
        do ip = 1, gr%mesh%np
          grx(1:gr%sb%dim) = gr%mesh%x(ip, 1:gr%sb%dim)
          ep%A_static(ip, :) = M_HALF/P_C*(/grx(2) * ep%B_field(3) - grx(3) * ep%B_field(2), &
                               grx(3) * ep%B_field(1) - grx(1) * ep%B_field(3), &
                               grx(1) * ep%B_field(2) - grx(2) * ep%B_field(1)/)
        end do
      end select

      SAFE_DEALLOCATE_A(grx)

    end if
    
    !%Variable GyromagneticRatio
    !%Type float
    !%Default 2.0023193043768
    !%Section Hamiltonian
    !%Description
    !% The gyromagnetic ratio of the electron. This is of course a physical 
    !% constant, and the default value is the exact one that you should not 
    !% touch, unless: 
    !% (i)  You want to disconnect the anomalous Zeeman term in the Hamiltonian 
    !% (then set it to zero; this number only affects that term);
    !% (ii) You are using an effective Hamiltonian, as is the case when
    !% you calculate a 2D electron gas, in which case you have an effective
    !% gyromagnetic factor that depends on the material.
    !%End
    call parse_variable('GyromagneticRatio', P_g, ep%gyromagnetic_ratio)

    !%Variable RelativisticCorrection
    !%Type integer
    !%Default non_relativistic
    !%Section Hamiltonian
    !%Description
    !% The default value means that <i>no</i> relativistic correction is used. To
    !% include spin-orbit coupling turn <tt>RelativisticCorrection</tt> to <tt>spin_orbit</tt> 
    !% (this will only work if <tt>SpinComponents</tt> has been set to <tt>non_collinear</tt>, which ensures
    !% the use of spinors).
    !%Option non_relativistic 0
    !% No relativistic corrections.
    !%Option spin_orbit 1
    !% Spin-orbit.
    !%End
    call parse_variable('RelativisticCorrection', NOREL, ep%reltype)
    if(.not.varinfo_valid_option('RelativisticCorrection', ep%reltype)) call messages_input_error('RelativisticCorrection')
    if (ispin /= SPINORS .and. ep%reltype == SPIN_ORBIT) then
      message(1) = "The spin-orbit term can only be applied when using spinors."
      call messages_fatal(1)
    end if

    call messages_print_var_option(stdout, "RelativisticCorrection", ep%reltype)

    !%Variable SOStrength
    !%Type float
    !%Default 1.0
    !%Section Hamiltonian
    !%Description
    !% Tuning of the spin-orbit coupling strength: setting this value to zero turns off spin-orbit terms in
    !% the Hamiltonian, and setting it to one corresponds to full spin-orbit.
    !%End
    if (ep%reltype == SPIN_ORBIT) then
      call parse_variable('SOStrength', M_ONE, ep%so_strength)
    else
      ep%so_strength = M_ONE
    end if

    !%Variable IgnoreExternalIons
    !%Type logical
    !%Default no
    !%Section Hamiltonian
    !%Description
    !% If this variable is set to "yes", then the ions that are outside the simulation box do not feel any
    !% external force (and therefore progress at constant velocity), and do not originate any force on other
    !% ions, or any potential on the electronic system.
    !%
    !% This feature is only available for finite systems; if the system is periodic in any dimension, 
    !% this variable cannot be set to "yes".
    !%End
    call parse_variable('IgnoreExternalIons', .false., ep%ignore_external_ions)
    if(ep%ignore_external_ions) then
      if(gr%sb%periodic_dim > 0) call messages_input_error('IgnoreExternalIons')
    end if

    !%Variable ForceTotalEnforce
    !%Type logical
    !%Default no
    !%Section Hamiltonian
    !%Description
    !% (Experimental) If this variable is set to "yes", then the sum
    !% of the total forces will be enforced to be zero.
    !%End
    call parse_variable('ForceTotalEnforce', .false., ep%force_total_enforce)
    if(ep%force_total_enforce) call messages_experimental('ForceTotalEnforce')

    SAFE_ALLOCATE(ep%proj(1:geo%natoms))
    do ia = 1, geo%natoms
      call projector_null(ep%proj(ia))
    end do

    ep%natoms = geo%natoms
    ep%non_local = .false.

    ep%eii = M_ZERO
    SAFE_ALLOCATE(ep%fii(1:gr%sb%dim, 1:geo%natoms))
    ep%fii = M_ZERO

    SAFE_ALLOCATE(ep%vdw_forces(1:gr%sb%dim, 1:geo%natoms))
    ep%vdw_forces = M_ZERO

    call gauge_field_nullify(ep%gfield)

    nullify(ep%local_potential)
    nullify(ep%Imlocal_potential)
    ep%local_potential_precalculated = .false.
    

    ep%have_density = .false.
    do ia = 1, geo%natoms
      if(local_potential_has_density(gr%mesh%sb, geo%atom(ia))) then
        ep%have_density = .true.
        exit
      end if
    end do

    if(ep%have_density) then
      ep%poisson_solver => psolver
    else
      nullify(ep%poisson_solver)
    end if

    call ion_interaction_init(ep%ion_interaction)

    nullify(subsys_ionic)
    if(present(subsys_hm))then
      ASSERT(.not.cmplxscl)
      call base_hamiltonian_get(subsys_hm, "ionic", subsys_ionic)
      ASSERT(associated(subsys_ionic))
      call ion_interaction_add_subsys_ionic(ep%ion_interaction, subsys_ionic)
      nullify(subsys_ionic)
    end if

    !%Variable TDGlobalForce
    !%Type string
    !%Section Time-Dependent
    !%Description
    !% If this variable is set, a global time-dependent force will be
    !% applied to the ions in the x direction during a time-dependent
    !% run. This variable defines the base name of the force, that
    !% should be defined in the <tt>TDFunctions</tt> block. This force
    !% does not affect the electrons directly.
    !%End

    if(parse_is_defined('TDGlobalForce')) then

      ep%global_force = .true.

      call parse_variable('TDGlobalForce', 'none', function_name)
      call tdf_read(ep%global_force_function, trim(function_name), ierr)

      if(ierr /= 0) then
        call messages_write("You have enabled the GlobalForce option but Octopus could not find")
        call messages_write("the '"//trim(function_name)//"' function in the TDFunctions block.")
        call messages_fatal()
      end if

    else

      ep%global_force = .false.

    end if
    

    POP_SUB(epot_init)
  end subroutine epot_init

  ! ---------------------------------------------------------
  subroutine epot_end(ep)
    type(epot_t), intent(inout) :: ep

    integer :: iproj

    PUSH_SUB(epot_end)

    call ion_interaction_end(ep%ion_interaction)
    
    if(ep%have_density) then
      nullify(ep%poisson_solver)
    end if

    SAFE_DEALLOCATE_P(ep%local_potential)
    SAFE_DEALLOCATE_P(ep%Imlocal_potential)!cmplxscl 
    SAFE_DEALLOCATE_P(ep%fii)
    SAFE_DEALLOCATE_A(ep%vdw_forces)

    if(associated(ep%subsys_external))then
      nullify(ep%vpsl)
    else
      SAFE_DEALLOCATE_P(ep%vpsl)
    end if
    nullify(ep%subsys_external)

    SAFE_DEALLOCATE_P(ep%Imvpsl)!cmplxscl

    if(ep%classical_pot > 0) then
      ep%classical_pot = 0
      ! sanity check
      ASSERT(associated(ep%Vclassical)) 
      SAFE_DEALLOCATE_P(ep%Vclassical)         ! and clean up
    end if


    call kick_end(ep%kick)

    ! the external laser
    call laser_end(ep%no_lasers, ep%lasers)

    ! the macroscopic fields
    SAFE_DEALLOCATE_P(ep%E_field)
    SAFE_DEALLOCATE_P(ep%v_static)
    SAFE_DEALLOCATE_P(ep%B_field)
    SAFE_DEALLOCATE_P(ep%A_static)

    do iproj = 1, ep%natoms
      if (projector_is_null(ep%proj(iproj))) cycle
      call projector_end(ep%proj(iproj))
    end do

    ASSERT(associated(ep%proj))
    SAFE_DEALLOCATE_P(ep%proj)

    POP_SUB(epot_end)

  end subroutine epot_end

  ! ---------------------------------------------------------
  subroutine epot_generate(ep, gr, geo, st, cmplxscl)
    type(epot_t),             intent(inout) :: ep
    type(grid_t),     target, intent(in)    :: gr
    type(geometry_t), target, intent(in)    :: geo
    type(states_t),           intent(inout) :: st
    logical,                  intent(in)    :: cmplxscl  

    integer :: ia, ip
    type(atom_t),      pointer :: atm
    type(mesh_t),      pointer :: mesh
    type(simul_box_t), pointer :: sb
    type(profile_t), save :: epot_generate_prof
    FLOAT, dimension(:), pointer :: vpsl
    FLOAT,    allocatable :: density(:)
    FLOAT,    allocatable :: Imdensity(:)
    FLOAT,    allocatable :: tmp(:)
    CMPLX,    allocatable :: zdensity(:)
    CMPLX,    allocatable :: ztmp(:)
    type(profile_t), save :: epot_reduce
    type(ps_t), pointer :: ps
    
    call profiling_in(epot_generate_prof, "EPOT_GENERATE")
    PUSH_SUB(epot_generate)

    sb   => gr%sb
    mesh => gr%mesh

    SAFE_ALLOCATE(density(1:mesh%np))
    density = M_ZERO
    if(cmplxscl) then
      SAFE_ALLOCATE(Imdensity(1:mesh%np))
      Imdensity = M_ZERO
    end if

    ! Local part
    nullify(vpsl)
    if(associated(ep%subsys_external))then
      ! Sets the vpsl pointer to the "live" part of the subsystem potential.
      call base_potential_gets(ep%subsys_external, "live", vpsl)
      ASSERT(associated(vpsl))
    else
      ! Sets the vpsl pointer to the total potential.
      vpsl => ep%vpsl
    end if
    vpsl = M_ZERO
    if(associated(ep%Imvpsl)) ep%Imvpsl = M_ZERO
    if(geo%nlcc) st%rho_core = M_ZERO

    do ia = geo%atoms_dist%start, geo%atoms_dist%end
      if(.not.simul_box_in_box(sb, geo, geo%atom(ia)%x) .and. ep%ignore_external_ions) cycle
      if(geo%nlcc) then
        if(cmplxscl) then
          call epot_local_potential(ep, gr%der, gr%dgrid, geo, ia, vpsl, ep%Imvpsl, &
            rho_core = st%rho_core, density = density, Imdensity = Imdensity)
        else
          call epot_local_potential(ep, gr%der, gr%dgrid, geo, ia, vpsl, &
            rho_core = st%rho_core, density = density)
        end if
      else
        if(cmplxscl) then
          call epot_local_potential(ep, gr%der, gr%dgrid, geo, ia, vpsl, ep%Imvpsl, density = density, Imdensity = Imdensity)
        else
          call epot_local_potential(ep, gr%der, gr%dgrid, geo, ia, vpsl, density = density)
        end if
      end if
    end do

    ! reduce over atoms if required
    if(geo%atoms_dist%parallel) then
      call profiling_in(epot_reduce, "EPOT_REDUCE")

      call comm_allreduce(geo%atoms_dist%mpi_grp%comm, vpsl, dim = gr%mesh%np)
      if(associated(st%rho_core)) &
        call comm_allreduce(geo%atoms_dist%mpi_grp%comm, st%rho_core, dim = gr%mesh%np)
      if(ep%have_density) &
        call comm_allreduce(geo%atoms_dist%mpi_grp%comm, density, dim = gr%mesh%np)
      ASSERT(.not.cmplxscl) ! not implemented
      call profiling_out(epot_reduce)
    end if

    if(ep%have_density) then
      ! now we solve the poisson equation with the density of all nodes

      if(cmplxscl) then
        SAFE_ALLOCATE(ztmp(1:mesh%np))
        SAFE_ALLOCATE(zdensity(1:mesh%np))
        ztmp(:) = M_ZERO
        zdensity(:) = density(:) + M_zI * Imdensity(:)
        call zpoisson_solve(ep%poisson_solver, ztmp, zdensity)
        forall(ip = 1:mesh%np) vpsl(ip) = vpsl(ip) + real(ztmp(ip), REAL_PRECISION)
        forall(ip = 1:mesh%np) ep%Imvpsl(ip) = ep%Imvpsl(ip) + aimag(ztmp(ip))
        SAFE_DEALLOCATE_A(zdensity)
        SAFE_DEALLOCATE_A(ztmp)
      else
        SAFE_ALLOCATE(tmp(1:gr%mesh%np_part))
        if(poisson_solver_is_iterative(ep%poisson_solver)) tmp(1:mesh%np) = M_ZERO
        call dpoisson_solve(ep%poisson_solver, tmp, density)
        forall(ip = 1:mesh%np) vpsl(ip) = vpsl(ip) + tmp(ip)
        SAFE_DEALLOCATE_A(tmp)
      end if

    end if
    SAFE_DEALLOCATE_A(density)
    if(cmplxscl) then
      SAFE_DEALLOCATE_A(Imdensity)
    end if

    ! we assume that we need to recalculate the ion-ion energy
    call ion_interaction_calculate(ep%ion_interaction, geo, sb, ep%ignore_external_ions, ep%eii, ep%fii)

    ! the pseudopotential part.
    do ia = 1, geo%natoms
      atm => geo%atom(ia)
      if(.not. species_is_ps(atm%species)) cycle
      if(.not.simul_box_in_box(sb, geo, geo%atom(ia)%x) .and. ep%ignore_external_ions) cycle
      call projector_end(ep%proj(ia))
      call projector_init(ep%proj(ia), gr%mesh, atm, st%d%dim, ep%reltype)
    end do

    do ia = geo%atoms_dist%start, geo%atoms_dist%end
      if(ep%proj(ia)%type == M_NONE) cycle
      ps => species_ps(geo%atom(ia)%species)
      call submesh_init(ep%proj(ia)%sphere, mesh%sb, mesh, geo%atom(ia)%x, ps%rc_max + mesh%spacing(1))
    end do

    if(geo%atoms_dist%parallel) then
      do ia = 1, geo%natoms
        if(ep%proj(ia)%type == M_NONE) cycle
        ps => species_ps(geo%atom(ia)%species)
        call submesh_broadcast(ep%proj(ia)%sphere, mesh, geo%atom(ia)%x, ps%rc_max + mesh%spacing(1), &
          geo%atoms_dist%node(ia), geo%atoms_dist%mpi_grp)
      end do
    end if
    
    do ia = 1, geo%natoms
      atm => geo%atom(ia)
      call projector_build(ep%proj(ia), gr, atm, ep%so_strength)
      if(.not. projector_is(ep%proj(ia), M_NONE)) ep%non_local = .true.
    end do

    ! add static electric fields
    if (ep%classical_pot > 0)   vpsl(1:mesh%np) = vpsl(1:mesh%np) + ep%Vclassical(1:mesh%np)
    if (associated(ep%e_field) .and. sb%periodic_dim < sb%dim) vpsl(1:mesh%np) = vpsl(1:mesh%np) + ep%v_static(1:mesh%np)

    ! Calculates the total potential by summing all the subsystem contributions.
    if(associated(ep%subsys_external)) call ssys_external_calc(ep%subsys_external)
  
    POP_SUB(epot_generate)
    call profiling_out(epot_generate_prof)
  end subroutine epot_generate

  ! ---------------------------------------------------------

  logical pure function local_potential_has_density(sb, atom) result(has_density)
    type(simul_box_t),        intent(in)    :: sb
    type(atom_t),             intent(in)    :: atom
    
    has_density = &
      species_has_density(atom%species) .or. (species_is_ps(atom%species) .and. simul_box_is_periodic(sb))

  end function local_potential_has_density
  
  ! ---------------------------------------------------------
  subroutine epot_local_potential(ep, der, dgrid, geo, iatom, vpsl, Imvpsl, rho_core, density, Imdensity)
    type(epot_t),             intent(inout) :: ep
    type(derivatives_t),      intent(in)    :: der
    type(double_grid_t),      intent(in)    :: dgrid
    type(geometry_t),         intent(in)    :: geo
    integer,                  intent(in)    :: iatom
    FLOAT,                    intent(inout) :: vpsl(:)
    FLOAT,          optional, intent(inout) :: Imvpsl(:)
    FLOAT,          optional, pointer       :: rho_core(:)
    FLOAT,          optional, intent(inout) :: density(:) !< If present, the ionic density will be added here.
    FLOAT,          optional, intent(inout) :: Imdensity(:) !< ...and here, for complex scaling

    integer :: ip
    FLOAT :: radius
    FLOAT, allocatable :: vl(:), Imvl(:), rho(:), Imrho(:)
    type(submesh_t)  :: sphere
    type(profile_t), save :: prof
    logical :: cmplxscl

    PUSH_SUB(epot_local_potential)
    call profiling_in(prof, "EPOT_LOCAL")

    cmplxscl = present(Imvpsl)
    if(present(Imdensity)) then
      ASSERT(cmplxscl)
      ASSERT(present(density))
    end if
    
    if(ep%local_potential_precalculated) then

      forall(ip = 1:der%mesh%np) vpsl(ip) = vpsl(ip) + ep%local_potential(ip, iatom)
      if(cmplxscl) then
        forall(ip = 1:der%mesh%np) Imvpsl(ip) = Imvpsl(ip) + ep%Imlocal_potential(ip, iatom)
      end if
    else

      !Local potential, we can get it by solving the Poisson equation
      !(for all-electron species or pseudopotentials in periodic
      !systems) or by applying it directly to the grid

      if(local_potential_has_density(der%mesh%sb, geo%atom(iatom))) then
        SAFE_ALLOCATE(rho(1:der%mesh%np))

        if (cmplxscl) then
          SAFE_ALLOCATE(Imrho(1:der%mesh%np))
          call species_get_density(geo%atom(iatom)%species, geo%atom(iatom)%x, der%mesh, rho, Imrho)
        else
          call species_get_density(geo%atom(iatom)%species, geo%atom(iatom)%x, der%mesh, rho)
        end if

        if(present(density)) then
          forall(ip = 1:der%mesh%np) density(ip) = density(ip) + rho(ip)
          if(cmplxscl) then
            forall(ip = 1:der%mesh%np) Imdensity(ip) = Imdensity(ip) + Imrho(ip)
          end if
        else

          SAFE_ALLOCATE(vl(1:der%mesh%np))
          if (cmplxscl) then
            SAFE_ALLOCATE(Imvl(1:der%mesh%np))
          end if
          
          if(poisson_solver_is_iterative(ep%poisson_solver)) then
            ! vl has to be initialized before entering routine
            ! and our best guess for the potential is zero
            vl(1:der%mesh%np) = M_ZERO
            if (cmplxscl) Imvl(1:der%mesh%np) = M_ZERO
          end if

          call dpoisson_solve(ep%poisson_solver, vl, rho, all_nodes = .false.)
          if (cmplxscl) then ! XXX this will not work for 1D because of soft-Coulomb not being Coulomb
            call dpoisson_solve(ep%poisson_solver, Imvl, Imrho, all_nodes = .false.)
          end if
        end if

        SAFE_DEALLOCATE_A(rho)

      else

        SAFE_ALLOCATE(vl(1:der%mesh%np))
        if(cmplxscl) then
          SAFE_ALLOCATE(Imvl(1:der%mesh%np))
          call species_get_local(geo%atom(iatom)%species, der%mesh, geo%atom(iatom)%x(1:der%mesh%sb%dim), vl, Imvl)
        else
          call species_get_local(geo%atom(iatom)%species, der%mesh, geo%atom(iatom)%x(1:der%mesh%sb%dim), vl)
        end if
      end if

      if(allocated(vl)) then
        forall(ip = 1:der%mesh%np) vpsl(ip) = vpsl(ip) + vl(ip)
        SAFE_DEALLOCATE_A(vl)
        if(cmplxscl) then
          forall(ip = 1:der%mesh%np) Imvpsl(ip) = Imvpsl(ip) + Imvl(ip)
          SAFE_DEALLOCATE_A(Imvl)
        end if
      end if

      !the localized part
      if(species_is_ps(geo%atom(iatom)%species)) then

        radius = double_grid_get_rmax(dgrid, geo%atom(iatom)%species, der%mesh) + der%mesh%spacing(1)

        call submesh_init(sphere, der%mesh%sb, der%mesh, geo%atom(iatom)%x, radius)
        SAFE_ALLOCATE(vl(1:sphere%np))

        call double_grid_apply_local(dgrid, geo%atom(iatom)%species, der%mesh, sphere, geo%atom(iatom)%x, vl)

        ! Cannot be written (correctly) as a vector expression since for periodic systems,
        ! there can be values ip, jp such that sphere%map(ip) == sphere%map(jp).
        do ip = 1, sphere%np
          vpsl(sphere%map(ip)) = vpsl(sphere%map(ip)) + vl(ip)
        end do

        SAFE_DEALLOCATE_A(vl)
        ASSERT(.not.cmplxscl)
        call submesh_end(sphere)

      end if

    end if

    !Non-local core corrections
    if(present(rho_core) .and. &
      species_has_nlcc(geo%atom(iatom)%species) .and. &
      species_is_ps(geo%atom(iatom)%species)) then
      SAFE_ALLOCATE(rho(1:der%mesh%np))
      call species_get_nlcc(geo%atom(iatom)%species, geo%atom(iatom)%x, der%mesh, rho)
      forall(ip = 1:der%mesh%np) rho_core(ip) = rho_core(ip) + rho(ip)
      SAFE_DEALLOCATE_A(rho)
      SAFE_DEALLOCATE_A(Imrho)
    end if

    call profiling_out(prof)
    POP_SUB(epot_local_potential)
  end subroutine epot_local_potential


  ! ---------------------------------------------------------
  subroutine epot_generate_classical(ep, mesh, geo)
    type(epot_t),     intent(inout) :: ep
    type(mesh_t),     intent(in)    :: mesh
    type(geometry_t), intent(in)    :: geo

    integer ip, ia
    FLOAT :: rr, rc

    PUSH_SUB(epot_generate_classical)

    ep%Vclassical = M_ZERO
    do ia = 1, geo%ncatoms
      do ip = 1, mesh%np
        call mesh_r(mesh, ip, rr, origin=geo%catom(ia)%x)
        select case(ep%classical_pot)
        case(CLASSICAL_POINT)
          if(rr < r_small) rr = r_small
          ep%Vclassical(ip) = ep%Vclassical(ip) - geo%catom(ia)%charge/rr
        case(CLASSICAL_GAUSSIAN)
          select case(geo%catom(ia)%label(1:1)) ! covalent radii
          case('H')
            rc = CNST(0.4) * P_Ang
          case('C')
            rc = CNST(0.8) * P_Ang
          case default
            rc = CNST(0.7) * P_Ang
          end select
          if(abs(rr - rc) < r_small) rr = rc + sign(r_small, rr - rc)
          ep%Vclassical(ip) = ep%Vclassical(ip) - geo%catom(ia)%charge * (rr**4 - rc**4) / (rr**5 - rc**5)
        case default
          call messages_input_error('ClassicalPotential')
        end select
      end do
    end do

    POP_SUB(epot_generate_classical)
  end subroutine epot_generate_classical

  ! ---------------------------------------------------------
  subroutine epot_precalc_local_potential(ep, gr, geo)
    type(epot_t),     intent(inout) :: ep
    type(grid_t),     intent(in)    :: gr
    type(geometry_t), intent(in)    :: geo

    integer :: iatom
    FLOAT, allocatable :: tmp(:), Imtmp(:)
    logical  :: cmplxscl
    
    PUSH_SUB(epot_precalc_local_potential)
    cmplxscl =.false.
    if(associated(ep%Imvpsl)) cmplxscl = .true.
    
    if(.not. associated(ep%local_potential)) then
      SAFE_ALLOCATE(ep%local_potential(1:gr%mesh%np, 1:geo%natoms))
    end if

    if(.not. associated(ep%Imlocal_potential) .and. cmplxscl) then
      SAFE_ALLOCATE(ep%Imlocal_potential(1:gr%mesh%np, 1:geo%natoms))
      SAFE_ALLOCATE(Imtmp(1:gr%mesh%np))
    end if


    ep%local_potential_precalculated = .false.

    SAFE_ALLOCATE(tmp(1:gr%mesh%np))
    
    if(cmplxscl) then
      do iatom = 1, geo%natoms
        tmp(1:gr%mesh%np) = M_ZERO
        Imtmp(1:gr%mesh%np) = M_ZERO
        call epot_local_potential(ep, gr%der, gr%dgrid, geo, iatom, tmp, Imtmp)!, time)
        ep%local_potential(1:gr%mesh%np, iatom) = real(tmp(1:gr%mesh%np), 4)
        ep%Imlocal_potential(1:gr%mesh%np, iatom) = real(Imtmp(1:gr%mesh%np), 4)
      end do
    else
      do iatom = 1, geo%natoms
        tmp(1:gr%mesh%np) = M_ZERO
        call epot_local_potential(ep, gr%der, gr%dgrid, geo, iatom, tmp)!, time)
        ep%local_potential(1:gr%mesh%np, iatom) = real(tmp(1:gr%mesh%np), 4)
      end do
    end if
    ep%local_potential_precalculated = .true.

    SAFE_DEALLOCATE_A(tmp)
    SAFE_DEALLOCATE_A(Imtmp)
    POP_SUB(epot_precalc_local_potential)
  end subroutine epot_precalc_local_potential

  ! ---------------------------------------------------------
  
  subroutine epot_global_force(ep, geo, time, force)
    type(epot_t),         intent(inout) :: ep
    type(geometry_t),     intent(in)    :: geo
    FLOAT,                intent(in)    :: time
    FLOAT,                intent(out)   :: force(:)

    PUSH_SUB(epot_global_force)

    force(1:geo%space%dim) = CNST(0.0)

    if(ep%global_force) then
      force(1) = units_to_atomic(units_inp%force, tdf(ep%global_force_function, time))
    end if

    POP_SUB(epot_global_force)
  end subroutine epot_global_force

end module epot_oct_m

!! Local Variables:
!! mode: f90
!! coding: utf-8
!! End:
