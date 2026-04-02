package scenarios.vehicular_multi_cell.apps;

import simu5g.apps.mec.MecRequestResponseApp.MECResponseApp;

//
// Local wrapper around Simu5G's MECResponseApp.
// Simu5G 1.3.1's C++ implementation expects a `localUePort` parameter,
// but the upstream NED module does not declare it.
//
simple VehicularMECResponseApp extends MECResponseApp
{
    parameters:
        @class(simu5g::MECResponseApp);
        int localUePort = default(4001);
}
