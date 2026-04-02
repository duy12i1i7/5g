# 5G Vehicular OMNeT++ Research Baseline

This repository is a reproducible orchestration layer for a 5G vehicular simulation stack built around OMNeT++, INET, Simu5G, Veins, and SUMO. Framework sources stay external under `./_deps` by default, while this repo carries the pinned version matrix, setup/build/run scripts, analysis tooling, and project-owned scenarios.

The current baseline completes stage 1 and a runnable stage 2 vehicular baseline:

- reproducible source checkout for the pinned stack
- environment verification
- end-to-end build script for OMNeT++, INET, Veins, veins_inet, and Simu5G
- a deterministic minimal single-cell 5G NR scenario runnable with Qtenv or Cmdenv
- a SUMO and Veins coupled vehicular scenario with single-cell and multi-cell presets
- MEC-enabled vehicular presets with Simu5G MEC host and request-response traffic
- KPI export and plotting helpers for throughput, delay, delivery ratio, and handover count

The vehicular baseline is intentionally conservative: it reuses the proven `NRCar` integration path from Simu5G and keeps the road network simple so the stack intersection remains reproducible.

## Repository Layout

- `docs/` architecture and troubleshooting notes
- `scripts/` shared shell helpers
- `configs/` pinned version matrix
- `scenarios/minimal_single_cell/` runnable stage 1 baseline
- `scenarios/vehicular_multi_cell/` SUMO, Veins, and Simu5G vehicular scenario
- `scenarios/imported_osm_template/` staging area for larger OSM-derived road networks
- `analysis/` result export and plotting scripts
- `results/` generated raw data, summaries, and plots
- `patches/` local compatibility notes for upstream patches if needed later
- `docker/` optional container notes and Dockerfile

## Pinned Version Matrix

The baseline stack is pinned to:

| Component | Version | Why this pin |
| --- | --- | --- |
| OMNeT++ | `6.1.0` | Explicitly supported by Simu5G 1.3.1 and Veins 5.3.1 |
| INET | `4.5.4` | Explicitly supported by Simu5G 1.3.1 and Veins 5.3.1 |
| Simu5G | `1.3.1` | Release notes mention OMNeT++ 6.1.0 and INET 4.5.4 |
| Veins | `5.3.1` | Official compatibility notes mention OMNeT++ 6.1.0 or 6.0.3 with INET 4.5.4 |
| SUMO | `1.22.0` | Stable recent SUMO release for the planned vehicular stage |

### Compatibility Notes

- Simu5G `1.4.x` moved to OMNeT++ `6.2.0`, but Veins documentation does not give the same clear compatibility statement there. For a research baseline that must bridge Simu5G and Veins, `Simu5G 1.3.1 + OMNeT++ 6.1.0 + INET 4.5.4` is the safer intersection.
- Simu5G still documents vehicular support as “integration with Veins 5.2”. Veins `5.3.1` remains compatible with INET `4.5.4`, so stage 2 will treat the Simu5G-to-Veins coupling as a smoke-tested integration point rather than assuming it is frictionless.
- The minimal stage 1 baseline does not require SUMO. The vehicular stage will.
- The included Ubuntu 22.04 container currently installs SUMO `1.12.0` from distro packages. The full baseline smoke test passes on that containerized stack, but the research pin remains `1.22.0` for native benchmarking environments.

## Linux Prerequisites

Ubuntu 22.04 or newer is the primary target. Install at least:

```bash
sudo apt-get update
sudo apt-get install -y \
  build-essential clang bison flex perl python3 python3-pip python3-venv \
  git wget curl pkg-config libxml2-dev zlib1g-dev doxygen graphviz \
  qtbase5-dev qtchooser qt5-qmake qtbase5-dev-tools \
  libgl1-mesa-dev libglu1-mesa-dev libwebkit2gtk-4.1-dev \
  default-jre sumo sumo-tools
```

Notes:

- `qmake` and Qt 5 development packages are required for Qtenv GUI support.
- `sumo` and `sumo-tools` are only required for the vehicular stage.
- If your distribution packages a different SUMO version, prefer installing `1.22.0` via the SUMO project packages or source build before stage 2 benchmarking.

## Quick Start

```bash
./setup.sh
./verify_env.sh
./build_all.sh
./run_minimal.sh --cmdenv
```

For GUI mode:

```bash
./run_minimal.sh --gui
```

## Minimal Scenario

The minimal baseline lives in [`scenarios/minimal_single_cell/omnetpp.ini`](scenarios/minimal_single_cell/omnetpp.ini) and uses:

- one gNB
- three stationary NR UEs
- one UPF chain and one remote server
- deterministic seed
- uplink UDP CBR traffic from each UE to the server
- light and heavy offered-load presets

Run presets:

```bash
./run_minimal.sh --config MinimalUlLight --cmdenv
./run_minimal.sh --config MinimalUlHeavy --cmdenv
./run_minimal.sh --config MinimalUlLight --gui
```

Results are written under `results/raw/minimal_single_cell/`.

## Vehicular Scenario

The vehicular baseline lives in [`scenarios/vehicular_multi_cell/omnetpp.ini`](scenarios/vehicular_multi_cell/omnetpp.ini) and uses:

- SUMO road traffic on a generated urban grid
- Veins `TraCIScenarioManagerLaunchd` through `VeinsInetManager`
- dynamic `NRCar` creation for each vehicle
- one or two gNBs depending on the selected preset
- one edge-like server and two core-side servers
- safety uplink, telemetry uplink, and optional burst downlink traffic
- optional MEC request-response traffic through a Simu5G MEC host on a separate MEC topology

