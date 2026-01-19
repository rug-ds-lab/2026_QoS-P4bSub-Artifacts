import logging

from ptf import config
import ptf.testutils as testutils
from ptf.mask import *
from bfruntime_client_base_tests import BfRuntimeTest
from p4testutils.misc_utils import *
import bfrt_grpc.bfruntime_pb2 as bfruntime_pb2
import bfrt_grpc.client as gc
import random
import time

from lib.Interface import *

from scapy.all import Packet
from scapy.all import Ether, IP, UDP, Raw

from lib.EventPacket import Event
from lib.types import *

logger = get_logger()
swports = get_sw_ports()

num_pipes = int(testutils.test_param_get('num_pipes'))
pipes = list(range(num_pipes))

# Hitless HA Support
client_id = 0
p4_name = "p4bsub-qos"
profile_name = 'pipe'
base_pick_path = testutils.test_param_get("base_pick_path")
base_put_path = testutils.test_param_get("base_put_path")
arch = testutils.test_param_get("arch")
if not base_pick_path:
  base_pick_path = "install/share/" + arch + "pd/"
if not base_put_path:
  base_put_path = "/tmp"

port1=1
port2=2
port3=3
port4=4

EVENT_ETHERTYPE = 0x9966
QUEUING_ETHERTYPE = 0x9977

attr_mask = 0xffff
val_mask = 0x7fff

dont_care_mask = 0x0

event_hdr1 = Event(attribute=AttributeID.PRESSURE,value=15,bos=1)
event_hdr2 = Event(attribute=AttributeID.PRESSURE,value=15,bos=0)/Event(attribute=AttributeID.TEMPERATURE,value=23,bos=1)
event_hdr3 = Event(attribute=AttributeID.PRESSURE,value=15,bos=0)/Event(attribute=AttributeID.TEMPERATURE,value=23,bos=0)/Event(attribute=AttributeID.HUMIDITY,value=65,bos=1)

class EventWithOneAttribute(Interface):
    def setUp(self):
        Interface.setUp(self)

    def runTest(self):
        self.subscriptions_tbl_add_with_send_with_priority(AttributeID.PRESSURE, attr_mask, 15, val_mask, 0, dont_care_mask, 0, dont_care_mask, 0, dont_care_mask, 0, dont_care_mask, egress_port=port2, qos_priority=PriorityID.MEDIUM_PRIORITY, dest_mac=0xefefababdede, match_priority=2)
        self.subscriptions_tbl_add_with_send_with_priority(AttributeID.PRESSURE, attr_mask, 15, val_mask, AttributeID.TEMPERATURE, attr_mask, 23, val_mask, 0, dont_care_mask, 0, dont_care_mask, egress_port=port3, qos_priority=PriorityID.LOW_PRIORITY, dest_mac=0xaabbccddeeff, match_priority=1)
        self.subscriptions_tbl_add_with_send_with_priority(AttributeID.PRESSURE, attr_mask, 15, val_mask, AttributeID.TEMPERATURE, attr_mask, 23, val_mask, AttributeID.HUMIDITY, attr_mask, 65, val_mask, egress_port=port4, qos_priority=PriorityID.HIGH_PRIORITY, dest_mac=0xeeffddccbbaa, match_priority=0)  # priority 0 is the highest priority

        pkt = Ether(src='00:11:22:33:44:55', dst='00:22:33:44:55:66',type=EVENT_ETHERTYPE)/event_hdr1/(60*'x')

        print("Sending %d packet on port %d" % (1, port1))
        send_packet(self, port_id=port1, pkt=pkt, count=1)

        exp_pkt=Ether(src='00:11:22:33:44:55', dst='ef:ef:ab:ab:de:de',type=EVENT_ETHERTYPE)/event_hdr1/(60*'x')
        print("Expecting %d packet on port %d " % (1, port2))
        verify_packets(self, exp_pkt, ports=[port2])

    def tearDown(self):
        Interface.tearDown(self)

