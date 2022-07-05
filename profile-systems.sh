#!/bin/bash --login
#SBATCH --partition=gpu-cascade
#SBATCH --qos=gpu
#SBATCH --gres=gpu:1
#SBATCH --time=00:1:00
#SBATCH --reservation=gputeachmsc

NVHPC_VERSION=21.2
module load nvidia/nvhpc/$NVHPC_VERSION

nsys profile -o test-${SLURM_JOB_ID} ./test

# For unknown reasons this isn't on the PATH
$NVHPC/Linux_x86_64/$NVHPC_VERSION/profilers/Nsight_Systems/host-linux-x64/QdstrmImporter test-${SLURM_JOB_ID}.qdstrm
