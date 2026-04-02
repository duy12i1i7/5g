#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/scripts/lib/common.sh"

status=0

check_cmd() {
    local name="$1"
    if command -v "${name}" >/dev/null 2>&1; then
        printf 'OK      %-18s %s\n' "${name}" "$(command -v "${name}")"
    else
        printf 'MISSING %-18s\n' "${name}"
        status=1
    fi
}

check_path() {
    local label="$1"
    local path="$2"
    if [[ -e "${path}" ]]; then
        printf 'OK      %-18s %s\n' "${label}" "${path}"
    else
        printf 'MISSING %-18s %s\n' "${label}" "${path}"
        status=1
    fi
}

check_optional_path() {
    local label="$1"
    local path="$2"
    if [[ -e "${path}" ]]; then
        printf 'OK      %-18s %s\n' "${label}" "${path}"
    else
        printf 'PENDING %-18s %s\n' "${label}" "${path}"
    fi
}

check_optional_build() {
    local label="$1"
    local probe="$2"
    if "${probe}"; then
        printf 'OK      %-18s %s\n' "${label}" "present"
    else
        printf 'PENDING %-18s %s\n' "${label}" "not built yet"
    fi
}

version_line() {
    printf '%-18s %s\n' "$1" "$2"
}

echo "Pinned versions"
version_line "OMNeT++" "${OMNETPP_VERSION}"
version_line "INET" "${INET_VERSION}"
version_line "Simu5G" "${SIMU5G_VERSION}"
version_line "Veins" "${VEINS_VERSION}"
version_line "SUMO" "${SUMO_VERSION}"
echo

echo "Required commands"
check_cmd git
check_cmd make
check_cmd python3
check_cmd gcc
check_cmd g++
check_cmd qmake
echo

echo "Dependency checkouts"
check_path "OMNeT++ root" "${OMNETPP_ROOT}"
check_path "INET root" "${INET_ROOT}"
check_path "Simu5G root" "${SIMU5G_ROOT}"
check_path "Veins root" "${VEINS_ROOT}"
check_path "veins_inet" "${VEINS_INET_ROOT}"
echo

if [[ -f "${OMNETPP_ROOT}/Version" ]]; then
    version_line "OMNeT++ source" "$(cat "${OMNETPP_ROOT}/Version")"
fi
if [[ -f "${INET_ROOT}/Version" ]]; then
    version_line "INET source" "$(cat "${INET_ROOT}/Version")"
fi
if [[ -x "${VEINS_ROOT}/print-veins-version" ]]; then
    version_line "Veins source" "$("${VEINS_ROOT}/print-veins-version")"
fi
if [[ -f "${SIMU5G_ROOT}/WHATSNEW.md" ]]; then
    version_line "Simu5G source" "${SIMU5G_VERSION}"
fi

sumo_version="$(detect_sumo_version)"
if [[ -n "${sumo_version}" ]]; then
    version_line "SUMO detected" "${sumo_version}"
else
    printf 'WARNING  %-18s %s\n' "SUMO detected" "not found; minimal scenario still runnable"
fi
if command -v netgenerate >/dev/null 2>&1; then
    printf 'OK      %-18s %s\n' "netgenerate" "$(command -v netgenerate)"
else
    printf 'WARNING  %-18s %s\n' "netgenerate" "not found; vehicular and OSM import flows are blocked"
fi
echo

echo "Expected build artifacts"
check_optional_build "opp_run" have_omnetpp_build
check_optional_build "INET build" have_inet_build
check_optional_build "Simu5G build" have_simu5g_build
check_optional_build "Veins build" have_veins_build
check_optional_build "veins_inet build" have_veins_inet_build
echo

if [[ "${status}" -ne 0 ]]; then
    fail "Environment verification failed"
fi

log "Environment verification passed"
