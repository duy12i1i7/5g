#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/scripts/lib/common.sh"

UI="Qtenv"
CONFIG="MinimalUlLight"
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --cmdenv)
            UI="Cmdenv"
            shift
            ;;
        --gui|--qtenv)
            UI="Qtenv"
            shift
            ;;
        --config)
            CONFIG="$2"
            shift 2
            ;;
        --)
            shift
            EXTRA_ARGS+=("$@")
            break
            ;;
        *)
            EXTRA_ARGS+=("$1")
            shift
            ;;
    esac
done

apply_local_patches
source_omnetpp_env

have_omnetpp_build || fail "opp_run not found. Run ./build_all.sh first."
have_inet_build || fail "INET build artifacts not found. Run ./build_all.sh first."
have_simu5g_build || fail "Simu5G build artifacts not found. Run ./build_all.sh first."
ensure_simu5g_build_fresh

RESULT_DIR="${REPO_ROOT}/results/raw/minimal_single_cell"
ensure_dir "${RESULT_DIR}"

SCENARIO_DIR="${REPO_ROOT}/scenarios/minimal_single_cell"
NED_PATH="${REPO_ROOT}:${SIMU5G_ROOT}/src:${INET_ROOT}/src"
NED_EXCLUSIONS="_deps"

log "Launching ${CONFIG} with ${UI}"
(
    cd "${SCENARIO_DIR}"
    export OMNETPP_NED_PACKAGE_EXCLUSIONS="${OMNETPP_NED_PACKAGE_EXCLUSIONS:+${OMNETPP_NED_PACKAGE_EXCLUSIONS};}${NED_EXCLUSIONS}"
    "${OMNETPP_ROOT}/bin/opp_run" \
        -u "${UI}" \
        -n "${NED_PATH}" \
        -l "${INET_ROOT}/src/INET" \
        -l "${SIMU5G_ROOT}/src/simu5g" \
        -f "omnetpp.ini" \
        -c "${CONFIG}" \
        "${EXTRA_ARGS[@]}"
)
