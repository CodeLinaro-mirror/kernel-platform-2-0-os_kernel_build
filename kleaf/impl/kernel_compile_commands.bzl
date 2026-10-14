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

"""Support `compile_commands.json`."""

load(
    ":common_providers.bzl",
    "CompileCommandsInfo",
    "KernelEnvToolchainsInfo",
)
load(":hermetic_toolchain.bzl", "hermetic_toolchain")
load(":utils.bzl", "utils")

visibility("//build/kernel/kleaf/...")

def _kernel_compile_commands_transition_impl(_settings, _attr):
    return {
        "//build/kernel/kleaf/impl:build_compile_commands": True,
    }

_kernel_compile_commands_transition = transition(
    implementation = _kernel_compile_commands_transition_impl,
    inputs = [],
    outputs = [
        "//build/kernel/kleaf/impl:build_compile_commands",
    ],
)

def _kernel_compile_commands_impl(ctx):
    hermetic_tools = hermetic_toolchain.get(ctx)

    if ctx.attr.kernel_build:
        # buildifier: disable=print
        print("WARNING: {}: kernel_compile_commands.kernel_build is deprecated. Use deps instead.".format(
            ctx.label,
        ))

    all_deps = ([ctx.attr.kernel_build] if ctx.attr.kernel_build else []) + ctx.attr.deps
    with_vars = depset(
        transitive = [dep[CompileCommandsInfo].with_vars for dep in all_deps],
        order = "postorder",
    )
    common_out_dirs = depset(
        transitive = [dep[CompileCommandsInfo].common_out_dirs for dep in all_deps],
        order = "postorder",
    )

    merged_with_vars = ctx.actions.declare_file(
        "{}/merged_compile_commands_with_vars.json".format(ctx.attr.name),
    )
    merge_args = ctx.actions.args()
    merge_args.add("--output", merged_with_vars)
    merge_args.add_all("--with_vars", with_vars)
    ctx.actions.run(
        mnemonic = "MergeCompileCommands",
        inputs = with_vars,
        outputs = [merged_with_vars],
        executable = ctx.executable._merge_compile_commands,
        arguments = [merge_args],
        progress_message = "Merging compile_commands_with_vars.json %{label}",
    )

    common_out_dirs_written = utils.write_depset(common_out_dirs, "common_out_dirs.txt")

    script = ctx.actions.declare_file(ctx.attr.name + ".sh")

    script_content = hermetic_tools.setup
    script_content += ctx.attr._toolchains[KernelEnvToolchainsInfo].setup_env_var_cmd

    # Handle rewritting clang path under user request
    #  using the option --real_clang_path
    script_content += """
        # Default values
        destination=
        full_clang_path=0
        out_directory="${BUILD_WORKSPACE_DIRECTORY}/out/bazel/compdb"

        # Parse command-line options
        while [[ ${#} -gt 0 ]]; do
          opt=${1}
          case "${opt}" in
            --real_clang_path)
              full_clang_path=1
              shift
              ;;
            --out_directory)
              out_directory="${2}"
              shift
              shift
              ;;
            *) # Positional argument
              if [[ -z "${destination}" ]]; then
                destination="${1}"
                shift
              else
                echo "ERROR: Too many positional arguments." >&2
                exit 1
              fi
              ;;
          esac
        done
    """

    script_content += """
        OUTPUT=${{destination:-${{BUILD_WORKSPACE_DIRECTORY}}/compile_commands.json}}

        while read -r compile_commands_common_out_dir; do
            if [[ -z "${{compile_commands_common_out_dir}}" ]]; then
                continue
            fi
            mkdir -p "${{out_directory}}/${{compile_commands_common_out_dir}}"
            rsync -a --prune-empty-dirs \\
                --include '*/' \\
                --include '*.c' \\
                --include '*.S' \\
                --include '*.h' \\
                --include '*.cflags' \\
                --include '*.asflags' \\
                --include '*.ldflags' \\
                --exclude '*' "${{BUILD_WORKSPACE_DIRECTORY}}/${{compile_commands_common_out_dir}}/" "${{out_directory}}/${{compile_commands_common_out_dir}}/"

            # Replace in extra files for this target
            extra_files=$(find "${{out_directory}}/${{compile_commands_common_out_dir}}" -name '*.cflags' -o -name '*.asflags')
            for extra_file in ${{extra_files}}
            do
                sed -i'' \\
                    -e "s:\\${{COMPDB_OUT_DIR_BASE}}:${{out_directory}}:g" \\
                    -e "s:\\${{ROOT_DIR}}:${{BUILD_WORKSPACE_DIRECTORY}}:g" \\
                    "${{extra_file}}"
            done
        done < {common_out_dirs_file}

        sed -e "s:\\${{COMPDB_OUT_DIR_BASE}}:${{out_directory}}:g" \\
            -e "s:\\${{ROOT_DIR}}:${{BUILD_WORKSPACE_DIRECTORY}}:g" \\
            {merged_with_vars} > "${{OUTPUT}}"

        if [[ "${{full_clang_path}}" == "1" ]]; then
            real_clang_path=$(realpath $(which clang))
            sed -i "s:\\"command\\"\\: \\"clang:\\"command\\"\\: \\"${{real_clang_path}}:g" "${{OUTPUT}}"
        fi

        echo "Written to ${{OUTPUT}}"
    """.format(
        common_out_dirs_file = common_out_dirs_written.depset_file.short_path,
        merged_with_vars = merged_with_vars.short_path,
    )
    ctx.actions.write(script, script_content, is_executable = True)

    return DefaultInfo(
        executable = script,
        runfiles = ctx.runfiles(
            files = [
                merged_with_vars,
            ],
            transitive_files = depset(
                transitive = [
                    common_out_dirs_written.depset,
                    hermetic_tools.deps,
                    ctx.attr._toolchains[KernelEnvToolchainsInfo].all_files,
                ],
            ),
        ),
    )

kernel_compile_commands = rule(
    implementation = _kernel_compile_commands_impl,
    doc = """Define an executable that creates `compile_commands.json` from kernel targets.""",
    attrs = {
        "kernel_build": attr.label(
            doc = """The `kernel_build` rule to extract from.

                Deprecated:
                    Use `deps` instead.
            """,
            providers = [CompileCommandsInfo],
        ),
        "deps": attr.label_list(
            doc = """The targets to extract from. The following are allowed:

                - [`kernel_build`](#kernel_build)
                - [`kernel_module`](#kernel_module)
                - [`ddk_module`](#ddk_module)
                - [`kernel_module_group`](#kernel_module_group)
            """,
            providers = [CompileCommandsInfo],
        ),
        "_merge_compile_commands": attr.label(
            default = "//build/kernel/kleaf/impl:merge_compile_commands",
            executable = True,
            cfg = "exec",
        ),
        # Allow any package to use kernel_compile_commands because it is a public API.
        # The ACK source tree may be checked out anywhere; it is not necessarily //common
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
        "_toolchains": attr.label(
            default = "//build/kernel/kleaf/impl:kernel_toolchains",
            providers = [KernelEnvToolchainsInfo],
            cfg = "exec",
        ),
    },
    executable = True,
    cfg = _kernel_compile_commands_transition,
    subrules = [utils.write_depset],
    toolchains = [hermetic_toolchain.type],
)
