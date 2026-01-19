import sys
#  pip3 install scapy

from ptf.testutils import *
import ptf.dataplane as dataplane

from scapy.all import *

try:
    import scapy.config
    import scapy.route
    import scapy.layers.l2
    import scapy.layers.inet
    import scapy.main
    from scapy.all import Packet
except ImportError:
    sys.exit("Need to install scapy for packet parsing")

class Event(Packet):
    name = "EventHeader"
    fields_desc = [
        ShortField("attribute", 0), # 2 bytes
        BitField("value", 0, 15), 
        BitField("bos", 0, 1)
    ]

class QueueInfo(Packet):
    name = "QueueInfo"
    fields_desc = [
        BitField("pad0", 0, 6), 
        BitField("deq_timedelta", 0, 18)
    ]