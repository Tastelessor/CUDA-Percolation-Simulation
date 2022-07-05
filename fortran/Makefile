# Copyright (C) 2022, Rupert Nash, The University of Edinburgh.
#
# All rights reserved.
#
# This file is provided to you to complete an assessment and for
# subsequent private study. It may not be shared and, in particular,
# may not be posted on the internet. Sharing this or any modified
# version may constitute academic misconduct under the University's
# regulations.

# Disable all of make's built-in rules (similar to Fortran's implicit none)
MAKEFLAGS += --no-builtin-rules --no-builtin-variables

# configuration
FC ?= nvfortran
CXX ?= nvc++

FCFLAGS ?= -O3
CXXFLAGS ?= --std=c++11 -O3
CUDAFLAGS ?= -cuda -gpu cc70
LDFLAGS ?=
LDLIBS ?= -lpng -c++libs

RM = rm -f

# list of all source files
COMMON_SRCS = test.f95 util.f95 ../c/util.cpp perc_cpu.f95 perc_gpu.cuf

PROGS = test

COMMON_OBJS = $(addsuffix .o, $(notdir $(COMMON_SRCS)))

.PHONY: all clean
all: $(PROGS)

test: $(COMMON_OBJS)
	$(FC) $(CUDAFLAGS) -o $@ $^ $(LDFLAGS) $(LDLIBS)

%.f95.o: %.f95
	$(FC) $(FCFLAGS) -c -o $@ $<
%.cuf.o: %.cuf
	$(FC) $(FCFLAGS) $(CUDAFLAGS) -c -o $@ $<
%.cpp.o : ../c/%.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

# define dependencies between object files (cos modules)
test.f95.o : util.f95.o perc_cpu.f95.o perc_gpu.cuf.o

clean:
	$(RM) $(COMMON_OBJS) bench.cuf.o hist_gpu.cuf.o $(wildcard *.mod) $(PROGS)
