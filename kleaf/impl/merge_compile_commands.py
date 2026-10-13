# SPDX-License-Identifier: GPL-2.0-only

"""Merges and deduplicates compile_commands_with_vars.json files."""

import argparse
import json
import pathlib
import sys
from typing import Any


def merge_entries(with_vars: list[pathlib.Path]) -> list[dict[str, Any]]:
    """Merges compile_commands_with_vars.json files, deduplicating by file."""
    merged_by_file: dict[str, dict[str, Any]] = {}
    for with_vars_path in with_vars:
        with open(with_vars_path, encoding="utf-8") as f:
            entries = json.load(f)
        for entry in entries:
            file_key = entry.get("file")
            if file_key is not None:
                merged_by_file[file_key] = entry
    return [merged_by_file[k] for k in sorted(merged_by_file.keys())]


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=pathlib.Path,
        required=True,
        help="Path to output merged compile_commands_with_vars.json",
    )
    parser.add_argument(
        "--with_vars",
        type=pathlib.Path,
        nargs="*",
        default=[],
        help="Paths to input compile_commands_with_vars.json files",
    )
    args = parser.parse_args(argv)

    merged = merge_entries(args.with_vars)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(merged, f, indent=2)
        f.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
