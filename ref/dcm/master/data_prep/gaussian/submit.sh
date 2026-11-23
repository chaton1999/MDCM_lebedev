#!/usr/bin/env bash

for f in *.com; do
    name="${f%.com}"

    echo "Submitting $f"

    sbatch \
        --job-name="$name" \
        gaussian.slurm "$f"
done
