export SDE=~/bf-sde-9.13.4
export SDE_INSTALL=$SDE/install
export PATH=$SDE_INSTALL/bin:$PATH

$SDE/run_p4_tests.sh -p qos_p4bsub -t ~/qos-p4bsub/ptf-tests/ -s quantum
# $SDE/run_p4_tests.sh -p qos_p4bsub -t ~/qos-p4bsub/ptf-tests/ -s subscriptions


