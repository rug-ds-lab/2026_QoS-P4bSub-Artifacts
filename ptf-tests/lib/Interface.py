import logging

from ptf import config
import ptf.testutils as testutils
from bfruntime_client_base_tests import BfRuntimeTest
import bfrt_grpc.bfruntime_pb2 as bfruntime_pb2
import bfrt_grpc.client as gc
import random
import time

num_pipes = int(testutils.test_param_get('num_pipes'))
pipes = list(range(num_pipes))

# Hitless HA Support
client_id = 0
p4_name = "qos_p4bsub"
profile_name = 'pipe'
base_pick_path = testutils.test_param_get("base_pick_path")
base_put_path = testutils.test_param_get("base_put_path")
arch = testutils.test_param_get("arch")
testutils.test_param_get("arch") == "tofino"
if not base_pick_path:
  base_pick_path = "install/share/" + arch + "pd/"
if not base_put_path:
  base_put_path = "/tmp"

class Interface(BfRuntimeTest):
    def setUp(self):
        client_id = 0
        p4_name = "qos_p4bsub"
        BfRuntimeTest.setUp(self, client_id, p4_name)
        self.bfrt_info = self.interface.bfrt_info_get(p4_name)
        self.target = gc.Target(device_id=0, pipe_id=0xffff)

    def l1_forwarding_tbl_add_with_send(self, port_in, port_out):
        print("Adding Entry to l1_forwarding Table Ingress Port : %d ==> Egress Port : %d" % (port_in, port_out))
        l1_forwarding_tbl = self.bfrt_info.table_get("SwitchIngress.l1_forwarding")
        key = l1_forwarding_tbl.make_key([gc.KeyTuple('ig_intr_md.ingress_port', port_in)])
        data = l1_forwarding_tbl.make_data([gc.DataTuple('egress_port', port_out)],
                                              'SwitchIngress.send')
        l1_forwarding_tbl.entry_add(self.target, [key], [data])

    def per_port_qid_to_global_qid(self, port, qid, index):
        print("Adding Port ID : %d, Egress Queue ID : %d ==> Index : %d" % (port, qid, index))
        egress_qid_tbl = self.bfrt_info.table_get("SwitchEgress.fq_codel_egress.per_port_qid_to_global_qid")
        key = egress_qid_tbl.make_key([gc.KeyTuple('eg_intr_md.egress_port', port),
                               gc.KeyTuple('eg_intr_md.egress_qid', qid)])
        data = egress_qid_tbl.make_data([gc.DataTuple('index', index)],
                                'SwitchEgress.fq_codel_egress.set_global_qid')
        egress_qid_tbl.entry_add(self.target, [key], [data])
    
    def flow_id_to_queue_id_add_mapping(self, flow_id, queue_id):
        print("Adding Flow ID : %d ==> Queue ID : %d" % (flow_id, queue_id))
        qid_tbl = self.bfrt_info.table_get("SwitchIngress.fq_codel_ingress.flow_id_to_queue_id")
        key = qid_tbl.make_key([gc.KeyTuple('ig_md.flow_id', flow_id)])
        data = qid_tbl.make_data([gc.DataTuple('queue_id', queue_id)],
                                              'SwitchIngress.fq_codel_ingress.mapping')
        qid_tbl.entry_add(self.target, [key], [data])

    def publisher_meter_tbl_add_with_set_meter_color(self, flow_id, cir_kbps, pir_kbps, cbs_kbits, pbs_kbits):
        print("Configuring Publisher Meter with Flow ID : %d " % (flow_id))
        publisher_meter_tbl = self.bfrt_info.table_get("SwitchIngress.publisher_meter_tbl")
        key = publisher_meter_tbl.make_key([gc.KeyTuple('ig_md.flow_id', flow_id)])
        data = publisher_meter_tbl.make_data([gc.DataTuple('$METER_SPEC_CIR_KBPS', cir_kbps),
                                              gc.DataTuple('$METER_SPEC_PIR_KBPS', pir_kbps),
                                              gc.DataTuple('$METER_SPEC_CBS_KBITS', cbs_kbits),
                                              gc.DataTuple('$METER_SPEC_PBS_KBITS', pbs_kbits)],
                                              'SwitchIngress.set_meter_color')

        publisher_meter_tbl.entry_add(self.target, [key], [data])

    def subscriptions_tbl_add_with_send_with_priority(self, attr1, attr1_mask, val1, val1_mask, attr2, attr2_mask, val2, val2_mask, attr3, attr3_mask, val3, val3_mask, egress_port, qos_priority, dest_mac, match_priority):
        print("Adding Subscription Priority ID %d ==> to Egress Port ID %d Dest MAC addr %x " % (qos_priority, egress_port, dest_mac))
        subscriptions_tbl = self.bfrt_info.table_get("SwitchIngress.subscriptions_tbl")
        key = subscriptions_tbl.make_key([gc.KeyTuple('$MATCH_PRIORITY', match_priority),
                                          gc.KeyTuple('hdr.event$0.attribute', attr1, attr1_mask),
                                          gc.KeyTuple('hdr.event$0.value', val1, val1_mask),
                                          gc.KeyTuple('hdr.event$1.attribute', attr2, attr2_mask),
                                          gc.KeyTuple('hdr.event$1.value', val2, val2_mask),
                                          gc.KeyTuple('hdr.event$2.attribute', attr3, attr3_mask),
                                          gc.KeyTuple('hdr.event$2.value', val3, val3_mask)])
        data = subscriptions_tbl.make_data([gc.DataTuple('egress_port', egress_port),
                                            gc.DataTuple('priority', qos_priority),
                                            gc.DataTuple('mac_addr', dest_mac)],
                                            'SwitchIngress.send_with_priority')
        subscriptions_tbl.entry_add(self.target, [key], [data])

    def interval_div_sqrt_count_tbl_add_value(self, pkt_count, value):
        print("Populate Precomputed sqrt(count = %d) lookup table (for INTERVAL/sqrt(count) = %d) " % (pkt_count, value))
        sqrt_count_tbl = self.bfrt_info.table_get("SwitchEgress.fq_codel_egress.interval_div_sqrt_count")
        key = sqrt_count_tbl.make_key([gc.KeyTuple('meta.current_count', pkt_count)])
        data = sqrt_count_tbl.make_data([gc.DataTuple('val', value)],
                                                'SwitchEgress.fq_codel_egress.calculate')

        sqrt_count_tbl.entry_add(self.target, [key], [data])

    # def tm_port_sched_cfg(self, port_id, enable, speed):
    #     print("Configuring Port ID: %d " %  port_id)
    #     self.port_sched_cfg_table = self.bfrt_info.table_get("tf1.tm.port.sched_cfg")
    #     self.port_sched_cfg_table.entry_mod(self.target,
    #         [self.port_sched_cfg_table.make_key([gc.KeyTuple('dev_port', port_id)])],
    #         [self.port_sched_cfg_table.make_data([gc.DataTuple('max_rate_enable', enable),
    #                                               gc.DataTuple('scheduling_speed', speed)])])
        
    # def tm_port_sched_shaping(self, port_id, unit, prov, rate, burst):
    #     print("Configuring Port ID: %d " %  port_id)
    #     self.port_sched_cfg_table = self.bfrt_info.table_get("tf1.tm.port.sched_shaping")
    #     self.port_sched_cfg_table.entry_mod(self.target,
    #         [self.port_sched_cfg_table.make_key([gc.KeyTuple('dev_port', port_id)])],
    #         [self.port_sched_cfg_table.make_data([gc.DataTuple('unit', unit),
    #                                               gc.DataTuple('provisioning', prov),
    #                                               gc.DataTuple('max_rate', rate),
    #                                               gc.DataTuple('max_burst_size', burst)])])

    def mirror_cfg_table_add_session_port(self, sid, port):
        print("Mirror Config - using session: %d for Egress Port: %d" % (sid, port))
        mirror_cfg_table = self.bfrt_info.table_get("$mirror.cfg")
        mirror_cfg_table.entry_add(self.target,
                    [mirror_cfg_table.make_key([gc.KeyTuple('$sid', sid)])],
                    [mirror_cfg_table.make_data([gc.DataTuple('$direction', str_val="INGRESS"),
                            gc.DataTuple('$ucast_egress_port', port),
                            gc.DataTuple('$ucast_egress_port_valid', bool_val=True),
                            gc.DataTuple('$session_enable', bool_val=True)],
                            '$normal')])
        
    def mirror_cfg_table_delete_session(self, sid):
        print("Mirror Config - deleting session %d " % sid) 
        mirror_cfg_table = self.bfrt_info.table_get("$mirror.cfg")
        mirror_cfg_table.entry_del(self.target,
                    [mirror_cfg_table.make_key([gc.KeyTuple('$sid', sid)])])
        
    def tearDown(self):
        # time.sleep(1)
        # l1_forwarding_tbl = self.bfrt_info.table_get("SwitchIngress.l1_forwarding")
        qid_tbl = self.bfrt_info.table_get("SwitchIngress.fq_codel_ingress.flow_id_to_queue_id")
        # sqrt_count_tbl = self.bfrt_info.table_get("SwitchEgress.fq_codel_egress.interval_div_sqrt_count")
        # publisher_meter_tbl = self.bfrt_info.table_get("SwitchIngress.publisher_meter_tbl")
        # subscriptions_tbl = self.bfrt_info.table_get("SwitchIngress.subscriptions_tbl")

        # Clean up
        # l1_forwarding_tbl.entry_del(self.target, [])
        qid_tbl.entry_del(self.target, [])
        # sqrt_count_tbl.entry_del(self.target, [])
        # publisher_meter_tbl.entry_del(self.target, [])
        # subscriptions_tbl.entry_del(self.target, [])
        BfRuntimeTest.tearDown(self)