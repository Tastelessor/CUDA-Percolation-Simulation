// Copyright (C) 2022, Rupert Nash, The University of Edinburgh.
//
// All rights reserved.
//
// This file is provided to you to complete an assessment and for
// subsequent private study. It may not be shared and, in particular,
// may not be posted on the internet. Sharing this or any modified
// version may constitute academic misconduct under the University's
// regulations.

#include "util.h"

#include <algorithm>
#include <random>
#include <png.h>

// Print the map to the file. If bounds is true, include the boundary
// halo.
void txt_print(FILE* f, int M, int N, int const* map, int bounds) {
  int lo_i = bounds ? 0 : 1;
  int hi_i = bounds ? M+2 : M+1;
  int lo_j = bounds ? 0 : 1;
  int hi_j = bounds ? N+2 : N+1;
  int stride = N + 2;

  for (int j = lo_j; j < hi_j; ++j) {
    std::fprintf(f, "%3d", map[lo_i * stride + j]);
    for (int i = lo_i + 1; i < hi_i; ++i) {
      std::fprintf(f, " %3d", map[i * stride + j]);
    }
    std::fprintf(f, "\n");
  }
}

// Macro to help with array access, accounting for the halo. Requires
// a variable `N` in scope.
#define get(array, i, j) array[(i)*(N+2) + j]

// Initialise map with target porosity. Zero indicates rock, a
// positive value indicates a hole. For the algorithm to work, all
// the holes must be initialised with a unique integer.
// Returns number of holes.
int fill_map(int seed, float porosity, int M, int N, int* map) {
  int nhole = 0;
  // Seed should really be unsigned, but Fortran doesn't do unsigned...
  std::mt19937 gen{(unsigned)seed};
  std::uniform_real_distribution<float> uni;

  // Zero edges
  for (int j = 0; j < N+2; ++j) {
    // i = 0
    get(map, 0, j) = 0;
    // i = M + 1
    get(map, M+1, j) = 0;
  }
  for (int i = 1; i < M+1; ++i) {
    // j = 0
    get(map, i, 0) = 0;
    // j = N + 1
    get(map, i, N+1) = 0;
  }

  // Fill middle
  for (int i = 1; i < M+1; ++i) {
    for (int j = 1; j < N+1; ++j) {
      auto r = uni(gen);

      if (r < porosity) {
	get(map, i, j) = ++nhole;
      } else {
	get(map, i, j) = 0;
      }
    }
  }

  // std::printf("Generated %d x %d with %d holes\n", M, N, nhole);
  // txt_print(stdout, M, N, map, 1);
  return nhole;
}


// Convert HSV(hue, 1, 1) to RGB color space
static void hue2rgb(float hue, std::uint16_t rgb[3]) {
  constexpr std::uint16_t MAX = std::numeric_limits<std::uint16_t>::max();
  float const huePrime = std::fmod(6.0f * hue, 6.0f);
  std::uint16_t const fX = (1.f - std::fabs(std::fmod(huePrime, 2.f) - 1.f)) * MAX;

  if(0 <= huePrime && huePrime < 1) {
    rgb[0] = MAX;
    rgb[1] = fX;
    rgb[2] = 0;
  } else if(1 <= huePrime && huePrime < 2) {
    rgb[0] = fX;
    rgb[1] = MAX;
    rgb[2] = 0;
  } else if(2 <= huePrime && huePrime < 3) {
    rgb[0] = 0;
    rgb[1] = MAX;
    rgb[2] = fX;
  } else if(3 <= huePrime && huePrime < 4) {
    rgb[0] = 0;
    rgb[1] = fX;
    rgb[2] = MAX;
  } else if(4 <= huePrime && huePrime < 5) {
    rgb[0] = fX;
    rgb[1] = 0;
    rgb[2] = MAX;
  } else if(5 <= huePrime && huePrime < 6) {
    rgb[0] = MAX;
    rgb[1] = 0;
    rgb[2] = fX;
  } else {
    rgb[0] = 0;
    rgb[1] = 0;
    rgb[2] = 0;
  }
}

int write_state_png(char const* file_name, int M, int N, int nhole, int const* state) {
  FILE *fp = std::fopen(file_name, "wb");
  if (!fp) {
    std::fprintf(stderr, "Could not open file '%s'\n", file_name);
    return 1;
  }

  // PNG basic init
  png_structp png_ptr =
    png_create_write_struct(PNG_LIBPNG_VER_STRING, nullptr,
			    nullptr, nullptr);
  if (!png_ptr) {
    std::fprintf(stderr, "png_create_write_struct error");
    std::fclose(fp);
    return 1;
  }
  png_infop info_ptr = png_create_info_struct(png_ptr);
  if (!info_ptr) {
    std::fprintf(stderr, "png_create_info_struct error");
    png_destroy_write_struct(&png_ptr,
			     nullptr);
    std::fclose(fp);
    return 1;
  }

  if (setjmp(png_jmpbuf(png_ptr))) {
    std::fprintf(stderr, "PNG error in png_init_io\n");
    png_destroy_write_struct(&png_ptr, &info_ptr);
    std::fclose(fp);
    return 1;
  }
  png_init_io(png_ptr, fp);

  // Headers
  if (setjmp(png_jmpbuf(png_ptr))) {
    std::fprintf(stderr, "PNG error in during header write\n");
    png_destroy_write_struct(&png_ptr, &info_ptr);
    std::fclose(fp);
    return 1;
  }
  png_set_IHDR(png_ptr, info_ptr, M, N,
	       16, PNG_COLOR_TYPE_RGB, PNG_INTERLACE_NONE,
	       PNG_COMPRESSION_TYPE_BASE, PNG_FILTER_TYPE_BASE);
  png_write_info(png_ptr, info_ptr);

  // write data
  if (setjmp(png_jmpbuf(png_ptr))) {
    std::fprintf(stderr, "PNG error in during data write\n");
    png_destroy_write_struct(&png_ptr, &info_ptr);
    std::fclose(fp);
    return 1;
  }

  // Write row by row
  // PNG can only have up to 16 bit per channel.
  // Write rock/solid (== 0) as black.
  // Map fluid (1 <= x <= nhole) onto hue (0, 1.0), then convert HSV
  // (h, 1, 1) into RGB.
  std::vector<std::uint16_t> row(3*M);
  for (int j = 1; j < N + 1; ++j) {
    for (int i = 1, r = 0; i < M + 1; ++i, r += 3) {
      int const& p = get(state, i, j);
      if (p == 0) {
	// solid is black
	row[r + 0] = 0;
	row[r + 1] = 0;
	row[r + 2] = 0;
      } else {
	hue2rgb((float)(p - 1) / (float)nhole, &row[r]);
      }
    }
    // Write the row
    png_write_row(png_ptr, reinterpret_cast<unsigned char const*>(row.data()));
  }

  // Finish writing, close file, etc.
  png_write_end(png_ptr, NULL);
  png_destroy_write_struct(&png_ptr, &info_ptr);
  std::fclose(fp);
  return 0;
}
