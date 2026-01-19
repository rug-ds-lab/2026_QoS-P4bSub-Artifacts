#include <core.p4>
#include <tna.p4>

#include "types.p4"
#include "headers.p4"
#include "parde.p4"
#include "CoDel.p4"
#include "FQ-CoDel.p4"

// ---------------------------------------------------------------------------
// Ingress
// ---------------------------------------------------------------------------
control SwitchIngress(
        inout header_t hdr,
        inout ig_metadata_t ig_md,
        in ingress_intrinsic_metadata_t ig_intr_md,
        in ingress_intrinsic_metadata_from_parser_t ig_prsr_md,
        inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md,
        inout ingress_intrinsic_metadata_for_tm_t ig_intr_tm_md) {
    
    FQCodelIngress() fq_codel_ingress;

    action drop_packet() { 
        ig_dprsr_md.drop_ctl = 0x1;
        exit;
    }

    #if defined(RL) 
    DirectMeter(MeterType_t.BYTES) publisher_meter;

    action set_meter_color() { 
        ig_md.pkt_color = publisher_meter.execute();
    }

    table publisher_meter_tbl {
        key = {
            // ig_intr_md.ingress_port : exact;
            ig_md.flow_id : exact;
        }
        actions = {
            set_meter_color;
        }
        meters = publisher_meter;
        size = PUBLISHERS_TABLE_SIZE;
    }

    DirectCounter<bit<32>>(CounterType_t.PACKETS_AND_BYTES) meter_cntr;

    action pkt_count() {
        meter_cntr.count();
    }

    table meter_colors {
        key = {
            ig_md.pkt_color : exact;
        }
        actions = {
            pkt_count;
        }
        counters = meter_cntr;
        size = 3;
        const entries = {
            (MeterColor_t.GREEN) : pkt_count();
            (MeterColor_t.YELLOW) : pkt_count();
            (MeterColor_t.RED) : pkt_count();
        }
    }
    #endif

    action send_with_priority(bit<9> egress_port, bit<32> flow_id) {
        ig_intr_tm_md.ucast_egress_port = egress_port;
        ig_md.flow_id = flow_id;
        // ig_intr_tm_md.ingress_cos = icos;  // TODO : Ingress cos (iCoS) for PG mapping,
    }

    // Content-based Routing 
    table subscriptions_tbl {
        key = {
            hdr.event[0].attribute : ternary;
            hdr.event[0].value : ternary;
            hdr.event[1].attribute : ternary;
            hdr.event[1].value : ternary;
            hdr.event[2].attribute : ternary;
            hdr.event[2].value : ternary;
        }
        actions = {
            send_with_priority;
        }
        size = SUBSCRIPTIONS_TABLE_SIZE;
    }

    action mapping(QueueId_t queue_id) {
        ig_intr_tm_md.qid = queue_id;
        ig_md.qid = (bit<32>) queue_id;
    }

    table flow_id_to_queue_id {
        key = {
            ig_md.flow_id : exact;
        }
        actions = {
            mapping;
        }
        size = MAX_FLOWS;
    }

    action send(bit<9> egress_port) {
        ig_intr_tm_md.ucast_egress_port = egress_port;
    }

    table l1_forwarding {
        key = {
            ig_intr_md.ingress_port : exact;
        }
        actions = {
            send;
        }
        size = 512;
    }

    action add_bridged_md() {
        hdr.bridged_md.setValid();
        hdr.bridged_md.pkt_type = PKT_TYPE_NORMAL;
        hdr.bridged_md.ingress_tstamp = ig_prsr_md.global_tstamp;  // Global timestamp (ns) taken upon arrival at ingress.
        hdr.bridged_md.flow_id = ig_md.flow_id; 
    }

    action set_normal_pkt() {
        add_bridged_md();
    }

    apply {
        // ingress rate limiting
        #if defined(RL) 
        publisher_meter_tbl.apply();
        meter_colors.apply();

        if (ig_md.pkt_color == MeterColor_t.RED) {
            drop_packet();
        }
        #endif

        #if defined(FQ_CODEL)
        subscriptions_tbl.apply();
        flow_id_to_queue_id.apply();
        if (hdr.tcp.isValid()) {
            fq_codel_ingress.apply(hdr, ig_md, ig_intr_md, ig_prsr_md, ig_dprsr_md, ig_intr_tm_md);
        } else if (hdr.udp.isValid()) {
            ig_intr_tm_md.qid = 7;
        }
        #endif

        #if defined(P4_CODEL) 
        l1_forwarding.apply();
        #endif

        add_bridged_md();
        if (ig_intr_md.ingress_port == RECIRC_PORT) {
            hdr.bridged_md.ingress_tstamp = hdr.ethernet.src_addr;
        }
    }
}

control SwitchEgress(
        inout header_t hdr,
        inout eg_metadata_t eg_md,
        in egress_intrinsic_metadata_t eg_intr_md,
        in egress_intrinsic_metadata_from_parser_t eg_intr_md_from_prsr,
        inout egress_intrinsic_metadata_for_deparser_t eg_intr_md_for_dprsr,
        inout egress_intrinsic_metadata_for_output_port_t eg_intr_oport_md) {

    CoDelEgress() codel_egress;
    FQCodelEgress() fq_codel_egress;

    action compute_timedelta_hit() {
        eg_md.deq_timedelta = eg_intr_md_from_prsr.global_tstamp[31:0] - eg_md.ingress_tstamp[31:0];
    }

    table compute_timedelta {
        actions = {
            compute_timedelta_hit;
        }
        default_action = compute_timedelta_hit;
    }

    action compute_e2e_latency_hit(){
        eg_md.e2e_latency = eg_intr_md_from_prsr.global_tstamp[31:0] - hdr.ethernet.src_addr[31:0];
    }

    table compute_e2e_latency {
        actions = {
            compute_e2e_latency_hit;
        }
        default_action = compute_e2e_latency_hit;
    }

    apply {
        compute_timedelta.apply();

        // Run FQ-CoDel logic
        #if defined(FQ_CODEL)
        if (hdr.tcp.isValid() && eg_intr_md.egress_port != RECIRC_PORT) {
            fq_codel_egress.apply(hdr, eg_md, eg_intr_md, eg_intr_md_from_prsr, eg_intr_md_for_dprsr, eg_intr_oport_md);
        }
        #endif

        #if defined(P4_CODEL) 
        codel_egress.apply(eg_md.ingress_tstamp, eg_intr_md_from_prsr.global_tstamp, eg_intr_md.egress_port, eg_intr_md_for_dprsr);
        #endif

        #if defined(RUG_TOF1)
        if (hdr.tcp.isValid() || hdr.udp.isValid()) {
            hdr.ethernet.src_addr[31:0] = eg_md.deq_timedelta;  // Queue Delay
            hdr.ethernet.src_addr[36:32] = eg_intr_md.egress_qid; // 5 bits
            hdr.ethernet.src_addr[47:37] = 0;
        }
        #endif

        hdr.bridged_md.setInvalid();
    }
}

Pipeline(SwitchIngressParser(),
       SwitchIngress(),
       SwitchIngressDeparser(),
       SwitchEgressParser(),
       SwitchEgress(),
       SwitchEgressDeparser()) pipe;

Switch(pipe) main;
