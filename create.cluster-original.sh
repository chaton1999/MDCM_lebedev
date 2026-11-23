#!/usr/bin/env bash

set -Eeuo pipefail


# ============================================================
# MDCM WORKFLOW PREPARATION
#
# Creates the complete workflow for ONE molecule:
#
#   0-resp-lebedev/
#       0-prepare-resp-lebedev.sh
#
#   1-mtp-fit/
#
#   2-fit-atoms/
#
#   3-fit-molecule/
#       ml14/ml26/ml38/ml50 and sl14/sl26/sl38/sl50 if LEBEDEV=true
#       m1...m6 and s1...s6 if LEBEDEV=false
#
#   4-analysis/
#       same variant names as Step 3
#
#   5-charmm-files/
#
#
# IMPORTANT DESIGN:
#
#   The templates are the source of truth for:
#
#       NFIT
#       NTRY
#       MAXATMCHG
#       optimizer flags
#       -greedy
#       -respgrid
#       -sym
#       -gnes
#       SLURM settings
#       etc.
#
#   create.sh only changes:
#
#       paths
#       NATOM in Step 2
#       MINCHG in Step 3
#       MAXCHG in Step 3
#
#
# Derived automatically:
#
#   NATOM = highest atom index in frames.txt
#
#   Step 3:
#
#       MINCHG = NATOM
#       MAXCHG = 4 * NATOM
#
#
# NATOM is additionally checked against the atom count
# contained in e_opt.cube.
#
# ============================================================



# ============================================================
# USER SETTINGS
# ============================================================


# ------------------------------------------------------------
# Molecule name
# ------------------------------------------------------------

MOL_NAME="a"


# ------------------------------------------------------------
# Main run directory
# ------------------------------------------------------------

RUN_PATH="/cluster/home/chaton/MDCM-project-pantelis/organic_molecules/dna_multilebedev"


# ------------------------------------------------------------
# Reference directory
#
# Must point to:
#
#   ref/<molecule>/single
#
# Example:
#
#   /cluster/home/chaton/MDCM-project-pantelis/organic_molecules/ref/4_dcm/single
#
# ------------------------------------------------------------

REF_PATH="/cluster/home/chaton/MDCM-project-pantelis/organic_molecules/ref/a/single"


# ------------------------------------------------------------
# Absolute frames.txt path
#
# Example:
#
#   /cluster/home/chaton/MDCM-project-pantelis/organic_molecules/ref/c/frames.txt
#
# create_all.sh changes this automatically for each molecule.
# ------------------------------------------------------------

FRAMEFILE="/cluster/home/chaton/MDCM-project-pantelis/organic_molecules/ref/a/frames.txt"


# ------------------------------------------------------------
# Binaries / utilities
# ------------------------------------------------------------

BIN_PATH="/cluster/home/chaton/MDCM-project-pantelis/organic_molecules/bin_sym"


# ------------------------------------------------------------
# Templates
# ------------------------------------------------------------

TEMPLATE_PATH="/cluster/home/chaton/MDCM-project-pantelis/organic_molecules/templates"


# ------------------------------------------------------------
# Number of grid levels
#
# Produces:
#
#   m1 ... m6
#   s1 ... s6
#
# ------------------------------------------------------------

NGRID=6


# ------------------------------------------------------------
# Switch the Step-3 grid selection:
#   true  -> ml14/ml26/ml38/ml50, sl14/sl26/sl38/sl50
#   false -> m1..m6 and s1..s6 (original density-based grid)
# Keep this as an assignment to support existing create_all.sh scripts.
# ------------------------------------------------------------

LEBEDEV=true

# Step 0 always prepares these four independent Lebedev references.
LEBEDEV_GRIDS=(14 26 38 50)

case "$LEBEDEV" in
    true|false) ;;
    *) echo "ERROR: LEBEDEV must be true or false" >&2; exit 1 ;;
esac



# ============================================================
# DERIVED PATHS
# ============================================================

ROOTDIR="$RUN_PATH/$MOL_NAME"

