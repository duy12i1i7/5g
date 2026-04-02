#!/usr/bin/env bash
set -euo pipefail

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${COMMON_DIR}/../.." && pwd)"
VERSION_FILE="${REPO_ROOT}/configs/versions.env"

if [[ ! -f "${VERSION_FILE}" ]]; then
    echo "Missing version file: ${VERSION_FILE}" >&2
    exit 1
fi

set -a
source "${VERSION_FILE}"
set +a

DEPS_DIR="${SIM5G_DEPS_DIR:-${REPO_ROOT}/_deps}"
DEFAULT_OMNETPP_ROOT="${DEPS_DIR}/omnetpp-${OMNETPP_VERSION}"
DEFAULT_INET_ROOT="${DEPS_DIR}/inet-${INET_VERSION}"
DEFAULT_SIMU5G_ROOT="${DEPS_DIR}/simu5g-${SIMU5G_VERSION}"
DEFAULT_VEINS_ROOT="${DEPS_DIR}/veins-${VEINS_VERSION}"

OMNETPP_ROOT="${OMNETPP_ROOT:-${DEFAULT_OMNETPP_ROOT}}"
INET_ROOT="${INET_ROOT:-${DEFAULT_INET_ROOT}}"
SIMU5G_ROOT="${SIMU5G_ROOT:-${DEFAULT_SIMU5G_ROOT}}"
VEINS_ROOT="${VEINS_ROOT:-${DEFAULT_VEINS_ROOT}}"
VEINS_INET_ROOT="${VEINS_INET_ROOT:-${VEINS_ROOT}/${VEINS_INET_SUBPROJECT}}"

log() {
    printf '[%s] %s\n' "$(basename "$0")" "$*"
}

warn() {
    printf '[%s] WARNING: %s\n' "$(basename "$0")" "$*" >&2
}

