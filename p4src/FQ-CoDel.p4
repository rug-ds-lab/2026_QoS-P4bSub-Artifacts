// Constants
// const bit<16> MAX_FLOWS = 1024;        // Maximum number of flows
const bit<32> MAX_QUEUES_PER_PORT = 32;   // Maximum number of physical queues per port
const bit<32> MAX_QUEUES = 16384;         // Total number of queues
const bit<32> MTU_SIZE = 1514;  
const bit<32> QUANTUM = 151400;     // Quantum of bytes per flow per round (e.g., MTU size)
const bit<32> TARGET_0 = 5000000;   // Target queuing delay (5 ms in nanoseconds)
const bit<32> TARGET_1 = 20000000;  // Target queuing delay (20 ms in nanoseconds)
const bit<32> TARGET_2 = 40000000;  // Target queuing delay (40 ms in nanoseconds)
const bit<32> INTERVAL = 100000000;       // Interval (100 ms in nanoseconds)
const bit<32> SQRT_PRECISION = 1000;      // Precision for sqrt lookup table scaling

#define NOT_DROPPING    0
#define DROPPING        1

struct pair {
    bit<32> next_drop_time; 
    bit<32> count; 
}

control FQCodelIngress(
        inout header_t hdr,
        inout ig_metadata_t ig_md,
        in ingress_intrinsic_metadata_t ig_intr_md,
        in ingress_intrinsic_metadata_from_parser_t ig_prsr_md,
        inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md,
        inout ingress_intrinsic_metadata_for_tm_t ig_intr_tm_md) {

    Register<bit<32>, bit<32>>(size=MAX_QUEUES, initial_value=QUANTUM) byte_credits;  // Deficit counter per queue

    RegisterAction<bit<32>, bit<32>, bit<1>>(byte_credits) update_credit = {
        void apply(inout bit<32> value, out bit<1> reset) {
            if (value < (bit<32>) ig_md.pkt_length) {
                value = QUANTUM;  // quantum = 1514 Bytes
                reset = 1;
            } else {
                value = value - (bit<32>) ig_md.pkt_length;
                reset = 0;
            }
        }
    };

    action drop_packet() { 
        ig_dprsr_md.drop_ctl = 0x1;
        exit;
    }

    action compute_pkt_size_hit() {
        ig_md.pkt_length = hdr.ipv4.total_len + ETHERNET_FCS_HDR_LEN;
    }
        
    table compute_pkt_size {
        actions = {
            compute_pkt_size_hit();
        }
        default_action = compute_pkt_size_hit;
    }

    apply {

#if defined(BYTES_LIMIT_WITH_RECIRC)
        compute_pkt_size.apply();
        ig_md.recirc_flag = update_credit.execute(ig_md.qid);
        if (ig_md.recirc_flag == 1 && ig_intr_md.ingress_port != RECIRC_PORT) {
            // relieving queues from one heavy flow using packet recirculation 
            ig_intr_tm_md.ucast_egress_port = RECIRC_PORT;
        }
#endif
    }
}

// Control block for FQ-CoDel logic (egress pipeline)
control FQCodelEgress(inout header_t hdr,
        inout eg_metadata_t eg_md,
        in egress_intrinsic_metadata_t eg_intr_md,
        in egress_intrinsic_metadata_from_parser_t eg_intr_md_from_prsr,
        inout egress_intrinsic_metadata_for_deparser_t eg_intr_md_for_dprsr,
        inout egress_intrinsic_metadata_for_output_port_t eg_intr_oport_md) {

    // State variables (registers)
    Register<bit<32>, bit<32>>(size=MAX_QUEUES, initial_value=0) current_time;
    Register<pair, bit<32>>(size=MAX_QUEUES, initial_value={0, 0}) drop_count_and_time;
    Register<bit<32>, bit<32>>(size=MAX_QUEUES, initial_value=0) drop_state;  // 0 = NOT_DROPPING, 1 = DROPPING
    Register<bit<32>, bit<32>>(size=MAX_QUEUES, initial_value=TARGET_0) target_reg;  // Sojourn target per queue

    action drop_packet() { 
        eg_intr_md_for_dprsr.drop_ctl = 0x1;
        // exit;
    }

    RegisterAction<bit<32>, bit<32>, bit<1>>(drop_state) update_codel_state = {
        void apply(inout bit<32> value, out bit<1> first_above) {
            if (value == NOT_DROPPING && eg_md.sojourn_time_is_above_target == 1w0x1) {
                first_above = 1w0x1;
            } else {
                first_above = 1w0x0;
            }
            if (eg_md.sojourn_time_is_above_target == 1w0x1) {
                value = DROPPING;
            } else {
                value = NOT_DROPPING;
            }
        }
    };

	MathUnit< bit<32> > (true, -1, 20,
		{0x46, 0x48, 0x4b, 0x4e,
		0x52, 0x56, 0x5a, 0x60,
		0x66, 0x6f, 0x79, 0x87,
		0x0, 0x0, 0x0, 0x0}) sqrtn;

    // A dual-width 32-bit register action 
    RegisterAction<pair, bit<32>, bit<1>>(drop_count_and_time) update_drop_count_and_time = {
        void apply(inout pair value, out bit<1> decide_to_drop){
            decide_to_drop = 1w0x0;
            if (eg_md.first_above_target == 1w0x1) {
                value.count = 1;
                value.next_drop_time = eg_md.current_time + INTERVAL;
            } else if (eg_md.current_time > value.next_drop_time) {
                value.count = value.count + 1;
                value.next_drop_time = value.next_drop_time + sqrtn.execute(value.count);
                decide_to_drop = 1w0x1;
            }
        }
    };

    action compute_above_target_hit() {
        // eg_md.delta_sojourn_time_target = eg_md.sojourn_target |-| eg_md.sojourn_time;
        eg_md.delta_sojourn_time_target = TARGET_0 |-| eg_md.sojourn_time;
    }

    table compute_above_target {
        actions = {
            compute_above_target_hit;
        }
        default_action = compute_above_target_hit;
    }

    action set_global_qid(bit<32> index) {
        eg_md.qid = index;
    }

    table per_port_qid_to_global_qid {
        key = {
            eg_intr_md.egress_port : exact;
            eg_intr_md.egress_qid : exact; // 0..31
        }
        actions = {
            set_global_qid;
        }
        size = MAX_QUEUES;
    }

    action set_sojourn_target(bit<32> target) {
        eg_md.sojourn_target = target;
    }

    apply {
        eg_intr_md_for_dprsr.drop_ctl = 0x0;
        
        per_port_qid_to_global_qid.apply();

        // Get current time (egress timestamp)
        eg_md.current_time = (bit<32>) eg_intr_md_from_prsr.global_tstamp;
        current_time.write(eg_md.qid, eg_md.current_time);

        // Calculate queuing delay (sojourn_time)
        eg_md.sojourn_time = eg_md.deq_timedelta;

        eg_md.sojourn_target = target_reg.read(eg_md.qid);

        compute_above_target.apply();
        if (eg_md.delta_sojourn_time_target == 0) {
            eg_md.sojourn_time_is_above_target = 1w0x1;
        } else {
            eg_md.sojourn_time_is_above_target = 1w0x0;
        }
        eg_md.first_above_target = update_codel_state.execute(eg_md.qid);
        eg_md.drop_flag = update_drop_count_and_time.execute(eg_md.qid);

        if ((eg_md.drop_flag == 1w0x1) && (eg_md.sojourn_time_is_above_target == 1w0x1)) {
            // Drop the packet
            drop_packet();
        }
    }
}
