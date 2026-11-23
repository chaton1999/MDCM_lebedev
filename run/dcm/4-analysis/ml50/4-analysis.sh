#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# STEP 4: MULTI-CONFORMER ANALYSIS
#
# This template analyzes the molecular charge model against:
#
#   equilibrium:
#       e_opt.cube
#       d_opt.cube
#
#   conformers:
#       e_conf1.cube / d_conf1.cube
#       e_conf2.cube / d_conf2.cube
#       ...
#
# A frame file is required to transform the charge model
# between conformers.
# ============================================================


# ============================================================
# FOLDERS
#
# These values will later be filled by the master prepare
# script.
# ============================================================

ROOTDIR="/cluster/home/chaton/MDCM-project-pantelis/MDCM_lebedev/run/dcm"

WORKDIR="/cluster/home/chaton/MDCM-project-pantelis/MDCM_lebedev/run/dcm/4-analysis/ml50"

BINDIR="/cluster/home/chaton/MDCM-project-pantelis/MDCM_lebedev/bin_sym"

REFDIR="/cluster/home/chaton/MDCM-project-pantelis/MDCM_lebedev/ref/dcm/single/resp_lebedev_50"

FRAMEFILE="/cluster/home/chaton/MDCM-project-pantelis/MDCM_lebedev/ref/dcm/single/frames.txt"


# ============================================================
# CHARGE MODEL
#
# Change these after selecting the desired Step-3 model.
# ============================================================

CHARGE_FILE="24charges.xyz"

NCHG=24

XYZFILE="$WORKDIR/$CHARGE_FILE"

NAME="${CHARGE_FILE%.xyz}"


# ============================================================
# REFERENCE CUBES
# ============================================================

PCUBE="$REFDIR/e_opt.cube"
DCUBE="$REFDIR/d_opt.cube"

PCUBE2="$REFDIR/e_conf1.cube"
DCUBE2="$REFDIR/d_conf1.cube"

PCUBE3="$REFDIR/e_conf2.cube"
DCUBE3="$REFDIR/d_conf2.cube"

PCUBE4="$REFDIR/e_conf3.cube"
DCUBE4="$REFDIR/d_conf3.cube"

PCUBE5="$REFDIR/e_conf4.cube"
DCUBE5="$REFDIR/d_conf4.cube"


# ============================================================
# ENTER WORK DIRECTORY
# ============================================================

cd "$WORKDIR"


# ============================================================
# CHECK REQUIRED FILES
# ============================================================

for f in \
    "$XYZFILE" \
    "$FRAMEFILE" \
    "$PCUBE" \
    "$DCUBE" \
    "$PCUBE2" \
    "$DCUBE2" \
    "$PCUBE3" \
    "$DCUBE3" \
    "$PCUBE4" \
    "$DCUBE4" \
    "$PCUBE5" \
    "$DCUBE5"
do

    if [[ ! -f "$f" ]]; then
        echo "ERROR: missing required file:"
        echo "  $f"
        exit 1
    fi

done


if [[ ! -x "$BINDIR/pcubefit.x" ]]; then

    echo "ERROR: pcubefit.x not found:"
    echo "  $BINDIR/pcubefit.x"
    exit 1

fi


echo
echo "============================================================"
echo "MULTI-CONFORMER ANALYSIS"
echo "============================================================"
echo "WORKDIR     = $WORKDIR"
echo "CHARGE_FILE = $CHARGE_FILE"
echo "NCHG        = $NCHG"
echo "REFDIR      = $REFDIR"
echo "FRAMEFILE   = $FRAMEFILE"
echo "============================================================"
echo


# ============================================================
# EQUILIBRIUM GEOMETRY
# ============================================================

"$BINDIR/pcubefit.x" \
    -generate \
    -xyz "$XYZFILE" \
    -esp "$PCUBE" \
    -dens "$DCUBE" \
    -v


cp "${NCHG}charges.cube" \
   "${NCHG}charge1.cube"


[[ -f conf2.xyz ]] && \
    cp conf2.xyz cconf1.xyz || true


"$BINDIR/pcubefit.x" \
    -v \
    -analysis \
    -esp "$PCUBE" \
    -esp2 "${NAME}.cube" \
    -dens "$DCUBE" \
    > "analyze-cube-${NAME}.log"


cp error.cube error1.cube


# ============================================================
# CONFORMER 1
# ============================================================

"$BINDIR/pcubefit.x" \
    -generate \
    -xyz "$XYZFILE" \
    -esp "$PCUBE" \
    -dens "$DCUBE" \
    -esp "$PCUBE2" \
    -dens "$DCUBE2" \
    -frames "$FRAMEFILE" \
    -v


cp "${NCHG}charges.cube" \
   "${NCHG}charge2.cube"


[[ -f conf2.xyz ]] && \
    cp conf2.xyz cconf2.xyz || true


"$BINDIR/pcubefit.x" \
    -v \
    -analysis \
    -esp "$PCUBE2" \
    -esp2 "${NAME}.cube" \
    -dens "$DCUBE2" \
    > "analyze-cube-${NAME}-2.log"


cp error.cube error2.cube


# ============================================================
# CONFORMER 2
# ============================================================

"$BINDIR/pcubefit.x" \
    -generate \
    -xyz "$XYZFILE" \
    -esp "$PCUBE" \
    -dens "$DCUBE" \
    -esp "$PCUBE3" \
    -dens "$DCUBE3" \
    -frames "$FRAMEFILE" \
    -v


cp "${NCHG}charges.cube" \
   "${NCHG}charge3.cube"


[[ -f conf2.xyz ]] && \
    cp conf2.xyz cconf3.xyz || true


"$BINDIR/pcubefit.x" \
    -v \
    -analysis \
    -esp "$PCUBE3" \
    -esp2 "${NAME}.cube" \
    -dens "$DCUBE3" \
    > "analyze-cube-${NAME}-3.log"


cp error.cube error3.cube


# ============================================================
# CONFORMER 3
# ============================================================

"$BINDIR/pcubefit.x" \
    -generate \
    -xyz "$XYZFILE" \
    -esp "$PCUBE" \
    -dens "$DCUBE" \
    -esp "$PCUBE4" \
    -dens "$DCUBE4" \
    -frames "$FRAMEFILE" \
    -v


cp "${NCHG}charges.cube" \
   "${NCHG}charge4.cube"


[[ -f conf2.xyz ]] && \
    cp conf2.xyz cconf4.xyz || true


"$BINDIR/pcubefit.x" \
    -v \
    -analysis \
    -esp "$PCUBE4" \
    -esp2 "${NAME}.cube" \
    -dens "$DCUBE4" \
    > "analyze-cube-${NAME}-4.log"


cp error.cube error4.cube


# ============================================================
# CONFORMER 4
# ============================================================

"$BINDIR/pcubefit.x" \
    -generate \
    -xyz "$XYZFILE" \
    -esp "$PCUBE" \
    -dens "$DCUBE" \
    -esp "$PCUBE5" \
    -dens "$DCUBE5" \
    -frames "$FRAMEFILE" \
    -v


cp "${NCHG}charges.cube" \
   "${NCHG}charge5.cube"


[[ -f conf2.xyz ]] && \
    cp conf2.xyz cconf5.xyz || true


"$BINDIR/pcubefit.x" \
    -v \
    -analysis \
    -esp "$PCUBE5" \
    -esp2 "${NAME}.cube" \
    -dens "$DCUBE5" \
    > "analyze-cube-${NAME}-5.log"


cp error.cube error5.cube


echo
echo "============================================================"
echo "MULTI-CONFORMER ANALYSIS FINISHED"
echo "============================================================"
