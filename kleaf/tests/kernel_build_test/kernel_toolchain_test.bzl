# Copyright (C) 2022 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Tests kernel_build.toolchain_version."""

load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@kernel_toolchain_info//:dict.bzl", "CLANG_VERSION")
load(
    "//build/kernel/kleaf/impl:constants.bzl",
    "MODULES_STAGING_ARCHIVE",
    "UNSTRIPPED_MODULES_ARCHIVE",
)
load("//build/kernel/kleaf/impl:kernel_build.bzl", "kernel_build")
load("//build/kernel/kleaf/impl:kernel_filegroup.bzl", "kernel_filegroup")
load("//build/kernel/kleaf/tests/utils:pass_analysis_test.bzl", "pass_analysis_test")

def kernel_toolchain_test(name):
    """Tests that building against kernel_filegroup does not fail toolchain version checks.

    Args:
        name: name of the test suite
    """

    filegroup_name = name + "_filegroup"

    write_file(
        name = filegroup_name + "_staging_archive",
        out = filegroup_name + "_staging_archive/" + MODULES_STAGING_ARCHIVE,
    )
    write_file(
        name = filegroup_name + "_unstripped_modules",
        out = filegroup_name + "_unstripped_modules/" + UNSTRIPPED_MODULES_ARCHIVE,
    )

    write_file(
        name = filegroup_name + "_gki_info",
        out = filegroup_name + "_gki_info/gki-info.txt",
        content = [
            "KERNEL_RELEASE=99.98.97",
            "",
        ],
    )

    native.platform(
        name = filegroup_name + "_target_platform",
        constraint_values = [
            "@platforms//os:android",
            "@platforms//cpu:arm64",
        ],
    )

    native.platform(
        name = filegroup_name + "_exec_platform",
        constraint_values = [
            "@platforms//os:linux",
            "@platforms//cpu:x86_64",
        ],
    )

    kernel_filegroup(
        name = filegroup_name,
        deps = [
            filegroup_name + "_unstripped_modules",
            filegroup_name + "_staging_archive",
        ],
        gki_artifacts = filegroup_name + "_gki_info",
        target_platform = filegroup_name + "_target_platform",
        exec_platform = filegroup_name + "_exec_platform",
        expected_toolchain_version = CLANG_VERSION,
        tags = ["manual"],
    )

    tests = []
    for suffix in ("_device_kernel", "/device_kernel_with_slash"):
        kernel_build(
            name = name + suffix,
            base_kernel = filegroup_name,
            outs = [],
            pahole = "//build/kernel/kleaf/tests:fake_pahole",
            make_goals = ["Image"],
            tags = ["manual"],
        )

        pass_analysis_test(
            name = name + suffix + "_analysis_test",
            target_under_test = name + suffix,
        )
        tests.append(name + suffix + "_analysis_test")

    native.test_suite(
        name = name,
        tests = tests,
    )
