"""Check fx-23 atlas regions against the base and write the heading sheet."""

import argparse
import hashlib
import json
import subprocess
from io import BytesIO
from pathlib import Path

from PIL import Image

BASE = "8f38fb277"
ROUND_ZERO = "2fbbd06c0"
ROOT = Path(__file__).resolve().parents[2]
METADATA = "data/shots.json"
DESIGNS = ("ember", "spark")
SHEET_CELLS = 68
SHEET_SCALE = 3
FLOOR = "#1a1614"


def base_file(path, revision=BASE):
    return subprocess.check_output(["git", "show", f"{revision}:{path}"], cwd=ROOT)


def atlas_path(sheet):
    return sheet["atlas"].removeprefix("res://")


def region(sheet, name, headings):
    frame = sheet["shots"][name]
    side = frame["frame_cells"]
    columns = headings if frame["kind"] == "heading" else 8
    return (0, frame["y"], columns * side, frame["y"] + frame["rows"] * side)


def check(base, current):
    approved = json.loads(base_file(METADATA, ROUND_ZERO))
    assert len(base["sizes"]) == len(current["sizes"]) == 7
    assert current["palette"][:len(base["palette"])] == base["palette"]
    assert len(current["palette"]) > len(base["palette"])
    for key in base.keys() - {"sizes", "shots", "palette", "shot_for_element", "shot_for_intent"}:
        assert current[key] == base[key], key
    assert current["shot_for_intent"] == {key: value for key, value in base["shot_for_intent"].items() if key != "scatter_shot"}
    assert current["shots"] == approved["shots"]
    for key in ("shots", "shot_for_element"):
        for name, value in base[key].items():
            if key != "shot_for_element" or name not in {"fire", "lightning"}:
                assert current[key][name] == value, (key, name)
    total = 0
    for old, round_zero, new in zip(base["sizes"], approved["sizes"], current["sizes"]):
        assert atlas_path(old) == atlas_path(new) and old["tile_cells"] == new["tile_cells"]
        old_image = Image.open(BytesIO(base_file(atlas_path(old))))
        new_image = Image.open(ROOT / atlas_path(new))
        assert old_image.mode == new_image.mode == "L"
        assert hashlib.sha256(new_image.tobytes()).hexdigest() == new["sha256_pixels"]
        assert set(new["shots"]) - set(old["shots"]) == set(DESIGNS)
        used_ink = set()
        for name, info in old["shots"].items():
            assert new["shots"][name] == info, (atlas_path(new), name, "geometry")
            box = region(old, name, base["headings"])
            assert old_image.crop(box).tobytes() == new_image.crop(box).tobytes(), (atlas_path(new), name, "pixels")
            total += 1
        assert new["shots"]["ember"] == round_zero["shots"]["ember"]
        ember_box = region(round_zero, "ember", approved["headings"])
        with Image.open(BytesIO(base_file(atlas_path(round_zero), ROUND_ZERO))) as approved_image:
            ember_bytes = new_image.crop(ember_box).tobytes()
            assert ember_bytes == approved_image.crop(ember_box).tobytes(), (atlas_path(new), "ember pixels")
            assert all(current["palette"][index] == approved["palette"][index] for index in set(ember_bytes)), (atlas_path(new), "ember colours")
        for name in DESIGNS:
            frame = new["shots"][name]
            assert frame["kind"] == "heading" and frame["rows"] == 3
            side = frame["frame_cells"]
            for row in range(frame["rows"]):
                for heading in range(current["headings"]):
                    x, y = heading * side, frame["y"] + row * side
                    cell = new_image.crop((x, y, x + side, y + side))
                    assert cell.getbbox(), (atlas_path(new), name, row, heading)
                    used_ink.update(cell.getdata())
        assert max(used_ink) < len(current["palette"])
        print(f"FX-23 ATLAS {Path(atlas_path(new)).name}: {len(old['shots'])} existing regions identical")
    print(f"FX-23 PIXEL IDENTITY: PASS ({total} regions across 7 atlases, indices and colours)")
    print(f"FX-23 EMBER IDENTITY: PASS (7 regions against {ROUND_ZERO}, indices and colours)")


def headings(metadata, output):
    sheet = next(size for size in metadata["sizes"] if size["tile_cells"] == SHEET_CELLS)
    with Image.open(ROOT / atlas_path(sheet)) as indexed:
        palette = bytes.fromhex("".join(metadata["palette"]))
        lookup = [tuple(palette[i:i + 4]) for i in range(0, len(palette), 4)]
        columns = range(0, metadata["headings"], 4)
        side = sheet["shots"][DESIGNS[0]]["frame_cells"]
        image = Image.new("RGB", (side * len(columns), side * 3 * len(DESIGNS)), FLOOR)
        for design_index, design in enumerate(DESIGNS):
            frame = sheet["shots"][design]
            assert frame["frame_cells"] == side
            for row in range(frame["rows"]):
                for column, heading in enumerate(columns):
                    x, y = heading * side, frame["y"] + row * side
                    cell = indexed.crop((x, y, x + side, y + side))
                    colours = Image.new("RGBA", cell.size)
                    colours.putdata([lookup[index] for index in cell.getdata()])
                    image.paste(colours, (column * side, (design_index * 3 + row) * side), colours)
        output.parent.mkdir(parents=True, exist_ok=True)
        image.resize((image.width * SHEET_SCALE, image.height * SHEET_SCALE), Image.Resampling.NEAREST).save(output)
    print(f"FX-23 HEADINGS: {output}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--headings", type=Path, required=True)
    args = parser.parse_args()
    current = json.loads((ROOT / METADATA).read_text())
    check(json.loads(base_file(METADATA)), current)
    headings(current, args.headings)