fail() {
    printf '[%s] ERROR: %s\n' "$(basename "$0")" "$*" >&2
    exit 1
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

ensure_dir() {
    mkdir -p "$1"
}

file_any() {
    local candidate
    for candidate in "$@"; do
        if [[ -f "${candidate}" ]]; then
            return 0
        fi
    done
    return 1
}

dir_any() {
    local candidate
    for candidate in "$@"; do
        if [[ -d "${candidate}" ]]; then
            return 0
        fi
    done
    return 1
}

clone_or_update_repo() {
    local url="$1"
    local ref="$2"
    local dest="$3"

    ensure_dir "$(dirname "${dest}")"
    if [[ ! -d "${dest}/.git" ]]; then
        log "Cloning ${url} @ ${ref} into ${dest}"
        git clone --depth 1 --branch "${ref}" "${url}" "${dest}"
        return
    fi

    log "Refreshing ${dest} to ${ref}"
    git -C "${dest}" fetch --depth 1 origin "${ref}"
    git -C "${dest}" checkout --detach FETCH_HEAD
}

apply_local_patches() {
    local patch_file

    if [[ ! -d "${SIMU5G_ROOT}" ]]; then
        return
    fi

    for patch_file in "${REPO_ROOT}"/patches/simu5g-*.patch; do
        [[ -f "${patch_file}" ]] || continue
        if git -C "${SIMU5G_ROOT}" apply --reverse --check "${patch_file}" >/dev/null 2>&1; then
            log "Local Simu5G patch already applied: $(basename "${patch_file}")"
        else
            log "Applying local Simu5G patch: $(basename "${patch_file}")"
            git -C "${SIMU5G_ROOT}" apply "${patch_file}"
        fi
    done
}

guess_jobs() {
    if command -v nproc >/dev/null 2>&1; then
        nproc
        return
    fi
    if command -v getconf >/dev/null 2>&1; then
        getconf _NPROCESSORS_ONLN
        return
    fi
    if command -v sysctl >/dev/null 2>&1; then
        sysctl -n hw.ncpu
        return
    fi
    echo 4
}

ensure_omnetpp_configure_user() {
    if [[ ! -f "${OMNETPP_ROOT}/configure.user" && -f "${OMNETPP_ROOT}/configure.user.dist" ]]; then
        cp "${OMNETPP_ROOT}/configure.user.dist" "${OMNETPP_ROOT}/configure.user"
    fi
    if [[ -f "${OMNETPP_ROOT}/configure.user" ]]; then
        perl -0pi -e 's/^WITH_QTENV=.*/WITH_QTENV=yes/m; s/^WITH_OSG=.*/WITH_OSG=no/m; s/^WITH_OSGEARTH=.*/WITH_OSGEARTH=no/m' "${OMNETPP_ROOT}/configure.user"
    fi
}

source_omnetpp_env() {
    ensure_omnetpp_configure_user
    [[ -f "${OMNETPP_ROOT}/setenv" ]] || fail "OMNeT++ setenv not found at ${OMNETPP_ROOT}/setenv"
    local old_pwd="${PWD}"
    local had_nounset=0
    [[ $- == *u* ]] && had_nounset=1
    cd "${OMNETPP_ROOT}"
    if [[ "${had_nounset}" -eq 1 ]]; then
        set +u
    fi
    # shellcheck source=/dev/null
    source "${OMNETPP_ROOT}/setenv"
    if [[ "${had_nounset}" -eq 1 ]]; then
        set -u
    fi
    cd "${old_pwd}"
}

source_inet_env() {
    [[ -f "${INET_ROOT}/setenv" ]] || fail "INET setenv not found at ${INET_ROOT}/setenv"
    local old_pwd="${PWD}"
    local had_nounset=0
    [[ $- == *u* ]] && had_nounset=1
    cd "${INET_ROOT}"
    if [[ "${had_nounset}" -eq 1 ]]; then
        set +u
    fi
    # shellcheck source=/dev/null
    source "${INET_ROOT}/setenv"
    if [[ "${had_nounset}" -eq 1 ]]; then
        set -u
    fi
    cd "${old_pwd}"
}

detect_sumo_version() {
    if command -v sumo >/dev/null 2>&1; then
        sumo --version 2>/dev/null | head -n 1 | sed 's/^Eclipse SUMO Version //'
        return
    fi
    if [[ -n "${SUMO_HOME:-}" && -x "${SUMO_HOME}/bin/sumo" ]]; then
        "${SUMO_HOME}/bin/sumo" --version 2>/dev/null | head -n 1 | sed 's/^Eclipse SUMO Version //'
        return
    fi
    echo ""
}

resolve_sumo_tool() {
    local tool_name="$1"
    if command -v "${tool_name}" >/dev/null 2>&1; then
        command -v "${tool_name}"
        return 0
    fi
    if [[ -n "${SUMO_HOME:-}" && -x "${SUMO_HOME}/bin/${tool_name}" ]]; then
        printf '%s\n' "${SUMO_HOME}/bin/${tool_name}"
        return 0
    fi
    return 1
}

have_omnetpp_build() {
    [[ -x "${OMNETPP_ROOT}/bin/opp_run" ]]
}

have_inet_build() {
    file_any \
        "${INET_ROOT}/out/clang-release/src/libINET.so" \
        "${INET_ROOT}/out/clang-release/src/libINET.dylib" \
        "${INET_ROOT}/out/clang-release/src/libINET.dll" \
        "${INET_ROOT}/out/clang-debug/src/libINET_dbg.so" \
        "${INET_ROOT}/out/clang-debug/src/libINET_dbg.dylib" \
        "${INET_ROOT}/out/clang-debug/src/libINET_dbg.dll" \
        "${INET_ROOT}/src/libINET.so" \
        "${INET_ROOT}/src/libINET.dylib" \
        "${INET_ROOT}/src/libINET.dll" \
        "${INET_ROOT}/src/libINET_dbg.so" \
        "${INET_ROOT}/src/libINET_dbg.dylib" \
        "${INET_ROOT}/src/libINET_dbg.dll" \
        "${INET_ROOT}/src/INET.dll" \
        "${INET_ROOT}/src/INET.exe" \
        "${INET_ROOT}/src/INET_dbg.exe" \
        "${INET_ROOT}/src/INET" \
        "${INET_ROOT}/src/INET_dbg"
}

have_simu5g_build() {
    file_any \
        "${SIMU5G_ROOT}/out/clang-release/src/libsimu5g.so" \
        "${SIMU5G_ROOT}/out/clang-release/src/libsimu5g.dylib" \
        "${SIMU5G_ROOT}/out/clang-release/src/libsimu5g.dll" \
        "${SIMU5G_ROOT}/out/clang-debug/src/libsimu5g_dbg.so" \
        "${SIMU5G_ROOT}/out/clang-debug/src/libsimu5g_dbg.dylib" \
        "${SIMU5G_ROOT}/out/clang-debug/src/libsimu5g_dbg.dll" \
        "${SIMU5G_ROOT}/src/libsimu5g.so" \
        "${SIMU5G_ROOT}/src/libsimu5g.dylib" \
        "${SIMU5G_ROOT}/src/libsimu5g.dll" \
        "${SIMU5G_ROOT}/src/libsimu5g_dbg.so" \
        "${SIMU5G_ROOT}/src/libsimu5g_dbg.dylib" \
        "${SIMU5G_ROOT}/src/libsimu5g_dbg.dll" \
        "${SIMU5G_ROOT}/src/simu5g.exe" \
        "${SIMU5G_ROOT}/src/simu5g" \
        "${SIMU5G_ROOT}/src/simu5g_dbg" \
        "${SIMU5G_ROOT}/bin/simu5g" \
        "${SIMU5G_ROOT}/bin/simu5g_dbg"
}

have_veins_build() {
    file_any \
        "${VEINS_ROOT}/out/clang-release/src/libveins.so" \
        "${VEINS_ROOT}/out/clang-release/src/libveins.dylib" \
        "${VEINS_ROOT}/out/clang-release/src/libveins.dll" \
        "${VEINS_ROOT}/out/clang-debug/src/libveins_dbg.so" \
        "${VEINS_ROOT}/out/clang-debug/src/libveins_dbg.dylib" \
        "${VEINS_ROOT}/out/clang-debug/src/libveins_dbg.dll" \
        "${VEINS_ROOT}/src/libveins.so" \
        "${VEINS_ROOT}/src/libveins.dylib" \
        "${VEINS_ROOT}/src/libveins.dll" \
        "${VEINS_ROOT}/src/libveins_dbg.so" \
        "${VEINS_ROOT}/src/libveins_dbg.dylib" \
        "${VEINS_ROOT}/src/libveins_dbg.dll" \
        "${VEINS_ROOT}/src/veins.exe" \
        "${VEINS_ROOT}/src/veins"
}

have_veins_inet_build() {
    file_any \
        "${VEINS_INET_ROOT}/out/clang-release/src/libveins_inet.so" \
        "${VEINS_INET_ROOT}/out/clang-release/src/libveins_inet.dylib" \
        "${VEINS_INET_ROOT}/out/clang-release/src/libveins_inet.dll" \
        "${VEINS_INET_ROOT}/out/clang-debug/src/libveins_inet_dbg.so" \
        "${VEINS_INET_ROOT}/out/clang-debug/src/libveins_inet_dbg.dylib" \
        "${VEINS_INET_ROOT}/out/clang-debug/src/libveins_inet_dbg.dll" \
        "${VEINS_INET_ROOT}/src/libveins_inet.so" \
        "${VEINS_INET_ROOT}/src/libveins_inet.dylib" \
        "${VEINS_INET_ROOT}/src/libveins_inet.dll" \
        "${VEINS_INET_ROOT}/src/libveins_inet_dbg.so" \
        "${VEINS_INET_ROOT}/src/libveins_inet_dbg.dylib" \
        "${VEINS_INET_ROOT}/src/libveins_inet_dbg.dll" \
        "${VEINS_INET_ROOT}/src/veins_inet.exe" \
        "${VEINS_INET_ROOT}/bin/veins_inet_run"
}

print_paths() {
    cat <<EOF
Repository root : ${REPO_ROOT}
Dependencies dir: ${DEPS_DIR}
OMNeT++ root    : ${OMNETPP_ROOT}
INET root       : ${INET_ROOT}
Simu5G root     : ${SIMU5G_ROOT}
Veins root      : ${VEINS_ROOT}
veins_inet root : ${VEINS_INET_ROOT}
EOF
}
