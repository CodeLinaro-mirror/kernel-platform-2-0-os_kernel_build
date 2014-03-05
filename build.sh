#!/bin/bash

# Usage:
#   ./build.sh <out directory> <make options>*
#
# Example:
#   ./build.sh out/dist -j24

set -e

cd $(dirname $0)
ROOT_DIR=$(pwd)

. build.config
DIST_DIR=${1:-out/dist}
if [ $# -ge 1 ]; then
  shift
fi

export PATH=${ROOT_DIR}/prebuilts/linux-x86/bin:${PATH}

mkdir -p out
echo "========================================================"
echo "Setting up for build"
(cd kernel && \
 make O=${ROOT_DIR}/out ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} ${DEFCONFIG} && \
 make mrproper)

echo "========================================================"
echo "Building Kernel"
(cd out && \
 make O=${ROOT_DIR}/out ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} $@)

mkdir -p ${DIST_DIR}
for FILE in ${FILES}; do
  echo "Copying $FILE"
  cp out/${FILE} ${DIST_DIR}/
done
