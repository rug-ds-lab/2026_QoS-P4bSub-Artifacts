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
import math
import os

from lib.Interface import *

from scapy.all import Packet
from scapy.all import Ether, IP, UDP, TCP, Raw

from lib.EventPacket import Event
from lib.types import *

port1=1
port2=2
recirc_port=68
sport=50000
qid=0

pkt_size=550

class RecircTest(Interface):
    def setUp(self):
        Interface.setUp(self)

    def runTest(self):
        self.flow_id_to_queue_id_add_mapping(flow_id=sport, queue_id=qid)
        random_payload = os.urandom(500) 
        pkt = Ether(src='00:00:00:00:00:01', dst='00:00:00:00:00:02') / IP(src='10.10.10.1', dst='10.10.10.2') / TCP(sport=sport, dport=9092) / Raw(load=random_payload)
        
        exp_pkt = pkt
        exp_pkt = Mask(exp_pkt)
        exp_pkt.set_do_not_care_packet(Ether, "src")
        print("Sending a packet on port : %d." % (port1))
        send_packet(self, port_id=port1, pkt=pkt, count=1)
        print("Expecting a packet on port : %d." % (port2))
        verify_packets(self, exp_pkt, ports=[port2])
  
        print("Sending a packet on port : %d." % (port1))
        send_packet(self, port_id=port1, pkt=pkt, count=1)
        print("Expecting a packet on port : %d." % (port2))
        verify_packets(self, exp_pkt, ports=[port2])

        print("Sending a packet on port : %d." % (port1))
        send_packet(self, port_id=port1, pkt=pkt, count=1)
        print("Expecting no packet on port : %d." % (port2))
        # verify_packets(self, exp_pkt, ports=[port2])
        verify_no_other_packets(self)

        print("Waiting ...")
        time.sleep(7)
        print("Sending a packet on port : %d." % (port1))
        send_packet(self, port_id=port1, pkt=pkt, count=1)
        print("Expecting a packet on port : %d." % (port2))
        verify_packets(self, exp_pkt, ports=[port2])

    def tearDown(self):
        time.sleep(1)
        Interface.tearDown(self)
