// #define P4_CODEL
#define FQ_CODEL
#define BYTES_LIMIT_WITH_RECIRC
#define RL
// #define HW_TEST
// #define RUG_TOF1
// #define RUG_TOF2
#define TOFINO_MODEL_TEST

typedef bit<48> mac_addr_t;
typedef bit<32> ipv4_addr_t;
typedef bit<16> ether_type_t;
typedef bit<8> ip_protocol_t;
typedef bit<3> mirror_type_t;
typedef bit<8> pkt_type_t;

const ether_type_t ETHERTYPE_IPV4 = 16w0x0800;
const ip_protocol_t IP_PROTOCOLS_TCP = 6;
const ip_protocol_t IP_PROTOCOLS_UDP = 17;
const bit<16> ETHERNET_HDR_LEN = 14; 
const bit<16> FCS_LEN = 4; 
const bit<16> ETHERNET_FCS_HDR_LEN = ETHERNET_HDR_LEN + FCS_LEN; 

/* Tof1 uses ports 64-71 in each pipe as recirc, we expose 68-71. */
#if defined(TOFINO_MODEL_TEST) 
const  PortId_t RECIRC_PORT = 68;  // on Tofino Model
#endif
#if defined(HW_TEST) 
const  PortId_t RECIRC_PORT = 196;  // in Hardware
#endif

const ether_type_t EVENT_ETHERTYPE = 16w0x9966;
const ether_type_t QUEUING_ETHERTYPE = 16w0x9977;

const mirror_type_t MIRROR_TYPE_I2E = 1;
const pkt_type_t PKT_TYPE_NORMAL = 1;
const pkt_type_t PKT_TYPE_MIRROR = 2;

const bit<2> EVENT_DEPTH = 3;

// Constants
const bit<32> MAX_FLOWS = 65536;  // Maximum number of flows
const bit<32> PUBLISHERS_TABLE_SIZE = 1024;
const bit<32> SUBSCRIPTIONS_TABLE_SIZE = 1024;  // 69764

enum bit<1> queue_state {
    NOT_DROPPING = 1w0x0, 
    DROPPING = 1w0x1
}

enum bit<2> priority_id {
    BEST_EFFORT = 2w0x0, 
    LOW_PRIORITY = 2w0x1,
    MEDIUM_PRIORITY = 2w0x2,
    HIGH_PRIORITY = 2w0x3
}

struct ig_metadata_t {
    bit<1> do_ing_mirroring;  // Enable ingress mirroring
    MirrorId_t ing_mir_ses;  // Ingress mirror session ID
    pkt_type_t pkt_type;
    bit<2>  priority;
    bit<32> flow_id;  // Flow ID 
    bit<8>  pkt_color;
    bit<1>  drop_flag;
    bit<48> ingress_tstamp;
    // Ingress Scheduling
    bit<16> pkt_length;  // Size of the current packet
    bit<1> recirc_flag;
    bit<32> qdepth;
    bit<32> qid;
    // bit<1> old_flow;  // marking the end of enqueuing "iteration"
}

struct eg_metadata_t {
    pkt_type_t pkt_type;
    bit<32> flow_id;  // Flow ID (hash of 5-tuple)
    bit<48> ingress_tstamp;
    bit<32> deq_timedelta;
    // Egress queue monitoring
    bit<32> qid;
    bit<32> qdepth;
    // Egress AQM
    bit<32> current_time;  // Current timestamp (egress time)
    bit<32> sojourn_time;  // Calculated queuing delay
    bit<32> delta_sojourn_time_target;     
    bit<1> drop_flag;
    bit<1> sojourn_time_is_above_target;
    bit<1> first_above_target;
    bit<32> sojourn_target;
    bit<32> e2e_latency;
}

