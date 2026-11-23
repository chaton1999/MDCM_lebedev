#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="/cluster/home/chaton/MDCM-project-pantelis/MDCM_lebedev"

# CREATED BY create.sh: all four ESP-mask reference sets.
BINDIR="/cluster/home/chaton/MDCM-project-pantelis/MDCM_lebedev/bin_sym"
REFDIR="/cluster/home/chaton/MDCM-project-pantelis/MDCM_lebedev/ref/dcm/single"
GRID_SCRIPT="${BINDIR}/make_resp_lebedev_grid.py"
LEBEDEV_GRIDS=(14 26 38 50)

[[ -f "$GRID_SCRIPT" ]] || { echo "Missing grid generator: $GRID_SCRIPT" >&2; exit 1; }
[[ -d "$REFDIR" ]] || { echo "Missing input cubes: $REFDIR" >&2; exit 1; }

shopt -s nullglob
ESP_FILES=( "$REFDIR"/e_*.cube )
(( ${#ESP_FILES[@]} > 0 )) || { echo "No e_*.cube files in $REFDIR" >&2; exit 1; }

# Preflight: fail before writing if any density cube is missing.
for ESP in "${ESP_FILES[@]}"; do
    ESP_NAME="$(basename "$ESP")"
    DENS="$REFDIR/d_${ESP_NAME#e_}"
    [[ -f "$DENS" ]] || { echo "Missing density: $DENS" >&2; exit 1; }
done

for LEBEDEV_POINTS in "${LEBEDEV_GRIDS[@]}"; do
    OUTDIR="$REFDIR/resp_lebedev_${LEBEDEV_POINTS}"
    mkdir -p "$OUTDIR"

    echo
    echo "===== Lebedev-$LEBEDEV_POINTS -> $OUTDIR ====="

    for ESP in "${ESP_FILES[@]}"; do
        ESP_NAME="$(basename "$ESP")"
        DENS_NAME="d_${ESP_NAME#e_}"
        XYZ_NAME="${ESP_NAME%.cube}_resp_lebedev_${LEBEDEV_POINTS}.xyz"

        "$GRID_SCRIPT"             --esp "$ESP"             --density "$REFDIR/$DENS_NAME"             --out-esp "$OUTDIR/$ESP_NAME"             --out-density "$OUTDIR/$DENS_NAME"             --xyz "$OUTDIR/$XYZ_NAME"             --lebedev "$LEBEDEV_POINTS"
    done
    echo "Completed Lebedev-$LEBEDEV_POINTS"
done

echo "Step 0 complete: four independent reference directories."
