#!/bin/bash

# Usage:
#   build/copy_to_tree.sh <android tree root>
# or:
#   DIST_DIR=<dist dir>
#     KEYS_DIR=<path to signing_key.x509 and signing_key.priv pair>
#     build/copy_to_tree.sh <android tree root>
#
# Example:
#   KEYS_DIR=output build/copy_to_tree.sh /work/seed

ROOT_DIR=$(readlink -f $(dirname $0)/..)
. ${ROOT_DIR}/build.config

# Locations copied from build.sh
OUT_DIR=$(readlink -m ${OUT_DIR:-${ROOT_DIR}/out/${BRANCH}})
DIST_DIR=$(readlink -m ${DIST_DIR:-${OUT_DIR}/dist})

DEV_DIR=$(readlink -f $1)
DEST_KERNEL_DIR=${DEV_DIR}/${OUT_KERNEL_DIR}

# Utility functions
write_prebuilt_text ()
{
    echo "include \$(CLEAR_VARS)" >> $2
    echo "LOCAL_MODULE := $1" >> $2
    echo "LOCAL_SRC_FILES := $1" >> $2
    echo "LOCAL_MODULE_CLASS := ETC" >> $2
    echo "LOCAL_ODM_MODULE := true" >> $2
    echo "LOCAL_MODULE_PATH := \$(TARGET_OUT)/modules" >> $2
    echo "include \$(BUILD_PREBUILT)" >> $2
    echo >> $2
}

# Set key file vars and check their existance
if [ -n "${KEYS_DIR}" ]; then
    KEYS_DIR=$(readlink -f ${KEYS_DIR})
    PRIV_KEY=${KEYS_DIR}/signing_key.priv
    if [ ! -f ${PRIV_KEY} ]; then
        echo "Cannot find ${KEYS_DIR}/signing_key.priv"
        exit -1
    fi

    PUB_KEY=${KEYS_DIR}/signing_key.x509
    if [ ! -f ${PUB_KEY} ]; then
        echo "Cannot find ${KEYS_DIR}/signing_key.priv"
        exit -1
    fi

    # KERNEL_DIR comes from build.config and sign-file should not change locations
    SIGN_FILE=${ROOT_DIR}/${KERNEL_DIR}/scripts/sign-file
    if [ ! -f ${SIGN_FILE} -a ]; then
        echo "Cannot find sign-file at ${SIGN_FILE}"
        exit -1
    fi
fi

echo "========================================================"
echo " Copying Modules"

# Start fresh Android.mk
echo -e  "LOCAL_PATH := \$(call my-dir)\n" > \
    ${DEST_KERNEL_DIR}/Android.mk

# Copy and sign modules and create Android.mk for modules
MODULES=$(find ${DIST_DIR} -maxdepth 1 -name \*.ko)
for MODULE in ${MODULES}; do
    DEST_FILE=${DEST_KERNEL_DIR}/$(basename ${MODULE})
    echo "  ${MODULE}"
    cp ${MODULE} ${DEST_FILE}

    [ -n "${KEYS_DIR}" ] && ${SIGN_FILE} sha512 ${PRIV_KEY} ${PUB_KEY} ${DEST_FILE}

    write_prebuilt_text $(basename ${MODULE}) ${DEST_KERNEL_DIR}/Android.mk
done
echo

echo "========================================================"
echo " Copying Kernel Image"
echo "  ${DIST_DIR}/zImage-dtb"
# Copy kernel image
cp ${DIST_DIR}/zImage-dtb ${DEST_KERNEL_DIR}/
echo

echo "========================================================"
echo " Copying Overlays"

# Find all destinations for overlays and create fresh makefiles
DEST_OVERLAY_DIRS=$(find ${DIST_DIR} -name \*.dtbo | xargs dirname | sort | uniq)

for DEST_OVERLAY_DIR in ${DEST_OVERLAY_DIRS}; do
    echo -e  "LOCAL_PATH := \$(call my-dir)\n" > \
        ${DEV_DIR}/device/${DEST_OVERLAY_DIR#${DIST_DIR}}-kernel/Android.mk
done

# Copy and sign device tree overlays and create Android.mk for overlays
OVERLAYS=$(find ${DIST_DIR} -name \*.dtbo)

for OVERLAY in ${OVERLAYS}; do
    DEST_FILE_DIR=${DEV_DIR}/device/$(dirname ${OVERLAY#${DIST_DIR}})-kernel
    DEST_FILE=${DEST_FILE_DIR}/$(basename ${OVERLAY})
    echo "  ${OVERLAY}"
    cp ${OVERLAY} ${DEST_FILE}

    [ -n "${KEYS_DIR}" ] && ${SIGN_FILE} sha512 ${PRIV_KEY} ${PUB_KEY} ${DEST_FILE}

    write_prebuilt_text $(basename ${OVERLAY}) ${DEST_FILE_DIR}/Android.mk
done
