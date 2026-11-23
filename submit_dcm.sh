#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# MDCM DCM WORKFLOW SUBMISSION
#
# Edit these booleans to choose which stages to submit.
#
# Examples:
#
#   Everything:
#       RUN_STEP0=true
#       RUN_STEP1=true
#       RUN_STEP2=true
#       RUN_STEP3=true
#
#   Step 2 only:
#       false false true false
#
#   Step 3 only:
#       false false false true
#
# Command-line shortcuts are also available:
#
#   ./submit_dcm.sh --only-step2
#   ./submit_dcm.sh --only-step3
#   ./submit_dcm.sh --dry-run
#
# ============================================================


# ============================================================
# USER SETTINGS
# ============================================================

RUN_STEP0=true
RUN_STEP1=true
RUN_STEP2=true
RUN_STEP3=true


# Step-3 directories to submit.
#
# All Lebedev variants:
STEP3_VARIANTS=(
    ml14
    ml26
    ml38
    ml50
    sl14
    sl26
    sl38
    sl50
)


# ============================================================
# WAIT TIMES
#
# These only matter when consecutive stages are enabled.
#
# Step 0 runs directly and blocks.
# Steps 1/2/3 submit Slurm jobs, so these waits are only
# practical delays, NOT strict dependency guarantees.
# ============================================================

WAIT_AFTER_STEP0=60
WAIT_AFTER_STEP1=3600
WAIT_AFTER_STEP2=10800


# ============================================================
# PATHS
# ============================================================

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RUN_ROOT="${ROOT}/run"
MOL="dcm"

MOL_ROOT="${RUN_ROOT}/${MOL}"


STEP0_SCRIPT="0-prepare-resp-lebedev.sh"
STEP1_SCRIPT="1-mtp-fit-l5.sh"
STEP2_SCRIPT="2-atom-fit.sh"
STEP3_SCRIPT="3-mol-fit.sh"


DRY_RUN=false


# ============================================================
# FUNCTIONS
# ============================================================

die()
{
    echo
    echo "ERROR: $*" >&2
    echo
    exit 1
}


is_true()
{
    [[ "$1" == true ]]
}


show_status()
{
    if is_true "$1"; then
        echo "RUN"
    else
        echo "SKIP"
    fi
}


wait_if_needed()
{
    local seconds="$1"
    local reason="$2"

    if is_true "$DRY_RUN"; then

        echo
        echo "DRY RUN: would wait ${seconds}s"
        echo "Reason: $reason"

    elif (( seconds > 0 )); then

        echo
        echo "Waiting ${seconds}s"
        echo "Reason: $reason"
        echo

        sleep "$seconds"

    fi
}


submit_job()
{
    local dir="$1"
    local script="$2"
    local label="$3"

    [[ -d "$dir" ]] || die "Missing directory: $dir"
    [[ -f "$dir/$script" ]] || die "Missing script: $dir/$script"

    echo
    echo "------------------------------------------------------------"
    echo "$label"
    echo "Directory:"
    echo "  $dir"
    echo
    echo "Script:"
    echo "  $script"
    echo "------------------------------------------------------------"

    if is_true "$DRY_RUN"; then

        echo "DRY RUN:"
        echo "  cd \"$dir\" && sbatch \"$script\""

    else

        (
            cd "$dir"
            sbatch "$script"
        )

    fi
}


run_step0()
{
    local dir="$1"

    [[ -d "$dir" ]] || die "Missing Step-0 directory: $dir"
    [[ -f "$dir/$STEP0_SCRIPT" ]] || \
        die "Missing $dir/$STEP0_SCRIPT"

    echo
    echo "------------------------------------------------------------"
    echo "STEP 0 : RESP / LEBEDEV"
    echo "Directory:"
    echo "  $dir"
    echo "------------------------------------------------------------"

    if is_true "$DRY_RUN"; then

        echo "DRY RUN:"
        echo "  cd \"$dir\" && bash \"$STEP0_SCRIPT\""

    else

        (
            cd "$dir"
            bash "$STEP0_SCRIPT"
        )

    fi
}


# ============================================================
# COMMAND-LINE OPTIONS
# ============================================================

