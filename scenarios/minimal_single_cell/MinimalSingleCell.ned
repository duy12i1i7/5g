package scenarios.minimal_single_cell;

import inet.networklayer.configurator.ipv4.Ipv4NetworkConfigurator;
import inet.networklayer.ipv4.RoutingTableRecorder;
import inet.node.ethernet.Eth10G;
import inet.node.inet.Router;
import inet.node.inet.StandardHost;
import simu5g.common.binder.Binder;
import simu5g.common.carrierAggregation.CarrierAggregation;
import simu5g.nodes.NR.NRUe;
import simu5g.nodes.NR.gNodeB;
import simu5g.nodes.Upf;
import simu5g.world.radio.LteChannelControl;

//
// Stage 1 baseline:
// - one gNB
// - one server
// - one UPF chain
// - a small number of stationary UEs
// - deterministic application traffic
//
network MinimalSingleCell
{
    parameters:
        int numUe = default(3);
        @display("i=block/network2;bgb=1024,640");
    submodules:
        channelControl: LteChannelControl {
            @display("p=50,30;is=s");
        }
        routingRecorder: RoutingTableRecorder {
            @display("p=50,90;is=s");
        }
        configurator: Ipv4NetworkConfigurator {
            @display("p=50,150");
        }
        binder: Binder {
            @display("p=50,210;is=s");
        }
        carrierAggregation: CarrierAggregation {
            @display("p=50,270;is=s");
        }
        server: StandardHost {
            @display("p=190,140;is=n;i=device/server");
        }
        router: Router {
            @display("p=340,140;i=device/smallrouter");
        }
        upf: Upf {
            @display("p=500,140");
        }
        iUpf: Upf {
            @display("p=670,140");
        }
        gnb: gNodeB {
            @display("p=670,310;is=vl");
        }
        ue[numUe]: NRUe {
            @display("p=540,500");
        }
    connections:
        server.pppg++ <--> Eth10G <--> router.pppg++;
        router.pppg++ <--> Eth10G <--> upf.filterGate;
        upf.pppg++ <--> Eth10G <--> iUpf.pppg++;
        iUpf.pppg++ <--> Eth10G <--> gnb.ppp;
}

