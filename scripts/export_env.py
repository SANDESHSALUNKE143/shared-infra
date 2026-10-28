"""Print a shell-safe export of .env for bash to eval."""

from __future__ import annotations

import sys
from pathlib import Path


def parse_env(text: str) -> dict[str, str]:
    """Read KEY=VALUE lines. Values may be wrapped in single or double quotes."""
    values: dict[str, str] = {}
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        key, separator, value = line.partition("=")
        if not separator:
            continue
        key = key.strip()
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
            value = value[1:-1]
        values[key] = value
    return values


def shell_exports(values: dict[str, str]) -> str:
    lines = []
    for key, value in values.items():
        escaped = value.replace("'", "'\"'\"'")
        lines.append(f"export {key}='{escaped}'")
    return "\n".join(lines) + ("\n" if lines else "")


def main() -> None:
    path = Path(sys.argv[1] if len(sys.argv) > 1 else ".env")
    print(shell_exports(parse_env(path.read_text(encoding="utf-8"))), end="")


if __name__ == "__main__":
    main()
