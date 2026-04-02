# Troubleshooting

## `./configure` fails while building OMNeT++

Most common cause: missing Qt development packages. Qtenv requires Qt 5 and a working `qmake` in `PATH`.

Checklist:

- `qmake --version`
- `pkg-config --modversion Qt5Core`
- install `qtbase5-dev`, `qt5-qmake`, and `qtbase5-dev-tools`

If you intentionally want a no-GUI build, change the OMNeT++ build invocation in [`build_all.sh`](../build_all.sh) to `WITH_QTENV=no`, but that disables the GUI requirement for this project.

## `verify_env.sh` reports missing SUMO

This is expected only if you run the minimal stage 1 baseline. The vehicular scenario requires:

Install SUMO before attempting the vehicular scenario:

- `sumo --version`
- `netgenerate --version`
- ensure `SUMO_HOME` or the `sumo` executable is discoverable

`verify_env.sh` now also checks `qmake`, because the pinned GUI-capable OMNeT++ build uses Qtenv.

## `opp_featuretool enable Simu5G_Cars` fails

Make sure:

- OMNeT++ has been built and `setenv` is sourced through [`build_all.sh`](../build_all.sh)
- the Simu5G checkout is exactly `v1.3.1`
- `.oppfeatures` exists in the Simu5G root

## `run_minimal.sh` cannot find shared libraries

Build artifacts are expected here:

- `${INET_ROOT}/src/INET`
- `${SIMU5G_ROOT}/src/simu5g`

Run:

```bash
./verify_env.sh
./build_all.sh
```

## Qtenv starts but icons or NED types are missing

This usually means the NED search path is incomplete. The minimal runner currently uses:

- repo root
- `${SIMU5G_ROOT}/src`
- `${INET_ROOT}/src`

If you customize scenarios that import upstream simulation packages, extend the `-n` path in [`run_minimal.sh`](../run_minimal.sh).

For the vehicular scenario, [`run_vehicular.sh`](../run_vehicular.sh) already includes:

- repo root
- `${SIMU5G_ROOT}/src`
- `${INET_ROOT}/src`
- `${VEINS_ROOT}/src/veins`
- `${VEINS_INET_ROOT}/src/veins_inet`

## Vehicular run fails with TraCI connection refused

Typical causes:

- `sumo` is not installed
- `veins_launchd` could not start SUMO
- the selected TraCI port is already in use

Checklist:

- run `./scripts/prepare_sumo_assets.sh`
- run `./run_vehicular.sh --cmdenv`
- inspect `results/raw/vehicular_multi_cell/veins_launchd-<Config>.log`
- retry on another port with `./run_vehicular.sh --port 10001`

## Vehicular run fails because `urban_grid.net.xml` is missing

Generate it explicitly:

```bash
./scripts/prepare_sumo_assets.sh --force
```

`run_vehicular.sh` also performs this step automatically.

## Analysis scripts produce empty KPI CSVs

If raw result files exist but KPI rows are empty, the most likely causes are:

- the run terminated before packets were exchanged
- vector recording was disabled
- the selected config did not enable the service whose KPI you expect

Use the full scalar export first:

```bash
python3 analysis/parse_results.py --input-dir results/raw/minimal_single_cell
```

For vehicular runs:

```bash
python3 analysis/parse_results.py --input-dir results/raw/vehicular_multi_cell
```

Then inspect the raw rows and the derived KPI rules in [`analysis/parse_results.py`](../analysis/parse_results.py).

## MEC vehicular config starts but MEC KPIs stay empty

Typical causes:

- `DeviceApp` and `UERequestApp` were not enabled in the selected config
- the MEC app descriptor file is missing from `scenarios/vehicular_multi_cell/ApplicationDescriptors/`
- the MEC host could not expose the required service (`RNIService` or `LocationService`)

Checklist:

- use `VehicularMultiCellMec` or `VehicularMultiCellMecStress`
- confirm `ApplicationDescriptors/ResponseApp.json` exists
- inspect the `.sca` file for `car[*].app[1].responseTime`
- inspect the run output for `UALCMP`, `mecOrchestrator`, or `mecHost` errors

## `VehicularMultiCellMec` fails during network initialization

This is no longer a known blocker on the pinned Linux container baseline. The current repo fixes the earlier MEC-stage failures by:

- using a `demo.xml` pattern that covers nested MEC host interfaces
- ordering `gNodeB1` and `gNodeB2` ahead of `mecHost` in `UrbanGrid5GMec.ned` so RNI collectors finish application-layer initialization first
- keeping `upf` as the logical gateway for both gNBs and the MEC host, while `iUpf1` and `iUpf2` remain transit routers for outer GTP/IP traffic
- declaring `virtualisationInfrastructure.numIndependentMecApp = parent.numIndependentMecApp`
- routing the MEC app descriptor through a local NED wrapper that adds the missing `localUePort` parameter expected by Simu5G's `MECResponseApp` implementation

