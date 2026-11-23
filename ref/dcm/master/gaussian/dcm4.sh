#!/bin/bash

#SBATCH --job-name=dcm4
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mail-type=NONE
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=1584
# 
hostname

 
#set -xv
export g16root=/cluster/software/g16-c.01
export GAUSS_SCRDIR=/scratch/chaton/dcm4
mkdir -p /scratch/chaton/dcm4
source $g16root/g16/bsd/g16.profile

$g16root/g16/g16 /cluster/home/chaton/MDCM/dcm/dcm4.com /scratch/chaton/dcm4/dcm4.out

# don't delete the result file if not able to copy to fileserver 
cp /scratch/chaton/dcm4/dcm4.out /cluster/home/chaton/MDCM/dcm/dcm4.out 
status=$?
if [ $status -eq 0 ] 
then 
   rm -rf /scratch/chaton/dcm4
else
   host=`/bin/hostname`
   /usr/bin/Mail -v -s "Error at end of batch job" $USER <<EOF

At the end of the batch job the system could not copy the output file
	$host:/scratch/chaton/dcm4/dcm4.out
to
	/cluster/home/chaton/MDCM/dcm/dcm4.out
Please copy this file by hand or inform the system manager.

EOF
 
fi
