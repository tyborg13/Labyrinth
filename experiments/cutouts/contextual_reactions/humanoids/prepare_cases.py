#!/usr/bin/env python3
"""Snapshot current production, then fork fresh editable humanoid/guardian cases.

Default clips cover changed reactions, changed Bell Tender actions and NPC idles.
--all-clips retains the complete authored-cycle audit catalog. This is a snapshot
adapter, never a historical art builder; no generated paint or layout is invented.
"""
from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / 'tools'))
from cutout_pipeline.cases import (  # noqa: E402
    baseline, digest, fork_case, image_records, init_case,
    seed_protagonist, write_json,
)

METADATA = Path(__file__).with_name('case_metadata.json')


def snapshot(output: Path, name: str, metadata: dict) -> Path:
    if name == 'protagonist':
        seed_protagonist(output, name)
        config = json.loads((output / 'cutout.json').read_text())
        # Keep seed's current melee curve and clocks rather than freezing them.
        seeded_clips = config['clips']
        config.update(metadata)
        config['clips'].update(seeded_clips)
    else:
        guardian = (ROOT / 'assets/units/guardians' / name).is_dir()
        source = ROOT / 'assets/units' / ('guardians/' + name if guardian else name + '_cutout')
        facings = [f for f in ('front', 'rear') if (source / (f + '.json')).exists()]
        init_case(output, name, facings)
        config = json.loads((output / 'cutout.json').read_text())
        config.update(metadata)
        config['source_baseline'] = {'kind': 'production_snapshot', 'files': {}}
        hashes = config['source_baseline']['files']
        for facing in facings:
            layout_path = source / (facing + '.json')
            layout = json.loads(layout_path.read_text())
            hashes[str(layout_path.relative_to(ROOT))] = digest(layout_path)

            def copy_image(value: str) -> str:
                image = ROOT / value.removeprefix('res://') if value.startswith('res://') else source / value
                relative = 'assets/' + str(image.relative_to(source))
                target = output / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(image, target)
                Path(str(target) + '.import').write_text('[remap]\n\nimporter="keep"\n')
                hashes[str(image.relative_to(ROOT))] = digest(image)
                return relative

            for item in image_records(layout):
                item['file'] = copy_image(item['file'])
            if layout.get('rest_source'):
                layout['rest_source'] = copy_image(layout['rest_source'])
            write_json(output / config['layouts'][facing], layout)
        motion = ROOT / 'scripts' / ('guardian_cutout' if guardian else name + '_cutout') / 'motion.gd'
        shutil.copyfile(motion, output / 'motion.gd')
        hashes[str(motion.relative_to(ROOT))] = digest(motion)
    write_json(output / 'cutout.json', config)
    baseline(output)
    return output


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True, help='Fresh output directory; existing cases are never overwritten')
    parser.add_argument('--all-clips', action='store_true', help='Include retained authored cycles for broad raw review')
    parser.add_argument('--actors', nargs='+', help='Optional actor ids; default all 19 combatants and both NPCs')
    args = parser.parse_args()
    metadata = json.loads(METADATA.read_text())
    actors = args.actors or list(metadata)
    output = args.output.resolve()
    if output.exists():
        parser.error('Output already exists; use a fresh directory')
    for name in actors:
        if name not in metadata:
            parser.error('Unknown actor: ' + name)
    for name in actors:
        source = snapshot(output / (name + '_baseline'), name, metadata[name])
        fork_case(source, output / name, name + '_contextual')
        path = output / name / 'cutout.json'
        config = json.loads(path.read_text())
        if not args.all_clips:
            keep = {'hit', 'death', 'block'}
            if name in ('acolyte', 'bell_tender', 'scavenger', 'graftwright'):
                keep.update(config['clips'])
            config['clips'] = {k: v for k, v in config['clips'].items() if k in keep}
            write_json(path, config)
        print(path, flush=True)


if __name__ == '__main__':
    main()
