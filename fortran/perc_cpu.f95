! Copyright (C) 2022, Rupert Nash, The University of Edinburgh.
!
! All rights reserved.
!
! This file is provided to you to complete an assessment and for
! subsequent private study. It may not be shared and, in particular,
! may not be posted on the internet. Sharing this or any modified
! version may constitute academic misconduct under the University's
! regulations.

module perc_cpu
  use iso_c_binding, only: c_int

  implicit none
contains

  ! Perform a single step of the algorithm.
  !
  ! For each point (if fluid), set it to the maximum of itself and the
  ! four von Neumann neighbours.
  !
  ! Returns the total number of changed cells.
  integer function percolate_cpu_step(M, N, state, next)
    integer, intent(in) :: M, N
    integer(kind=c_int), dimension(0:,0:), intent(in) :: state
    integer(kind=c_int), dimension(0:,0:), intent(out) :: next

    integer :: i, j
    integer(kind=c_int) :: oldval, newval
    percolate_cpu_step = 0

    do j = 1, N
       do i = 1, M
          oldval = state(i, j)
          newval = oldval

          ! 0 => solid, so do nothing
          if (oldval .ne. 0) then
             ! Set next(i, j) to be the maximum value of state[i][j]
             ! and its four nearest neighbours
             newval = max(state(i-1, j), newval)
             newval = max(state(i+1, j), newval)
             newval = max(state(i, j-1), newval)
             newval = max(state(i, j+1), newval)
             
             if (newval .ne. oldval) then
                percolate_cpu_step = percolate_cpu_step + 1
             end if
          end if
          next(i, j) = newval
       end do
    end do
  end function percolate_cpu_step

  ! Given an array, state, of size (M+2) x (N+2) with a halo of zeros,
  ! iteratively perform percolation of the non-zero elements until no
  ! changes or 4 *max(M, N) iterations.
  subroutine percolate_cpu(M, N, state)
    integer, intent(in) :: M, N
    integer(kind=c_int), dimension(0:M+1,0:N+1), intent(inout) :: state

    integer, parameter :: printfreq = 100

    ! Temporary work arrays
    integer(kind=c_int), dimension(0:M+1, 0:N+1), target :: a, b
    ! and pointers to them so we can swap below (hence tmp also)
    integer(kind=c_int), dimension(:,:), pointer :: current, next, tmp
    ! Aux
    integer :: maxstep, step, nchange, j

    maxstep = 4 * max(M, N)
    step = 1
    nchange = 1

    ! Copy the initial state to the temporaries, only the halos are
    ! *required*, but much easier this way!
    a = state
    b = state

    ! Set up pointers
    current => a
    next => b

    do while (nchange .gt. 0 .and. step .le. maxstep)
       nchange = percolate_cpu_step(M, N, current, next);

       if (modulo(step, printfreq) == 0) then
          print *, "percolate: number of changes on step ", step, nchange
       end if

       ! Swap pointers for the next iteration
       tmp => next
       next => current
       current => tmp
       step = step + 1
    end do

    ! Copy out result
    state = current
  end subroutine percolate_cpu
end module perc_cpu