STEP0="$ROOTDIR/0-resp-lebedev"
STEP1="$ROOTDIR/1-mtp-fit"
STEP2="$ROOTDIR/2-fit-atoms"
STEP3="$ROOTDIR/3-fit-molecule"
STEP4="$ROOTDIR/4-analysis"
STEP5="$ROOTDIR/5-charmm-files"


# In Lebedev mode each Step-3 directory has its own reference path:
#   $REF_PATH/resp_lebedev_14, _26, _38, _50
# The original REF_PATH is retained for Steps 1/2 and false mode.
RESP_REFDIR="$REF_PATH"



# ============================================================
# BASIC CHECKS
# ============================================================

if [[ ! -d "$REF_PATH" ]]; then

    echo
    echo "ERROR: Reference directory does not exist:"
    echo
    echo "  $REF_PATH"
    echo

    exit 1

fi


if [[ ! -f "$FRAMEFILE" ]]; then

    echo
    echo "ERROR: frames.txt does not exist:"
    echo
    echo "  $FRAMEFILE"
    echo

    exit 1

fi


if [[ ! -d "$BIN_PATH" ]]; then

    echo
    echo "ERROR: Binary directory does not exist:"
    echo
    echo "  $BIN_PATH"
    echo

    exit 1

fi


if [[ ! -d "$TEMPLATE_PATH" ]]; then

    echo
    echo "ERROR: Template directory does not exist:"
    echo
    echo "  $TEMPLATE_PATH"
    echo

    exit 1

fi



# ============================================================
# CHECK REFERENCE CUBES
# ============================================================

for FILE in \
    "$REF_PATH/e_opt.cube" \
    "$REF_PATH/d_opt.cube"
do

    if [[ ! -f "$FILE" ]]; then

        echo
        echo "ERROR: Required reference cube is missing:"
        echo
        echo "  $FILE"
        echo

        exit 1

    fi

done



# ============================================================
# DETERMINE NATOM FROM frames.txt
#
# frames.txt format:
#
#   MOLECULE_NAME
#   4    1    2    BO
#   5    3    7    BO
#   ...
#
# We look at the first three columns of all numeric lines and
# take the largest atom index.
#
# Example acetone:
#
#   4  1  2
#   5  3  7
#   6  3  1
#   8  2  9
#  10  2  1
#
# gives:
#
#   NATOM=10
#
# ============================================================

NATOM=$(
    awk '
        $1 ~ /^[0-9]+$/ {

            for (i = 1; i <= 3; i++) {

                if ($i ~ /^[0-9]+$/ && $i > max) {
                    max = $i
                }

            }

        }

        END {

            if (max > 0) {
                print max
            }

        }
    ' "$FRAMEFILE"
)


if [[ -z "$NATOM" ]]; then

    echo
    echo "ERROR: Could not determine NATOM from:"
    echo
    echo "  $FRAMEFILE"
    echo

    exit 1

fi



# ============================================================
# VERIFY NATOM AGAINST e_opt.cube
#
# Gaussian cube:
#
# line 3, column 1 = number of atoms
#
# abs() is used because some cube variants may use a negative
# atom count for additional orbital information.
# ============================================================

CUBE_NATOM=$(
    awk '
        NR == 3 {

            n = $1

            if (n < 0) {
                n = -n
            }

            print n
            exit
        }
    ' "$REF_PATH/e_opt.cube"
)


if [[ -z "$CUBE_NATOM" ]]; then

    echo
    echo "ERROR: Could not determine atom count from:"
    echo
    echo "  $REF_PATH/e_opt.cube"
    echo

    exit 1

fi


if [[ "$NATOM" -ne "$CUBE_NATOM" ]]; then

    echo
    echo "============================================================"
    echo " ERROR: ATOM COUNT MISMATCH"
    echo "============================================================"
    echo
    echo "frames.txt gives:"
    echo
    echo "  NATOM = $NATOM"
    echo
    echo "e_opt.cube gives:"
    echo
    echo "  NATOM = $CUBE_NATOM"
    echo
    echo "Frame file:"
    echo
    echo "  $FRAMEFILE"
    echo
    echo "Cube:"
    echo
    echo "  $REF_PATH/e_opt.cube"
    echo

    exit 1

