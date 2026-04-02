#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/scripts/lib/common.sh"

JOBS="${JOBS:-$(guess_jobs)}"

require_cmd git
require_cmd make
require_cmd python3
require_cmd qmake

[[ -d "${OMNETPP_ROOT}" ]] || fail "OMNeT++ sources not found. Run ./setup.sh first."
[[ -d "${INET_ROOT}" ]] || fail "INET sources not found. Run ./setup.sh first."
[[ -d "${SIMU5G_ROOT}" ]] || fail "Simu5G sources not found. Run ./setup.sh first."
[[ -d "${VEINS_ROOT}" ]] || fail "Veins sources not found. Run ./setup.sh first."

apply_local_patches
source_omnetpp_env

log "Building OMNeT++ with Qtenv enabled"
(
    cd "${OMNETPP_ROOT}"
    WITH_QTENV=yes WITH_OSG=no WITH_OSGEARTH=no ./configure
    make -j"${JOBS}"
)

log "Building INET"
source_inet_env
(
    cd "${INET_ROOT}"
    make makefiles
    make MODE=release -j"${JOBS}"
    make MODE=debug -j"${JOBS}"
)

log "Building Veins"
(
    cd "${VEINS_ROOT}"
    ./configure
    make -j"${JOBS}"
)

log "Building veins_inet"
(
    cd "${VEINS_INET_ROOT}"
    ./configure --with-veins="${VEINS_ROOT}" --with-inet="${INET_ROOT}"
    make -j"${JOBS}"
)

log "Enabling Simu5G cars feature and building Simu5G"
source_inet_env
(
    cd "${SIMU5G_ROOT}"
    opp_featuretool enable --with-dependencies Simu5G_Cars
    make makefiles
    make MODE=release -j"${JOBS}"
    make MODE=debug -j"${JOBS}"
)

log "Build complete"
