#!/bin/bash

# Usage:
#   build/build_test.sh

export MAKE_ARGS=$@
export ROOT_DIR=$(dirname $(readlink -f $0))
export NET_TEST=${ROOT_DIR}/../kernel/tests/net/test
export BUILD_CONFIG=build/build.config.net_test

test=all_tests.sh
set -e
# Source the per-device build config in order to set $BRANCH.
# envsetup.sh will later source build.config.net_test, which
# will overwrite the variables we care about.
source ${ROOT_DIR}/build.config
source ${ROOT_DIR}/envsetup.sh

echo "========================================================"
echo " Building kernel and running tests "

cd ${KERNEL_DIR}/*
$NET_TEST/run_net_test.sh --builder --branch $BRANCH $test
echo $?
echo "======Finished running tests======"
