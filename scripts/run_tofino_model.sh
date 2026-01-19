export SDE=~/bf-sde-9.13.4
export SDE_INSTALL=$SDE/install
export PATH=$SDE_INSTALL/bin:$PATH
# sudo $SDE_INSTALL/bin/veth_setup.sh

$SDE/run_tofino_model.sh -p qos_p4bsub
