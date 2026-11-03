#!/usr/bin/env python3
"""Report rest-silhouette clearance; never change presentation or roster data."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = Path('/private/tmp/labyrinth_codex/grb-01/floating_roster.txt')
CLEARANCE_HEIGHT_SHARE = 0.12
OPAQUE_ALPHA = 255
VIEWS = ('front', 'rear')


def clearance(image: Image.Image, floor_y: float) -> tuple[int, int]:
    """Use opaque silhouette span as width, full source canvas as height."""
    rgba = image.convert('RGBA')
    lowest = {}
    for x in range(rgba.width):
        for y in range(rgba.height - 1, -1, -1):
            if rgba.getpixel((x, y))[3] == OPAQUE_ALPHA:
                lowest[x] = y
                break
    if not lowest:
        raise ValueError('Rest has no fully opaque pixels')
    width = max(lowest) - min(lowest) + 1
    raised = sum(floor_y - y > image.height * CLEARANCE_HEIGHT_SHARE
                 for y in lowest.values())
    return raised, width


def roster_rows(project: Path = ROOT) -> list[dict]:
    enemies = json.loads((project / 'data/enemies.json').read_text())
    source = (project / 'scripts/actor_presentation.gd').read_text().split('const PROFILES:', 1)[1]
    profiles = {unit: {view: (float(x), float(y)) for view, x, y in re.findall(
        r'"(front|rear)": Vector2\(([\d.]+), ([\d.]+)\)', body)}
        for unit, body in re.findall(r'^\s*"([\w]+)": \{([^\n]+)\}', source, re.M)}
    presentation = (project / 'scripts/maquette_cutout_runtime/presentation.gd').read_text()
    creatures = dict(re.findall(r'"(\w+)": "(\w+)"', presentation.split('const CREATURES :=', 1)[1].split('static var', 1)[0]))
    rows = []
    for unit, definition in enemies.items():
        if definition.get('flying', False):
            continue
        directory = project / 'assets/units' / (creatures.get(unit, 'stone_warden' if unit == 'warden' else unit) + '_cutout')
        guardian_directory = project / 'assets/units/guardians' / unit
        if (guardian_directory / 'front/rest.png').is_file():
            directory = guardian_directory
        if unit in creatures:
            integration = json.loads((directory / 'integration.json').read_text())
            child = integration.get('rig_directory', 'humanoid_v2' if unit in ('hoarfrost_seer', 'arc_thrall', 'glacial_mirror') else '')
            directory = directory / child
        for view in VIEWS:
            rest = directory / view / 'rest.png'
            if not rest.is_file():
                key = 'art_path' if view == 'front' else 'art_rear_path'
                rest = project / definition[key].removeprefix('res://')
            with Image.open(rest) as image:
                # Registered floor landmarks are in the 255 px rest canvas.
                if unit in profiles:
                    floor_y = profiles[unit][view][1] * image.height / 255.0
                    landmark = 'ActorPresentation.PROFILES'
                else:
                    layout = json.loads((directory / (view + '.json')).read_text())
                    floor_y = layout['joints']['root']['position'][1] * image.height / layout['canvas_size'][1]
                    landmark = 'production layout root'
                raised, width = clearance(image, floor_y)
                rows.append(dict(unit=unit, view=view, share=raised / width, raised=raised,
                                 width=width, height=image.height, floor_y=floor_y,
                                 landmark=landmark, path=str(rest.relative_to(project))))
    return sorted(rows, key=lambda row: (-row['share'], row['unit'], row['view']))


def write_report(output: Path, rows: list[dict]) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        'grb-01 floating roster — report only; no tuning decisions',
        'Non-flying means data/enemies.json flying != true (no inferred exclusions).',
        'Opaque means alpha=255; width is min..max opaque x inclusive.',
        'Raised means floor_y - lowest_opaque_y > 12% of full sprite canvas height.',
        'Empty columns within the opaque span remain in the width denominator.',
        'Profiles supply registered floors; types without profiles use production layout roots.',
        f'{len(rows)} views, {len({r["unit"] for r in rows})} enemies; worst first.',
        '', 'share\traised/width\tunit\tview\tfloor_y\theight\tlandmark\trest',
    ]
    lines.extend(f'{r["share"]:.2%}\t{r["raised"]}/{r["width"]}\t{r["unit"]}\t{r["view"]}\t'
                 f'{r["floor_y"]:.4f}\t{r["height"]}\t{r["landmark"]}\t{r["path"]}' for r in rows)
    output.write_text('\n'.join(lines) + '\n')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    rows = roster_rows()
    write_report(args.output, rows)
    print(f'GRB01 FLOATING ROSTER: PASS ({len(rows)} views; {args.output})')


if __name__ == '__main__':
    main()
