#!/bin/bash

# ============================================================
# Convert all Gaussian checkpoint files:
#
#   *.chk
#       -> *.fchk
#       -> *_dens.cube
#       -> *_esp.cube
#
# Density and ESP generated using MP2 density.
# ============================================================

set -Eeuo pipefail

# ============================================================
# Gaussian installation
# ============================================================

g16root=/cluster/software/g16-c.01

FORMCHK="$g16root/g16/formchk"
CUBEGEN="$g16root/g16/cubegen"

# ============================================================
# Check Gaussian executables
# ============================================================

if [[ ! -x "$FORMCHK" ]]; then
    echo "ERROR: formchk not found:"
    echo "$FORMCHK"
    exit 1
fi

if [[ ! -x "$CUBEGEN" ]]; then
    echo "ERROR: cubegen not found:"
    echo "$CUBEGEN"
    exit 1
fi

# ============================================================
# Find checkpoint files
# ============================================================

shopt -s nullglob
chk_files=( *.chk )

if (( ${#chk_files[@]} == 0 )); then
    echo "No .chk files found in:"
    echo "$(pwd)"
    exit 0
fi

echo "=============================================="
echo "Gaussian cube generation"
echo "=============================================="
echo "Directory : $(pwd)"
echo "Gaussian  : $g16root"
echo "CHK files : ${#chk_files[@]}"
echo
printf '  %s\n' "${chk_files[@]}"
echo "=============================================="
echo

# ============================================================
# Process every checkpoint
# ============================================================

for chk in "${chk_files[@]}"; do

    base="${chk%.chk}"

    fchk="${base}.fchk"
    dens="${base}_dens.cube"
    esp="${base}_esp.cube"

    echo
    echo "=============================================="
    echo "Processing: $base"
    echo "=============================================="

    # --------------------------------------------------------
    # CHK -> FCHK
    # --------------------------------------------------------

    echo
    echo "[1/3] CHK -> FCHK"
    echo "$chk -> $fchk"

    "$FORMCHK" "$chk" "$fchk"

    if [[ ! -s "$fchk" ]]; then
        echo "ERROR: Failed to generate $fchk"
        exit 1
    fi

    # --------------------------------------------------------
    # MP2 electron density
    # --------------------------------------------------------

    echo
    echo "[2/3] Generating MP2 density cube"
    echo "$dens"

    "$CUBEGEN" \
        0 \
        Density=MP2 \
        "$fchk" \
        "$dens" \
        -2 \
        h

    if [[ ! -s "$dens" ]]; then
        echo "ERROR: Failed to generate $dens"
        exit 1
    fi

    # --------------------------------------------------------
    # MP2 electrostatic potential
    # --------------------------------------------------------

    echo
    echo "[3/3] Generating MP2 ESP cube"
    echo "$esp"

    "$CUBEGEN" \
        0 \
        Potential=MP2 \
        "$fchk" \
        "$esp" \
        -2 \
        h

    if [[ ! -s "$esp" ]]; then
        echo "ERROR: Failed to generate $esp"
        exit 1
    fi

    echo
    echo "Finished: $base"

done

echo
echo "=============================================="
echo "ALL CUBE FILES GENERATED"
echo "=============================================="

echo
ls -lh *.fchk *_dens.cube *_esp.cube
