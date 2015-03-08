#!/bin/bash

# Usage:
#   build/build.sh <make options>*
# or:
#   OUT_DIR=<out dir> DIST_DIR=<dist dir> build/build.sh <make options>*
#
# Example:
#   OUT_DIR=output DIST_DIR=dist build/build.sh -j24

set -e

export ROOT_DIR=$(readlink -f $(dirname $0)/..)
export MAKE_ARGS=$@

. ${ROOT_DIR}/build.config
export OUT_DIR=$(readlink -m ${OUT_DIR:-${ROOT_DIR}/out/${BRANCH}})
export DIST_DIR=$(readlink -m ${DIST_DIR:-${OUT_DIR}/dist})

export PATH=${ROOT_DIR}/${LINUX_GCC_CROSS_COMPILE_PREBUILTS_BIN}:${PATH}
cd ${ROOT_DIR}

mkdir -p ${OUT_DIR}
echo "========================================================"
echo " Setting up for build"
set -x
(cd ${KERNEL_DIR} && \
 make O=${OUT_DIR} ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} ${DEFCONFIG} && \
 make mrproper)
set +x

echo "========================================================"
echo " Building kernel"
set -x
(cd ${OUT_DIR} && \
 make O=${OUT_DIR} ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} -j8 $@)
set +x

if [ "${EXTRA_CMDS}" != "" ]; then
  echo "========================================================"
  echo " Running extra build command(s):"
  set -x
  eval ${EXTRA_CMDS}
  set +x
fi

mkdir -p ${DIST_DIR}
echo "========================================================"
echo " Copying files"
for FILE in ${FILES}; do
  echo "  $FILE"
  cp ${OUT_DIR}/${FILE} ${DIST_DIR}/
done

echo "========================================================"
echo " Files copied to ${DIST_DIR}"
