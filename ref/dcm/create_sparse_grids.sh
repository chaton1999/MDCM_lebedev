#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# CREATE SPARSE CUBE GRIDS n1 ... n6
#
# Run from:
#
#   /cluster/home/chaton/MDCM-project-pantelis/organic_molecules/ref/4_dcm
#
# Expected:
#
#   ./fix_cube.pl
#   ./single/e_opt.cube
#   ./single/d_opt.cube
#   ./single/e_conf1.cube ...
#
# Output:
#
#   single/n1/
#   single/n2/
#   ...
#   single/n6/
#
# n1 = original grid
# n2 = every 2nd grid point along x,y,z
# ...
# n6 = every 6th grid point along x,y,z
# ============================================================

ROOT="$(pwd)"
FIX_CUBE="$ROOT/fix_cube.pl"
REFDIR="$ROOT/single"

NGRID=6

# ============================================================
# CHECKS
# ============================================================

[[ -f "$FIX_CUBE" ]] || {
    echo "ERROR: fix_cube.pl not found:"
    echo "  $FIX_CUBE"
    exit 1
}

[[ -d "$REFDIR" ]] || {
    echo "ERROR: single/ directory not found:"
    echo "  $REFDIR"
    exit 1
}

# Only take cubes directly inside single/.
# This avoids accidentally reading cubes from existing n1/n2/... directories.
mapfile -t CUBES < <(
    find "$REFDIR" \
        -maxdepth 1 \
        -type f \
        \( -name 'e_*.cube' -o -name 'd_*.cube' \) \
        | sort
)

if (( ${#CUBES[@]} == 0 )); then
    echo "ERROR: No e_*.cube or d_*.cube files found in:"
    echo "  $REFDIR"
    exit 1
fi

echo
echo "============================================================"
echo " CREATE SPARSE CUBE GRIDS"
echo "============================================================"
echo
echo "Reference directory:"
echo "  $REFDIR"
echo
echo "fix_cube.pl:"
echo "  $FIX_CUBE"
echo
echo "Cube files found:"
for cube in "${CUBES[@]}"; do
    echo "  - $(basename "$cube")"
done
echo

# ============================================================
# CREATE n1 ... n6
# ============================================================

for ((SKIP=1; SKIP<=NGRID; SKIP++)); do

    OUTDIR="$REFDIR/n${SKIP}"

    echo "------------------------------------------------------------"
    echo "Creating n${SKIP}"
    echo "skip = ${SKIP}"
    echo "output = $OUTDIR"
    echo "------------------------------------------------------------"

    mkdir -p "$OUTDIR"

    for INPUT in "${CUBES[@]}"; do

        NAME="$(basename "$INPUT")"
        OUTPUT="$OUTDIR/$NAME"

        echo "  $NAME"

        if (( SKIP == 1 )); then

            # n1 should be exactly the original grid.
            cp -f "$INPUT" "$OUTPUT"

        else

            # fix_cube.pl syntax:
            #
            #   perl fix_cube.pl SKIP INPUT.cube > OUTPUT.cube
            #
            perl "$FIX_CUBE" "$SKIP" "$INPUT" > "$OUTPUT"

        fi

        # Basic safety check
        if [[ ! -s "$OUTPUT" ]]; then
            echo "ERROR: Output cube is empty:"
            echo "  $OUTPUT"
            exit 1
        fi

    done

    echo "Completed n${SKIP}"
    echo

done

# ============================================================
# SUMMARY
# ============================================================

echo "============================================================"
echo " SPARSE GRID PREPARATION COMPLETE"
echo "============================================================"

for ((SKIP=1; SKIP<=NGRID; SKIP++)); do
    COUNT=$(
        find "$REFDIR/n${SKIP}" \
            -maxdepth 1 \
            -type f \
            -name '*.cube' \
            | wc -l
    )

    echo "  n${SKIP}: ${COUNT} cube files"
done

echo
echo "Done."