fi



# ============================================================
# STEP-3 CHARGE RANGE
#
# User-defined rule:
#
#   MINCHG = NATOM
#
#   MAXCHG = 4 * NATOM
#
# ============================================================

STEP3_MINCHG="$NATOM"

STEP3_MAXCHG=$((4 * NATOM))



# ============================================================
# CHECK TEMPLATE STRUCTURE
# ============================================================

REQUIRED_TEMPLATE_DIRS=(

    "$TEMPLATE_PATH/1-mtp-fit"

    "$TEMPLATE_PATH/2-fit-atoms"

    "$TEMPLATE_PATH/3-fit-molecule/m"
    "$TEMPLATE_PATH/3-fit-molecule/s"

    "$TEMPLATE_PATH/4-analysis/m"
    "$TEMPLATE_PATH/4-analysis/s"

    "$TEMPLATE_PATH/5-charmm-files"

)


for DIR in "${REQUIRED_TEMPLATE_DIRS[@]}"; do

    if [[ ! -d "$DIR" ]]; then

        echo
        echo "ERROR: Required template directory is missing:"
        echo
        echo "  $DIR"
        echo

        exit 1

    fi

done



# ============================================================
# DISPLAY CONFIGURATION
# ============================================================

echo
echo "============================================================"
echo " MDCM WORKFLOW PREPARATION"
echo "============================================================"
echo
echo "Molecule:"
echo "  $MOL_NAME"
echo
echo "Run directory:"
echo "  $ROOTDIR"
echo
echo "Reference directory:"
echo "  $REF_PATH"
echo
echo "Step-0 Lebedev reference directories:"
for GRID_SIZE in "${LEBEDEV_GRIDS[@]}"; do
    echo "  $REF_PATH/resp_lebedev_${GRID_SIZE}"
done
echo "Step-3 Lebedev mode: $LEBEDEV"
echo
echo "Frame file:"
echo "  $FRAMEFILE"
echo
echo "Binary directory:"
echo "  $BIN_PATH"
echo
echo "Template directory:"
echo "  $TEMPLATE_PATH"
echo
echo "Grid levels:"
echo "  $NGRID"
echo
echo "Lebedev grids: ${LEBEDEV_GRIDS[*]}"
echo
echo "Derived molecule size:"
echo "  NATOM = $NATOM"
echo
echo "Step-3 molecular charge range:"
echo "  MINCHG = $STEP3_MINCHG"
echo "  MAXCHG = $STEP3_MAXCHG"
echo
echo "Template policy:"
echo "  Optimizer / fitting / SLURM options come from templates."
echo "============================================================"
echo



# ============================================================
# CREATE RUN CONTAINER
# ============================================================

mkdir -p "$RUN_PATH"



# ============================================================
# WARN IF OTHER MOLECULES ARE ALREADY PRESENT
# ============================================================

mapfile -t EXISTING_RUNS < <(

    find "$RUN_PATH" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -printf '%f\n' \
        | sort

)


