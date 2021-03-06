#include "global.h"

module fio_hamiltonian_oct_m

  use base_hamiltonian_oct_m
  use base_potential_oct_m
  use fio_external_oct_m
  use global_oct_m
  use json_oct_m
  use kinds_oct_m
  use messages_oct_m
  use profiling_oct_m

  implicit none

  private

  public ::                  &
    fio_hamiltonian__load__

contains

  ! ---------------------------------------------------------
  subroutine fio_hamiltonian__load__(this)
    type(base_hamiltonian_t), intent(inout) :: this

    type(base_potential_t), pointer :: epot

    PUSH_SUB(fio_hamiltonian__load__)

    nullify(epot)
    call base_hamiltonian_get(this, "external", epot)
    ASSERT(associated(epot))
    call fio_external__load__(epot)
    nullify(epot)

    POP_SUB(fio_hamiltonian__load__)
  end subroutine fio_hamiltonian__load__

end module fio_hamiltonian_oct_m

!! Local Variables:
!! mode: f90
!! End:
