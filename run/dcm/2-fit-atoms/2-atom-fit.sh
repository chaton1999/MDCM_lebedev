#!/bin/bash

# Here we fit atomic MDCM models to the atomic multipoles from the previous step,
# again for a single conformer only.
# We fit models with 1,2,3..MAXCHG charges per atom, and for each fit we repeat
# NTRY times to increase chances of a good solution. We additionally run NFIT
# completely independent fits to more widely explore potential solutions. 
#
# We also apply symmetry constraints to ensure that the final charge model
# reflects the symmetry of the H2O molecule. For more details, see the 
# "symmetry-constrained" example.

# Note: adapt the Slurm script below to whatever cluster you're using...

#____________________________________________________________________________________________
# Define paths
#____________________________________________________________________________________________

ROOT="/cluster/home/chaton/MDCM-project-pantelis/MDCM_lebedev/run/dcm"
WORKDIR="/cluster/home/chaton/MDCM-project-pantelis/MDCM_lebedev/run/dcm/2-fit-atoms"
BINDIR="/cluster/home/chaton/MDCM-project-pantelis/MDCM_lebedev/bin_sym"
REFDIR="/cluster/home/chaton/MDCM-project-pantelis/MDCM_lebedev/ref/dcm/single"
MTPDIR=$ROOT/1-mtp-fit


#_____________________________________________________________________________________________
# Dedine inputs
#_____________________________________________________________________________________________

PCUBE=$REFDIR/e_opt.cube                    # ESP CUBE file supplied by user
DCUBE=$REFDIR/d_opt.cube                    # Density CUBE file supplied by user
MTPFILE=$MTPDIR/fitted-mtpl.dat             # fitted multipoles from step 1 


#_________________________________________________________________________________________________
# FITTING PARAMETERS
#__________________________________________________________________________________________________
NFIT=6      # number of separate fits to perform for each atom (more is better but needs more cores)
NTRY=13      # number of tries for each fit (more is better but slower)
NATOM=5     # total atoms in molecule to fit (usually number of atoms in molecule)
MAXCHG=4    # max charges per atom to fit (4 is usually enough for l=2 quality)



#_________________________________________________________________________________________________
#Jobs
#__________________________________________________________________________________________________


cd $WORKDIR
rm -r fit*

for ((j=1; j<=$NFIT; j++)); do
  cd $WORKDIR
  mkdir fit$j && cd fit$j

  for ((i=1; i<=$NATOM; i++)); do

    # Adapt this submission script for your cluster environment
    SCRIPT="atom"$i".sh"
    echo "#!/bin/bash

#SBATCH --job-name=atom$i
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --partition=vshort


#_________________________________________________________________________________________________
#Functions
#__________________________________________________________________________________________________



WORKDIR="/cluster/home/chaton/MDCM-project-pantelis/MDCM_lebedev/run/dcm/2-fit-atoms"
BINDIR="/cluster/home/chaton/MDCM-project-pantelis/MDCM_lebedev/bin_sym"
REFDIR="/cluster/home/chaton/MDCM-project-pantelis/MDCM_lebedev/ref/dcm/single"
MTPFILE=$MTPFILE
PCUBE=$PCUBE
DCUBE=$DCUBE
NTRY=$NTRY
ATOMINDEX=$i
MAXCHG=$MAXCHG

cd \$WORKDIR/fit$j
hostname

\$BINDIR/pcubefit.x -greedy -mtpfile \$MTPFILE -esp \$PCUBE -dens \$DCUBE -nacmin 1 -nacmax \$MAXCHG -atom \$ATOMINDEX -ntry \$NTRY -onlymultipoles -v > atom$i-fit.out
" > $SCRIPT

    sbatch $SCRIPT
  done
done

