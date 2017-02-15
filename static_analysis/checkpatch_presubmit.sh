#!/bin/bash

# Wrapper around checkpatch.sh to gather necessary information from the
# dist dir. Notably, this includes the git_sha1 and whether to suppress
# the check for post-submit.

set -e

export STATIC_ANALYSIS_SRC_DIR=$(dirname $(readlink -f $0))

source ${STATIC_ANALYSIS_SRC_DIR}/../envsetup.sh
export OUT_DIR=$(readlink -m ${OUT_DIR:-${ROOT_DIR}/out/${BRANCH}})
export DIST_DIR=$(readlink -m ${DIST_DIR:-${OUT_DIR}/dist})

REPO_PROP_PATH=${DIST_DIR}/repo.prop
BUILD_INFO_PATH=${DIST_DIR}/BUILD_INFO

verify_file_exists() {
  if [[ ! -f ${REPO_PROP_PATH} ]]; then
    echo "Missing ${REPO_PROP_PATH}"
    exit 1
  fi
}

# Skip checkpatch for postsubmit (b/35390488)
verify_file_exists ${BUILD_INFO_PATH}
set +e
grep -E build_type.*pending "${BUILD_INFO_PATH}"
if [[ $? -ne 0 ]]; then
   echo "Did not identify a presubmit build. Exiting."
   exit 0
fi
set -e

# Pick the correct patch to test.
verify_file_exists ${REPO_PROP_PATH}
GIT_SHA1=$(grep -E "${KERNEL_DIR} [0-9a-f]+" "${REPO_PROP_PATH}" | awk '{print $2}')
if [[ -z ${GIT_SHA1} ]]; then
  echo "Failed to find git sha1 for ${KERNEL_DIR}."
  exit 1
fi

${STATIC_ANALYSIS_SRC_DIR}/checkpatch.sh --git_sha1 ${GIT_SHA1} $@

