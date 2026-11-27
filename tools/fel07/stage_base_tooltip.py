"""Stage the fel-06 tooltip methods as a probe-only board subclass."""

from pathlib import Path
import re
import subprocess
import sys

BASE_REVISION = "6203cf9aae29ac5926dab02dfbdf2b970b83f81b"
BOARD_SCRIPT = "scripts/combat_board_view.gd"


def method(source, name):
    match = re.search(rf"^func {name}\(.*\n(?:\t[^\n]*\n|\n)*", source, re.MULTILINE)
    if match is None:
        raise ValueError(f"Missing {name} in {BASE_REVISION}:{BOARD_SCRIPT}")
    return match[0].rstrip() + "\n"


def main():
    source = subprocess.check_output(
        ["git", "show", f"{BASE_REVISION}:{BOARD_SCRIPT}"], text=True
    )
    methods = "\n".join(method(source, name) for name in (
        "_get_tooltip", "_loot_tooltip_at_position",
    ))
    # The old loot helper took one argument. Give the inherited helper and
    # the baseline helper distinct names so their signatures can coexist.
    methods = methods.replace("_loot_tooltip_at_position(", "_base_loot_tooltip_at_position(")
    Path(sys.argv[1]).write_text(f'extends "res://{BOARD_SCRIPT}"\n\n{methods}', encoding="utf-8")


if __name__ == "__main__":
    main()
