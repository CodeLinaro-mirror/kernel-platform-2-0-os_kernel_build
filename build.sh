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

# For module file Signing with the kernel (if needed)
FILE_SIGN_BIN=scripts/sign-file
SIGN_SEC=certs/signing_key.pem
SIGN_CERT=certs/signing_key.x509
SIGN_ALGO=sha512

source "${ROOT_DIR}/build/envsetup.sh"

export MAKE_ARGS=$@
export OUT_DIR=$(readlink -m ${OUT_DIR:-${ROOT_DIR}/out/${BRANCH}})
export DIST_DIR=$(readlink -m ${DIST_DIR:-${OUT_DIR}/dist})

cd ${ROOT_DIR}

export CLANG_TRIPLE CROSS_COMPILE CROSS_COMPILE_ARM32 ARCH SUBARCH

mkdir -p ${OUT_DIR}
echo "========================================================"
echo " Setting up for build"
set -x
(cd ${KERNEL_DIR} && \
 make O=${OUT_DIR} mrproper && \
 make O=${OUT_DIR} ${DEFCONFIG})
set +x

if [ "${POST_DEFCONFIG_CMDS}" != "" ]; then
  echo "========================================================"
  echo " Running pre-make command(s):"
  set -x
  eval ${POST_DEFCONFIG_CMDS}
  set +x
fi

echo "========================================================"
echo " Building kernel"

if [ -n "${CC}" ]; then
  CC_ARG="CC=${CC}"
fi

set -x
(cd ${OUT_DIR} && \
 make O=${OUT_DIR} ${CC_ARG} -j8 $@)
set +x

if [ "${EXT_MODULES}" != "" ]; then
  echo "========================================================"
  echo " Building external modules"

  for EXT_MOD in ${EXT_MODULES}; do
    pushd ${ROOT_DIR}/${EXT_MOD}
    make KERNEL_SRC=${ROOT_DIR}/${KERNEL_DIR} O=${OUT_DIR} -j8
    MODS=$(find ${ROOT_DIR}/${EXT_MOD} -name "*.ko")
    for FILE in ${MODS}; do
      echo "Signing the module file: ${FILE}"
      ${OUT_DIR}/${FILE_SIGN_BIN} ${SIGN_ALGO} ${OUT_DIR}/${SIGN_SEC} ${OUT_DIR}/${SIGN_CERT} ${FILE}
    done
   popd
  done
fi

if [ "${EXTRA_CMDS}" != "" ]; then
  echo "========================================================"
  echo " Running extra build command(s):"
  set -x
  eval ${EXTRA_CMDS}
  set +x
fi

OVERLAYS_OUT=""
for ODM_DIR in ${ODM_DIRS}; do
  OVERLAY_DIR=${ROOT_DIR}/device/${ODM_DIR}/overlays

  if [ -d ${OVERLAY_DIR} ]; then
    OVERLAY_OUT_DIR=${OUT_DIR}/overlays/${ODM_DIR}
    mkdir -p ${OVERLAY_OUT_DIR}
    make -C ${OVERLAY_DIR} DTC=${OUT_DIR}/scripts/dtc/dtc OUT_DIR=${OVERLAY_OUT_DIR}
    OVERLAYS=$(find ${OVERLAY_OUT_DIR} -name "*.dtbo")
    OVERLAYS_OUT="$OVERLAYS_OUT $OVERLAYS"
  fi
done

mkdir -p ${DIST_DIR}
echo "========================================================"
echo " Copying files"
for FILE in ${FILES}; do
  if [ -f ${OUT_DIR}/${FILE} ]; then
    echo "  $FILE"
    cp ${OUT_DIR}/${FILE} ${DIST_DIR}/
  else
    echo "  $FILE does not exist, skipping"
  fi
done

for FILE in ${OVERLAYS_OUT}; do
  OVERLAY_DIST_DIR=${DIST_DIR}/$(dirname ${FILE#${OUT_DIR}/overlays/})
  echo "  ${FILE#${OUT_DIR}/}"
  mkdir -p ${OVERLAY_DIST_DIR}
  cp ${FILE} ${OVERLAY_DIST_DIR}/
done

if [ -n "${IN_KERNEL_MODULES}" ]; then
  MODULES=$(find ${OUT_DIR} -name "*.ko")
  for FILE in ${MODULES}; do
    echo "  ${FILE#${OUT_DIR}/}"
    cp ${FILE} ${DIST_DIR}
  done
fi

if [ "${EXT_MODULES}" != "" ]; then
  echo "========================================================"
  echo " copying external modules files"
  for EXT_MOD in ${EXT_MODULES}; do
    MODS=$(find ${ROOT_DIR}/${EXT_MOD} -name "*.ko")
    for FILE in ${MODS}; do
      echo "  ${FILE#${ROOT_DIR}/${EXT_MOD}/}"
      cp ${FILE} ${DIST_DIR}
    done
    echo "Cleaning the module tree... "
    pushd ${ROOT_DIR}/${EXT_MOD}
    make KERNEL_SRC=${ROOT_DIR}/${KERNEL_DIR} O=${OUT_DIR} clean
    popd
  done
fi

echo "========================================================"
echo " Files copied to ${DIST_DIR}"