if (( ${#EXISTING_RUNS[@]} > 0 )); then

    echo
    echo "============================================================"
    echo " RUN DIRECTORY ALREADY CONTAINS MOLECULES"
    echo "============================================================"
    echo

    for DIR in "${EXISTING_RUNS[@]}"; do
        echo "  - $DIR"
    done

    echo
    echo "New molecule:"
    echo
    echo "  $MOL_NAME"
    echo
    echo "will be created as:"
    echo
    echo "  $ROOTDIR"
    echo

    read -r -p "Do you want to continue? [y/N]: " ANSWER

    case "$ANSWER" in

        y|Y|yes|YES|Yes)
            echo
            echo "Continuing..."
            ;;

        *)
            echo
            echo "Preparation cancelled."
            echo
            exit 0
            ;;

    esac

fi



# ============================================================
# PROTECT EXISTING MOLECULE DIRECTORY
# ============================================================

if [[ -d "$ROOTDIR" ]] && \
   [[ -n "$(find "$ROOTDIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]
then

    echo
    echo "============================================================"
    echo " ERROR: MOLECULE RUN ALREADY EXISTS"
    echo "============================================================"
    echo
    echo "Directory:"
    echo
    echo "  $ROOTDIR"
    echo
    echo "Nothing has been overwritten."
    echo

    exit 1

fi



# ============================================================
# FUNCTIONS
# ============================================================


# ------------------------------------------------------------
# Copy template directory exactly
# ------------------------------------------------------------

copy_template()
{
    local SRC="$1"
    local DST="$2"

    mkdir -p "$DST"

    cp -a "$SRC"/. "$DST"/
}



# ------------------------------------------------------------
# Configure path variables in ONE shell script.
#
# Scientific settings are NOT changed here.
# ------------------------------------------------------------

configure_script()
{
    local FILE="$1"
    local WORKDIR_NEW="$2"
    local MODE="${3:-}"
    local GRID="${4:-}"
    local REFDIR_NEW="${5:-$REF_PATH}"


    # --------------------------------------------------------
    # Placeholder-based templates
    # --------------------------------------------------------

    sed -i \
        -e "s|__ROOTDIR__|$ROOTDIR|g" \
        -e "s|__WORKDIR__|$WORKDIR_NEW|g" \
        -e "s|__BINDIR__|$BIN_PATH|g" \
        -e "s|__REFDIR__|$REFDIR_NEW|g" \
        -e "s|__RESP_REFDIR__|$REFDIR_NEW|g" \
        -e "s|__FRAMEFILE__|$FRAMEFILE|g" \
        "$FILE"


    if [[ -n "$MODE" ]]; then

        sed -i \
            "s|__MODE__|$MODE|g" \
            "$FILE"

    fi


    if [[ -n "$GRID" ]]; then

        sed -i \
            "s|__GRID_LEVEL__|$GRID|g" \
            "$FILE"

    fi


    # --------------------------------------------------------
    # Existing variable-style templates
    # --------------------------------------------------------


    # ROOTDIR=

    if grep -Eq '^[[:space:]]*ROOTDIR=' "$FILE"; then

        sed -i -E \
            "s|^[[:space:]]*ROOTDIR=.*|ROOTDIR=\"$ROOTDIR\"|" \
            "$FILE"

    fi


    # Some templates, especially Step 2, use ROOT=

    if grep -Eq '^[[:space:]]*ROOT=' "$FILE"; then

        sed -i -E \
            "s|^[[:space:]]*ROOT=.*|ROOT=\"$ROOTDIR\"|" \
            "$FILE"

    fi


    # WORKDIR=

    if grep -Eq '^[[:space:]]*WORKDIR=' "$FILE"; then

        sed -i -E \
            "s|^[[:space:]]*WORKDIR=.*|WORKDIR=\"$WORKDIR_NEW\"|" \
            "$FILE"

    fi


    # BINDIR=

    if grep -Eq '^[[:space:]]*BINDIR=' "$FILE"; then

        sed -i -E \
            "s|^[[:space:]]*BINDIR=.*|BINDIR=\"$BIN_PATH\"|" \
            "$FILE"

    fi


    # REFDIR=

    if grep -Eq '^[[:space:]]*REFDIR=' "$FILE"; then

        sed -i -E \
            "s|^[[:space:]]*REFDIR=.*|REFDIR=\"$REFDIR_NEW\"|" \
            "$FILE"

    fi


    # Some Step-3 templates use RESP_REFDIR rather than REFDIR.
    if grep -Eq '^[[:space:]]*RESP_REFDIR=' "$FILE"; then
        sed -i -E \
            "s|^[[:space:]]*RESP_REFDIR=.*|RESP_REFDIR=\"$REFDIR_NEW\"|" \
            "$FILE"
    fi

    # FRAMEFILE=
    #
    # Always use the absolute molecule-specific frame file.

    if grep -Eq '^[[:space:]]*FRAMEFILE=' "$FILE"; then

        sed -i -E \
            "s|^[[:space:]]*FRAMEFILE=.*|FRAMEFILE=\"$FRAMEFILE\"|" \
            "$FILE"

    fi


    chmod +x "$FILE"
}



# ------------------------------------------------------------
# Configure all shell scripts inside directory
# ------------------------------------------------------------

configure_directory()
{
    local DIR="$1"
    local WORKDIR_NEW="$2"
    local MODE="${3:-}"
    local GRID="${4:-}"
    local REFDIR_NEW="${5:-$REF_PATH}"


    while IFS= read -r -d '' SCRIPT; do

        echo "Configuring:"
        echo "  $SCRIPT"

        configure_script \
            "$SCRIPT" \
            "$WORKDIR_NEW" \
            "$MODE" \
            "$GRID" \
            "$REFDIR_NEW"

    done < <(

        find "$DIR" \
            -type f \
            -name "*.sh" \
            -print0

    )
}



# ------------------------------------------------------------
# Set NATOM in Step 2
#
# At least one Step-2 shell script MUST contain:
#
#   NATOM=...
#
# ------------------------------------------------------------

configure_step2_natom()
{
    local DIR="$1"
    local FOUND=0


    while IFS= read -r -d '' SCRIPT; do

        if grep -Eq '^[[:space:]]*NATOM=' "$SCRIPT"; then

            sed -i -E \
                "s|^([[:space:]]*NATOM=)[^[:space:]#]+|\1${NATOM}|" \
                "$SCRIPT"

            echo "Step 2 NATOM:"
            echo "  $SCRIPT"
            echo "  NATOM=$NATOM"

            FOUND=1

        fi

    done < <(

        find "$DIR" \
            -type f \
            -name "*.sh" \
            -print0

    )


    if (( FOUND == 0 )); then

        echo
        echo "ERROR: No NATOM= variable found in Step-2 templates."
        echo
        echo "Expected somewhere under:"
        echo
        echo "  $DIR"
        echo

        exit 1

    fi
}



# ------------------------------------------------------------
# Set Step-3 MINCHG and MAXCHG
#
#   MINCHG = NATOM
#   MAXCHG = 4*NATOM
#
# MAXATMCHG is deliberately NOT changed.
# ------------------------------------------------------------

configure_step3_charge_range()
{
    local DIR="$1"

    local FOUND_MIN=0
    local FOUND_MAX=0


    while IFS= read -r -d '' SCRIPT; do


        # Update only top-level numeric assignments, not MINCHG=${NCHG}
        # embedded in the Step-3 job-generation heredoc.
        if grep -Eq '^[[:space:]]*MINCHG=[0-9]+([[:space:]]|$)' "$SCRIPT"; then

            sed -i -E \
                "s#^([[:space:]]*MINCHG=)[0-9]+([[:space:]]|$)#\1${STEP3_MINCHG}\2#" \
                "$SCRIPT"

            FOUND_MIN=1

        fi


        # Keep MAXCHG=${NCHG} in the heredoc intact as well.
        if grep -Eq '^[[:space:]]*MAXCHG=[0-9]+([[:space:]]|$)' "$SCRIPT"; then

            sed -i -E \
                "s#^([[:space:]]*MAXCHG=)[0-9]+([[:space:]]|$)#\1${STEP3_MAXCHG}\2#" \
                "$SCRIPT"

            FOUND_MAX=1

        fi


    done < <(

        find "$DIR" \
            -type f \
            -name "*.sh" \
            -print0

    )


    if (( FOUND_MIN == 0 )); then

        echo
        echo "ERROR: No MINCHG= found under:"
        echo
        echo "  $DIR"
        echo

        exit 1

    fi


    if (( FOUND_MAX == 0 )); then

        echo
        echo "ERROR: No MAXCHG= found under:"
        echo
        echo "  $DIR"
        echo

        exit 1

    fi

    # Fail early if a template accidentally loses the per-job charge bindings.
    # Every generated molecular Slurm job must use its own NCHG value.
    while IFS= read -r -d '' SCRIPT; do
        if ! grep -Fq 'MINCHG=${NCHG}' "$SCRIPT" || \
           ! grep -Fq 'MAXCHG=${NCHG}' "$SCRIPT"; then
            echo "ERROR: Per-job charge assignments are missing in $SCRIPT"
            echo 'Expected MINCHG=${NCHG} and MAXCHG=${NCHG} inside the heredoc.'
            exit 1
        fi
    done < <(find "$DIR" -type f -name '3-mol-fit.sh' -print0)


    echo "Step 3 charge range:"
    echo "  $DIR"
    echo "  MINCHG=$STEP3_MINCHG"
    echo "  MAXCHG=$STEP3_MAXCHG"
}



# ------------------------------------------------------------
# Step 0: build all independent Lebedev masks in one invocation.
# Inputs remain under REF_PATH; nothing is written to the source cubes.
# ------------------------------------------------------------

create_step0_script()
{
    mkdir -p "$STEP0"
    local SCRIPT="$STEP0/0-prepare-resp-lebedev.sh"

    cat > "$SCRIPT" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail

# CREATED BY create.sh: all four ESP-mask reference sets.
BINDIR="$BIN_PATH"
REFDIR="$REF_PATH"
GRID_SCRIPT="\${BINDIR}/make_resp_lebedev_grid.py"
LEBEDEV_GRIDS=(${LEBEDEV_GRIDS[*]})

[[ -f "\$GRID_SCRIPT" ]] || { echo "Missing grid generator: \$GRID_SCRIPT" >&2; exit 1; }
[[ -d "\$REFDIR" ]] || { echo "Missing input cubes: \$REFDIR" >&2; exit 1; }

shopt -s nullglob
ESP_FILES=( "\$REFDIR"/e_*.cube )
(( \${#ESP_FILES[@]} > 0 )) || { echo "No e_*.cube files in \$REFDIR" >&2; exit 1; }

# Preflight: fail before writing if any density cube is missing.
for ESP in "\${ESP_FILES[@]}"; do
    ESP_NAME="\$(basename "\$ESP")"
    DENS="\$REFDIR/d_\${ESP_NAME#e_}"
    [[ -f "\$DENS" ]] || { echo "Missing density: \$DENS" >&2; exit 1; }
done

for LEBEDEV_POINTS in "\${LEBEDEV_GRIDS[@]}"; do
    OUTDIR="\$REFDIR/resp_lebedev_\${LEBEDEV_POINTS}"
    mkdir -p "\$OUTDIR"

    echo
    echo "===== Lebedev-\$LEBEDEV_POINTS -> \$OUTDIR ====="

    for ESP in "\${ESP_FILES[@]}"; do
        ESP_NAME="\$(basename "\$ESP")"
        DENS_NAME="d_\${ESP_NAME#e_}"
        XYZ_NAME="\${ESP_NAME%.cube}_resp_lebedev_\${LEBEDEV_POINTS}.xyz"

        "\$GRID_SCRIPT" \
            --esp "\$ESP" \
            --density "\$REFDIR/\$DENS_NAME" \
            --out-esp "\$OUTDIR/\$ESP_NAME" \
            --out-density "\$OUTDIR/\$DENS_NAME" \
            --xyz "\$OUTDIR/\$XYZ_NAME" \
            --lebedev "\$LEBEDEV_POINTS"
    done
    echo "Completed Lebedev-\$LEBEDEV_POINTS"
done

echo "Step 0 complete: four independent reference directories."
EOF
    chmod +x "$SCRIPT"
}

# ============================================================
# CREATE MOLECULE ROOT
# ============================================================

mkdir -p "$ROOTDIR"



# ============================================================
# STEP 0
# ============================================================

echo
echo "============================================================"
echo " STEP 0 : RESP / LEBEDEV"
echo "============================================================"
echo

create_step0_script



# ============================================================
# STEP 1
#
# Copy template exactly, then only configure paths.
# ============================================================

echo
echo "============================================================"
echo " STEP 1 : MTP FIT"
echo "============================================================"
echo


copy_template \
    "$TEMPLATE_PATH/1-mtp-fit" \
    "$STEP1"


configure_directory \
    "$STEP1" \
    "$STEP1" \
    "" \
    "" \
    "$REF_PATH"



# ============================================================
# STEP 2
#
# Copy template.
#
# Template controls:
#
#   NFIT
#   NTRY
#   MAXCHG
#   -greedy
#   -sym
#   -gnes if desired
#   SLURM
#
# create.sh changes ONLY:
#
#   paths
#   NATOM
#
# ============================================================

echo
echo "============================================================"
echo " STEP 2 : ATOMIC MDCM FIT"
echo "============================================================"
echo


copy_template \
    "$TEMPLATE_PATH/2-fit-atoms" \
    "$STEP2"


configure_directory \
    "$STEP2" \
    "$STEP2" \
    "" \
    "" \
    "$REF_PATH"


configure_step2_natom \
    "$STEP2"



# ------------------------------------------------------------
# Activate the requested ESP-selection policy in Step-3 scripts.
# Do not change -sym, -gnes, NTRY, NFIT or SLURM options.
# ------------------------------------------------------------
configure_step3_grid_flag()
{
    local DIR="$1"
    local SCRIPT
    while IFS= read -r -d '' SCRIPT; do
        if [[ "$LEBEDEV" == true ]]; then
            sed -i 's/__RESPGRID_FLAG__/-respgrid/g' "$SCRIPT"
        else
            sed -i 's/__RESPGRID_FLAG__//g' "$SCRIPT"
            # Remove only real flag tokens, not comments.
            sed -i -E '/^[[:space:]]*#/!s/[[:space:]]+-respgrid([[:space:]\]|$)/\1/g' "$SCRIPT"
        fi
    done < <(find "$DIR" -type f -name '*.sh' -print0)

    if [[ "$LEBEDEV" == true ]]; then
        # Every Step-3 job generator must enable mask-based selection.
        local found=0
        while IFS= read -r -d '' SCRIPT; do
            if grep -v '^[[:space:]]*#' "$SCRIPT" | grep -Eq -- '(^|[[:space:]])-respgrid([[:space:]\]|$)'; then
                found=1
            fi
        done < <(find "$DIR" -type f -name '3-mol-fit.sh' -print0)
        if (( found == 0 )); then
            echo "ERROR: $DIR is missing -respgrid in its executable template." >&2
            echo "Add -respgrid to the relevant command in the m/s Step-3 template." >&2
            exit 1
        fi
    fi
}

# ------------------------------------------------------------
# Create matching Step-3/Step-4 variant directories.
# ------------------------------------------------------------
create_variant()
{
    local MODE="$1" DIRNAME="$2" GRID_LEVEL="$3" REF_FOR_FIT="$4"
    local FIT_DIR="$STEP3/$DIRNAME"
    local ANALYSIS_DIR="$STEP4/$DIRNAME"

    echo "Creating variant $DIRNAME -> $REF_FOR_FIT"
    copy_template "$TEMPLATE_PATH/3-fit-molecule/$MODE" "$FIT_DIR"
    configure_directory "$FIT_DIR" "$FIT_DIR" "$MODE" "$GRID_LEVEL" "$REF_FOR_FIT"
    configure_step3_charge_range "$FIT_DIR"
    configure_step3_grid_flag "$FIT_DIR"

    copy_template "$TEMPLATE_PATH/4-analysis/$MODE" "$ANALYSIS_DIR"
    configure_directory "$ANALYSIS_DIR" "$ANALYSIS_DIR" "$MODE" "$GRID_LEVEL" "$REF_FOR_FIT"

    # Analysis scripts that use explicit older variant names need template updates.
    if grep -REn '(3-fit-molecule/(m|s)[1-6](/|\b))' "$ANALYSIS_DIR" --include='*.sh' >/dev/null 2>&1; then
        echo "WARNING: Old Step-3 paths may be hardcoded in $ANALYSIS_DIR" >&2
    fi
}

# ============================================================
# STEP 3 + STEP 4: use matching directory names in both trees.
# ============================================================

echo "============================================================"
echo " STEP 3 / STEP 4 : MDCM FIT + ANALYSIS (LEBEDEV=$LEBEDEV)"
echo "============================================================"
mkdir -p "$STEP3" "$STEP4"

if [[ "$LEBEDEV" == true ]]; then
    for GRID_SIZE in "${LEBEDEV_GRIDS[@]}"; do
        # GRID_LEVEL remains 1 for mask selection; the angular rule is
        # selected by the separate resp_lebedev_<N> reference directory.
        REF_FOR_FIT="$REF_PATH/resp_lebedev_${GRID_SIZE}"
        create_variant m "ml${GRID_SIZE}" 1 "$REF_FOR_FIT"
        create_variant s "sl${GRID_SIZE}" 1 "$REF_FOR_FIT"
    done
else
    for ((grid=1; grid<=NGRID; grid++)); do
        create_variant m "m${grid}" "$grid" "$REF_PATH"
        create_variant s "s${grid}" "$grid" "$REF_PATH"
    done
fi

# ============================================================
# STEP 5
#
# Template copied unchanged except paths.
# ============================================================

echo
echo "============================================================"
echo " STEP 5 : CHARMM FILES"
echo "============================================================"
echo


copy_template \
    "$TEMPLATE_PATH/5-charmm-files" \
    "$STEP5"


configure_directory \
    "$STEP5" \
    "$STEP5" \
    "" \
    "" \
    "$REF_PATH"



# ============================================================
# FINAL SANITY CHECK
# ============================================================

echo
echo "============================================================"
echo " VERIFYING GENERATED MOLECULE PARAMETERS"
echo "============================================================"
echo


echo "Step 2:"
grep -R -n -E \
    '^[[:space:]]*NATOM=' \
    "$STEP2" \
    || true


echo
echo "Step 3:"
grep -R -n -E \
    '^[[:space:]]*(MINCHG|MAXCHG)=' \
    "$STEP3" \
    || true



# ============================================================
# FINAL SUMMARY
# ============================================================

echo
echo
echo "============================================================"
echo " MDCM WORKFLOW PREPARATION COMPLETE"
echo "============================================================"
echo
echo "Molecule:"
echo
echo "  $MOL_NAME"
echo
echo "Run root:"
echo
echo "  $ROOTDIR"
echo
echo "Reference:"
echo
echo "  $REF_PATH"
echo
echo "Frame file:"
echo
echo "  $FRAMEFILE"
echo
echo "Reference grids: ${LEBEDEV_GRIDS[*]}"
echo "Lebedev mode: $LEBEDEV"
echo "Original reference: $REF_PATH"
echo
echo "Derived molecule parameters:"
echo
echo "  NATOM        = $NATOM"
echo "  STEP3_MINCHG = $STEP3_MINCHG"
echo "  STEP3_MAXCHG = $STEP3_MAXCHG"
echo
echo "Created:"
echo
echo "  0-resp-lebedev/"
echo "  1-mtp-fit/"
echo "  2-fit-atoms/"
echo "  3-fit-molecule/ and 4-analysis/:"
if [[ "$LEBEDEV" == true ]]; then
    for GRID_SIZE in "${LEBEDEV_GRIDS[@]}"; do
        echo "      ml${GRID_SIZE}  sl${GRID_SIZE}"
    done
else
    echo "      m1..m${NGRID}  s1..s${NGRID}"
fi
echo "  5-charmm-files/"
echo
echo "Optimizer / fitting options were NOT rewritten."
echo "They come directly from the templates."
echo
echo "============================================================"
echo



# ============================================================
# DIRECTORY TREE
# ============================================================

if command -v tree >/dev/null 2>&1; then

    tree -L 3 "$ROOTDIR"

else

    find "$ROOTDIR" \
        -maxdepth 3 \
        -type d \
        | sort

fi


echo
echo "Done."
echo

