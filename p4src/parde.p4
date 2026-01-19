// ---------------------------------------------------------------------------
// Ingress parser
// ---------------------------------------------------------------------------
parser TofinoIngressParser(
        packet_in pkt,
        out ingress_intrinsic_metadata_t ig_intr_md) {
    state start {
        pkt.extract(ig_intr_md);
        transition select(ig_intr_md.resubmit_flag) {
            1 : parse_resubmit;
            0 : parse_port_metadata;
        }
    }

    state parse_resubmit {
        // Parse resubmitted packet here.
        transition reject;
    }

    state parse_port_metadata {
        pkt.advance(PORT_METADATA_SIZE);
        transition accept;
    }
}

parser SwitchIngressParser(
        packet_in pkt,
        out header_t hdr,
        out ig_metadata_t ig_md,
        out ingress_intrinsic_metadata_t ig_intr_md) {

    TofinoIngressParser() tofino_parser;

    state start {
        /* Initialize Metadata to Zero */
        ig_md = {
            do_ing_mirroring = 0,
            ing_mir_ses = 0,
            pkt_type = 0,
            priority = 0,
            flow_id = 0,
            pkt_color = 0,
            drop_flag = 0,
            ingress_tstamp = 0,
            // Ingress Scheduling
            pkt_length = 0,
            recirc_flag = 0,
            qdepth = 0,
            qid= 0
        };
        tofino_parser.apply(pkt, ig_intr_md);
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            EVENT_ETHERTYPE : parse_event;
            QUEUING_ETHERTYPE : parse_queuing;
            ETHERTYPE_IPV4 : parse_ipv4;
            default : accept;
        }
    }

    state parse_queuing {
        pkt.extract(hdr.queue);
        transition accept;
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            IP_PROTOCOLS_TCP : parse_tcp;
            IP_PROTOCOLS_UDP : parse_udp;
            default : accept;
        }
    }

    state parse_tcp {
        pkt.extract(hdr.tcp);
        transition accept;
    }

    state parse_udp {
        pkt.extract(hdr.udp);
        // pkt.extract(hdr.event);
        transition accept;
    }

    state parse_event {
        pkt.extract(hdr.event.next);
        transition select(hdr.event.last.bos) {
            0 : parse_event;
            1 : accept;
        }
    }
}

// ---------------------------------------------------------------------------
// Ingress Deparser
// ---------------------------------------------------------------------------
control SwitchIngressDeparser(
            packet_out pkt,
            inout header_t hdr,
            in ig_metadata_t ig_md,
            in ingress_intrinsic_metadata_for_deparser_t dprsr_md) {

    apply {        
        // pkt.emit(hdr);
        pkt.emit(hdr.bridged_md);
        pkt.emit(hdr.ethernet);
        pkt.emit(hdr.queue);
        pkt.emit(hdr.ipv4);
        pkt.emit(hdr.udp);
        pkt.emit(hdr.tcp);
    }
}

parser SwitchEgressParser(
        packet_in pkt,
        out header_t hdr,
        out eg_metadata_t eg_md,
        out egress_intrinsic_metadata_t eg_intr_md) {

    state start {
        eg_md = {
            pkt_type = 0,
            flow_id = 0,
            ingress_tstamp = 0,
            deq_timedelta = 0,
            qid = 0,
            qdepth = 0,
            current_time = 0,
            sojourn_time = 0,
            delta_sojourn_time_target = 0,    
            drop_flag = 0,
            sojourn_time_is_above_target = 0,
            first_above_target = 0,
            sojourn_target = 0,
            e2e_latency = 0
        };
        pkt.extract(eg_intr_md);
        transition parse_bridged_md;
    }

    state parse_bridged_md {
        pkt.extract(hdr.bridged_md);
        /* copy bridged metadata fields to eg_md fields */
        eg_md.pkt_type = hdr.bridged_md.pkt_type;
        eg_md.ingress_tstamp = hdr.bridged_md.ingress_tstamp;
        eg_md.flow_id = hdr.bridged_md.flow_id;
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            EVENT_ETHERTYPE : parse_event;
            QUEUING_ETHERTYPE : parse_queuing;
            ETHERTYPE_IPV4 : parse_ipv4;
            default : accept;
        }
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            IP_PROTOCOLS_TCP : parse_tcp;
            IP_PROTOCOLS_UDP : parse_udp;
            default : accept;
        }
    }

    state parse_tcp {
        pkt.extract(hdr.tcp);
        transition accept;
    }

    state parse_udp {
        pkt.extract(hdr.udp);
        transition accept;
    }

    state parse_queuing {
        pkt.extract(hdr.queue);
        transition accept;
    }

    state parse_event {
        pkt.extract(hdr.event.next);
        transition select(hdr.event.last.bos) {
            0 : parse_event;
            1 : accept;
        }
    }
}

control SwitchEgressDeparser(
        packet_out pkt,
        inout header_t hdr,
        in eg_metadata_t eg_md,
        in egress_intrinsic_metadata_for_deparser_t ig_intr_dprs_md) {
    apply {
        // pkt.emit(hdr.ethernet);
        // pkt.emit(hdr.queuing_info);
        // pkt.emit(hdr.event[0]);
        // pkt.emit(hdr.event[1]);
        // pkt.emit(hdr.event[2]);
        pkt.emit(hdr); 
    }
}
