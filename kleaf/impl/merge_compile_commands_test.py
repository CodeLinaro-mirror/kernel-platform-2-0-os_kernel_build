# SPDX-License-Identifier: GPL-2.0-only

"""Tests for merge_compile_commands."""

import json
import pathlib
import tempfile
import unittest

from absl.testing import absltest
import merge_compile_commands


class MergeCompileCommandsTest(unittest.TestCase):

    def test_empty(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = pathlib.Path(tmp) / "merged.json"
            ret = merge_compile_commands.main(["--output", str(out)])
            self.assertEqual(ret, 0)
            self.assertEqual(json.loads(out.read_text(encoding="utf-8")), [])

    def test_merge_dedup_and_sort(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = pathlib.Path(tmp)
            base_json = tmp_path / "base_with_vars.json"
            device_json = tmp_path / "device_with_vars.json"
            module_json = tmp_path / "module_with_vars.json"
            out_json = tmp_path / "merged.json"

            base_json.write_text(
                json.dumps([
                    {
                        "command": "clang -DCONFIG_BASE -c z.c",
                        "directory": "${COMPDB_OUT_DIR_BASE}/base_out/common",
                        "file": "${ROOT_DIR}/common/z.c",
                    },
                    {
                        "command": "clang -DCONFIG_BASE -c shared.c",
                        "directory": "${COMPDB_OUT_DIR_BASE}/base_out/common",
                        "file": "${ROOT_DIR}/common/shared.c",
                    },
                ]),
                encoding="utf-8",
            )
            device_json.write_text(
                json.dumps([
                    {
                        "command": "clang -DCONFIG_DEVICE -c shared.c",
                        "directory": "${COMPDB_OUT_DIR_BASE}/device_out/common",
                        "file": "${ROOT_DIR}/common/shared.c",
                    },
                    {
                        "command": "clang -DCONFIG_DEVICE -c a.c",
                        "directory": "${COMPDB_OUT_DIR_BASE}/device_out/common",
                        "file": "${ROOT_DIR}/common/a.c",
                    },
                ]),
                encoding="utf-8",
            )
            module_json.write_text(
                json.dumps([
                    {
                        "command": "clang -DMOD -c mod.c",
                        "directory": "${COMPDB_OUT_DIR_BASE}/mod_out/common",
                        "file": "${ROOT_DIR}/modules/mod.c",
                    },
                ]),
                encoding="utf-8",
            )

            ret = merge_compile_commands.main([
                "--output",
                str(out_json),
                "--with_vars",
                str(base_json),
                str(device_json),
                str(module_json),
            ])
            self.assertEqual(ret, 0)

            result = json.loads(out_json.read_text(encoding="utf-8"))
            self.assertEqual(
                result,
                [
                    {
                        "command": "clang -DCONFIG_DEVICE -c a.c",
                        "directory": "${COMPDB_OUT_DIR_BASE}/device_out/common",
                        "file": "${ROOT_DIR}/common/a.c",
                    },
                    {
                        "command": "clang -DCONFIG_DEVICE -c shared.c",
                        "directory": "${COMPDB_OUT_DIR_BASE}/device_out/common",
                        "file": "${ROOT_DIR}/common/shared.c",
                    },
                    {
                        "command": "clang -DCONFIG_BASE -c z.c",
                        "directory": "${COMPDB_OUT_DIR_BASE}/base_out/common",
                        "file": "${ROOT_DIR}/common/z.c",
                    },
                    {
                        "command": "clang -DMOD -c mod.c",
                        "directory": "${COMPDB_OUT_DIR_BASE}/mod_out/common",
                        "file": "${ROOT_DIR}/modules/mod.c",
                    },
                ],
            )


if __name__ == "__main__":
    absltest.main()
