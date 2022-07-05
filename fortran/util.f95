! Copyright (C) 2022, Rupert Nash, The University of Edinburgh.
!
! All rights reserved.
!
! This file is provided to you to complete an assessment and for
! subsequent private study. It may not be shared and, in particular,
! may not be posted on the internet. Sharing this or any modified
! version may constitute academic misconduct under the University's
! regulations.

! This module just wraps the C versions of the functions below, see
! c/util.h for full details.
module util
  implicit none

  interface
     ! int fill_map(int seed, float porosity, int M, int N, int* map);
     integer(c_int) function fill_map_c(seed, porosity, M, N, map) bind(C, name="fill_map")
       use iso_c_binding
       integer(kind=c_int), value, intent(in) :: seed, M, N
       real(kind=c_float), value, intent(in) :: porosity
       integer(kind=c_int), intent(out) :: map
     end function fill_map_c

     ! int write_state_png(char const* file_name, int M, int N, int nhole, int const* state);
     integer(c_int) function write_state_png_c(file_name, M, N, nhole, state) bind(C, name="write_state_png")
       use iso_c_binding
       character(len=1, kind=C_CHAR), intent(in) :: file_name(*)
       integer(kind=c_int), value, intent(in) :: M, N, nhole
       integer(kind=c_int), intent(in) :: state
     end function write_state_png_c

  end interface

contains

  integer(kind=c_int) function fill_map(seed, porosity, M, N, map)
    use iso_c_binding
    integer, intent(in) :: seed, M, N
    real, intent(in) :: porosity
    integer(kind=c_int), dimension(0:,0:), intent(out) :: map
    integer :: i, j
    ! Transposed cos C/Fortran ordering...
    integer(kind=c_int), dimension(0:N+1,0:M+1) :: trans4c
    fill_map = fill_map_c(seed, porosity, M, N, trans4c(0,0))
    ! Do the transposition back to Fortran's preferred order
    do i = 0,M+1
       do j = 0,N+1
          map(i, j) = trans4c(j, i)
       end do
    end do
  end function fill_map

  integer(c_int) function write_state_png(file_name, M, N, nhole, state)
    use iso_c_binding
    character(len=*), intent(in) :: file_name
    integer(kind=c_int), intent(in) :: M, N, nhole
    integer(kind=c_int), dimension(0:,0:), intent(in) :: state
    integer(kind=c_int), dimension(0:N+1,0:M+1) :: trans4c

    character(len=1, kind=C_CHAR) :: c_fn(len_trim(file_name) + 1)
    integer :: i, j, len

    ! Converting Fortran string to C string
    len = len_trim(file_name)
    do i = 1, len
       c_fn(i) = file_name(i:i)
    end do
    c_fn(len + 1) = C_NULL_CHAR
    do i = 0,M+1
       do j = 0,N+1
          trans4c(j, i) = state(i, j)
       end do
    end do
    
    write_state_png = write_state_png_c(c_fn, M, N, nhole, trans4c(0,0))

  end function write_state_png
end module util
