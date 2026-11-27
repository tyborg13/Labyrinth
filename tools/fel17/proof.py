"""Configure the shared viewport driver and verify or compose its paired evidence."""

import json
from pathlib import Path
import sys

TOOL_DIR = Path(__file__).resolve().parent
HOVER_SECONDS = 1.0
PANEL_BOUNDS_TOLERANCE_PX = 0.25
CASES = [
    {"name": "one-exit", "objective_type": "reach_exit", "special_type": "", "exit_count": 1},
    {"name": "two-exits", "objective_type": "reach_exit", "special_type": "umbral_snare", "exit_count": 2},
    {"name": "warband", "objective_type": "kill_leader", "special_type": "warband"},
]
BODY_TEXT = {
    "reach_exit": "Reach a marked tile to escape.",
    "kill_leader": "Defeat the captain to make each follower flee.",
}


def prepare(output):
    rows = []
    for case in CASES:
        source = output / "fixtures" / case["name"]
        rows.append({**case, "source": str(source), "target": "hud", "mount": "load", "settle": HOVER_SECONDS})
    (output / "cases.json").write_text(json.dumps(rows, indent=2) + "\n", encoding="utf-8")


def read_side(output, side):
    rows = json.loads((output / side / "observations.json").read_text(encoding="utf-8"))
    if [row["case"] for row in rows] != [case["name"] for case in CASES]:
        raise ValueError(f"Unexpected {side} case list")
    return rows


def verify(output):
    before = read_side(output, "release")
    after = read_side(output, "branch")
    for case, first, second in zip(CASES, before, after):
        name = case["name"]
        expected = {"title": first["title"], "lines": [BODY_TEXT[case["objective_type"]]]}
        if len(first["popups"]) != 1 or first["popups"][0]["panels"] != [expected] or second["popups"]:
            raise ValueError(f"Expected the original Objective pop-up before and no pop-up after for {name}")
        for field in ("title", "detail"):
            if first[field] != second[field]:
                raise ValueError(f"Objective {field} differs between revisions for {name}")
        if any(abs(a - b) > PANEL_BOUNDS_TOLERANCE_PX for a, b in zip(first["anchor"], second["anchor"])):
            raise ValueError(f"Objective bounds differ between revisions for {name}")
        print(f"FEL17 CASE PASS {name} before=1 after=0 title_detail_bounds=matched")
    return before, after


def compose(output, before, after):
    sys.path.insert(0, str(TOOL_DIR.parent / "fel08" / "before_after"))
    from pairs import Image, common_crop, pair, read_frame

    pairs = []
    for first, second in zip(before, after):
        name = first["case"]
        crop = common_crop(first, second)
        path = output / f"{name}-pair.png"
        pair(read_frame(output / "release" / first["frame"]).crop(crop),
             read_frame(output / "branch" / second["frame"]).crop(crop), name, path)
        with Image.open(path) as frame:
            pairs.append((path, frame.width, frame.height))
    sheet = Image.new("RGB", (max(width for _, width, _ in pairs), sum(height for _, _, height in pairs)))
    top = 0
    for path, _, height in pairs:
        with Image.open(path) as frame:
            sheet.paste(frame, (0, top))
        top += height
        print(path)
    path = output / "contact-sheet.png"
    sheet.save(path)
    print(path)


def main(mode, output):
    if mode == "prepare":
        prepare(output)
        return
    before, after = verify(output)
    if mode == "native":
        compose(output, before, after)
    print(f"FEL17 {mode.upper()} PASS cases={len(CASES)}")


if __name__ == "__main__":
    try:
        main(sys.argv[1], Path(sys.argv[2]).resolve())
    except (OSError, ValueError, KeyError) as exc:
        sys.exit(f"FEL17 FAIL {exc}")
