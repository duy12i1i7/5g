package scenarios.vehicular_multi_cell;

import inet.networklayer.configurator.ipv4.Ipv4NetworkConfigurator;
import inet.networklayer.ipv4.RoutingTableRecorder;
import inet.node.ethernet.Eth10G;
import simu5g.world.radio.LteChannelControl;
import simu5g.common.carrierAggregation.CarrierAggregation;
import simu5g.nodes.Upf;
import simu5g.common.binder.Binder;
import simu5g.nodes.NR.gNodeB;
import simu5g.nodes.cars.NRCar;
import simu5g.nodes.mec.MECHost;
import simu5g.nodes.mec.MECOrchestrator.MecOrchestrator;
import simu5g.nodes.mec.UALCMP.UALCMP;
import org.car2x.veins.subprojects.veins_inet.VeinsInetManager;

//
// Vehicular stage-3 MEC topology:
// - SUMO mobility through Veins/TraCI
// - dynamic NRCar creation
// - two gNBs with X2 connectivity
// - one MEC host attached to the 5G core side
// - one MEC orchestrator and one UALCMP
//
network UrbanGrid5GMec
{
    parameters:
        double playgroundSizeX @unit(m) = default(450m);
        double playgroundSizeY @unit(m) = default(450m);
        double playgroundSizeZ @unit(m) = default(50m);
        @display("bgb=1180,760");

    submodules:
        routingRecorder: RoutingTableRecorder {
            @display("p=60,80;is=s");
        }
        configurator: Ipv4NetworkConfigurator {
            @display("p=60,140");
        }
        veinsManager: VeinsInetManager {
            @display("p=60,240;is=s");
        }
        channelControl: LteChannelControl {
            @display("p=60,30;is=s");
        }
        binder: Binder {
            @display("p=60,190;is=s");
        }
        carrierAggregation: CarrierAggregation {
            @display("p=60,290;is=s");
        }
        upf: Upf {
            @display("p=540,180");
        }
        iUpf1: Upf {
            @display("p=640,180");
        }
        iUpf2: Upf {
            @display("p=820,180");
        }
        gNodeB1: gNodeB {
            @display("p=470,470;is=vl");
        }
        gNodeB2: gNodeB {
            @display("p=800,470;is=vl");
        }
        mecHost: MECHost {
            @display("p=640,90;is=l");
        }
        mecOrchestrator: MecOrchestrator {
            @display("p=250,70;is=l");
        }
        ualcmp: UALCMP {
            @display("p=380,70;i=device/mainframe");
        }

        // Dynamic vehicle modules are inserted here by Veins.
        car[0]: NRCar;

    connections allowunconnected:
        upf.pppg++ <--> Eth10G <--> iUpf1.pppg++;
        upf.pppg++ <--> Eth10G <--> iUpf2.pppg++;
        iUpf1.pppg++ <--> Eth10G <--> gNodeB1.ppp;
        iUpf2.pppg++ <--> Eth10G <--> gNodeB2.ppp;

        ualcmp.ppp++ <--> Eth10G <--> upf.filterGate;
        mecHost.ppp++ <--> Eth10G <--> iUpf1.pppg++;

        ualcmp.toMecOrchestrator --> mecOrchestrator.fromUALCMP;
        ualcmp.fromMecOrchestrator <-- mecOrchestrator.toUALCMP;
        gNodeB1.x2++ <--> Eth10G <--> gNodeB2.x2++;
}
