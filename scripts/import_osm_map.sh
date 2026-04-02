#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/common.sh"

OSM_FILE=""
OUTPUT_DIR=""
PREFIX="imported_city"
SEED=20260402
BEGIN=0
END=600
VEHICLES=120

while [[ $# -gt 0 ]]; do
    case "$1" in
        --osm-file)
            OSM_FILE="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --prefix)
            PREFIX="$2"
            shift 2
            ;;
        --seed)
            SEED="$2"
            shift 2
            ;;
        --begin)
            BEGIN="$2"
            shift 2
            ;;
        --end)
            END="$2"
            shift 2
            ;;
        --vehicles)
            VEHICLES="$2"
            shift 2
            ;;
        *)
            fail "Unknown argument: $1"
            ;;
    esac
done

[[ -n "${OSM_FILE}" ]] || fail "Provide --osm-file <path-to.osm.xml>"
[[ -f "${OSM_FILE}" ]] || fail "OSM input not found: ${OSM_FILE}"
[[ -n "${OUTPUT_DIR}" ]] || fail "Provide --output-dir <dir>"

NETCONVERT="$(resolve_sumo_tool netconvert || true)"
DUAROUTER="$(resolve_sumo_tool duarouter || true)"
[[ -n "${NETCONVERT}" ]] || fail "netconvert was not found. Install SUMO first."
[[ -n "${DUAROUTER}" ]] || fail "duarouter was not found. Install SUMO first."

RANDOM_TRIPS=""
if [[ -n "${SUMO_HOME:-}" && -f "${SUMO_HOME}/tools/randomTrips.py" ]]; then
    RANDOM_TRIPS="${SUMO_HOME}/tools/randomTrips.py"
elif command -v randomTrips.py >/dev/null 2>&1; then
    RANDOM_TRIPS="$(command -v randomTrips.py)"
fi
[[ -n "${RANDOM_TRIPS}" ]] || fail "randomTrips.py was not found. Install sumo-tools or set SUMO_HOME."

OUTPUT_DIR="$(cd "$(dirname "${OUTPUT_DIR}")" && mkdir -p "$(basename "${OUTPUT_DIR}")" && pwd)/$(basename "${OUTPUT_DIR}")"
ensure_dir "${OUTPUT_DIR}"

NET_FILE="${OUTPUT_DIR}/${PREFIX}.net.xml"
TRIPS_FILE="${OUTPUT_DIR}/${PREFIX}.trips.xml"
ROUTES_FILE="${OUTPUT_DIR}/${PREFIX}.rou.xml"
SUMOCFG_FILE="${OUTPUT_DIR}/${PREFIX}.sumocfg"

log "Generating SUMO net from ${OSM_FILE}"
"${NETCONVERT}" \
    --osm-files "${OSM_FILE}" \
    --output-file "${NET_FILE}" \
    --geometry.remove \
    --roundabouts.guess \
    --ramps.guess \
    --junctions.join \
    --tls.guess-signals \
    --tls.discard-simple

log "Generating random trips"
python3 "${RANDOM_TRIPS}" \
    -n "${NET_FILE}" \
    -o "${TRIPS_FILE}" \
    --seed "${SEED}" \
    -b "${BEGIN}" \
    -e "${END}" \
    -p "$(python3 - <<PY
vehicles = max(int(${VEHICLES}), 1)
begin = float(${BEGIN})
end = float(${END})
duration = max(end - begin, 1.0)
print(duration / vehicles)
PY
)"

log "Building routes"
"${DUAROUTER}" \
    -n "${NET_FILE}" \
    --route-files "${TRIPS_FILE}" \
    --output-file "${ROUTES_FILE}" \
    --seed "${SEED}"

cat > "${SUMOCFG_FILE}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               xsi:noNamespaceSchemaLocation="http://sumo.dlr.de/xsd/sumoConfiguration.xsd">
    <input>
        <net-file value="$(basename "${NET_FILE}")"/>
        <route-files value="$(basename "${ROUTES_FILE}")"/>
    </input>
    <time>
        <begin value="${BEGIN}"/>
        <end value="${END}"/>
    </time>
</configuration>
EOF

cat <<EOF

Imported OSM assets ready:
  - ${NET_FILE}
  - ${TRIPS_FILE}
  - ${ROUTES_FILE}
  - ${SUMOCFG_FILE}

Next step:
  Wire these files into a new OMNeT++ scenario directory or adapt run_vehicular.sh to point at them.

EOF
