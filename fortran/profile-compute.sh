#!/bin/bash --login
#SBATCH --partition=gpu-cascade
#SBATCH --qos=gpu
#SBATCH --gres=gpu:1
#SBATCH --time=00:1:00
#SBATCH --reservation=gputeachmsc

NVHPC_VERSION=21.2
module load nvidia/nvhpc/$NVHPC_VERSION

cmd=(
    ncu
    -o test-${SLURM_JOB_ID} # save to file
    --kernel-regex 'percolate_gpu_step' # specify kernel to allow skip and count
    --launch-count 10 # collect only ten runs (as collecting detailed info)
    --set detailed # collect
    ./test # application
)
"${cmd[@]}"
