---
name: working-with-ddk
description: >-
  Guides developers through converting a traditional kernel module compiled via kernel_module (Makefile/Kbuild setup) to a Driver Development Kit (DDK) module using ddk_module (BUILD.bazel setup) in Kleaf. Maps Kbuild lines to Bazel attributes and explains headers, configs, and build performance.
---

# Converting a Kernel Module to a DDK Module

This skill guides you through migrating a traditional kernel module configured via `Makefile` or `Kbuild` to a Bazel-based configuration using the **Driver Development Kit (DDK)** in Kleaf.

> **IMPORTANT (Guideline for the AI Assistant / Developer):**
> Before performing any module conversions or creating `BUILD` files, read and analyze the reference targets and build patterns defined inside the Kleaf DDK examples directory at [build/kernel/kleaf/tests/ddk_examples](../../../kleaf/tests/ddk_examples/).
> These directories provide working reference implementations for conditional dependencies, pKVM hypervisor libraries, centralized configs, and other advanced configurations.

---

## 1. Core Principle: 1-to-1 Mapping

When migrating to the DDK, the standard rule is: **One `ddk_module` target per `.ko` output file.**

> **WARNING:**
> Do not use `outs` (plural) with DDK. The `ddk_module` rule accepts a single output file via the `out` attribute.
> If your existing configuration compiles multiple `.ko` files, declare a separate `ddk_module` for each.

### Downstream Compatibility for Multi-`.ko` Targets
If you are migrating an existing `kernel_module` that compiled multiple modules using `outs = ["a.ko", "b.ko"]`, downstream targets (such as `kernel_modules_install`) may still reference the original target name.
To split the target without breaking downstream configurations:
1. Define a separate `ddk_module` target for each output file.
2. Define a `kernel_module_group` target named after the original target, listing the new `ddk_module` targets in `srcs`:
```python
# Original target name: my_driver_package
ddk_module(
    name = "driver_a",
    out = "a.ko",
    srcs = ["a.c"],
    kernel_build = "//common:kernel_aarch64",
)

ddk_module(
    name = "driver_b",
    out = "b.ko",
    srcs = ["b.c"],
    kernel_build = "//common:kernel_aarch64",
)

kernel_module_group(
    name = "my_driver_package",
    srcs = [
        ":driver_a",
        ":driver_b",
    ],
)
```


### Single-Source Modules
For simple modules compiled from a single source file (e.g., `obj-m += my_driver.o` where `my_driver.c` is the only source file and there is no `my_driver-objs` or `my_driver-y` line), map the single source file directly to the `srcs` attribute:
```python
ddk_module(
    name = "my_driver",
    out = "my_driver.ko",
    srcs = ["my_driver.c"],
    kernel_build = "//common:kernel_aarch64",
)
```

---

## 2. Kbuild to Bazel Mapping Guide

The following table shows how typical Kbuild goal definitions or Makefile lines map to attributes in a `ddk_module` target in a `BUILD.bazel` file.

