// Copyright (C) 2022, Rupert Nash, The University of Edinburgh.
//
// All rights reserved.
//
// This file is provided to you to complete an assessment and for
// subsequent private study. It may not be shared and, in particular,
// may not be posted on the internet. Sharing this or any modified
// version may constitute academic misconduct under the University's
// regulations.

#include "perc_cpu.h"

#include <cstdio>
#include <cstring>
#include <vector>

constexpr int printfreq = 100;

// Do the 2D indexing into the array.
//
// Assumes that you have a variable `N` in scope specifying the the
// size of the non-halo part of the grid.
#define get(array, i, j) array[(i)*(N+2) + j]

// Perform a single step of the algorithm.
//
// For each point (if fluid), set it to the maximum of itself and the
// four von Neumann neighbours.
//
// Returns the total number of changed cells.
int percolate_cpu_step(int M, int N, int const* state, int* next) {
  int nchange = 0;

  for (int i = 1; i <= M; ++i) {
    for (int j = 1; j <= N; ++j) {
      int const oldval = get(state, i, j);
      int newval = oldval;

      // 0 => solid, so do nothing
      if (oldval != 0) {
	// Set next[i][j] to be the maximum value of state[i][j] and
	// its four nearest neighbours
	newval = std::max(newval, get(state, i-1, j  ));
	newval = std::max(newval, get(state, i+1, j  ));
	newval = std::max(newval, get(state, i  , j-1));
	newval = std::max(newval, get(state, i  , j+1));

	if (newval != oldval) {
	  ++nchange;
	}
      }

      next[(i)*(N+2) + j] = newval;
    }
  }
  return nchange;
}

// Given an array, state, of size (M+2) x (N+2) with a halo of zeros,
// iteratively perform percolation of the non-zero elements until no
// changes or 4 *max(M, N) iterations.
void percolate_cpu(int M, int N, int* state) {
  int const npoints = (M + 2) * (N + 2);
  // Temporary work array
  std::vector<int> temp(npoints);
  // Copy the initial state to the temp, only the halos are
  // *required*, but much easier this way!
  std::memcpy(temp.data(), state, sizeof(int) * npoints);

  int const maxstep = 4 * std::max(M, N);
  int step = 1;
  int nchange = 1;

  // Use pointers to the buffers (which we swap below) to avoid copies.
  int* current = state;
  int* next = temp.data();

  while (nchange && step <= maxstep) {
    nchange = percolate_cpu_step(M, N, current, next);

    //  Report progress every now and then
    if (step % printfreq == 0) {
      std::printf("percolate: number of changes on step %d is %d\n",
		  step, nchange);
    }

    // Swap the pointers for the next iteration
    std::swap(next, current);
    step++;
  }

  // Answer now in `current`, if that's not the same pointer as
  // `state`, have to copy out.
  if (current != state) {
    std::memcpy(state, temp.data(), sizeof(int) * npoints);
  }
}
