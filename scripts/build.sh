export SDE=~/bf-sde-9.13.4
export SDE_INSTALL=$SDE/install
export PATH=$SDE_INSTALL/bin:$PATH

sudo rm -rf *.log
sudo rm -rf build
mkdir build && cd build 

cmake $SDE/p4studio/ \
 -DCMAKE_INSTALL_PREFIX=$SDE/install \
 -DCMAKE_MODULE_PATH=$SDE/cmake \
 -DP4_NAME=qos_p4bsub\
 -DP4_PATH=/path/to/2026_QoS-P4bSub-Artifacts/p4src/qos-p4bsub.p4 

sudo make qos_p4bsub && make install