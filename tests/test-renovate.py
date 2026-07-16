#!/usr/bin/env python3

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
CONFIG = json.loads((ROOT / "renovate.json").read_text(encoding="utf-8"))
FILES = [
    ROOT / "manifests/release-tools.tsv",
    ROOT / "manifests/versions.sh",
    ROOT / "manifests/powershell-modules.tsv",
]


def python_pattern(expression: str) -> str:
    return re.sub(
        r"\(\?<([A-Za-z][A-Za-z0-9_]*)>",
        r"(?P<\1>",
        expression,
    )


counts: list[int] = []
for manager, path in zip(CONFIG["customManagers"], FILES, strict=True):
    content = path.read_text(encoding="utf-8")
    matches = []
    for expression in manager["matchStrings"]:
        matches.extend(re.finditer(python_pattern(expression), content))
    if not matches:
        raise SystemExit(f"Renovate manager did not match dependencies in {path}")
    if any(not match.groupdict().get("depName") for match in matches):
        raise SystemExit(f"Renovate manager missed a dependency name in {path}")
    counts.append(len(matches))

release_count = sum(
    1
    for line in FILES[0].read_text(encoding="utf-8").splitlines()
    if line and not line.startswith("#")
)
module_count = sum(
    1
    for line in FILES[2].read_text(encoding="utf-8").splitlines()
    if line and not line.startswith("#")
)
if counts[0] != release_count:
    raise SystemExit(
        f"Renovate matched {counts[0]} of {release_count} release tools"
    )
if counts[2] != module_count:
    raise SystemExit(
        f"Renovate matched {counts[2]} of {module_count} PowerShell modules"
    )

print(f"test-renovate: PASS ({sum(counts)} dependencies)")
