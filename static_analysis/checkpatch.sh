#!/bin/bash

# Wrapper around checkpatch.pl to filter results.

set -e

export STATIC_ANALYSIS_SRC_DIR=$(dirname $(readlink -f $0))

source ${STATIC_ANALYSIS_SRC_DIR}/../envsetup.sh
export OUT_DIR=$(readlink -m ${OUT_DIR:-${ROOT_DIR}/out/${BRANCH}})
export DIST_DIR=$(readlink -m ${DIST_DIR:-${OUT_DIR}/dist})
mkdir -p ${DIST_DIR}

export KERNEL_DIR=$(readlink -m ${KERNEL_DIR})

CHECKPATCH_PL_PATH="${KERNEL_DIR}/scripts/checkpatch.pl"
GIT_SHA1="HEAD"
BLACKLIST_FILE="${STATIC_ANALYSIS_SRC_DIR}/checkpatch_blacklist"
RESULTS_PATH=${DIST_DIR}/checkpatch_violations.txt

# Parse flags.
CHECKPATCH_ARGS=()
while [[ $# -gt 0 ]]; do
  next="$1"
  case ${next} in --git_sha1)
    GIT_SHA1="$2"
    shift
    ;;
  --blacklisted_checks)
    BLACKLIST_FILE="$2"
    shift
    ;;
  --help)
    echo "Gets a patch from git, passes it checkpatch.pl, and then reports"
    echo "the subset of violations we choose to enforce."
    echo ""
    echo "Usage: $0"
    echo "  <--git_sha1 nnn> (Defaults to HEAD)"
    echo "  <--blacklisted_checks path_to_file> (Defaults to checkpatch_blacklist)"
    echo "  <args for checkpatch.pl>"
    exit 0
    ;;
  *)
    CHECKPATCH_ARGS+=("$1")
    ;;
  esac
  shift
done


echo "========================================================"
echo " Running static analysis..."
echo "    Using KERNEL_DIR: " ${KERNEL_DIR}
echo "    Results written to: " ${RESULTS_PATH}

# Update blacklist.
if [[ -f "${BLACKLIST_FILE}" ]]; then
  IGNORED_ERRORS=$(grep -v '^#' ${BLACKLIST_FILE} | paste -s -d,)
  if [[ -n "${IGNORED_ERRORS}" ]]; then
    CHECKPATCH_ARGS+=(--ignore)
    CHECKPATCH_ARGS+=("${IGNORED_ERRORS}")
  fi
fi

# Check the patch for errors.
cd ${KERNEL_DIR}
git format-patch -1 --stdout "${GIT_SHA1}" | "${CHECKPATCH_PL_PATH}" ${CHECKPATCH_ARGS[*]} - | { grep -E -A1 "^ERROR:" || true; } > ${RESULTS_PATH}

echo "======Finished running static analysis.======"

