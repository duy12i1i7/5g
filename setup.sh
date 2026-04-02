#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/scripts/lib/common.sh"

require_cmd git

log "Preparing pinned source checkouts"
print_paths
ensure_dir "${DEPS_DIR}"

clone_or_update_repo "${OMNETPP_GIT_URL}" "${OMNETPP_REF}" "${OMNETPP_ROOT}"
clone_or_update_repo "${INET_GIT_URL}" "${INET_REF}" "${INET_ROOT}"
clone_or_update_repo "${SIMU5G_GIT_URL}" "${SIMU5G_REF}" "${SIMU5G_ROOT}"
clone_or_update_repo "${VEINS_GIT_URL}" "${VEINS_REF}" "${VEINS_ROOT}"
apply_local_patches

sumo_version="$(detect_sumo_version)"
if [[ -z "${sumo_version}" ]]; then
    warn "SUMO was not detected. This does not block the minimal baseline, but it will block the vehicular TraCI scenario."
    warn "Install SUMO ${SUMO_VERSION} before stage 2 runs."
else
    log "Detected SUMO ${sumo_version}"
fi

cat <<EOF

Setup complete.

Next steps:
  1. Install Linux system prerequisites described in README.md
  2. Run ./verify_env.sh
  3. Run ./build_all.sh
  4. Run ./run_minimal.sh --cmdenv

EOF
