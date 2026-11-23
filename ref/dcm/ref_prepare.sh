#!/usr/bin/env bash

set -Eeuo pipefail


# ============================================================
# USER CONFIGURATION
# ============================================================
#
# MASTER_DIR:
#   Directory containing the original full-grid cube files.
#
# MOL_NAME:
#   Generic name used for the additional conformers.
#
# Example:
#
#   MOL_NAME="conf"
#
# gives:
#
#   d_conf1.cube
#   e_conf1.cube
#   d_conf2.cube
#   e_conf2.cube
#   ...
#
# ============================================================

MASTER_DIR="./master/gaussian"
OUTDIR="./single_test"

MOL_NAME="conf"

# ------------------------------------------------------------
# Number of atoms
# ------------------------------------------------------------

N_ATOMS=5


# ------------------------------------------------------------
# Optimized/reference geometry
# ------------------------------------------------------------

REF_DENSITY="dcm.cube"
REF_ESP="esp-dcm.cube"


# ------------------------------------------------------------
# Number of additional conformers
# ------------------------------------------------------------

N_CONFORMERS=4


# ------------------------------------------------------------
# Density cube filenames in master/
# ------------------------------------------------------------

CONFORMER_DENSITY=(
    "dcm1.cube"
    "dcm2.cube"
    "dcm3.cube"
    "dcm4.cube"
)


# ------------------------------------------------------------
# ESP cube filenames in master/
# ------------------------------------------------------------

CONFORMER_ESP=(
    "esp-dcm1.cube"
    "esp-dcm2.cube"
    "esp-dcm3.cube"
    "esp-dcm4.cube"
)


# ============================================================
# END OF USER CONFIGURATION
# ============================================================


# ============================================================
# Scripts
# ============================================================

GET_FRAME="./get_frame.py"


# ============================================================
# Standard output names
# ============================================================

OPT_DENSITY_OUT="$OUTDIR/d_opt.cube"
OPT_ESP_OUT="$OUTDIR/e_opt.cube"


# ============================================================
# Automatically determine residue name
# ============================================================
#
# Example:
#
#   dcm.cube -> DCM
#
# ============================================================

RESNAME="${REF_DENSITY%.cube}"
RESNAME="${RESNAME^^}"


# ============================================================
# Helper functions
# ============================================================

die()
{
    echo
    echo "ERROR: $*" >&2
    echo
    exit 1
}


check_file()
{
    local file="$1"

    if [[ ! -f "$file" ]]; then
        die "File does not exist: $file"
    fi

    if [[ ! -s "$file" ]]; then
        die "File is empty: $file"
    fi
}


# ============================================================
# Header
# ============================================================

echo
echo "============================================================"
echo " Cube preparation"
echo "============================================================"
echo
echo "Master directory : $MASTER_DIR"
echo "Output directory : $OUTDIR"
echo "Conformer name   : $MOL_NAME"
echo "Residue name     : $RESNAME"
echo "Number of atoms  : $N_ATOMS"
echo "Conformers       : $N_CONFORMERS"
echo


# ============================================================
# Check master directory
# ============================================================

if [[ ! -d "$MASTER_DIR" ]]; then
    die "Master directory does not exist: $MASTER_DIR"
fi


# ============================================================
# Check get_frame.py
# ============================================================

if [[ ! -f "$GET_FRAME" ]]; then
    die "get_frame.py not found: $GET_FRAME"
fi


# ============================================================
# Check numerical settings
# ============================================================

if (( N_ATOMS < 1 )); then
    die "N_ATOMS must be greater than zero."
fi


if (( N_CONFORMERS < 0 )); then
    die "N_CONFORMERS cannot be negative."
fi


# ============================================================
# Check conformer array lengths
# ============================================================

