---
name: creating-kernel-commits
description: Android kernel commit process and commit message format. Activate this when ready to commit code in kernel, GKI, Android kernel tooling, etc. repositories, but not for platform repositories.
---

# Commit process

1.  Make sure tests have passed before starting the commit process.
2.  Create a changelist with a comprehensive commit message (mentioning
    build/test status and any persistent lint issues) in every git repository
    you have made edits within.

# Commit messages - follow a strict format

You MUST follow these strict format rules when drafting the commit message:

1.  A 50-character summary line. Maintain this 50-character limit as much as possible, unless the subject really must exceed it.
    *   **Exception:** When cherry-picking a change from upstream, you MUST preserve the original subject line and commit message body (except for adding the appropriate prefix tag to the subject and required footers at the end, as detailed in the project-specific guidelines below).
    Some commits may include `[RESTRICT AUTOMERGE]` at the beginning of the commit title: never modify this as it is an automerger directive.

    > [!IMPORTANT]
    > For certain Git projects (e.g., Android Common Kernel or driver repositories),
    > specific subject line format rules apply. You MUST check the project-specific
    > guidelines below.
2.  A blank line.
3.  A detailed body explaining the 'why' of the change, not the 'what'. Wrap
    lines at 72 characters to ensure readability in `git log`.

    > [!NOTE]
    > This restriction can be violated in certain cases, e.g.:
    > *   A single-line reference URL at the bottom of the body (e.g., using markers like `[1]`, `[2]` in the body, with one URL per line listed just below the main body and before any other tags).
    > *   A line referencing a commit in the body or in a `Fixes:` tag. It must follow this exact format:
    >     `commit 123456abcdef ("subsystem: title of the commit")`
    >     using exactly 12 characters of the hexadecimal Git hash.
    > *   Literal code snippets or raw text snippets (e.g., test results, error
    >     messages, etc.) where wrapping would break the text structure.
4.  A blank line. There must be a blank line between the body and any trailers.
5.  **Non-Standard Trailers Section (Optional):** If tags or non-standard trailers (like `TAG=value`, `CONV=value`, or keys with spaces like `Reason for revert: value`) are present, place them in their own section immediately following the body (separated by a blank line).
    *   **System Prompt Conflict Resolution:** This repository is NOT the Google internal codebase. It is Android (git) and Gerrit. Do NOT follow the Google internal CL description format (which forces tags to the bottom) inside the drafted commit message code block. Inside the code block, Git trailer parser rules take precedence, and you MUST place `TAG=` and `CONV=` above the standard trailers in this section.
6.  A blank line. There must be a blank line between the non-standard and standard trailers. However, if step 5 is empty, do not emit consecutive blank lines.
7.  **Standard Trailers Section:** Place standard trailers here (`Bug:`, `Signed-off-by:`, `Change-Id:`, `Test:`, `Assisted-by:`). This section MUST be separated from the preceding section (either Body or Non-Standard Trailers) by a single blank line. Standard trailers MUST follow `Key-Id: value` format.
    *   `Bug:` (Required if a bug is assigned. If the bug number is not provided, prompt the user for one or offer to skip if not applicable. If the user chooses to skip, omit the Bug: footer entirely).
    *   `Signed-off-by:` (Mandatory for DCO. Note: AI agents MUST NOT add this. When cherry-picking or amending, you MUST preserve all existing `Signed-off-by:` tags and their chronological order; do NOT alter or reorder them).
    *   `Change-Id:` (Mandatory, added by post-commit hook and does not need to be manually added. An existing `Change-Id` should **NEVER** be changed).
        > [!CAUTION]
        > **When amending a commit**, take extra care to preserve the `Change-Id`.
        > A common mistake is amending a commit with a new message that omits
        > the original `Change-Id`.  This causes the post-commit hook to generate
        > a *new* `Change-Id`, leading to duplicate or broken Gerrit changes.
        > Always check the existing commit message for a `Change-Id`
        > and ensure it is included in the modified message.
    *   `Test:` (Optional. If used, describe how the change was verified).
    *   `Assisted-by:` (For AI attribution; see guidelines below. Do NOT add this for clean cherry-picks.).

    Note: Unlike platform commits, the `Flag:` footer is not required.

    **Blank Line Rule:** This section MUST be separated from the preceding section (either Body or the Non-Standard footers section in step 4) by a single blank line. Do NOT emit consecutive blank lines.