class EventWithTwoAttributes(Interface):
    def setUp(self):
        Interface.setUp(self)

    def runTest(self):
        self.subscriptions_tbl_add_with_send_with_priority(AttributeID.PRESSURE, attr_mask, 15, val_mask, 0, dont_care_mask, 0, dont_care_mask, 0, dont_care_mask, 0, dont_care_mask, egress_port=port2, qos_priority=PriorityID.MEDIUM_PRIORITY, dest_mac=0xefefababdede, match_priority=2)
        self.subscriptions_tbl_add_with_send_with_priority(AttributeID.PRESSURE, attr_mask, 15, val_mask, AttributeID.TEMPERATURE, attr_mask, 23, val_mask, 0, dont_care_mask, 0, dont_care_mask, egress_port=port3, qos_priority=PriorityID.LOW_PRIORITY, dest_mac=0xaabbccddeeff, match_priority=1)
        self.subscriptions_tbl_add_with_send_with_priority(AttributeID.PRESSURE, attr_mask, 15, val_mask, AttributeID.TEMPERATURE, attr_mask, 23, val_mask, AttributeID.HUMIDITY, attr_mask, 65, val_mask, egress_port=port4, qos_priority=PriorityID.HIGH_PRIORITY, dest_mac=0xeeffddccbbaa, match_priority=0)  # priority 0 is the highest priority

        pkt = Ether(src='00:11:22:33:44:55', dst='00:22:33:44:55:66',type=EVENT_ETHERTYPE)/event_hdr2/(60*'x')

        print("Sending %d packet on port %d" % (1, port1))
        send_packet(self, port_id=port1, pkt=pkt, count=1)

        exp_pkt = Ether(src='00:11:22:33:44:55', dst='aa:bb:cc:dd:ee:ff',type=EVENT_ETHERTYPE)/event_hdr2/(60*'x')
        print("Expecting %d packet on port %d " % (1, port3))
        verify_packets(self, exp_pkt, ports=[port3])

    def tearDown(self):
        Interface.tearDown(self)

class EventWithThreeAttributes(Interface):
    def setUp(self):
        Interface.setUp(self)

    def runTest(self):
        self.subscriptions_tbl_add_with_send_with_priority(AttributeID.PRESSURE, attr_mask, 15, val_mask, 0, dont_care_mask, 0, dont_care_mask, 0, dont_care_mask, 0, dont_care_mask, egress_port=port2, qos_priority=PriorityID.MEDIUM_PRIORITY, dest_mac=0xefefababdede, match_priority=2)
        self.subscriptions_tbl_add_with_send_with_priority(AttributeID.PRESSURE, attr_mask, 15, val_mask, AttributeID.TEMPERATURE, attr_mask, 23, val_mask, 0, dont_care_mask, 0, dont_care_mask, egress_port=port3, qos_priority=PriorityID.LOW_PRIORITY, dest_mac=0xefefababdede, match_priority=1)
        self.subscriptions_tbl_add_with_send_with_priority(AttributeID.PRESSURE, attr_mask, 15, val_mask, AttributeID.TEMPERATURE, attr_mask, 23, val_mask, AttributeID.HUMIDITY, attr_mask, 65, val_mask, egress_port=port4, qos_priority=PriorityID.HIGH_PRIORITY, dest_mac=0xeeffddccbbaa, match_priority=0)  # priority 0 is the highest priority

        pkt = Ether(src='00:11:22:33:44:55', dst='00:22:33:44:55:66',type=EVENT_ETHERTYPE)/event_hdr3/(60*'x')

        print("Sending %d packet on port %d" % (1, port1))
        send_packet(self, port_id=port1, pkt=pkt, count=1)

        exp_pkt = Ether(src='00:11:22:33:44:55', dst='ee:ff:dd:cc:bb:aa',type=EVENT_ETHERTYPE)/event_hdr3/(60*'x')
        print("Expecting %d packet on port %d " % (1, port4))
        verify_packets(self, exp_pkt, ports=[port4])

    def tearDown(self):
        Interface.tearDown(self)
