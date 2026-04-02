#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/scripts/lib/common.sh"

IMAGE_NAME="${IMAGE_NAME:-sim5g-vehicular:latest}"
CONTAINER_NAME="${CONTAINER_NAME:-sim5g-vehicular}"
BUILD_IMAGE=1
RUN_GUI=0
COMMAND=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-build)
            BUILD_IMAGE=0
            shift
            ;;
        --gui)
            RUN_GUI=1
            shift
            ;;
        --)
            shift
            COMMAND=("$@")
            break
            ;;
        *)
            fail "Unknown argument: $1"
            ;;
    esac
done

require_cmd docker

if [[ "${BUILD_IMAGE}" -eq 1 ]]; then
    log "Building container image ${IMAGE_NAME}"
    docker build -t "${IMAGE_NAME}" -f "${REPO_ROOT}/docker/Dockerfile" "${REPO_ROOT}"
fi

docker_args=(
    run
    --rm
    --name "${CONTAINER_NAME}"
    -v "${REPO_ROOT}:/workspace/5g"
    -w /workspace/5g
)

if [[ "${RUN_GUI}" -eq 1 ]]; then
    if [[ -z "${DISPLAY:-}" ]]; then
        fail "DISPLAY is not set. Export DISPLAY and configure X11 forwarding before using --gui."
    fi
    docker_args+=(
        -e "DISPLAY=${DISPLAY}"
        -v /tmp/.X11-unix:/tmp/.X11-unix
    )
fi

if [[ "${#COMMAND[@]}" -eq 0 ]]; then
    COMMAND=(bash)
fi

exec docker "${docker_args[@]}" "${IMAGE_NAME}" "${COMMAND[@]}"
