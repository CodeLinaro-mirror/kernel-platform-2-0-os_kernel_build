#!/bin/bash

# Usage:
#   build/build.sh <make options>*
# or:
#   OUT_DIR=<out dir> DIST_DIR=<dist dir> build/build.sh <make options>*
#
# Example:
#   OUT_DIR=output DIST_DIR=dist build/build.sh -j24

set -e

# rel_path <to> <from>
# Generate relative directory path to reach directory <to> from <from>
function rel_path() {
	local to=$1
	local from=$2
	local path=
	local stem=
	local prevstem=
	[ -n "$to" ] || return 1
	[ -n "$from" ] || return 1
	to=$(readlink -e "$to")
	from=$(readlink -e "$from")
	[ -n "$to" ] || return 1
	[ -n "$from" ] || return 1
	stem=${from}/
	while [ "${to#$stem}" == "${to}" -a "${stem}" != "${prevstem}" ]; do
		prevstem=$stem
		stem=$(readlink -e "${stem}/..")
		[ "${stem%/}" == "${stem}" ] && stem=${stem}/
		path=${path}../
	done
	echo ${path}${to#$stem}
}

export ROOT_DIR=$(readlink -f $(dirname $0)/..)

# For module file Signing with the kernel (if needed)
FILE_SIGN_BIN=scripts/sign-file
SIGN_SEC=certs/signing_key.pem
SIGN_CERT=certs/signing_key.x509
SIGN_ALGO=sha512

source "${ROOT_DIR}/build/envsetup.sh"

export MAKE_ARGS=$@
export OUT_DIR=$(readlink -m ${OUT_DIR:-${ROOT_DIR}/out/${BRANCH}})
export KERNEL_OUT_DIR=$(readlink -m ${OUT_DIR}/${KERNEL_DIR})
export MODULES_STAGING_DIR=$(readlink -m ${OUT_DIR}/staging)
export DIST_DIR=$(readlink -m ${DIST_DIR:-${OUT_DIR}/dist})

cd ${ROOT_DIR}

export CLANG_TRIPLE CROSS_COMPILE CROSS_COMPILE_ARM32 ARCH SUBARCH

mkdir -p ${KERNEL_OUT_DIR}
echo "========================================================"
echo " Setting up for build"
set -x
(cd ${KERNEL_DIR} && \
 make O=${KERNEL_OUT_DIR} mrproper && \
 make O=${KERNEL_OUT_DIR} ${DEFCONFIG})
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
(cd ${KERNEL_OUT_DIR} && \
 make O=${KERNEL_OUT_DIR} ${CC_ARG} -j8 $@)
set +x

rm -rf ${MODULES_STAGING_DIR}
mkdir -p ${MODULES_STAGING_DIR}

if [ -n "${IN_KERNEL_MODULES}" ]; then
  echo "========================================================"
  echo " Installing kernel modules into staging directory"

  (cd ${KERNEL_OUT_DIR} && \
   make O=${KERNEL_OUT_DIR} ${CC_ARG} INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=${MODULES_STAGING_DIR} modules_install)
fi

if [ "${EXT_MODULES}" != "" ]; then
  echo "========================================================"
  echo " Building external modules and installing them into staging directory"

  for EXT_MOD in ${EXT_MODULES}; do
    # The path that we pass in via the variable M needs to be a relative path
    # relative to the kernel source directory. The source files will then be
    # looked for in ${KERNEL_DIR}/${EXT_MOD_REL} and the object files (i.e. .o
    # and .ko) files will be stored in ${KERNEL_OUT_DIR}/${EXT_MOD_REL}. If we
    # instead set M to an absolute path, then object (i.e. .o and .ko) files
    # are stored in the module source directory which is not what we want.
    EXT_MOD_REL=$(rel_path ${ROOT_DIR}/${EXT_MOD} ${KERNEL_DIR})
    # The output directory must exist before we invoke make. Otherwise, the
    # build system behaves horribly wrong.
    mkdir -p ${KERNEL_OUT_DIR}/${EXT_MOD_REL}
    set -x
    make -C ${EXT_MOD} M=${EXT_MOD_REL} KERNEL_SRC=${ROOT_DIR}/${KERNEL_DIR} O=${KERNEL_OUT_DIR} -j8 "$@"
    make -C ${EXT_MOD} M=${EXT_MOD_REL} KERNEL_SRC=${ROOT_DIR}/${KERNEL_DIR} O=${KERNEL_OUT_DIR} INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=${MODULES_STAGING_DIR} modules_install
    set +x
  done

fi

MODULES=$(find ${MODULES_STAGING_DIR} -type f -name "*.ko")
if [ -n "${MODULES}" ]; then
  echo "========================================================"
  echo " Signing modules"

  for FILE in ${MODULES}; do
    echo "Signing the module file: ${FILE#${MODULES_STAGING_DIR}/}"
    ${KERNEL_OUT_DIR}/${FILE_SIGN_BIN} ${SIGN_ALGO} ${KERNEL_OUT_DIR}/${SIGN_SEC} ${KERNEL_OUT_DIR}/${SIGN_CERT} ${FILE}
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
    OVERLAY_OUT_DIR=${KERNEL_OUT_DIR}/overlays/${ODM_DIR}
    mkdir -p ${OVERLAY_OUT_DIR}
    make -C ${OVERLAY_DIR} DTC=${KERNEL_OUT_DIR}/scripts/dtc/dtc OUT_DIR=${OVERLAY_OUT_DIR}
    OVERLAYS=$(find ${OVERLAY_OUT_DIR} -name "*.dtbo")
    OVERLAYS_OUT="$OVERLAYS_OUT $OVERLAYS"
  fi
done

mkdir -p ${DIST_DIR}
echo "========================================================"
echo " Copying files"
for FILE in ${FILES}; do
  if [ -f ${KERNEL_OUT_DIR}/${FILE} ]; then
    echo "  $FILE"
    cp -p ${KERNEL_OUT_DIR}/${FILE} ${DIST_DIR}/
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

if [ -n "${MODULES}" ]; then
  echo "========================================================"
  echo " Copying modules files"
  if [ -n "${IN_KERNEL_MODULES}" -o "${EXT_MODULES}" != "" ]; then
    for FILE in ${MODULES}; do
      echo "  ${FILE#${MODULES_STAGING_DIR}/}"
      cp ${FILE} ${DIST_DIR}
    done
  fi
fi

echo "========================================================"
echo " Files copied to ${DIST_DIR}"
