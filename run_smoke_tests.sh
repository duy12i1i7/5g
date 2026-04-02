#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/scripts/lib/common.sh"

MODE="minimal"
RUN_PLOTS=0
SMOKE_SIM_TIME_LIMIT="10s"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)
            MODE="$2"
            shift 2
            ;;
        --plots)
            RUN_PLOTS=1
            shift
            ;;
        *)
            fail "Unknown argument: $1"
            ;;
    esac
done

case "${MODE}" in
    minimal|full)
        ;;
    *)
        fail "Unsupported mode '${MODE}'. Use 'minimal' or 'full'."
        ;;
esac

if [[ ! -d "${OMNETPP_ROOT}" || ! -d "${INET_ROOT}" || ! -d "${SIMU5G_ROOT}" || ! -d "${VEINS_ROOT}" ]]; then
    log "Dependency checkouts are missing, running setup first"
    "${REPO_ROOT}/setup.sh"
fi

log "Verifying environment"
"${REPO_ROOT}/verify_env.sh"

if ! have_omnetpp_build || ! have_inet_build || ! have_simu5g_build || ! have_veins_build || ! have_veins_inet_build; then
    log "Build artifacts missing, building pinned stack"
    "${REPO_ROOT}/build_all.sh"
fi

log "Running minimal smoke test"
"${REPO_ROOT}/run_minimal.sh" --config MinimalUlLight --cmdenv -- --sim-time-limit="${SMOKE_SIM_TIME_LIMIT}"

ANALYSIS_CONFIGS=(MinimalUlLight)

if [[ "${MODE}" == "full" ]]; then
    resolve_sumo_tool sumo >/dev/null 2>&1 || fail "SUMO is required for --mode full."
    resolve_sumo_tool netgenerate >/dev/null 2>&1 || fail "netgenerate is required for --mode full."
    log "Running vehicular baseline smoke test"
    "${REPO_ROOT}/run_vehicular.sh" --config VehicularMultiCellMixed --cmdenv -- --sim-time-limit="${SMOKE_SIM_TIME_LIMIT}"
    log "Running vehicular MEC smoke test"
    "${REPO_ROOT}/run_vehicular.sh" --config VehicularMultiCellMec --cmdenv -- --sim-time-limit="${SMOKE_SIM_TIME_LIMIT}"
    log "Running vehicular MEC stress smoke test"
    "${REPO_ROOT}/run_vehicular.sh" --config VehicularMultiCellMecStress --cmdenv -- --sim-time-limit="${SMOKE_SIM_TIME_LIMIT}"
    ANALYSIS_CONFIGS+=(VehicularMultiCellMixed VehicularMultiCellMec VehicularMultiCellMecStress)
fi

log "Parsing smoke test results"
analysis_args=(
    --input-dir "${REPO_ROOT}/results/raw"
    --output "${REPO_ROOT}/results/summary/smoke_scalars.csv"
    --vector-summary-output "${REPO_ROOT}/results/summary/smoke_vector_summary.csv"
    --kpi-output "${REPO_ROOT}/results/summary/smoke_kpis.csv"
)
for config in "${ANALYSIS_CONFIGS[@]}"; do
    analysis_args+=(--config "${config}")
done

python3 "${REPO_ROOT}/analysis/parse_results.py" \
    "${analysis_args[@]}"

if [[ "${RUN_PLOTS}" -eq 1 ]]; then
    log "Plotting smoke test KPIs"
    python3 "${REPO_ROOT}/analysis/plot_kpis.py" \
        --input "${REPO_ROOT}/results/summary/smoke_kpis.csv" \
        --output-dir "${REPO_ROOT}/results/plots/smoke"
fi

cat <<EOF

Smoke tests complete.
Mode: ${MODE}
Artifacts:
  - ${REPO_ROOT}/results/summary/smoke_scalars.csv
  - ${REPO_ROOT}/results/summary/smoke_vector_summary.csv
  - ${REPO_ROOT}/results/summary/smoke_kpis.csv

EOF
