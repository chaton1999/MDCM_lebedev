#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# USER SETTINGS
# ============================================================

NPROC=16
MEM="400GB"

METHOD="mp2/aug-cc-pvtz"
SCF="scf=maxcycle=200"

# IMPORTANT:
# Required so that the MP2 density is written to the checkpoint
# and can later be used with:
#
#   cubegen Density=MP2
#   cubegen Potential=MP2
#
DENSITY="density=current"

CHARGE=0
MULTIPLICITY=1

# ============================================================
# OPTIMIZATION SETTINGS
#
# ONLY this XYZ file will be optimized.
#
# Every other *.xyz file in this directory will be treated
# as a fixed geometry and run as an MP2 single-point.
# ============================================================

OPT_XYZ="dcm.xyz"

OPT_JOB="opt Freq=NoRaman"

# ============================================================
# DIRECTORY SETTINGS
#
# Anchor everything to the location of this create.sh script.
# Therefore the script can be called from another directory
# without breaking relative paths.
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GAUSSIAN_DIR="${SCRIPT_DIR}/gaussian"

mkdir -p "$GAUSSIAN_DIR"

# ============================================================
# FIND XYZ FILES
# ============================================================

shopt -s nullglob

XYZ_FILES=(
    "$SCRIPT_DIR"/*.xyz
)

if (( ${#XYZ_FILES[@]} == 0 )); then
    echo "ERROR: No XYZ files found in:"
    echo "  $SCRIPT_DIR"
    exit 1
fi

# ============================================================
# CHECK THAT OPT_XYZ EXISTS
# ============================================================

if [[ ! -f "$SCRIPT_DIR/$OPT_XYZ" ]]; then
    echo "ERROR: Optimized reference XYZ not found:"
    echo "  $SCRIPT_DIR/$OPT_XYZ"
    exit 1
fi

# ============================================================
# HEADER
# ============================================================

echo
echo "============================================================"
echo "Gaussian input generation"
echo "============================================================"
echo
echo "Input directory : $SCRIPT_DIR"
echo "Output directory: $GAUSSIAN_DIR"
echo
echo "Method          : $METHOD"
echo "Density         : $DENSITY"
echo
echo "OPT structure   : $OPT_XYZ"
echo "OPT options     : $OPT_JOB"
echo
echo "All other XYZ files:"
echo "  fixed-geometry MP2 single point"
echo
echo "XYZ files found : ${#XYZ_FILES[@]}"
echo

printf '  %s\n' "${XYZ_FILES[@]##*/}"

echo
echo "============================================================"

# ============================================================
# GENERATE GAUSSIAN INPUTS
# ============================================================

for xyz_path in "${XYZ_FILES[@]}"; do

    xyz="$(basename "$xyz_path")"

    # --------------------------------------------------------
    # Remove .xyz extension
    #
    # dcm.xyz  -> dcm
    # dcm1.xyz -> dcm1
    # --------------------------------------------------------

    name="${xyz%.xyz}"

    com="${GAUSSIAN_DIR}/${name}.com"

    # Checkpoint name remains relative because gaussian.slurm
    # copies the calculation to scratch and then copies the
    # resulting .chk back into gaussian/.
    chk="${name}.chk"

    # --------------------------------------------------------
    # Decide whether optimization is required
    # --------------------------------------------------------

    if [[ "$xyz" == "$OPT_XYZ" ]]; then

        JOB_OPTION="$OPT_JOB"
        CALC_TYPE="OPT + Frequency"

    else

        JOB_OPTION=""
        CALC_TYPE="Single point"

    fi

    echo
    echo "------------------------------------------------------------"
    echo "XYZ         : $xyz"
    echo "Gaussian    : ${name}.com"
    echo "Calculation : $CALC_TYPE"
    echo "------------------------------------------------------------"

    # ========================================================
    # GAUSSIAN HEADER
    # ========================================================

    cat > "$com" << EOF
%nprocshared=${NPROC}
%mem=${MEM}
%chk=${chk}

# ${JOB_OPTION} ${METHOD} ${DENSITY} ${SCF}

${name}

${CHARGE} ${MULTIPLICITY}
EOF

    # ========================================================
    # COORDINATES
    #
    # XYZ format:
    #
    # line 1 = atom count
    # line 2 = comment
    # line 3+ = element X Y Z ...
    #
    # Only first four columns are retained.
    # ========================================================

    tail -n +3 "$xyz_path" | awk '
        NF >= 4 {
            printf "%-2s %18.10f %18.10f %18.10f\n",
                   $1, $2, $3, $4
        }
    ' >> "$com"

    # Gaussian terminating blank line
    echo "" >> "$com"

done

# ============================================================
# COPY WORKFLOW SCRIPTS INTO gaussian/
# ============================================================

echo
echo "============================================================"
echo "Copying Gaussian workflow scripts"
echo "============================================================"
echo

HELPER_SCRIPTS=(
    "submit.sh"
    "gaussian.slurm"
    "cube.sh"
)

for script in "${HELPER_SCRIPTS[@]}"; do

    source_file="${SCRIPT_DIR}/${script}"

    if [[ -f "$source_file" ]]; then

        cp -f \
            "$source_file" \
            "$GAUSSIAN_DIR/$script"

        chmod +x \
            "$GAUSSIAN_DIR/$script"

        echo "Copied: $script"

    else

        echo "WARNING: $script not found in:"
        echo "  $SCRIPT_DIR"

    fi

done

# ============================================================
# SUMMARY
# ============================================================

echo
echo "============================================================"
echo "Gaussian preparation complete"
echo "============================================================"
echo
echo "Optimization:"
echo "  $OPT_XYZ"
echo
echo "Route:"
echo "  # $OPT_JOB $METHOD $DENSITY $SCF"
echo
echo "All other XYZ files:"
echo "  # $METHOD $DENSITY $SCF"
echo
echo "Gaussian files:"
echo

for com in "$GAUSSIAN_DIR"/*.com; do
    echo "  $(basename "$com")"
done

echo
echo "Workflow scripts:"
echo

for script in "${HELPER_SCRIPTS[@]}"; do
    if [[ -f "$GAUSSIAN_DIR/$script" ]]; then
        echo "  $script"
    fi
done

echo
echo "Output directory:"
echo "  $GAUSSIAN_DIR"
echo
echo "============================================================"
