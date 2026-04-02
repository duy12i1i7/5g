package scenarios.vehicular_multi_cell;

import inet.networklayer.configurator.ipv4.Ipv4NetworkConfigurator;
import inet.networklayer.ipv4.RoutingTableRecorder;
import inet.node.ethernet.Eth10G;
import inet.node.inet.Router;
import inet.node.inet.StandardHost;
import simu5g.world.radio.LteChannelControl;
import simu5g.common.carrierAggregation.CarrierAggregation;
import simu5g.nodes.Upf;
import simu5g.common.binder.Binder;
import simu5g.nodes.NR.gNodeB;
import simu5g.nodes.cars.NRCar;
import org.car2x.veins.subprojects.veins_inet.VeinsInetManager;

//
// Vehicular stage-2 baseline:
// - SUMO mobility through Veins/TraCI
// - dynamic NRCar creation
// - three application servers behind the data-network router
// - one or two gNBs depending on the configuration
//
network UrbanGrid5G
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

        edgeServer: StandardHost {
            @display("p=190,90;is=n;i=device/server");
        }
        cloudServer: StandardHost {
            @display("p=190,170;is=n;i=device/server");
        }
        videoServer: StandardHost {
            @display("p=190,250;is=n;i=device/server");
        }
        router: Router {
            @display("p=360,170;i=device/smallrouter");
        }
        upf: Upf {
            @display("p=520,170");
        }
        iUpf: Upf {
            @display("p=690,170");
        }
        gNodeB1: gNodeB {
            @display("p=410,470;is=vl");
        }
        gNodeB2: gNodeB {
            @display("p=740,470;is=vl");
        }

        // Dynamic vehicle modules are inserted here by Veins.
        car[0]: NRCar;

    connections allowunconnected:
        edgeServer.pppg++ <--> Eth10G <--> router.pppg++;
        cloudServer.pppg++ <--> Eth10G <--> router.pppg++;
        videoServer.pppg++ <--> Eth10G <--> router.pppg++;
        router.pppg++ <--> Eth10G <--> upf.filterGate;
        upf.pppg++ <--> Eth10G <--> iUpf.pppg++;
        iUpf.pppg++ <--> Eth10G <--> gNodeB1.ppp;
        iUpf.pppg++ <--> Eth10G <--> gNodeB2.ppp;
        gNodeB1.x2++ <--> Eth10G <--> gNodeB2.x2++;
}
