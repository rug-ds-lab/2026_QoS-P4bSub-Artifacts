header ethernet_h {
    mac_addr_t dst_addr;
    mac_addr_t src_addr;
    bit<16> ether_type;
}

header topic_h {
    // bit<32> timestamp;  /* occurance time of the event. */
    bit<16> topic;      /* example: weather. */
}

// qos_pubsub
header event_h {
    bit<16> attribute;  /* example: humidity, temperature. */
    bit<15> value;      /* example: 45% humidity and 23 degrees celsius temperature . */
    bit<1> bos;
}

header ipv4_h {
    bit<4> version; 
    bit<4> ihl;
    bit<8> diffserv;
    bit<16> total_len;
    bit<16> identification;
    bit<3> flags;
    bit<13> frag_offset;
    bit<8> ttl;
    bit<8> protocol;
    bit<16> hdr_checksum;
    ipv4_addr_t src_addr;
    ipv4_addr_t dst_addr;
}

header udp_h {
    bit<16> src_port;
    bit<16> dst_port;
    bit<16> hdr_length;
    bit<16> checksum;
}

header tcp_h {
    bit<16> src_port;
    bit<16> dst_port;
    bit<32> seq_no;
    bit<32> ack_no;
    bit<4> data_offset;
    bit<4> res;
    bit<8> flags;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgent_ptr;
}

header queuing_info_h {
    QueueId_t egress_qid;
    bit<19> qdepth;
    // bit<16> pkt_length;
}

header bridged_metadata_h {
    pkt_type_t pkt_type;
    bit<32> flow_id;
    bit<48> ingress_tstamp;
}

header mirror_h {
    pkt_type_t pkt_type;
    bit<32> flow_id;
    bit<48> ingress_tstamp;
}

struct header_t {
    bridged_metadata_h bridged_md;
    ethernet_h ethernet;
    queuing_info_h queue;
    ipv4_h ipv4;
    udp_h udp;
    tcp_h tcp;
    topic_h topic;
    event_h[EVENT_DEPTH] event;
}
