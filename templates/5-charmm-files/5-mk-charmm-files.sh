#!/bin/bash

# This script converts a fitted charge model to a ".dcm" file that can be used
# in CHARMM. Pay attention to the atom ordering in the "frames.txt" file.
# assuming that the atom ordering used for fitting matches the order in the 
# CHARMM topology file, the frames.txt file contains groups of 3 atoms that make
# up each frame. The label "BO" or "BI" requests either a bond as the z-axis or
# the A-B-C bisector angle as the z-axis for the given frame.
#
# Example:
# SCN                        !Title
# 2    1    3    BO          !Frame is defined by atoms 2,1,3 using bonds for z-axes
#

# FOLDERS
ROOTDIR=/cluster/home/chaton/MDCM-master/examples_orginal/MDCM/dcm
WORKDIR=$ROOTDIR/5-charmm-files
BINDIR=/cluster/home/chaton/MDCM-master/bin
REFDIR=$ROOTDIR/../../../ref/dcm
FITDIR=$ROOTDIR/4-analysis
# INPUT
XYZFILE=$FITDIR/cconf2.xyz # fitted model
DCUBE=$REFDIR/esp-dcm1.cube #CPhOH_fixed.cube
FRAMEFILE=$REFDIR/frames-dcm.txt

cd $WORKDIR

NAME=$(basename $XYZFILE)
NAME=${NAME%.*}

$BINDIR/comb-xyz-to-dcm.pl $XYZFILE $DCUBE $FRAMEFILE ${NAME}.dcm


