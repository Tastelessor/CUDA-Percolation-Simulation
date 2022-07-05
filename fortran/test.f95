! Copyright (C) 2022, Rupert Nash, The University of Edinburgh.
!
! All rights reserved.
!
! This file is provided to you to complete an assessment and for
! subsequent private study. It may not be shared and, in particular,
! may not be posted on the internet. Sharing this or any modified
! version may constitute academic misconduct under the University's
! regulations.

program test
  use iso_fortran_env, only: real64
  use iso_c_binding, only: c_int
  use util
  use perc_cpu
  use perc_gpu
  implicit none
  type :: run_stats
     real(kind=real64) :: min, max, mean, std
     integer :: N
  end type run_stats

  ! aux
  integer :: err, i, j
  real(kind=real64) :: t0, t1

  ! Parse commandline helpers
  integer :: argc, iarg, flag_len, val_len
  integer, parameter :: maxarglen = 100
  character(maxarglen) :: flag, val

  ! Command line arguments
  integer :: M, N, seed, nruns
  real :: porosity
  character(maxarglen) :: img_fn

  ! Actual data
  integer(kind=c_int), dimension(:,:), allocatable :: map, cpu_state, gpu_state
  integer(kind=c_int) :: nhole
  
  real(kind=real64), dimension(:), allocatable :: gpu_runtime_s
  real(kind=real64) :: cpu_runtime_s
  type(run_stats) :: cpu_stats, gpu_stats
  integer :: ndiff

  ! Parse command line args (use C convention for argc)
  seed = 1234
  M = 512
  N = 512
  porosity = 0.4
  nruns = 3
  img_fn = "test.png"

  argc = command_argument_count()
  do iarg = 1, argc, 2
     call get_command_argument(iarg, flag, flag_len)
     if (flag_len .ne. 2) then
        print *, "Invalid length for flag"
        call usage_and_die()
     end if

     call get_command_argument(iarg + 1, val, val_len)
     if (flag(1:2) == "-M") then
        read (val, *, iostat=err) M
        if (err .ne. 0) then
           print *, "Problem with argument to option '-M'"
           call usage_and_die()
        end if
     else if (flag(1:2) == "-N") then
        read (val, *, iostat=err) N
        if (err .ne. 0) then
           print *, "Problem with argument to option '-N'"
           call usage_and_die()
        end if
     else if (flag(1:2) == "-s") then
        read (val, *, iostat=err) seed
        if (err .ne. 0) then
           print *, "Problem with argument to option '-s'"
           call usage_and_die()
        end if
     else if (flag(1:2) == "-p") then
        read (val, *, iostat=err) porosity
        if (err .ne. 0) then
           print *, "Problem with argument to option '-p'"
           call usage_and_die()
        end if
     else if (flag(1:2) == "-r") then
        read (val, *, iostat=err) nruns
        if (err .ne. 0) then
           print *, "Problem with argument to option '-r'"
           call usage_and_die()
        end if
     else if (flag(1:2) == "-o") then
        img_fn = val
     else
        print *, "Unknown argument"
        call usage_and_die()
     end if
  end do

  write (*, "('M = 'I4', N = 'I4)") M, N
  allocate(map(0:M+1,0:N+1))
  nhole = fill_map(seed, porosity, M, N, map)

  write (*, "(AF7.5AF7.5)") "porosity target = ", porosity, ", actual = ", real(nhole)/real(M*N)

  ! We'll do the runs and print stats at the end.
  !allocate(cpu_runtime_s(1))
  allocate(cpu_state(0:M+1,0:N+1))
  
  print *, "Beginning CPU run"
  cpu_state = map
  call cpu_time(t0)
  call percolate_cpu(M, N, cpu_state)
  call cpu_time(t1)
  cpu_runtime_s = t1 - t0
  print *, "Run", i, cpu_runtime_s, "s"

  allocate(gpu_runtime_s(nruns))
  allocate(gpu_state(0:M+1,0:N+1))
  write (*, "('Beginning 'I2' GPU runs')") nruns
  do i = 1, nruns
     gpu_state = map
     call cpu_time(t0)
     call percolate_gpu(M, N, gpu_state)
     call cpu_time(t1)
     gpu_runtime_s(i) = t1 - t0
     print *, "Run", i, gpu_runtime_s(i), "s"
  end do

  ! Check results match CPU
  ndiff = count(cpu_state .ne. gpu_state)
  if (ndiff .gt. 0) then
     print *, "CPU and GPU results differ this many places", ndiff
     error stop 1
  end if
  print *, "CPU and GPU results match"

  ! Print timing information
  write (*, "('CPU runtime 'e12.5' s')") cpu_runtime_s
  call calc_stats(gpu_runtime_s, gpu_stats)
  call print_stats("GPU", gpu_stats)

  write (*, "('Writing image to 'A)") img_fn
  i = write_state_png(img_fn, M, N, nhole, cpu_state)

contains
  subroutine usage_and_die()
    print *, "Benchmark percolation implementation"
    print *,   "    test [-M integer] [-N integer] [-s integer] [-r integer] [-p float] [-o filename]"
    print *,   ""
    print *,   "-M grid size in x direction"
    print *,   "-N grid size in y direction"
    print *,   "-S random seed"
    print *,   "-r number of repeats for benchmarking"
    print *,   "-p target porosity"
    print *,   "-o file name to write output PNG image"
    error stop 1
  end subroutine usage_and_die

  ! Compute stats
  subroutine calc_stats(data, ans)
    real(kind=real64), dimension(:), intent(in) :: data
    type(run_stats), intent(out) :: ans
    real(kind=real64) :: tsum, tsumsq
    integer :: i, N

    N = size(data)

    ans % min = minval(data)
    ans % max = maxval(data)

    tsum = sum(data)
    tsumsq = sum(data**2)
    ans % mean = tsum / N
    ans % std = sqrt((tsumsq - tsum*tsum / N) / (N - 1))
  end subroutine calc_stats

  subroutine print_stats(where, ans)
    type(run_stats), intent(in) :: ans
    character(len=*), intent(in) :: where
    print *, "Summary for ", where, " (all in s):"
    write (*, "('min = 'e12.5', max = 'e12.5', mean = 'e12.5', std = 'e12.5)") ans % min, ans % max, ans % mean, ans % std
  end subroutine print_stats
end program test
