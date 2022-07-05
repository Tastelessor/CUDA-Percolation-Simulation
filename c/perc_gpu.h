// Copyright (C) 2022, Rupert Nash, The University of Edinburgh.
//
// All rights reserved.
//
// This file is provided to you to complete an assessment and for
// subsequent private study. It may not be shared and, in particular,
// may not be posted on the internet. Sharing this or any modified
// version may constitute academic misconduct under the University's
// regulations.

#ifndef APT_CUDACW_PERC_GPU_H
#define APT_CUDACW_PERC_GPU_H

// Given an array, state, of size (M+2) x (N+2) with a halo of zeros,
// iteratively perform percolation of the non-zero elements until no
// changes or 4 *max(M, N) iterations.
void percolate_gpu(int M, int N, int* state);

#endif
