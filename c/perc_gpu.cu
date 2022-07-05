// -*- mode: C++; -*-
//
// Copyright (C) 2022, Rupert Nash, The University of Edinburgh.
//
// All rights reserved.
//
// This file is provided to you to complete an assessment and for
// subsequent private study. It may not be shared and, in particular,
// may not be posted on the internet. Sharing this or any modified
// version may constitute academic misconduct under the University's
// regulations.

#include "perc_gpu.h"

#include <cstdio>
#include <cstring>
#include <vector>

constexpr int printfreq = 100;

// Do the 2D indexing into the array.
//
// Assumes that you have a variable `N` in scope specifying the the
// size of the non-halo part of the grid.
#define get(array, i, j) array[(i)*(N+2) + j]
#define INT sizeof(int)

__global__ void update_by_neighbours(int* current_state, int* next_state, int N, int *dchange) {
    int row, col;

    row = blockIdx.y * blockDim.y + threadIdx.y + 1;
    col = blockIdx.x * blockDim.x + threadIdx.x + 1;

    int old_val = current_state[(row)*(N+2)+col];
    int new_val = old_val;

    if (old_val != 0) {
        new_val = current_state[(row-1)*(N+2)+col] > new_val ? current_state[(row-1)*(N+2)+col] : new_val;
        new_val = current_state[(row+1)*(N+2)+col] > new_val ? current_state[(row+1)*(N+2)+col] : new_val;
        new_val = current_state[(row)*(N+2)+col-1] > new_val ? current_state[(row)*(N+2)+col-1] : new_val;
        new_val = current_state[(row)*(N+2)+col+1] > new_val ? current_state[(row)*(N+2)+col+1] : new_val;
    }

    if (new_val != old_val) {
        *dchange = atomicAdd(dchange, 1);
        next_state[row * (N + 2) + col] = new_val;
    }
}

// Perform a single step of the algorithm.
//
// For each point (if fluid), set it to the maximum of itself and the
// four von Neumann neighbours.
//
// Returns the total number of changed cells.
int percolate_gpu_step(int M, int N, int const *state, int *next) {
    int nchange = 0;

    for (int i = 1; i <= M; ++i) {
        for (int j = 1; j <= N; ++j) {
            int const oldval = get(state, i, j);
            int newval = oldval;

            // 0 => solid, so do nothing
            if (oldval != 0) {
                // Set next[i][j] to be the maximum value of state[i][j] and
                // its four nearest neighbours
                newval = std::max(newval, get(state, i - 1, j));
                newval = std::max(newval, get(state, i + 1, j));
                newval = std::max(newval, get(state, i, j - 1));
                newval = std::max(newval, get(state, i, j + 1));

                if (newval != oldval) {
                    ++nchange;
                }
            }

            next[(i) * (N + 2) + j] = newval;
        }
    }
    return nchange;
}

// Given an array, state, of size (M+2) x (N+2) with a halo of zeros,
// iteratively perform percolation of the non-zero elements until no
// changes or 4 *max(M, N) iterations.
void percolate_gpu(int M, int N, int *state) {
    int const npoints = (M + 2) * (N + 2);
    // Temporary work array
    std::vector<int> temp(npoints);
    // Copy the initial state to the temp, only the halos are
    // *required*, but much easier this way!
    std::memcpy(temp.data(), state, INT * npoints);

    int const maxstep = 4 * std::max(M, N);
    int step = 1;
    int nchange = 1;

    // Use pointers to the buffers (which we swap below) to avoid copies.
//    int *current = state;
//    int *next = temp.data();
    int *current;
    int *next;
    int *dchange;

    // Print device details
    int deviceNum;
    cudaGetDevice(&deviceNum);
    cudaDeviceProp prop;
    cudaGetDeviceProperties(&prop, deviceNum);
    std::printf("Device name: %s\n", prop.name);

    // Allocate memory on device
    size_t memory_size = npoints * INT;
    cudaMalloc(&current, memory_size);
    cudaMalloc(&next, memory_size);
    cudaMalloc(&dchange, INT);
    cudaMemcpy(current, state, memory_size, cudaMemcpyHostToDevice);
    cudaMemcpy(next, temp.data(), memory_size, cudaMemcpyHostToDevice);
    cudaMemcpy(dchange, &nchange, INT, cudaMemcpyHostToDevice);

    // GPU decomposition
    const dim3 threadsPerBlock(256, 256, 1);
    const dim3 blocksPerGrid(N/256, M/256, 1);

    while (nchange && step <= maxstep) {
        nchange = 0;
        update_by_neighbours<<<blocksPerGrid, threadsPerBlock>>> (current, next, N, dchange);
        cudaDeviceSynchronize();
//        nchange = percolate_gpu_step(M, N, current, next);
        cudaMemcpy(&nchange, dchange, INT, cudaMemcpyDeviceToHost);

        //  Report progress every now and then
        if (step % printfreq == 0) {
            std::printf("percolate: number of changes on step %d is %d\n",
                        step, nchange);
        }

        // Swap the pointers for the next iteration
//        std::swap(next, current);
        cudaMemcpy(current, next, memory_size, cudaMemcpyDeviceToHost);
        step++;
    }

    cudaMemcpy(state, current, memory_size, cudaMemcpyDeviceToHost);

    // Answer now in `current`, if that's not the same pointer as
    // `state`, have to copy out.
/*    if (current != state) {
        std::memcpy(state, temp.data(), INT * npoints);
    }*/
    std::memcpy(state, temp.data(), INT * npoints);

    cudaFree(current);
    cudaFree(next);
    cudaFree(dchange);
}
