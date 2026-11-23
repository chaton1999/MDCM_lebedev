#!/bin/bash

# In this step we use the atomic fits from the previous step to create an initial
# guess, then we use differential evolution to fit a molecular charge model.
# Again, we repeat the fitting NTRY times for each run to get a good solution,
# and run NFIT separate fits to explore varied solutions.

# We can also run fits with different numbers of charges, so that we can see the
# impact of adding more charges on RMSE and choose a good compromise between
# accuracy and computational cost

# Note: adapt the Slurm script below to whatever cluster environment you're using

# FOLDERS
ROOTDIR="/cluster/home/chaton/MDCM-project-pantelis/MDCM_lebedev/run/dcm"
WORKDIR="/cluster/home/chaton/MDCM-project-pantelis/MDCM_lebedev/run/dcm/3-fit-molecule/sl50"
BINDIR="/cluster/home/chaton/MDCM-project-pantelis/MDCM_lebedev/bin_sym"
REFDIR="/cluster/home/chaton/MDCM-project-pantelis/MDCM_lebedev/ref/dcm/single/resp_lebedev_50"
ATOMDIR=$ROOTDIR/2-fit-atoms

# INPUT
MTPFILE=$ROOTDIR/1-mtp-fit/fitted-mtpl.dat   # from step 1
PCUBE=$REFDIR/e_opt.cube
DCUBE=$REFDIR/d_opt.cube

# FITTING PARAMETERS
NFIT=6         # number of separate fits to perform for each fragment (should not exceed atom fits)
NTRY=10         # number of tries for each fit
MAXATMCHG=4    # max charges per atom used in atom fits in step 2
MINCHG=5      # smallest number of charges to fit for molecule
MAXCHG=20      # largest number of charges to fit for molecule

cd "$WORKDIR" || exit 1

for ((j=1; j<=NFIT; j++)); do
  cd "$WORKDIR" || exit 1
  mkdir -p "fit$j" && cd "fit$j" || exit 1
  cp "$ATOMDIR/fit$j/"*xyz . 2>/dev/null

  for ((k=MINCHG; k<=MAXCHG; k++)); do
    SCRIPT="${k}chgs.sh"
    NCHG=$k

    cat > "$SCRIPT" <<EOF
#!/bin/bash
#SBATCH --job-name=fit${j}q${k}
#SBATCH --nodes=1
#SBATCH --ntasks=16
#SBATCH --partition=vshort
#SBATCH --exclude=node[15-20]

WORKDIR="/cluster/home/chaton/MDCM-project-pantelis/MDCM_lebedev/run/dcm/3-fit-molecule/sl50"
BINDIR="/cluster/home/chaton/MDCM-project-pantelis/MDCM_lebedev/bin_sym"
REFDIR="/cluster/home/chaton/MDCM-project-pantelis/MDCM_lebedev/ref/dcm/single/resp_lebedev_50"
PCUBE=${PCUBE}
DCUBE=${DCUBE}
MTPFILE=$ROOTDIR/1-mtp-fit/fitted-mtpl.dat   # from step 1
NTRY=${NTRY}
MINCHG=${NCHG}
MAXCHG=${NCHG}
NAME="${k}chgs"

cd "\${WORKDIR}/fit${j}" || exit 1

START_TIME=\$(date +%s)
echo "Job started at: \$(date)"

"\${BINDIR}/pcubefit.x" -greedy -respgrid \\
  -esp "\${PCUBE}" \\
  -dens "\${DCUBE}" \\
  -mtpfile "\${MTPFILE}" \\
  -ncmin "\${MINCHG}" \\
  -ncmax "\${MAXCHG}" \\
  -nacmax ${MAXATMCHG} \\
  -ntry "\${NTRY}" \\
  -gnes -v  > "\${NAME}.out"

END_TIME=\$(date +%s)
ELAPSED=\$((END_TIME - START_TIME))
echo "Job finished at: \$(date)"
echo "Elapsed time (seconds): \${ELAPSED}"
EOF

    sbatch "$SCRIPT"
    sleep 1
  done
done