If the config still fails locally, re-run:

```bash
./run_vehicular.sh --config VehicularMultiCellMec --cmdenv -- --sim-time-limit=10s
./run_vehicular.sh --config VehicularMultiCellMecStress --cmdenv -- --sim-time-limit=10s
```

Then inspect:

- `scenarios/vehicular_multi_cell/UrbanGrid5GMec.ned`
- `scenarios/vehicular_multi_cell/omnetpp.ini`
- `scenarios/vehicular_multi_cell/ApplicationDescriptors/ResponseApp.json`
- `scenarios/vehicular_multi_cell/apps/VehicularMECResponseApp.ned`

## `VehicularMultiCellMec` crashes mid-run with `Floating point exception`

If the stack trace points to `BaseStationStatsCollector`, `UeStatsCollector`, or `L2MeasBase`, you are likely running a stale Simu5G binary after pulling a repo update that changed local Simu5G patches.

This repo now includes [`patches/simu5g-statscollector-guards.patch`](../patches/simu5g-statscollector-guards.patch), which hardens Simu5G's RNI stats collectors against zero-length measurement windows and zero-denominator PDR calculations during MEC vehicular runs.

Rebuild Simu5G after pulling:

```bash
./build_all.sh
```

If you do not want to rebuild the full stack, rebuild Simu5G only in an environment where OMNeT++ and INET are already sourced and built.

`run_minimal.sh` and `run_vehicular.sh` now fail early when they detect patched Simu5G sources newer than the current `libsimu5g` build.

## `VehicularMultiCellMec` crashes mid-run with `Segmentation fault`

If the stack trace still points to `BaseStationStatsCollector`, `UeStatsCollector`, or `L2MeasBase` after the floating-point guard patch is already applied, pull the latest repo changes and rebuild Simu5G again.

This repo now also includes [`patches/simu5g-ue-collector-cleanup.patch`](../patches/simu5g-ue-collector-cleanup.patch), which unregisters dynamic vehicular UE collectors from the serving base station collector during module teardown. Without that cleanup, MEC vehicular runs can keep stale `UeStatsCollector*` pointers after SUMO removes a vehicle, eventually crashing later in the collector timer path.

Rebuild after pulling:

```bash
./build_all.sh
```

Or rebuild Simu5G only if OMNeT++ and INET are already built and sourced.

## Vehicular run prints `End.` and then `Killed.`

This is not, by itself, a simulation failure when it appears after `End.` and before the next config starts.

In that case the OMNeT++ run already completed successfully, and the trailing `Killed.` comes from the vehicular runner shutting down the background `veins_launchd` helper that was used to manage SUMO.

Treat it as benign cleanup unless it appears before `End.` or together with a stack trace, `Floating point exception`, or `Segmentation fault`.

## `run_smoke_tests.sh` fails before building

The script intentionally stops early when the environment cannot support the requested scope.

Common blockers:

- missing `qmake` for OMNeT++ with Qtenv
- missing `sumo` or `netgenerate` for `--mode full`
- dependency checkouts not present yet

Recommended order:

```bash
./setup.sh
./verify_env.sh
./run_smoke_tests.sh --mode minimal
```

## `import_osm_map.sh` fails

The OSM import helper requires SUMO tooling beyond the base `sumo` binary.

Checklist:

- `netconvert --version`
- `duarouter --version`
- `python3 $SUMO_HOME/tools/randomTrips.py --help`

If `randomTrips.py` is missing, install `sumo-tools` or set `SUMO_HOME` to a SUMO installation that includes the `tools/` directory.

## `run_suite.sh` finishes runs but plots are missing

Most common causes:

- `matplotlib` is not installed in the active Python environment
- `--skip-analysis` or `--no-plots` was passed
- the selected suite produced no KPI rows

Checklist:

- `python3 -m pip install -r analysis/requirements.txt`
- rerun `./run_suite.sh --suite quick --analysis-only`
- inspect `results/summary/<suite>_kpis.csv`

## Devcontainer builds but Qtenv does not open

The included container support is aimed first at build and Cmdenv execution. Qtenv startup has been validated headlessly with `xvfb-run`, but interactive GUI use still depends on the host display path. If Qtenv fails inside the container, the usual causes are:

- no X11 or Wayland forwarding from the host
- missing host-side permission for GUI socket access
- Qt plugin mismatch between host display stack and container runtime

Use the container for reproducible builds, smoke tests, and batch runs first. For Qtenv-heavy work, prefer a native Linux host until the GUI forwarding path is explicitly validated for your machine.
