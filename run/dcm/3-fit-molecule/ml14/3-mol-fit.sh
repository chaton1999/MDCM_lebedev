#!/bin/bash

# Step 3: Fit molecular charge model (differential evolution) for multiple charge counts
# and multiple independent fits. Submits one SLURM job per (fit j, Ncharges k).

# =========================
# FOLDERS
# =========================
ROOTDIR="/cluster/home/chaton/MDCM-project-pantelis/MDCM_lebedev/run/dcm"
WORKDIR="/cluster/home/chaton/MDCM-project-pantelis/MDCM_lebedev/run/dcm/3-fit-molecule/ml14"
BINDIR="/cluster/home/chaton/MDCM-project-pantelis/MDCM_lebedev/bin_sym"
REFDIR="/cluster/home/chaton/MDCM-project-pantelis/MDCM_lebedev/ref/dcm/single/resp_lebedev_14"
ATOMDIR=$ROOTDIR/2-fit-atoms

# =========================
# INPUT
# =========================
MTPFILE=$ROOTDIR/1-mtp-fit/fitted-mtpl.dat   # from step 1

PCUBE=$REFDIR/e_opt.cube        # Equilibrium geometry ESP
DCUBE=$REFDIR/d_opt.cube        # Equilibrium geometry density
PCUBE2=$REFDIR/e_conf1.cube     # 2nd conformer ESP
DCUBE2=$REFDIR/d_conf1.cube     # 2nd conformer density
PCUBE3=$REFDIR/e_conf2.cube     # 3rd conformer ESP
DCUBE3=$REFDIR/d_conf2.cube     # 3rd conformer density
PCUBE4=$REFDIR/e_conf3.cube     # 4th conformer ESP
DCUBE4=$REFDIR/d_conf3.cube     # 4th conformer density
PCUBE5=$REFDIR/e_conf4.cube     # 5th conformer ESP
DCUBE5=$REFDIR/d_conf4.cube     # 5th conformer density

#FRAMEFILE=/cluster/home/chaton/MDCM-project-pantelis/organic_molecules/ref/dcm/frames.txt
FRAMEFILE="/cluster/home/chaton/MDCM-project-pantelis/MDCM_lebedev/ref/dcm/single/frames.txt"

# =========================
# FITTING PARAMETERS
# =========================
NFIT=6        # number of separate fits to perform (should not exceed atom fits)
NTRY=10        # number of tries for each fit
MAXATMCHG=4   # max charges per atom used in atom fits in step 2
MINCHG=5     # smallest number of charges to fit for molecule
MAXCHG=20     # largest number of charges to fit for molecule

# SLURM defaults (adjust if needed)
PARTITION=vshort
NTASKS=16
NODES=1

cd "$WORKDIR" || exit 1

for ((j=1; j<=NFIT; j++)); do
  cd "$WORKDIR" || exit 1
  mkdir -p "fit$j" && cd "fit$j" || exit 1

  # copy atom fit results used to build starting population + symmetry parameters
  cp "$ATOMDIR/fit$j/"*xyz . 2>/dev/null
  cp "$ATOMDIR/fit$j/"*fit . 2>/dev/null

  for ((k=MINCHG; k<=MAXCHG; k++)); do
    SCRIPT="${k}chgs.sh"
    NCHG=$k

    cat > "$SCRIPT" <<EOF
#!/bin/bash
#SBATCH --job-name=fit${j}q${k}
#SBATCH --nodes=${NODES}
#SBATCH --ntasks=${NTASKS}
#SBATCH --partition=${PARTITION}
#SBATCH --exclude=node[15-20]

WORKDIR="/cluster/home/chaton/MDCM-project-pantelis/MDCM_lebedev/run/dcm/3-fit-molecule/ml14"
BINDIR="/cluster/home/chaton/MDCM-project-pantelis/MDCM_lebedev/bin_sym"
REFDIR="/cluster/home/chaton/MDCM-project-pantelis/MDCM_lebedev/ref/dcm/single/resp_lebedev_14"

PCUBE=${PCUBE}
DCUBE=${DCUBE}
PCUBE2=${PCUBE2}
DCUBE2=${DCUBE2}
PCUBE3=${PCUBE3}
DCUBE3=${DCUBE3}
PCUBE4=${PCUBE4}
DCUBE4=${DCUBE4}
PCUBE5=${PCUBE5}
DCUBE5=${DCUBE5}

FRAMEFILE="/cluster/home/chaton/MDCM-project-pantelis/MDCM_lebedev/ref/dcm/single/frames.txt"
MTPFILE=$ROOTDIR/1-mtp-fit/fitted-mtpl.dat   # from step 1

NTRY=${NTRY}
MINCHG=${NCHG}
MAXCHG=${NCHG}
NAME="${k}chgs"

cd "\${WORKDIR}/fit${j}" || exit 1

START_TIME=\$(date +%s)
echo "Job started at: \$(date)"

"\${BINDIR}/pcubefit.x" -greedy -respgrid \\
  -esp "\${PCUBE}"  -dens "\${DCUBE}" \\
  -esp "\${PCUBE2}" -dens "\${DCUBE2}" \\
  -esp "\${PCUBE3}" -dens "\${DCUBE3}" \\
  -esp "\${PCUBE4}" -dens "\${DCUBE4}" \\
  -esp "\${PCUBE5}" -dens "\${DCUBE5}" \\
  -mtpfile "\${MTPFILE}" \\
  -ncmin "\${MINCHG}" -ncmax "\${MAXCHG}" \\
  -nacmax ${MAXATMCHG} -ntry "\${NTRY}" \\
  -frames "\${FRAMEFILE}" -gnes -v > "\${NAME}.out"

END_TIME=\$(date +%s)
ELAPSED=\$((END_TIME - START_TIME))
echo "Job finished at: \$(date)"
echo "Elapsed time (seconds): \${ELAPSED}"
EOF

    sbatch "$SCRIPT"
    sleep 1
  done
done

