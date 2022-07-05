# Copyright (C) 2022, Rupert Nash, The University of Edinburgh.
#
# All rights reserved.
#
# This file is provided to you to complete an assessment and for
# subsequent private study. It may not be shared and, in particular,
# may not be posted on the internet. Sharing this or any modified
# version may constitute academic misconduct under the University's
# regulations.

CXX ?= g++
NVCC ?= nvcc
LD ?= $(nvcc)

CXXFLAGS ?= -O3 --std=c++11
NVCCFLAGS ?= $(CXXFLAGS)

LDFLAGS ?=
LDLIBS ?= -lm -lpng

COMMON = util.o perc_cpu.o perc_gpu.o
PROGS = test

OBJECTS = $(COMMON) $(PROGS:=.o)

test : $(OBJECTS)
	$(NVCC) $(LDFLAGS) $(OBJECTS) $(LDLIBS) -o $@

%.o : %.cu
	$(NVCC) -c -dc $(NVCCFLAGS) -o $@ $<

.PHONY : clean
clean :
	rm -f $(PROGS) $(OBJECTS)