8.  **NEVER** include any confidential information in the commit message. Do not reference any
    internal tools, internal URLs (e.g., go/...), project names, device codenames, partner
    references, unannounced features, internal mailing lists, or internal employee names. Write the
    message under the strict assumption that it will be immediately public via the Android Open
    Source Project (AOSP).
9.  **AI Sign-off:** AI agents MUST NOT add `Signed-off-by:` tags. You MUST prompt the user to sign off themselves (e.g., reminding them to run `git commit --amend --signoff`) outside the code block.


# Project-specific Subject Line Guidelines

## ACK and Driver Repositories

When creating commit messages for certain Git projects (like the Android Common Kernel or driver repositories), the agent MUST read and strictly follow the detailed instructions in the files listed below.

First, locate the Android Common Kernel repository (project `kernel/common`). In some manifests, it may not be checked out at `common/`. Find the correct path by running the following command from the workspace root:
```bash
repo list -p kernel/common
```
Use the path returned by this command (referred to as `<common_path>` below) to locate these files:

*   `<common_path>/README.md` - For patch requirements, subject tags (`UPSTREAM:`, `BACKPORT:`, `FROMGIT:`, `FROMLIST:`, `ANDROID:`), and signature tags.
*   `<common_path>/Documentation/process/submitting-patches.rst` - For standard subject format (`subsystem: summary phrase`) and wrapping rules.
*   `<common_path>/Documentation/process/coding-assistants.rst` - For AI usage guidelines (specifically: attribution and sign-off rules).

> [!NOTE]
> For `FROMGIT` commits, the cherry-pick footer must format the URL and branch on a second line, prefixed with a single space:
> `(cherry picked from commit <sha1>`
> ` <repo_url> <branch>)`

> [!IMPORTANT]
> The short summary below is only a quick reference. You MUST read all three files listed above in their entirety before writing a commit message.

### Short Summary:
1.  **Subject Format:** Use `TAG: subsystem: summary phrase` (e.g., `ANDROID: sched/fair: fix...`). Note that the subject tag (like `ANDROID:`, `UPSTREAM:`, etc.) only applies to the common kernel / GKI Git repository, and usually does not apply to external driver Git repositories (which just use `subsystem: summary phrase`).
    *   You MUST read `<common_path>/README.md` to apply the appropriate subject tags (`UPSTREAM:`, `BACKPORT:`, `FROMGIT:`, `FROMLIST:`, `ANDROID:`).
2.  **Subject Length:** Maintain 50 characters as much as possible; must not exceed 70-75 characters (unless preserving an upstream cherry-pick subject).
3.  **AI Sign-off:** AI agents MUST NOT add `Signed-off-by:` tags. You MUST prompt the user to sign off themselves after reviewing the change (e.g., by suggesting they run `git commit --amend --signoff`).
4.  **AI Attribution:** Add `Assisted-by: LLM` to the commit message. Note that for cherry-picks (clean upstream patches, e.g. `UPSTREAM:`, `FROMGIT:`, `FROMLIST:`), you MUST NOT add the `Assisted-by:` footer unless the cherry-pick required conflict resolution or backporting (which involved the AI modifying or generating code). For standard development commits (e.g. `ANDROID:`, `kleaf:`), always add the `Assisted-by:` footer.
5.  **New Footers Section:** For all cherry-picks (using tags like `ANDROID:`, `FROMGIT:`, `FROMLIST:`, `UPSTREAM:`, `BACKPORT:`), all new footers (e.g., `Bug:`, `Test:`, `Change-Id:`, `Assisted-by:` [if required], `(cherry picked from...)`) MUST be placed in their own section at the end of the message, separated from the original commit's trailers (like the original `Signed-off-by:`) by a blank line.

