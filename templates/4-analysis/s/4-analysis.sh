#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# STEP 4: SINGLE-CONFORMER ANALYSIS
#
# Uses only the equilibrium reference:
#
#   e_opt.cube
#   d_opt.cube
# ============================================================


# ============================================================
# FOLDERS
#
# These values will later be filled by the master prepare
# script.
# ============================================================

ROOTDIR="__ROOTDIR__"

WORKDIR="$ROOTDIR/4-analysis/s"

BINDIR="__BINDIR__"

REFDIR="__REFDIR__"


# ============================================================
# CHARGE MODEL
# ============================================================

CHARGE_FILE="24charges.xyz"

NCHG=24

XYZFILE="$WORKDIR/$CHARGE_FILE"

NAME="${CHARGE_FILE%.xyz}"


# ============================================================
# REFERENCE CUBE
# ============================================================

PCUBE="$REFDIR/e_opt.cube"

DCUBE="$REFDIR/d_opt.cube"


# ============================================================
# ENTER WORK DIRECTORY
# ============================================================

cd "$WORKDIR"


# ============================================================
# CHECK REQUIRED FILES
# ============================================================

for f in \
    "$XYZFILE" \
    "$PCUBE" \
    "$DCUBE"
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
echo "SINGLE-CONFORMER ANALYSIS"
echo "============================================================"
echo "WORKDIR     = $WORKDIR"
echo "CHARGE_FILE = $CHARGE_FILE"
echo "NCHG        = $NCHG"
echo "REFDIR      = $REFDIR"
echo "PCUBE       = $PCUBE"
echo "DCUBE       = $DCUBE"
echo "============================================================"
echo


# ============================================================
# GENERATE CUBE
# ============================================================

"$BINDIR/pcubefit.x" \
    -generate \
    -xyz "$XYZFILE" \
    -esp "$PCUBE" \
    -dens "$DCUBE" \
    -v


# ============================================================
# ANALYZE
# ============================================================

"$BINDIR/pcubefit.x" \
    -v \
    -analysis \
    -esp "$PCUBE" \
    -esp2 "${NAME}.cube" \
    -dens "$DCUBE" \
    > "analyze-cube-${NAME}.log"


echo
echo "============================================================"
echo "SINGLE-CONFORMER ANALYSIS FINISHED"
echo "============================================================"
