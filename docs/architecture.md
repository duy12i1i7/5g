# Architecture Overview

## Scope

This repository separates three concerns:

1. Upstream frameworks stay external and version pinned.
2. Project-owned scenarios, automation, and analysis live in this repo.
3. Vehicular coupling is staged so the baseline remains runnable even if SUMO and TraCI are not installed yet.

## Stack Layers

### Stage 1 baseline

```text
OMNeT++ kernel + Qtenv/Cmdenv
        |
      INET
        |
     Simu5G
        |
  minimal_single_cell
```

### Stage 2 vehicular baseline

```text
SUMO road traffic
   <-> TraCI
Veins / veins_inet
   <-> dynamic vehicle creation and mobility sync
OMNeT++
   <-> INET networking
   <-> Simu5G NR radio + core path
```

### Stage 3 MEC-enabled extension

```text
SUMO vehicles
   <-> Veins dynamic NRCar nodes
NRCar applications
   <-> DeviceApp
   <-> UALCMP
   <-> MEC Orchestrator
   <-> MEC Host
   <-> MEC Services (RNI, Location)
```

## Module Interactions

### Control and execution path

- `OMNeT++` provides the discrete-event kernel, result recording, and GUI runtime.
- `INET` supplies IPv4 routing, transport protocols, hosts, routers, and mobility base classes.
- `Simu5G` provides the NR UE, gNB, UPF, carrier aggregation, channel model, and handover logic.
- `Veins` and `veins_inet` provide TraCI coupling and SUMO-driven mobility for dynamically created vehicles.
- `SUMO` remains the source of truth for road topology, routes, and vehicle movement in the vehicular stage.

### Vehicular data path

1. SUMO spawns and moves vehicles on the road network.
2. Veins receives TraCI updates and mirrors each active vehicle inside OMNeT++.
3. Each mirrored vehicle is instantiated as a Simu5G NR UE-capable node.
4. UEs attach to one or more gNBs through Simu5G radio logic.
5. Traffic flows traverse the Simu5G core path toward application servers or MEC-like hosts.
6. OMNeT++ records scalar and vector metrics for later export and plotting.

### MEC request-response path

1. A vehicle-side `UERequestApp` asks its local `DeviceApp` to instantiate a MEC application.
2. `DeviceApp` forwards that lifecycle request to `UALCMP`.
3. `UALCMP` forwards the request to the Simu5G `MecOrchestrator`.
4. The orchestrator places `MECResponseApp` on `mecHost`.
5. The MEC app serves request-response traffic and queries MEC services on the same host.
6. Vehicle-side applications record end-to-end response, uplink, downlink, service, and processing times.

## Repository Design

- `configs/versions.env` is the single source of truth for dependency pins.
- `setup.sh` fetches framework sources into `./_deps` unless the user supplies external paths.
- `build_all.sh` builds the frameworks in dependency order.
- `run_minimal.sh` runs a local scenario without requiring Veins or SUMO.
- `run_suite.sh` executes named benchmark suites and exports per-suite summaries.
- `analysis/` scripts operate on OMNeT++ output files and emit flat CSV and PNG artifacts.

## Staged Implementation Path

### Stage 1

- Pure Simu5G single-cell baseline
- Deterministic traffic and fixed positions
- CLI and Qtenv runnable

### Stage 2

- SUMO + Veins + Simu5G vehicular baseline
- Dynamic `NRCar` creation per SUMO vehicle
- Single-cell and two-cell presets
- Traffic mapped per vehicle

### Stage 3

- Larger imported road networks through the OSM import helper
- MEC-specific applications and placement policies
- Expanded radio and benchmarking presets
