# source this file. Don't run it.
#
# Usage:
#   source build/envsetup.sh
#     to setup your path and cross compiler so that a kernel build command is
#     just:
#       make -j24


# TODO: Use a $(gettop) style method.
export ROOT_DIR=$PWD

export BUILD_CONFIG=${BUILD_CONFIG:-build.config}
. ${ROOT_DIR}/${BUILD_CONFIG}

echo "========================================================"
echo "= build config: ${ROOT_DIR}/${BUILD_CONFIG}"
cat ${ROOT_DIR}/${BUILD_CONFIG}

# Mitigate dup paths
PATH=${PATH//"${ROOT_DIR}/${LINUX_GCC_CROSS_COMPILE_PREBUILTS_BIN}:"}
export PATH=${ROOT_DIR}/${LINUX_GCC_CROSS_COMPILE_PREBUILTS_BIN}:${PATH}

if [ ! -z "${LZ4_PREBUILTS_BIN}" ] ; then
    PATH=${PATH//"${ROOT_DIR}/${LZ4_PREBUILTS_BIN}:"}
    export PATH=${ROOT_DIR}/${LZ4_PREBUILTS_BIN}:${PATH}
fi

if [ ! -z "${DTC_PREBUILTS_BIN}" ] ; then
    PATH=${PATH//"${ROOT_DIR}/${DTC_PREBUILTS_BIN}:"}
    export PATH=${ROOT_DIR}/${DTC_PREBUILTS_BIN}:${PATH}
fi

if [ ! -z "${LIBUFDT_PREBUILTS_BIN}" ] ; then
    PATH=${PATH//"${ROOT_DIR}/${LIBUFDT_PREBUILTS_BIN}:"}
    export PATH=${ROOT_DIR}/${LIBUFDT_PREBUILTS_BIN}:${PATH}
fi

echo
echo "PATH=${PATH}"
echo

export $(sed -n -e 's/\([^=]\)=.*/\1/p' ${ROOT_DIR}/${BUILD_CONFIG})

# verifies that defconfig matches the DEFCONFIG
function check_defconfig() {
    (cd ${OUT_DIR} && \
     make O=${OUT_DIR} savedefconfig)
    echo Verifying that savedefconfig matches ${KERNEL_DIR}/arch/${ARCH}/configs/${DEFCONFIG}
    RES=0
    diff ${OUT_DIR}/defconfig ${KERNEL_DIR}/arch/${ARCH}/configs/${DEFCONFIG} ||
      RES=$?
    if [ ${RES} -ne 0 ]; then
        echo ERROR: savedefconfig does not match ${KERNEL_DIR}/arch/${ARCH}/configs/${DEFCONFIG}
    fi
    return ${RES}
}

