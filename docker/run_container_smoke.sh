#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-full}"

cd /workspace/5g

export JOBS="${JOBS:-$(nproc)}"

./setup.sh
./verify_env.sh
./build_all.sh
./run_smoke_tests.sh --mode "${MODE}"

# Validate that Qtenv can initialize in the Linux container even without host GUI forwarding.
# Xvfb provides a headless X server so the GUI stack is actually exercised.
if [[ "${MODE}" == "full" ]]; then
    xvfb-run -a ./run_vehicular.sh --config VehicularMultiCellMixed --gui -- --sim-time-limit=5s
else
    xvfb-run -a ./run_minimal.sh --config MinimalUlLight --gui -- --sim-time-limit=5s
fi
