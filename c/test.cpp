// Copyright (C) 2022, Rupert Nash, The University of Edinburgh.
//
// All rights reserved.
//
// This file is provided to you to complete an assessment and for
// subsequent private study. It may not be shared and, in particular,
// may not be posted on the internet. Sharing this or any modified
// version may constitute academic misconduct under the University's
// regulations.

#include <chrono>
#include <cmath>
#include <cstring>
#include <iostream>
#include <numeric>
#include <vector>

#include "util.h"
#include "perc_cpu.h"
#include "perc_gpu.h"

using Clock = std::chrono::high_resolution_clock;
using Time = Clock::time_point;
using Dur = Clock::duration;

char const* usage =
  "Benchmark percolation implementation\n"
  "    test [-M integer] [-N integer] [-s integer] [-r integer] [-p float] [-o filename]\n"
  "\n"
  "-M grid size in x direction\n"
  "-N grid size in y direction\n"
  "-S random seed\n"
  "-r number of repeats for benchmarking\n"
  "-p target porosity\n"
  "-o file name to write output PNG image\n"
  ;

int main(int argc, char* argv[]) {

  int seed = 1234;
  int M = 512;
  int N = 512;
  float porosity = 0.4;
  int nruns = 3;
  char const* img_fn = "test.png";

  for (int i = 1; i < argc; i += 2) {
    char const* flag = argv[i];
    char const* value = argv[i + 1];
    if (std::strncmp("-M", flag, 2) == 0) {
      M = std::atoi(value);
    } else if (std::strncmp("-N", flag, 2) == 0) {
      N = std::atoi(value);
    } else if (std::strncmp("-s", flag, 2) == 0) {
      seed = std::atoi(value);
    } else if (std::strncmp("-p", flag, 2) == 0) {
      porosity = std::atof(value);
    } else if (std::strncmp("-r", flag, 2) == 0) {
      nruns = std::atoi(value);
    } else if (std::strncmp("-o", flag, 2) == 0) {
      img_fn = value;
    } else {
      std::cerr << "Unknown flag: " << flag << "\n" << usage;
      return 1;
    }
  }

  std::printf("M = %d, N = %d\n", M, N);
  std::vector<int> map((M+2) * (N+2));
  int nhole = fill_map(seed, porosity, M, N, map.data());

  std::printf("Porosity: target = %f, actual = %f\n",
	      porosity, ((double) nhole)/((double) M*N) );

  auto benchmarker = [&](
		   int nruns,
		   std::vector<int>& state,
		   std::vector<double>& time_s,
		   void (func)(int,int,int*)
		   ) {
    std::printf("Starting %d runs\n", nruns);
    for (int i = 0; i < nruns; ++i) {
      std::copy(map.begin(), map.end(), state.begin());
      Time const start = Clock::now();
      func(M, N, state.data());
      Time const stop = Clock::now();
      std::chrono::duration<double> dt{stop - start};
      time_s[i] = dt.count();
      std::printf("Run %d, time = %f s\n", i, dt.count());
    }
  };

  std::printf("CPU section\n");
  std::vector<int> cpu_state(map.size());
  std::vector<double> cpu_time_s(1);
  benchmarker(1, cpu_state, cpu_time_s, percolate_cpu);

  std::printf("GPU section\n");
  std::vector<int> gpu_state(map.size());
  std::vector<double> gpu_time_s(nruns);
  benchmarker(nruns, gpu_state, gpu_time_s, percolate_gpu);

  // Check for match
  int ndiff =
    std::inner_product(
      cpu_state.begin(), cpu_state.end(),
      gpu_state.begin(),
      0,
      std::plus<int>{},
      [](int const& a, int const& b) {
        return a == b ? 0 : 1;
      }
    );

  if (ndiff) {
    std::printf("CPU and GPU results differ at %d locations\n", ndiff);
    return 1;
  }

  std::printf("CPU and GPU results match\n");

  auto print_stats = [] (std::vector<double> const& data, char const* where) {
    // Compute and print stats
    int N = data.size();
    double min = INFINITY;
    double max = -INFINITY;
    double tsum = 0.0, tsumsq = 0.0;
    for (int i = 0; i < N; ++i) {
      double const& t = data[i];
      tsum += t;
      tsumsq += t * t;
      min = (t < min) ? t : min;
      max = (t > max) ? t : max;
    }
    double mean = tsum / N;
    double tvar = (tsumsq - tsum*tsum / N) / (N - 1);
    double std = std::sqrt(tvar);
    std::printf("\nSummary for %s (all in s):\nmin = %e, max = %e, mean = %e, std = %e\n",
		where,
		min, max, mean, std);
  };

  print_stats(cpu_time_s, "CPU");
  print_stats(gpu_time_s, "GPU");

  std::printf("Writing image to '%s'\n", img_fn);
  write_state_png(img_fn, M, N, nhole, cpu_state.data());
}
