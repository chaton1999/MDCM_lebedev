#!/bin/bash

#SBATCH --job-name=dcm
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mail-type=NONE
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=1584
# 
hostname

 
#set -xv
export g16root=/cluster/software/g16-c.01
export GAUSS_SCRDIR=/scratch/chaton/dcm
mkdir -p /scratch/chaton/dcm
source $g16root/g16/bsd/g16.profile

$g16root/g16/g16 /cluster/home/chaton/MDCM/dcm/dcm.com /scratch/chaton/dcm/dcm.out

# don't delete the result file if not able to copy to fileserver 
cp /scratch/chaton/dcm/dcm.out /cluster/home/chaton/MDCM/dcm/dcm.out 
status=$?
if [ $status -eq 0 ] 
then 
   rm -rf /scratch/chaton/dcm
else
   host=`/bin/hostname`
   /usr/bin/Mail -v -s "Error at end of batch job" $USER <<EOF

At the end of the batch job the system could not copy the output file
	$host:/scratch/chaton/dcm/dcm.out
to
	/cluster/home/chaton/MDCM/dcm/dcm.out
Please copy this file by hand or inform the system manager.

EOF
 
fi
