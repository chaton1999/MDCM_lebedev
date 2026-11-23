#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# USER SETTINGS
# ============================================================

# Input XYZ containing ONE molecule
DEFAULT_XYZ="dcm.xyz"

# If a filename is supplied on the command line, use it instead
XYZ="${1:-$DEFAULT_XYZ}"

# ============================================================
# MD SETTINGS
# ============================================================

TEMP=300        # K
TIME_PS=20      # ps
STEP_FS=0.5     # fs
DUMP_FS=10      # fs

GFN=2           # GFN2-xTB

# ============================================================
# CHECK INPUT
# ============================================================

if [[ ! -f "$XYZ" ]]; then
    echo "ERROR: XYZ file not found: $XYZ"
    exit 1
fi

# ============================================================
# OUTPUT DIRECTORY
# ============================================================

NAME=$(basename "$XYZ" .xyz)
OUTDIR="${NAME}_xtb_md"

mkdir -p "$OUTDIR"

cp "$XYZ" "$OUTDIR/input.xyz"

cd "$OUTDIR"

# ============================================================
# CREATE xTB MD INPUT
# ============================================================

cat > md.inp << EOF
\$md
   temp=${TEMP}
   time=${TIME_PS}
   dump=${DUMP_FS}
   step=${STEP_FS}
   velo=false
   nvt=true
   hmass=1
   shake=0
   sccacc=1.0
\$end
EOF

# ============================================================
# RUN xTB MD
# ============================================================

echo "=============================================="
echo " xTB molecular dynamics"
echo "=============================================="
echo "Structure   : $XYZ"
echo "Method      : GFN${GFN}-xTB"
echo "Temperature : ${TEMP} K"
echo "Time        : ${TIME_PS} ps"
echo "Timestep    : ${STEP_FS} fs"
echo "Dump        : ${DUMP_FS} fs"
echo "Output      : $OUTDIR"
echo "=============================================="

xtb input.xyz \
    --gfn ${GFN} \
    --input md.inp \
    --md \
    > xtb_md.log 2>&1

echo
echo "MD finished."
echo
echo "Trajectory : $(pwd)/xtb.trj"
echo "Log        : $(pwd)/xtb_md.log"
echo "Restart    : $(pwd)/mdrestart"
