#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/scripts/lib/common.sh"

UI="Qtenv"
CONFIG="VehicularMultiCellMixed"
PORT="${TRACI_PORT:-9999}"
REGEN_SUMO=0
SUMO_MODE="sumo"
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
        --sumo-gui)
            SUMO_MODE="sumo-gui"
            shift
            ;;
        --sumo)
            SUMO_MODE="sumo"
            shift
            ;;
        --config)
            CONFIG="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --regen|--regenerate-sumo)
            REGEN_SUMO=1
            shift
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

source_omnetpp_env

have_omnetpp_build || fail "opp_run not found. Run ./build_all.sh first."
have_inet_build || fail "INET build artifacts not found. Run ./build_all.sh first."
have_simu5g_build || fail "Simu5G build artifacts not found. Run ./build_all.sh first."
have_veins_build || fail "Veins build artifacts not found. Run ./build_all.sh first."
have_veins_inet_build || fail "veins_inet build artifacts not found. Run ./build_all.sh first."

SUMO_CMD="${SUMO_CMD:-$(resolve_sumo_tool "${SUMO_MODE}" || true)}"
[[ -n "${SUMO_CMD}" ]] || fail "Could not find ${SUMO_MODE}. Install SUMO or set SUMO_CMD."

PREPARE_ARGS=()
if [[ "${REGEN_SUMO}" -eq 1 ]]; then
    PREPARE_ARGS+=(--force)
fi
"${REPO_ROOT}/scripts/prepare_sumo_assets.sh" "${PREPARE_ARGS[@]}"

RESULT_DIR="${REPO_ROOT}/results/raw/vehicular_multi_cell"
ensure_dir "${RESULT_DIR}"

LOG_FILE="${RESULT_DIR}/veins_launchd-${CONFIG}.log"
PID_FILE="${RESULT_DIR}/veins_launchd-${CONFIG}.pid"

cleanup() {
    if [[ -f "${PID_FILE}" ]]; then
        local pid
        pid="$(cat "${PID_FILE}")"
        if kill -0 "${pid}" >/dev/null 2>&1; then
            kill "${pid}" >/dev/null 2>&1 || true
            wait "${pid}" >/dev/null 2>&1 || true
        fi
        rm -f "${PID_FILE}"
    fi
}
trap cleanup EXIT INT TERM

log "Starting veins_launchd on port ${PORT} using ${SUMO_CMD}"
python3 "${VEINS_ROOT}/bin/veins_launchd" \
    -v \
    -p "${PORT}" \
    -b 127.0.0.1 \
    -c "${SUMO_CMD}" \
    -L "${LOG_FILE}" &
echo $! > "${PID_FILE}"
sleep 1

SCENARIO_DIR="${REPO_ROOT}/scenarios/vehicular_multi_cell"
NED_PATH="${REPO_ROOT}:${SIMU5G_ROOT}/src:${INET_ROOT}/src:${VEINS_ROOT}/src/veins:${VEINS_INET_ROOT}/src/veins_inet"
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
        -l "${VEINS_ROOT}/src/veins" \
        -l "${VEINS_INET_ROOT}/src/veins_inet" \
        -f "omnetpp.ini" \
        -c "${CONFIG}" \
        "--*.veinsManager.port=${PORT}" \
        "${EXTRA_ARGS[@]}"
)