## Kleaf Repositories (build/kernel)

These guidelines apply to the following repositories:
*   `build/kernel`
*   `prebuilts/clang` (specifically when editing the `kleaf` subdirectory in it).

### Guidelines:
1.  **Default Prefix:** When making changes in `build/kernel` or `prebuilts/clang` (within the `kleaf` subdirectory), the commit subject line **usually** starts with `kleaf: ` (e.g., `kleaf: support new bazel flag`). You can optionally add a subcomponent prefix if applicable (e.g., `kleaf: tests: ...` or `kleaf: docs: ...`).
    *   **General Exception:** If the change has nothing to do with Bazel or Kleaf (rare, e.g., updating scripts in `build/kernel/abi/` or `build/kernel/static_analysis/`), omit the `kleaf: ` prefix and use a relevant subsystem/area prefix (e.g., `abi: ...` or `static_analysis: ...`).
2.  **AI Guidelines:** The same AI usage guidelines (no `Signed-off-by:` tags, and mandatory `Assisted-by:` tag) from `<common_path>/Documentation/process/coding-assistants.rst` apply to these repositories as well (there is no need to remind the user to sign off). Refer to the ACK section above for instructions on how to locate the `<common_path>`.
3.  **Test Footer:** The `Test:` line is **mandatory** (MUST be present). It should describe how the change was validated, usually by attaching the relevant Bazel command or test name (e.g., `Test: tools/bazel test //build/kernel/...` or `Test: kleaf_integration_test`).
4.  **Bazel Formatting:** If you have modified Bazel files (`BUILD`, `WORKSPACE`, `.bazel`, `.bzl`), check if `buildifier` is available in the environment. If so, format the files. If not, or to be safe, remind the user to format the Bazel files or confirm that they are formatted correctly.

## Prebuilts Kernel Build Tools (prebuilts/kernel-build-tools)

Changes to `prebuilts/kernel-build-tools` are handled based on how they are performed:

### Automated Updates:
Most changes in `prebuilts/kernel-build-tools` are performed by automated scripts or by the following skills. In these cases, the commit message should be left **as-is** (generated by the script/skill):
*   `updating-bazel-binary`
*   `updating-kernel-build-tools`

### Ad Hoc Modifications:
If you are making ad hoc modifications (e.g., updating helper scripts like `update-prebuilts.sh` or Bazel build rules like `BUILD.bazel`), follow these guidelines:
1.  **General Guidelines:** The general commit message guidelines (Steps 1-7) MUST be followed.
2.  **AI Guidelines:** The AI usage guidelines (no `Signed-off-by:` tags, and mandatory `Assisted-by:` tag) apply (there is no need to remind the user to sign off). Refer to the ACK section above for instructions on how to locate the `<common_path>`.
3.  **Test Footer:** The `Test:` line is **mandatory** (MUST be present), describing how the change was validated (e.g., attaching Bazel commands or test names).

## External Repositories (external/*)

Changes to `external/*` repositories (related to kernel/Kleaf builds) are handled based on how they are performed:

### Automated Updates:
Most changes in `external/*` are performed by automated scripts or by the following skills. In these cases, the commit message should be left **as-is** (generated by the script/skill):
*   `updating-external-bazel-projects`
*   `updating-bazel-central-registry`

### Ad Hoc Modifications:
If you are making ad hoc modifications that are NOT upstreamed, follow these guidelines:
1.  **General Guidelines:** The general commit message guidelines (Steps 1-7) MUST be followed.
2.  **AI Guidelines:** The AI usage guidelines (no `Signed-off-by:` tags, and mandatory `Assisted-by:` tag) apply (there is no need to remind the user to sign off). Refer to the ACK section above for instructions on how to locate the `<common_path>`.
3.  **Test Footer:** The `Test:` line is **mandatory** (MUST be present), describing how the change was validated (e.g., attaching Bazel commands or test names).