For the MEC topology, `upf` remains the logical core gateway for gNBs and the MEC host, while `iUpf1` and `iUpf2` act as transit routers for outer GTP/IP traffic. This matches how the pinned Simu5G `Upf` module forwards decapsulated packets.

Run presets:

```bash
./run_vehicular.sh --config VehicularSingleCellSafety --cmdenv
./run_vehicular.sh --config VehicularSingleCellMixed --gui
./run_vehicular.sh --config VehicularMultiCellMixed --gui
./run_vehicular.sh --config VehicularMultiCellDense --cmdenv
./run_vehicular.sh --config VehicularMultiCellMec --cmdenv
./run_vehicular.sh --config VehicularMultiCellMecStress --cmdenv
```

`run_vehicular.sh` will:

- generate the SUMO road network if it is missing
- start `veins_launchd`
- launch OMNeT++ with the required INET, Simu5G, Veins, and `veins_inet` libraries
- clean up `veins_launchd` on exit

Results are written under `results/raw/vehicular_multi_cell/`.

## Experiment Suites

For repeatable benchmark batches, use `run_suite.sh`. The suite definitions live in `configs/experiment_presets.env`.

Available suites:

- `quick`: one minimal run plus two vehicular runs for smoke testing
- `minimal`: all minimal single-cell presets
- `vehicular`: all vehicular presets
- `full`: every preset in the repository

Examples:

```bash
./run_suite.sh --suite quick
./run_suite.sh --suite vehicular --regen-sumo
./run_suite.sh --suite full
./run_suite.sh --suite vehicular --analysis-only
```

Each suite writes:

- `results/summary/<suite>_scalars.csv`
- `results/summary/<suite>_vector_summary.csv`
- `results/summary/<suite>_kpis.csv`
- `results/plots/<suite>/`

## KPI Export and Plotting

Export scalar summaries:

```bash
python3 analysis/parse_results.py \
  --input-dir results/raw \
  --config MinimalUlLight \
  --config MinimalUlHeavy \
  --output results/summary/minimal_scalars.csv \
  --vector-summary-output results/summary/minimal_vector_summary.csv \
  --kpi-output results/summary/minimal_kpis.csv
```

Create plots:

```bash
python3 -m pip install -r analysis/requirements.txt
python3 analysis/plot_kpis.py \
  --input results/summary/minimal_kpis.csv \
  --output-dir results/plots
```

The parser now has two roles:

- export raw scalar rows for inspection
- derive scenario-level KPIs from scalar and vector files

Derived vehicular KPIs include:

- safety uplink throughput, delay, and packet delivery ratio
- telemetry uplink throughput, delay, and packet delivery ratio
- burst downlink delay and packet delivery ratio
- MEC request-response end-to-end, uplink, downlink, processing, and service times
- handover count from serving-cell vector transitions

## Smoke Tests

Use the smoke-test runner when you want a single command that checks the environment, builds if needed, runs baseline scenarios, and exports KPIs.

```bash
./run_smoke_tests.sh --mode minimal
./run_smoke_tests.sh --mode full
```

Notes:

- `minimal` runs the deterministic Simu5G baseline only
- `full` additionally runs the SUMO, Veins, and Simu5G vehicular baseline
- `run_smoke_tests.sh` will stop early if required dependencies such as `qmake`, `sumo`, or `netgenerate` are missing

## Imported OSM Maps

For larger road networks, use the helper:

```bash
./scripts/import_osm_map.sh \
  --osm-file /path/to/city.osm.xml \
  --output-dir scenarios/imported_city_assets
```

This generates a SUMO network, trips, routes, and a `.sumocfg` file. It is intentionally kept separate from the pinned baseline so the core repository remains light and reproducible.

## Windows Notes

- OMNeT++ supports Windows through its bundled MinGW shell.
- INET, Veins, and Simu5G are usually built from the OMNeT++ shell after running `mingwenv.cmd`.
- This repo’s shell scripts target Linux/macOS style shells first. On Windows, treat them as reference steps or run them from WSL2.
- For a native Windows path, use the same version pins and import the projects into the OMNeT++ IDE workspace without copying them.

## Docker and Devcontainer

Optional container support is included for build-oriented workflows:

- `docker/Dockerfile` installs the Linux prerequisites and Python plotting dependency
- `.devcontainer/devcontainer.json` opens the repo as a VS Code devcontainer

Current scope:

- validated for `setup.sh`, `build_all.sh`, `run_smoke_tests.sh --mode full`, KPI export, and plotting
- Qtenv startup is validated headlessly inside the container with `xvfb-run`
- interactive Qtenv use still requires host GUI forwarding or a native Linux desktop session

## Current Status

Implemented now:

- version pinning
- setup, verification, build, minimal run, and vehicular run scripts
- smoke-test runner
- batch suite runner with preset groups
- deterministic single-cell stage 1 scenario
- runnable SUMO and Veins vehicular scenario
- MEC-enabled vehicular presets
- architecture and troubleshooting docs
- KPI extraction and plotting pipeline for the current traffic profiles
- optional Docker and devcontainer scaffolding
- optional OSM import helper for larger map workflows
- full Linux container build of OMNeT++, INET, Veins, `veins_inet`, and Simu5G
- full Linux smoke test of the minimal baseline, the SUMO/TraCI/Veins/Simu5G vehicular baseline, and the MEC vehicular preset
- generated smoke-test KPI CSVs and plots under `results/summary/` and `results/plots/smoke/`
- local wrapper for the upstream `MECResponseApp` NED bug so dynamic MEC request/response apps can be instantiated without patching the external Simu5G tree
