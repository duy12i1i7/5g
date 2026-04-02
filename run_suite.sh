#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/scripts/lib/common.sh"

PRESET_FILE="${REPO_ROOT}/configs/experiment_presets.env"
[[ -f "${PRESET_FILE}" ]] || fail "Missing preset file: ${PRESET_FILE}"
# shellcheck source=/dev/null
source "${PRESET_FILE}"

SUITE="quick"
RUN_EXPERIMENTS=1
RUN_ANALYSIS=1
RUN_PLOTS=1
REGEN_SUMO=0
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --suite)
            SUITE="$2"
            shift 2
            ;;
        --analysis-only)
            RUN_EXPERIMENTS=0
            shift
            ;;
        --skip-analysis)
            RUN_ANALYSIS=0
            RUN_PLOTS=0
            shift
            ;;
        --no-plots)
            RUN_PLOTS=0
            shift
            ;;
        --regen-sumo)
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

suite_configs() {
    case "${SUITE}" in
        minimal)
            printf '%s\n' ${MINIMAL_PRESETS}
            ;;
        vehicular)
            printf '%s\n' ${VEHICULAR_PRESETS}
            ;;
        quick)
            printf '%s\n' ${QUICK_PRESETS}
            ;;
        full)
            printf '%s\n' ${FULL_PRESETS}
            ;;
        *)
            fail "Unknown suite '${SUITE}'. Use one of: minimal, vehicular, quick, full."
            ;;
    esac
}

CONFIGS=()
while IFS= read -r config; do
    CONFIGS+=("${config}")
done < <(suite_configs)
[[ "${#CONFIGS[@]}" -gt 0 ]] || fail "No configurations resolved for suite '${SUITE}'"

summary_dir="${REPO_ROOT}/results/summary"
plot_dir="${REPO_ROOT}/results/plots/${SUITE}"
ensure_dir "${summary_dir}"
ensure_dir "${plot_dir}"

run_config() {
    local config="$1"

    if [[ "${config}" == Minimal* ]]; then
        log "Running minimal preset ${config}"
        "${REPO_ROOT}/run_minimal.sh" --config "${config}" --cmdenv "${EXTRA_ARGS[@]}"
        return
    fi

    local vehicular_args=(--config "${config}" --cmdenv)
    if [[ "${REGEN_SUMO}" -eq 1 ]]; then
        vehicular_args+=(--regen)
    fi
    vehicular_args+=("${EXTRA_ARGS[@]}")

    log "Running vehicular preset ${config}"
    "${REPO_ROOT}/run_vehicular.sh" "${vehicular_args[@]}"
}

if [[ "${RUN_EXPERIMENTS}" -eq 1 ]]; then
    for config in "${CONFIGS[@]}"; do
        run_config "${config}"
    done
fi

if [[ "${RUN_ANALYSIS}" -eq 1 ]]; then
    analysis_args=(
        --input-dir "${REPO_ROOT}/results/raw"
        --output "${summary_dir}/${SUITE}_scalars.csv"
        --vector-summary-output "${summary_dir}/${SUITE}_vector_summary.csv"
        --kpi-output "${summary_dir}/${SUITE}_kpis.csv"
    )

    for config in "${CONFIGS[@]}"; do
        analysis_args+=(--config "${config}")
    done

    log "Exporting KPIs for suite ${SUITE}"
    python3 "${REPO_ROOT}/analysis/parse_results.py" "${analysis_args[@]}"

    if [[ "${RUN_PLOTS}" -eq 1 ]]; then
        log "Plotting KPIs for suite ${SUITE}"
        python3 "${REPO_ROOT}/analysis/plot_kpis.py" \
            --input "${summary_dir}/${SUITE}_kpis.csv" \
            --output-dir "${plot_dir}"
    fi
fi

cat <<EOF

Suite complete: ${SUITE}
Configs:
$(printf '  - %s\n' "${CONFIGS[@]}")

Summary files:
  - ${summary_dir}/${SUITE}_scalars.csv
  - ${summary_dir}/${SUITE}_vector_summary.csv
  - ${summary_dir}/${SUITE}_kpis.csv

Plots:
  - ${plot_dir}

EOF
