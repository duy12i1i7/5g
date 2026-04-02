# Vehicular Multi-Cell Scenario

This directory contains the runnable stage 2 vehicular baseline.

Contents:

- `UrbanGrid5G.ned`: validated baseline OMNeT++ network with Veins, Simu5G, two gNBs, and server hosts
- `UrbanGrid5GMec.ned`: staged MEC topology for Simu5G MEC request-response experiments
- `omnetpp.ini`: experiment presets
- `urban_grid.netccfg`: SUMO netgenerate source config
- `ApplicationDescriptors/`: MEC application descriptors used by `DeviceApp`
- light and dense route, SUMO, and launchd files

The generated `urban_grid.net.xml` file is not stored in git. It is created automatically by:

- `scripts/prepare_sumo_assets.sh`
- `run_vehicular.sh`

Presets:

- `VehicularSingleCellSafety`
- `VehicularSingleCellMixed`
- `VehicularMultiCellMixed`
- `VehicularMultiCellDense`
- `VehicularMultiCellMec`
- `VehicularMultiCellMecStress`

Topology note:

- `upf` is the logical core gateway used by the pinned Simu5G forwarding model
- `iUpf1` and `iUpf2` are retained as transit routers between the gNB side and the MEC host side
- `mecHost.upf_mec` is the GTP endpoint used for MEC-bound traffic after the local Simu5G patch resolves its core-facing `ppp0` address

Validation status:

- `VehicularSingleCellSafety`, `VehicularSingleCellMixed`, `VehicularMultiCellMixed`, and `VehicularMultiCellDense` share the validated `UrbanGrid5G` baseline
- `VehicularMultiCellMec` and `VehicularMultiCellMecStress` target `UrbanGrid5GMec` and are smoke-tested on the pinned Linux container baseline
- `apps/VehicularMECResponseApp.ned` is a local compatibility wrapper for Simu5G `1.3.1`, because the upstream `MECResponseApp` C++ code expects a `localUePort` parameter that its NED file does not declare
