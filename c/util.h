// Copyright (C) 2022, Rupert Nash, The University of Edinburgh.
//
// All rights reserved.
//
// This file is provided to you to complete an assessment and for
// subsequent private study. It may not be shared and, in particular,
// may not be posted on the internet. Sharing this or any modified
// version may constitute academic misconduct under the University's
// regulations.

#ifndef APT_CUDACW_UTIL_H
#define APT_CUDACW_UTIL_H

#include <stdio.h>

// These functions require an interface suitable for calling from
// Fortran.
#ifdef __cplusplus
extern "C" {
#endif

  // Print the map to the file. If bounds is true (i.e. non zero),
  // include the boundary halo.
  void txt_print(FILE* f, int M, int N, int const* map, int bounds);
  
  // Initialise map with density target density rho. Zero indicates
  // rock, a positive value indicates a hole. For the algorithm to
  // work, all the holes must be initialised with a unique integer.
  //
  // seed - random number generator seed
  //
  // porosity - target porosity
  //
  // M, N - active array size
  //
  // map - the pointer where to store the generated data, must have
  //       size (M+2)*(N+2)
  //
  // Returns number of holes.
  int fill_map(int seed, float porosity, int M, int N, int* map);

  // Write a simulation state/map to the file in PNG format.
  // Rock is black, fluid coloured based on cluster.
  int write_state_png(char const* file_name, int M, int N, int nhole, int const* state);

#ifdef __cplusplus
}
#endif

#endif
