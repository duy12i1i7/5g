#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/common.sh"

SCENARIO_DIR="${REPO_ROOT}/scenarios/vehicular_multi_cell"
FORCE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force|--regen)
            FORCE=1
            shift
            ;;
        *)
            fail "Unknown argument: $1"
            ;;
    esac
done

NETGENERATE="$(resolve_sumo_tool netgenerate || true)"
[[ -n "${NETGENERATE}" ]] || fail "netgenerate was not found. Install SUMO before generating vehicular assets."

OUTPUT_NET="${SCENARIO_DIR}/urban_grid.net.xml"
if [[ -f "${OUTPUT_NET}" && "${FORCE}" -eq 0 ]]; then
    log "SUMO network already exists at ${OUTPUT_NET}"
    exit 0
fi

log "Generating SUMO road network in ${SCENARIO_DIR}"
(
    cd "${SCENARIO_DIR}"
    "${NETGENERATE}" -c urban_grid.netccfg
)

log "Generated ${OUTPUT_NET}"
