#!/bin/bash

#SBATCH --job-name=Stream
#SBATCH --ntasks=2
#SBATCH --nodes=2
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=2M
#SBATCH --output=stream_%j.log
pwd; date

srun ./stream_c.exe
wait

date