| Kbuild Goal / Makefile Line | DDK `ddk_module` Attribute | Explanation |
| :--- | :--- | :--- |
| `obj-m += my_driver.o`<br>*(With single source `my_driver.c`, no `-objs` or `-y` list)* | `name = "my_driver"`,<br>`out = "my_driver.ko"`,<br>`srcs = ["my_driver.c"]` | Defines the module output and maps the single source file directly. |
| `obj-m += my_driver.o`<br>`my_driver-objs := main.o core.o`<br>*(Multi-source module)* | `name = "my_driver"`,<br>`out = "my_driver.ko"`,<br>`srcs = ["main.c", "core.c"]` | Defines the module output and lists all source files compiling into the objects. |
| `my_driver-$(CONFIG_FEATURE_A) += feat.o` | `conditional_srcs = { "CONFIG_FEATURE_A": { True: ["feat.c"] } }` | Conditionally compiles and links source files based on kernel configurations. |
| `ccflags-y += -DDEBUG_LEVEL=3` | `local_defines = ["DEBUG_LEVEL=3"]` | Adds preprocessor definitions local to this compilation unit. |
| `ccflags-y += -Wno-unused` | `copts = ["-Wno-unused"]` | Passes compiler flags directly to the compiler. |
| `ccflags-y += -I$(src)/include` | `deps = [":my_driver_headers"]` | Reference to helper `ddk_headers` target for private headers in subdirectories. See [3. Handling Includes and Headers](#3_handling-includes-and-headers). |
| `ccflags-y += -I$(src)/include` | `includes = ["include"]` | Appends include directories searched **after** the standard kernel headers (`LINUXINCLUDE`). |
| `LINUXINCLUDE := -I$(srctree)/... $(LINUXINCLUDE)` | `linux_includes = ["include"]` | Prepends include directories searched **before** the standard kernel headers (`LINUXINCLUDE`). |
| `AFLAGS_main.o += -Wa,-compress-debug-sections` | `asopts = ["-Wa,-compress-debug-sections"]` | Passes assembler flags. |
| `LDFLAGS_my_driver.o += -static` | `linkopts = ["-static"]` | Passes linker flags. |

---

## 3. Handling Includes and Headers

Unlike traditional makefiles that use `-I` flags to search for headers, DDK resolves header files explicitly to support Bazel's hermetic sandboxing.

### Local Headers (Same Directory, No `-I` Flag Needed)
If a header is in the same directory and included via relative paths (e.g., `#include "local_header.h"`), simply list it in `srcs`:
```python
ddk_module(
    name = "my_driver",
    out = "my_driver.ko",
    srcs = [
        "main.c",
        "local_header.h",
    ],
    kernel_build = "//common:kernel_aarch64",
)
```

### Private Headers in Subdirectories (Requiring `-I`)
If you need to add an include path (e.g., `#include <core/helper.h>`), wrap the headers in a `ddk_headers` target and list it in `deps`.

> **IMPORTANT (Guideline for the Agent/Helper):**
> When performing the conversion, **prefer explicitly listing local header files** in `srcs` or `ddk_headers.hdrs` by parsing the source files (`.c`, `.S`, `.h`) to find actual `#include` statements.
>
> Using `glob()` should generally be avoided but is acceptable in certain scenarios (including but not limited to):
> 1.  **Dedicated Public/UAPI Header Directories** (e.g., `glob(["include/uapi/**/*.h"])`): Directories containing only headers that do not produce intermediate build outputs.
> 2.  **Large Upstream/Third-party Imports**: Subfolders where listing hundreds of headers manually is impractical.

```python
ddk_headers(
    name = "private_headers",
    hdrs = [
        "core/helper.h",
        "core/internal.h",
    ],
    includes = ["core"],
)

ddk_module(
    name = "my_driver",
    out = "my_driver.ko",
    srcs = ["main.c"],
    deps = [":private_headers"],
    kernel_build = "//common:kernel_aarch64",
)
```

### Exported Headers
If other external modules depend on this module and need to include its headers, list the `ddk_headers` target in the `hdrs` attribute of your `ddk_module` instead of `deps`:
```python
ddk_module(
    name = "core_driver",
    out = "core_driver.ko",
    srcs = ["core.c"],
    hdrs = [":exported_headers"], # Downstream modules get these headers automatically
    kernel_build = "//common:kernel_aarch64",
)
```

### Include Path Search Order & Priorities
Kleaf DDK enforces a strict precedence ordering when resolving include paths during compilation. The compiler searches `-I` directories in the following order:
1.  **`linux_includes`** (Pre-kernel search paths): Directories specified here are searched **before** standard kernel headers (`LINUXINCLUDE`). Use this when your module headers must override standard common kernel definitions.
2.  **`LINUXINCLUDE`**: Standard common kernel directories (e.g., `include/linux`).
3.  **`includes`** (Post-kernel search paths): Directories specified here are searched **after** standard kernel headers.

For a detailed breakdown of include flag traversal logic, refer to the documentation in [kleaf/impl/ddk/ddk_module.bzl](../../../kleaf/impl/ddk/ddk_module.bzl).

---

## 4. Configuration (Kconfig & defconfig)

You can specify local Kconfig options and their values directly on the `ddk_module`:

```python
ddk_module(
    name = "my_driver",
    out = "my_driver.ko",
    srcs = ["main.c"],
    kconfig = "Kconfig",
    defconfig = "defconfig",
    kernel_build = "//common:kernel_aarch64",
)
```

### Modifying Configuration via `menuconfig`
Kleaf automatically instantiates a config target (suffix `_config`) for each `ddk_module` or `ddk_config` target. You can bring up the interactive kernel menu configuration UI by running:
```shell
tools/bazel run //path/to/my_driver:my_driver_config -- menuconfig
```

After modifying settings and exiting the menu, the command calculates the configuration diff and prints the resulting delta. Copy and append these printed config lines directly into your target's local `defconfig` file.

For detailed instructions on using interactive config menu tools, see the [Kleaf Configuration Guide](../../../kleaf/docs/kernel_config.md).

### Configuration Strategies (Distributed vs. Centralized)

Depending on your build setup and driver complexity, you can configure Kconfigs and defconfigs in three ways:
1. **Distributed (Default)**: Each module defines its own Kconfig/defconfig directly (recommended for self-contained modules, but has overhead when compiling many modules).
2. **Centralized**: Define a shared `ddk_config` (usually device-specific) to speed up overall build time at the cost of cross-device caching.
3. **Subsystem-level**: Define a shared `ddk_config` per subsystem (recommended intermediate approach).

> **NOTE:**
> For a detailed breakdown of the pros, cons, and performance implications of each configuration strategy, check the [Kleaf DDK Configuration Guide](../../../kleaf/docs/ddk/config.md).

---

## 5. Performance Caveat: Downplaying `ddk_submodule`

Kleaf provides a `ddk_submodule` rule designed to define multiple `.ko` modules within a single `ddk_module`.

> **CAUTION:**
> **Using `ddk_submodule` is strongly discouraged.**
>
> - **No Incremental Caching:** If a source file in any submodule changes, Bazel invalidates the entire top-level `ddk_module` target, forcing a complete rebuild of all submodules.
> - **Unclear Dependencies:** Symbol dependencies between submodules are resolved implicitly, hiding the dependency graph.
>
> **Recommendation:** Migrate submodules to separate `ddk_module` targets and define dependencies explicitly in the `deps` attribute.

---

## 6. Migration Example

Below is a complete, generic example of migrating a traditional driver.

### Before: `Kbuild`
```make
ccflags-y += -I$(src)/include -DCONFIG_ENABLE_LOGS
my_driver-objs := main.o helper.o
my_driver-$(CONFIG_FEATURE_DEBUG) += debug.o

obj-m += my_driver.o
```

### After: `BUILD.bazel`
```python
load("@kleaf//build/kernel/kleaf:kernel.bzl", "ddk_headers", "ddk_module")

ddk_headers(
    name = "my_driver_headers",
    hdrs = glob(["include/**/*.h"]),
    includes = ["include"],
)

ddk_module(
    name = "my_driver",
    out = "my_driver.ko",
    srcs = [
        "main.c",
        "helper.c",
    ],
    conditional_srcs = {
        "CONFIG_FEATURE_DEBUG": {
            True: ["debug.c"],
        },
    },
    local_defines = ["CONFIG_ENABLE_LOGS"],
    deps = [
        ":my_driver_headers",
    ],
    kernel_build = "//common:kernel_aarch64",
)
```

---

## 7. Advanced Migration Scenarios

### Scenario A: File-Specific Compiler Flags (e.g., `CFLAGS_file.o += -O3`)
In Kbuild, it's possible to specify per-file options for compiler flags with:
```make
CFLAGS_helper.o += -O3
```
**DDK Mapping:**
Since `copts` on a `ddk_module` applies to all source files in the target, you must isolate the file with specific flags into a `ddk_library` and list it in `deps`:
```python
# lib/BUILD.bazel
ddk_library(
    name = "helper_lib",
    srcs = ["helper.c"],
    copts = ["-O3"],
    kernel_build = "//common:kernel_aarch64",
)

# BUILD.bazel
ddk_module(
    name = "my_driver",
    out = "my_driver.ko",
    srcs = ["main.c"],
    deps = ["//path/to/lib:helper_lib"],
    kernel_build = "//common:kernel_aarch64",
)
```

### Scenario B: Conditional Preprocessor Defines (e.g., `ccflags-$(CONFIG_DEBUG) += -DDEBUG`)
In Kbuild:
```make
ccflags-$(CONFIG_MY_DRIVER_DEBUG) += -DDEBUG
```
**DDK Mapping:**
Do not try to map this dynamically inside `local_defines` or `copts` using Bazel select statements. Instead, move the conditional check into a local header file (e.g., `debug.h`) and include it implicitly:
1. Create a `debug.h` file:
   ```c
   #if IS_ENABLED(CONFIG_MY_DRIVER_DEBUG)
   #define DEBUG
   #endif
   ```
2. In your `BUILD.bazel`, add it to `srcs` and include it implicitly via `copts`:
   ```python
   ddk_module(
       name = "my_driver",
       out = "my_driver.ko",
       srcs = ["main.c", "debug.h"],
       copts = ["-include", "$(execpath debug.h)"],
       kernel_build = "//common:kernel_aarch64",
   )
   ```

### Scenario C: Integrating Prebuilt Objects (e.g., `.o` files)
If your driver incorporates a prebuilt object file:
**DDK Mapping:**
Wrap the prebuilt object using the `ddk_prebuilt_object` rule, and add it to `deps`:
```python
ddk_prebuilt_object(
    name = "prebuilt_helper",
    src = "libs/helper.o",
)

ddk_module(
    name = "my_driver",
    out = "my_driver.ko",
    srcs = ["main.c"],
    deps = [":prebuilt_helper"],
    kernel_build = "//common:kernel_aarch64",
)
```
> **IMPORTANT:**
> If the prebuilt object target contains a `.cmd` file (via `cmd` attribute) and your main `ddk_module` specifies `MODULE_VERSION()`, `modpost` will require all original source files for the prebuilt to be available.
>
> **Workaround:** Omit the `cmd` attribute in `ddk_prebuilt_object` to prevent `modpost` from checking for the original sources.

### Scenario D: Conditional Module Dependencies & Stubs
If your driver depends on another optional driver, you can use a Bazel `bool_flag` and `alias(select(...))` to switch between the real implementation and a stub interface.
See the reference pattern implementation in [BUILD.bazel in ddk_examples/conditional_dependency/parent/BUILD.bazel](../../../kleaf/tests/ddk_examples/conditional_dependency/parent/BUILD.bazel).

### Scenario E: Building pKVM Modules
To build a protected KVM (pKVM) module with DDK:
1. Compile EL2 hypervisor code using a `ddk_library` target with `pkvm_el2 = True`.
2. Compile EL1 kernel code using a regular `ddk_module` target, specifying the `ddk_library` target in its `deps`.

> **NOTE:**
> If the original Kbuild/Makefile explicitly specifies compilation flags like `ccflags-y += -DMODULE` or `subdir-ccflags-y += -DMODULE` (frequently used for compiling hypervisor EL2 code libraries), preserve these flags by adding `"MODULE"` to the `local_defines` attribute of your `ddk_library` target:
> ```python
> ddk_library(
>     name = "hyp",
>     srcs = [...],
>     pkvm_el2 = True,
>     local_defines = ["MODULE"],
>     ...
> )
> ```

For a complete working example, refer to [ddk_examples/pkvm/README.md](../../../kleaf/tests/ddk_examples/pkvm/README.md).

### Scenario F: Compiling Rust Modules
If you are compiling Rust-based kernel modules with DDK:
*   Use the `crate_root` attribute to specify the crate entry point.
*   For a single-file Rust module:
    ```python
    ddk_module(
        name = "my_rust_module",
        out = "my_rust_module.ko",
        crate_root = "main.rs",
        kernel_build = "//common:kernel_aarch64",
    )
    ```
*   For a multi-file Rust module, specify the entry point in `crate_root` and list the other `.rs` files in `srcs`:
    ```python
    ddk_module(
        name = "my_rust_module",
        out = "my_rust_module.ko",
        crate_root = "crate_root.rs",
        srcs = ["other_module.rs"],
        kernel_build = "//common:kernel_aarch64",
    )
    ```

For full test cases, refer to the [Kleaf Rust DDK tests](../../../../../common-modules/virtual-device/kleaf_test/rust_test/BUILD.bazel).

### Scenario G: Removing Compiler Flags and ftrace Controls
1. **Removing Specific Compiler Flags (`removed_copts`)**:
   In Kbuild, compiler flags are sometimes removed for individual object files:
   ```make
   CFLAGS_REMOVE_helper.o += -mgeneral-regs-only
   ```
   In DDK, use the `removed_copts` attribute (available on `ddk_module` and `ddk_library`):
   ```python
   ddk_module(
       name = "my_driver",
       out = "my_driver.ko",
       srcs = ["main.c"],
       removed_copts = ["-mgeneral-regs-only"],
       kernel_build = "//common:kernel_aarch64",
   )
   ```
2. **Disabling ftrace Flags (`support_ftrace`)**:
   Kleaf automatically appends ftrace compilation flags. To disable this behavior for a module or library, set `support_ftrace = False`:
   ```python
   ddk_module(
       name = "my_driver",
       out = "my_driver.ko",
       srcs = ["main.c"],
       support_ftrace = False,
       kernel_build = "//common:kernel_aarch64",
   )
   ```

For references, see `_makefiles_support_ftrace_tests` and `_removed_copts` target definitions in [kleaf/tests/ddk_test/makefiles_test.bzl](../../../kleaf/tests/ddk_test/makefiles_test.bzl).

### Scenario H: Configuring GCOV Coverage Profiling
In Kbuild, coverage profiling is enabled or disabled per directory or per file:
```make
# Enable coverage for all objects in this Makefile
GCOV_PROFILE := y

# Disable coverage for a specific object
GCOV_PROFILE_helper.o := n
```
**DDK Mapping:**
Set the `gcov` attribute (available on `ddk_module` and `ddk_library`) to `"always"`, `"never"`, or `"inherit"`:
*   `"always"`: Forces coverage profiling on for all source files in the target (maps to `GCOV_PROFILE_*.o := y`).
*   `"never"`: Disables profiling for all source files in the target (maps to `GCOV_PROFILE_*.o := n`).
*   `"inherit"` (Default): Inherits coverage behavior from the global `kernel_build` configuration (e.g., when building with `--gcov=enabled` or `--gcov=profile_all`).
```python
ddk_module(
    name = "my_driver",
    out = "my_driver.ko",
    srcs = ["main.c"],
    gcov = "always", # or "never", "inherit"
    kernel_build = "//common:kernel_aarch64",
)
```

For references, see `_makefiles_gcov_tests` in [kleaf/tests/ddk_test/makefiles_test.bzl](../../../kleaf/tests/ddk_test/makefiles_test.bzl).

### Scenario I: Sharing Source Files Between Multiple Modules
In Kbuild, compiling a shared source file (e.g. `common/core_logic.c`) into two different modules often requires complex makefile variables or file copying.
**DDK Mapping:**
In Bazel, multiple `ddk_module` or `ddk_library` targets can reference the exact same source files directly in their `srcs` attributes:
```python
ddk_module(
    name = "driver_v1",
    out = "driver_v1.ko",
    srcs = [
        "v1/main.c",
        "common/core_logic.c",
    ],
    kernel_build = "//common:kernel_aarch64",
)

ddk_module(
    name = "driver_v2",
    out = "driver_v2.ko",
    srcs = [
        "v2/main.c",
        "common/core_logic.c",
    ],
    kernel_build = "//common:kernel_aarch64",
)
```

### Scenario J: Dependency Ordering & Header Collisions (`# do not sort`)
If two of your dependencies export a header with the same name (causing a collision), you can force a specific compilation search order by adjusting their ordering in the `deps` or `hdrs` attributes.
Because `buildifier` (the Bazel code formatter) does not typically sort these list attributes automatically, you usually do not need special annotations. However, when there are active header naming conflicts, you can use the `# do not sort` magic comment to make the ordering explicit and prevent future automatic formatting tools from changing the list order:
```python
deps = [
    # do not sort
    ":higher_priority_headers",
    ":lower_priority_headers",
]
```
For a detailed explanation of the include path resolution order, check the documentation in [kleaf/impl/ddk/ddk_module.bzl](../../../kleaf/impl/ddk/ddk_module.bzl).

### Scenario K: Implicitly Including a Header File (`-include` in `copts`)
If you want to use the compiler's `-include` flag to implicitly include a header file (such as a shared configuration or defines header) in all compilation units of a module, without manually adding `#include` to every `.c` file:
1. Add the header file (whether checked into the source tree or auto-generated by another target) to the `srcs` list of your `ddk_module`.
2. In the `copts` attribute, specify `"-include", "$(execpath <header_file>)"`. The `$(execpath)` macro is required because Bazel runs the compiler in a sandboxed output directory, and this forces Bazel to expand the path to the correct relative sandbox path.

```python
ddk_module(
    name = "my_driver",
    out = "my_driver.ko",
    srcs = [
        "main.c",
        "my_driver_defines.h",  # List the header in srcs
    ],
    copts = [
        "-include",  # Force implicit inclusion
        "$(execpath my_driver_defines.h)",
    ],
    kernel_build = "//common:kernel_aarch64",
)
```

For references, check the test implementations in `_ddk_genfiles_test` inside [common-modules/virtual-device/kleaf_test/kleaf_test.bzl](../../../../../common-modules/virtual-device/kleaf_test/kleaf_test.bzl) and [Kleaf DDK Includes documentation](../../../kleaf/docs/ddk/includes.md#implicitly-including-a-single-header-file).

### Scenario L: Using Non-Standard ACK Headers (e.g., under `drivers/` or `arch/`)
By default, `ddk_module` targets compiled against the Android Common Kernel (ACK) only have visibility to stable headers (such as directories under `include/` and `arch/*/include/`).
If your module requires ACK headers that are not in these stable include paths (e.g., helper headers under `common/drivers/usb/core/usb.h` or `common/arch/arm64/kvm/hyp/include/nvhe/memory.h`):

1.  **Priority 1: Add to SoC Unsafe List (Recommended Workaround for Migration)**
    If you need to use unsafe ACK headers during DDK migration, group them in an SoC-specific unsafe headers target in `common/BUILD.bazel`, add it to the global unsafe list, and compile with the unsafe headers flag. *This is the recommended immediate path for migration as it does not expose the headers publicly.*

    a. Define an SoC-specific unsafe headers target in [common/BUILD.bazel](../../../../../common/BUILD.bazel):
       ```python
       # common/BUILD.bazel
       ddk_headers(
           name = "all_headers_unsafe_<soc_name>",
           hdrs = [
               "drivers/usb/core/usb.h",
           ],
           visibility = ["//visibility:private"],
       )
       ```
    b. Add your SoC-specific unsafe target to the global `all_headers_unsafe` target in [common/BUILD.bazel](../../../../../common/BUILD.bazel):
       ```python
       # common/BUILD.bazel
       ddk_headers(
           name = "all_headers_unsafe",
           hdrs = [
               "//build/kernel/kleaf:user_ddk_unsafe_headers",
               ":all_headers_unsafe_<soc_name>", # Add this
           ],
           ...
       )
       ```
    c. To compile against these headers, you must explicitly pass the special flag **`--allow_ddk_unsafe_headers`** in your Bazel build command:
       ```shell
       tools/bazel build --allow_ddk_unsafe_headers //path/to:my_module
       ```

2.  **Priority 2: Add to SoC Allowlist (Permanent Solution, Scrutinized Review Process)**
    If the header is generally safe and stable, group them in an SoC-specific allowlist target in `common/BUILD.bazel` and add it to the main arch allowlist. *Note: While this is the permanent solution, it requires scrutinized review from the GKI team to expose private headers publicly, which is a lengthy process.*
    **Guideline for the Agent:** You must inform the user that the GKI team may push back on adding private headers to allowlists, and you must get explicit approval from the user before proceeding with this option.

    a. Define a `ddk_headers` target for your SoC in [common/BUILD.bazel](../../../../../common/BUILD.bazel) (if it doesn't exist yet) and list your headers:
       ```python
       # common/BUILD.bazel
       ddk_headers(
           name = "all_headers_allowlist_<soc_name>",
           hdrs = [
               "drivers/usb/core/usb.h",
           ],
           visibility = ["//visibility:private"],
       )
       ```
    b. Add your SoC target to the standard allowlist target `all_headers_allowlist_aarch64` (or `all_headers_allowlist_x86_64`) in [common/BUILD.bazel](../../../../../common/BUILD.bazel):
       ```python
       # common/BUILD.bazel
       ddk_headers(
           name = "all_headers_allowlist_aarch64",
           hdrs = [
               ...
               ":all_headers_allowlist_<soc_name>", # Add this
               ...
           ],
           ...
       )
       ```
    This makes the headers available to your module without any additional build flags.

For references, check the [Using headers from the common kernel guide](../../../kleaf/docs/ddk/common_headers.md).

---

## References & Further Reading
* [Kleaf DDK main.md](../../../kleaf/docs/ddk/main.md)
* [Kleaf DDK rules.md](../../../kleaf/docs/ddk/rules.md)
* [Kleaf DDK includes.md](../../../kleaf/docs/ddk/includes.md)
* [Kleaf DDK config.md](../../../kleaf/docs/ddk/config.md)
* [Kleaf DDK errors.md](../../../kleaf/docs/ddk/errors.md)
* [Kleaf DDK common_headers.md](../../../kleaf/docs/ddk/common_headers.md)