N_DENSITY=${#CONFORMER_DENSITY[@]}
N_ESP=${#CONFORMER_ESP[@]}


echo "============================================================"
echo " Checking configuration"
echo "============================================================"
echo
echo "Declared conformers : $N_CONFORMERS"
echo "Density files       : $N_DENSITY"
echo "ESP files           : $N_ESP"
echo


if (( N_DENSITY != N_CONFORMERS )); then

    die \
    "N_CONFORMERS=$N_CONFORMERS but CONFORMER_DENSITY contains $N_DENSITY files."

fi


if (( N_ESP != N_CONFORMERS )); then

    die \
    "N_CONFORMERS=$N_CONFORMERS but CONFORMER_ESP contains $N_ESP files."

fi


if (( N_DENSITY != N_ESP )); then

    die \
    "Density and ESP conformer lists have different lengths."

fi


echo "Conformer-count check : OK"


# ============================================================
# Check for duplicate filenames
# ============================================================

if (( N_CONFORMERS > 0 )); then

    unique_density=$(
        printf '%s\n' "${CONFORMER_DENSITY[@]}" |
        sort -u |
        wc -l
    )

    unique_esp=$(
        printf '%s\n' "${CONFORMER_ESP[@]}" |
        sort -u |
        wc -l
    )


    if (( unique_density != N_CONFORMERS )); then
        die "Duplicate filename detected in CONFORMER_DENSITY."
    fi


    if (( unique_esp != N_CONFORMERS )); then
        die "Duplicate filename detected in CONFORMER_ESP."
    fi

fi


echo "Duplicate-file check   : OK"


# ============================================================
# Check optimized/reference cube files
# ============================================================

REF_DENSITY_PATH="$MASTER_DIR/$REF_DENSITY"
REF_ESP_PATH="$MASTER_DIR/$REF_ESP"


echo
echo "============================================================"
echo " Checking optimized geometry"
echo "============================================================"
echo

check_file "$REF_DENSITY_PATH"
check_file "$REF_ESP_PATH"


echo "Density : $REF_DENSITY_PATH"
echo "ESP     : $REF_ESP_PATH"
echo
echo "Optimized geometry check : OK"


# ============================================================
# Check all conformer files
# ============================================================

echo
echo "============================================================"
echo " Checking conformer cube files"
echo "============================================================"
echo


for (( i=0; i<N_CONFORMERS; i++ )); do

    number=$((i + 1))

    density_file="$MASTER_DIR/${CONFORMER_DENSITY[$i]}"
    esp_file="$MASTER_DIR/${CONFORMER_ESP[$i]}"

    check_file "$density_file"
    check_file "$esp_file"

    echo "Conformer $number"
    echo "  Density : ${CONFORMER_DENSITY[$i]}"
    echo "  ESP     : ${CONFORMER_ESP[$i]}"
    echo

done


echo "All requested cube files exist."


# ============================================================
# Create output directory
# ============================================================

mkdir -p "$OUTDIR"


# ============================================================
# Remove old files produced by this script
# ============================================================
#
# This prevents old conformers from surviving if, for example,
# N_CONFORMERS is changed from 8 to 4.
#
# ============================================================

rm -f \
    "$OUTDIR/d_opt.cube" \
    "$OUTDIR/e_opt.cube"

rm -f \
    "$OUTDIR"/d_"${MOL_NAME}"*.cube \
    "$OUTDIR"/e_"${MOL_NAME}"*.cube


# ============================================================
# Copy optimized/reference geometry
# ============================================================

echo
echo "============================================================"
echo " Preparing optimized geometry"
echo "============================================================"
echo


cp -f \
    "$REF_DENSITY_PATH" \
    "$OPT_DENSITY_OUT"

cp -f \
    "$REF_ESP_PATH" \
    "$OPT_ESP_OUT"


echo "$REF_DENSITY_PATH"
echo "  -> $OPT_DENSITY_OUT"
echo

echo "$REF_ESP_PATH"
echo "  -> $OPT_ESP_OUT"


# ============================================================
# Prepare conformers
# ============================================================

echo
echo "============================================================"
echo " Preparing conformers"
echo "============================================================"


for (( i=0; i<N_CONFORMERS; i++ )); do

    number=$((i + 1))

    density_in="$MASTER_DIR/${CONFORMER_DENSITY[$i]}"
    esp_in="$MASTER_DIR/${CONFORMER_ESP[$i]}"

    density_out="$OUTDIR/d_${MOL_NAME}${number}.cube"
    esp_out="$OUTDIR/e_${MOL_NAME}${number}.cube"


    echo
    echo "Conformer $number"
    echo "------------------------------------------------------------"


    cp -f \
        "$density_in" \
        "$density_out"

    cp -f \
        "$esp_in" \
        "$esp_out"


    echo "$density_in"
    echo "  -> $density_out"
    echo

    echo "$esp_in"
    echo "  -> $esp_out"

done


# ============================================================
# Generate local frames from optimized geometry
# ============================================================
#
# IMPORTANT:
#
# Only the optimized density cube is used to determine the
# molecular connectivity and local frames.
#
# Open Babel inside get_frame.py uses:
#
#   obabel -icube ...
#
# ============================================================

echo
echo "============================================================"
echo " Generating local frames"
echo "============================================================"
echo

echo "Optimized cube : $OPT_DENSITY_OUT"
echo "Residue name   : $RESNAME"
echo "Number of atoms: $N_ATOMS"
echo


# Remove old temporary Open Babel files before running
rm -f babel.sdf babel.err


python3 "$GET_FRAME" \
    "$OPT_DENSITY_OUT" \
    "$RESNAME" \
    "$N_ATOMS"


# ============================================================
# Check frames.txt
# ============================================================

if [[ ! -s "frames.txt" ]]; then
    die "get_frame.py did not generate frames.txt"
fi


echo
echo "Generated frames.txt:"
echo
echo "------------------------------------------------------------"
cat frames.txt
echo "------------------------------------------------------------"


# ============================================================
# Remove temporary Open Babel files after successful run
# ============================================================

rm -f babel.sdf babel.err


# ============================================================
# Final verification
# ============================================================

echo
echo "============================================================"
echo " Final verification"
echo "============================================================"
echo


check_file "$OPT_DENSITY_OUT"
check_file "$OPT_ESP_OUT"


for (( i=1; i<=N_CONFORMERS; i++ )); do

    check_file \
        "$OUTDIR/d_${MOL_NAME}${i}.cube"

    check_file \
        "$OUTDIR/e_${MOL_NAME}${i}.cube"

done


EXPECTED_FILES=$((2 + 2 * N_CONFORMERS))


echo "Expected cube files : $EXPECTED_FILES"
echo "Verified cube files : $EXPECTED_FILES"
echo
echo "frames.txt          : OK"


# ============================================================
# Display generated files
# ============================================================

echo
echo "============================================================"
echo " Generated files"
echo "============================================================"
echo


ls -lh \
    "$OPT_DENSITY_OUT" \
    "$OPT_ESP_OUT"


for (( i=1; i<=N_CONFORMERS; i++ )); do

    ls -lh \
        "$OUTDIR/d_${MOL_NAME}${i}.cube" \
        "$OUTDIR/e_${MOL_NAME}${i}.cube"

done


echo
echo "frames.txt:"
echo

cat frames.txt


echo
echo "============================================================"
echo " PREPARATION COMPLETED SUCCESSFULLY"
echo "============================================================"
echo
