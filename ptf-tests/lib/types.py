from collections import namedtuple

class PriorityID:
    BEST_EFFORT = 0x0
    LOW_PRIORITY = 0x1
    MEDIUM_PRIORITY = 0x2
    HIGH_PRIORITY = 0x3
    
class AttributeID:
    TEMPERATURE = 0x1 
    PRESSURE = 0x2
    HUMIDITY = 0x3
    ACOUSTIC = 0x4
    FLOW = 0x5
    VIBRATION = 0x6
    GAS = 0x7
    WATER_LEVEL = 0x8
    PROXIMITY = 0x9
    OPTICAL = 0x10