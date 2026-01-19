# QoS-P4bSub Artifacts (NOMS 2026)

This repository contains the source code and experimental scripts for our NOMS 2026 submission on network-centric Pub/Sub QoS.

## 1. Prerequisites
- **Hardware:** Intel Tofino ASIC (SDE v9.13.4)
- **Software:** Python 3.8+, PTF Framework

## 2. Build Instructions
To compile the P4 pipeline, run:
```bash
export SDE=~/bf-sde-9.13.4
export SDE_INSTALL=$SDE/install
export PATH=$SDE_INSTALL/bin:$PATH

Update /path/to/2026_QoS-P4bSub-Artifacts/p4src/qos-p4bsub.p4 in ./scripts/build.sh then run it 
./scripts/build.sh
```

## 3. Testing with Tofino Model 
```bash
export SDE=~/bf-sde-9.13.4
export SDE_INSTALL=$SDE/install
export PATH=$SDE_INSTALL/bin:$PATH
sudo $SDE_INSTALL/bin/dma_setup.sh
sudo $SDE_INSTALL/bin/veth_setup.sh

./scripts/run_tofino_model.sh 
./scripts/run_app.sh
./scripts/run_ptf_tests.sh
```

## 4. Testing on Tofino ASIC  
```bash
grep -i huge /proc/meminfo

echo '2048' | sudo tee -a /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
2048

export SDE=~/bf-sde-9.13.4
export SDE_INSTALL=$SDE/install
export PATH=$SDE_INSTALL/bin:$PATH
sudo $SDE_INSTALL/bin/dma_setup.sh

sudo ~/bf-sde-9.13.4/install/bin/bf_kpkt_mod_load $SDE_INSTALL
sudo modprobe cdc_ether
sudo ip link set enx020000000002 up
sudo ip link set dev ens1 up
sudo ethtool ens1

./scripts/build.sh
./scripts/run_app.sh

ucli
pm
# Rug-Tofino-1
port-del 1/-
port-add 1/- 10G NONE
an-set 1/- 2  
port-enb 1/-
port-del 2/-
port-add 2/- 10G NONE
an-set 2/- 2  
port-enb 2/-
port-del 3/-
port-add 3/- 10G NONE
an-set 3/- 2  
port-enb 3/-
port-del 4/-
port-add 4/- 10G NONE
an-set 4/- 2  
port-enb 4/-

# Rug-Tofino-2
port-del 1/-
port-add 1/- 10G NONE
an-set 1/- 2  
port-enb 1/-
port-del 2/-
port-add 2/- 10G NONE
an-set 2/- 2  
port-enb 2/-

bfrt.qos_p4bsub.pipe.SwitchEgress.fq_codel_egress.target_reg.mod(0,5000000)
bfrt.qos_p4bsub.pipe.SwitchEgress.fq_codel_egress.target_reg.mod(1,5000000)
bfrt.qos_p4bsub.pipe.SwitchEgress.fq_codel_egress.target_reg.mod(2,5000000)
bfrt.qos_p4bsub.pipe.SwitchEgress.fq_codel_egress.target_reg.mod(3,20000000)
bfrt.qos_p4bsub.pipe.SwitchEgress.fq_codel_egress.target_reg.mod(4,20000000)
bfrt.qos_p4bsub.pipe.SwitchEgress.fq_codel_egress.target_reg.mod(5,20000000)
bfrt.qos_p4bsub.pipe.SwitchEgress.fq_codel_egress.target_reg.mod(6,40000000)
bfrt.qos_p4bsub.pipe.SwitchEgress.fq_codel_egress.target_reg.mod(7,40000000)
bfrt.qos_p4bsub.pipe.SwitchEgress.fq_codel_egress.target_reg.dump(from_hw=True)

# Setting port rate to 100Mbits/sec
# Rug-Tofino-1
bfrt.tf1.tm.port.sched_cfg.mod(0x94, True, 'BF_SPEED_1G')
bfrt.tf1.tm.port.sched_shaping.mod(0x94, 'BPS', 'UPPER', 0x186BE, 0x2400)

# Rug-Tofino-2
bfrt.tf1.tm.port.sched_cfg.mod(0x84, True, 'BF_SPEED_1G')
bfrt.tf1.tm.port.sched_shaping.mod(0x84, 'BPS', 'UPPER', 0x186BE, 0x2400)

bfrt.tf1.tm.port.sched_cfg.mod(0x86, True, 'BF_SPEED_1G')
bfrt.tf1.tm.port.sched_shaping.mod(0x86, 'BPS', 'UPPER', 0x186BE, 0x2400)
```
