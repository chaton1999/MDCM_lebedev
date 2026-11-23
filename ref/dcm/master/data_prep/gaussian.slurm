#!/bin/bash

#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=450G
#SBATCH --time=7-00:00:00
#SBATCH --mail-type=NONE

# ============================================================
# Input
# ============================================================

INPUT="$1"
INPUT=$(realpath "$INPUT")

NAME=$(basename "$INPUT" .com)
WORKDIR=$(dirname "$INPUT")

echo "=============================================="
echo "Gaussian job"
echo "=============================================="
echo "Job ID      : $SLURM_JOB_ID"
echo "Node        : $(hostname)"
echo "Input       : $INPUT"
echo "Name        : $NAME"
echo "Workdir     : $WORKDIR"
echo "CPUs        : $SLURM_CPUS_PER_TASK"
echo "SLURM Memory: 450G"
echo "=============================================="

# ============================================================
# Gaussian installation
# ============================================================

export g16root=/cluster/software/g16-c.01

# ============================================================
# Gaussian scratch
# ============================================================

export GAUSS_SCRDIR="/scratch/$USER/${NAME}_${SLURM_JOB_ID}"

mkdir -p "$GAUSS_SCRDIR"

echo "Scratch     : $GAUSS_SCRDIR"

# ============================================================
# Load Gaussian environment
# ============================================================

source "$g16root/g16/bsd/g16.profile"

PROFILE_STATUS=$?

if [ "$PROFILE_STATUS" -ne 0 ]; then
    echo "ERROR: g16.profile failed with status $PROFILE_STATUS"
    exit "$PROFILE_STATUS"
fi

echo "Gaussian environment loaded."

# ============================================================
# Copy input to scratch
# ============================================================

cp "$INPUT" "$GAUSS_SCRDIR/${NAME}.com"

cd "$GAUSS_SCRDIR"

# ============================================================
# Run Gaussian
# ============================================================

echo
echo "=============================================="
echo "Starting Gaussian"
echo "=============================================="
date

"$g16root/g16/g16" \
    "${NAME}.com" \
    "${NAME}.out"

STATUS=$?

echo
date
echo "Gaussian exit status: $STATUS"

# ============================================================
# Copy persistent files back
# ============================================================

if [ -f "${NAME}.out" ]; then
    cp "${NAME}.out" "$WORKDIR/${NAME}.out"
fi

if [ -f "${NAME}.chk" ]; then
    cp "${NAME}.chk" "$WORKDIR/${NAME}.chk"
fi

# ============================================================
# Finish
# ============================================================

if [ "$STATUS" -eq 0 ]; then

    echo
    echo "=============================================="
    echo "Gaussian completed successfully"
    echo "=============================================="

    cd /
    rm -rf "$GAUSS_SCRDIR"

else

    echo
    echo "=============================================="
    echo "Gaussian FAILED"
    echo "=============================================="
    echo "Scratch retained at:"
    echo "$GAUSS_SCRDIR"

    exit "$STATUS"

fi
