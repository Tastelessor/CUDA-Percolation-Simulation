#!/bin/bash --login
#SBATCH --partition=gpu-cascade
#SBATCH --qos=gpu
#SBATCH --gres=gpu:1
#SBATCH --time=00:1:00
#SBATCH --reservation=gputeachmsc

./test