while (( $# > 0 )); do

    case "$1" in

        --only-step0)

            RUN_STEP0=true
            RUN_STEP1=false
            RUN_STEP2=false
            RUN_STEP3=false

            shift
            ;;


        --only-step1)

            RUN_STEP0=false
            RUN_STEP1=true
            RUN_STEP2=false
            RUN_STEP3=false

            shift
            ;;


        --only-step2)

            RUN_STEP0=false
            RUN_STEP1=false
            RUN_STEP2=true
            RUN_STEP3=false

            shift
            ;;


        --only-step3)

            RUN_STEP0=false
            RUN_STEP1=false
            RUN_STEP2=false
            RUN_STEP3=true

            shift
            ;;


        --skip-step0)

            RUN_STEP0=false
            shift
            ;;


        --skip-step1)

            RUN_STEP1=false
            shift
            ;;


        --skip-step2)

            RUN_STEP2=false
            shift
            ;;


        --skip-step3)

            RUN_STEP3=false
            shift
            ;;


        --dry-run)

            DRY_RUN=true
            shift
            ;;


        -h|--help)

            echo
            echo "Usage:"
            echo
            echo "  ./submit_dcm.sh"
            echo
            echo "  ./submit_dcm.sh --only-step0"
            echo "  ./submit_dcm.sh --only-step1"
            echo "  ./submit_dcm.sh --only-step2"
            echo "  ./submit_dcm.sh --only-step3"
            echo
            echo "  ./submit_dcm.sh --skip-step0"
            echo "  ./submit_dcm.sh --skip-step1"
            echo "  ./submit_dcm.sh --skip-step2"
            echo "  ./submit_dcm.sh --skip-step3"
            echo
            echo "  ./submit_dcm.sh --dry-run"
            echo

            exit 0
            ;;


        *)

            die "Unknown option: $1"
            ;;

    esac

done


# ============================================================
# PRECHECK
# ============================================================

if [[ ! -d "$MOL_ROOT" ]]; then

    echo
    echo "============================================================"
    echo " ERROR: DCM WORKFLOW HAS NOT BEEN CREATED"
    echo "============================================================"
    echo
    echo "Missing:"
    echo
    echo "  $MOL_ROOT"
    echo
    echo "Run:"
    echo
    echo "  ./create.sh"
    echo
    echo "before using submit_dcm.sh."
    echo

    exit 1

fi


# ============================================================
# SUMMARY
# ============================================================

echo
echo "============================================================"
echo " MDCM DCM SUBMISSION"
echo "============================================================"
echo
echo "Run directory:"
echo
echo "  $MOL_ROOT"
echo
echo "Stages:"
echo
echo "  Step 0 : $(show_status "$RUN_STEP0")"
echo "  Step 1 : $(show_status "$RUN_STEP1")"
echo "  Step 2 : $(show_status "$RUN_STEP2")"
echo "  Step 3 : $(show_status "$RUN_STEP3")"
echo

if is_true "$RUN_STEP3"; then

    echo "Step-3 variants:"
    printf '  %s\n' "${STEP3_VARIANTS[@]}"
    echo

fi

if is_true "$DRY_RUN"; then

    echo "Mode:"
    echo
    echo "  DRY RUN"
    echo

fi

echo "============================================================"


# ============================================================
# STEP 0
# ============================================================

if is_true "$RUN_STEP0"; then

    run_step0 \
        "$MOL_ROOT/0-resp-lebedev"

    if is_true "$RUN_STEP1"; then

        wait_if_needed \
            "$WAIT_AFTER_STEP0" \
            "Step 0 -> Step 1"

    fi

else

    echo
    echo "Skipping Step 0"

fi


# ============================================================
# STEP 1
# ============================================================

if is_true "$RUN_STEP1"; then

    submit_job \
        "$MOL_ROOT/1-mtp-fit" \
        "$STEP1_SCRIPT" \
        "STEP 1 : MTP FIT"

    if is_true "$RUN_STEP2"; then

        wait_if_needed \
            "$WAIT_AFTER_STEP1" \
            "Step 1 -> Step 2"

    fi

else

    echo
    echo "Skipping Step 1"

fi


# ============================================================
# STEP 2
# ============================================================

if is_true "$RUN_STEP2"; then

    submit_job \
        "$MOL_ROOT/2-fit-atoms" \
        "$STEP2_SCRIPT" \
        "STEP 2 : ATOMIC MDCM FIT"

    if is_true "$RUN_STEP3"; then

        wait_if_needed \
            "$WAIT_AFTER_STEP2" \
            "Step 2 -> Step 3"

    fi

else

    echo
    echo "Skipping Step 2"

fi


# ============================================================
# STEP 3
# ============================================================

if is_true "$RUN_STEP3"; then

    echo
    echo "============================================================"
    echo " STEP 3 : MOLECULAR MDCM FIT"
    echo "============================================================"

    for variant in "${STEP3_VARIANTS[@]}"; do

        submit_job \
            "$MOL_ROOT/3-fit-molecule/$variant" \
            "$STEP3_SCRIPT" \
            "STEP 3 : $variant"

    done

else

    echo
    echo "Skipping Step 3"

fi


# ============================================================
# END
# ============================================================

echo
echo "============================================================"
echo " SUBMISSION SCRIPT FINISHED"
echo "============================================================"
echo
echo "Step 0 : $(show_status "$RUN_STEP0")"
echo "Step 1 : $(show_status "$RUN_STEP1")"
echo "Step 2 : $(show_status "$RUN_STEP2")"
echo "Step 3 : $(show_status "$RUN_STEP3")"
echo
echo "Check queue:"
echo
echo "  squeue -u \$USER"
echo
