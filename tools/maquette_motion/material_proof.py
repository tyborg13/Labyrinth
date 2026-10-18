"""CPU contact sheets of approved cutout paint; no native-renderer claim."""
import argparse
import math
from pathlib import Path
from PIL import Image
from cutout_pipeline.cases import read_json, write_json, digest
from maquette_motion.hidden_material import render_layers
from maquette_motion.gates import input_bindings


def generate(before_case, after_case, before_samples, after_samples, crops, output):
    output.mkdir(parents=True, exist_ok=True)
    stages = {}
    background = tuple(crops['background_rgb']) + (255,)
    metadata = {'basis': 'CPU nearest-source composition; director must recapture native output',
                'crops': crops, 'sheets': {}, 'individual_shell_frames': [],
                'tool_sha256': digest(Path(__file__)),
                'before_inputs': input_bindings(before_case), 'after_inputs': input_bindings(after_case),
                'before_samples_sha256': digest(before_samples), 'after_samples_sha256': digest(after_samples)}
    for name, case, samples in (('before', before_case, before_samples), ('after', after_case, after_samples)):
        layout = read_json(case / 'layouts/rear.json')
        rows = {(r['clip'], r['frame']): r for r in read_json(samples)['samples'] if r['view'] == 'rear'}
        images = {p['name']: Image.open(case / p['file']).convert('RGBA') for p in layout['parts']}
        cache = {}

        def frame(clip, at):
            key = ('idle' if clip == 'rest' else clip, at)
            if key not in cache:
                image, _ = render_layers(case, layout, rows[key], images)
                cache[key] = Image.fromarray(image)
            return cache[key]

        stages[name] = frame
        # Capture all requested Shell frames, not only the ten sheet samples.
        for at in range(crops['individual_shell_frames'][0], crops['individual_shell_frames'][1] + 1):
            path = f'{name}/rear_shell/{at:04d}.png'
            (output / path).parent.mkdir(parents=True, exist_ok=True)
            frame('shell', at).save(output / path)
            metadata['individual_shell_frames'].append(path)
        # Bind each stage's closure to its own rows/images/cache before moving
        # on to the other stage (the sheets are assembled after this loop).
        stages[name] = dict(cache)
        for clip, at in crops['detail_poses'] + crops['action_poses']:
            stages[name][('idle' if clip == 'rest' else clip, at)] = frame(clip, at)

    selections = {'shell': [('shell', at) for at in crops['shell_frames']],
                  'left': crops['detail_poses'], 'top': crops['detail_poses'],
                  'actions': crops['action_poses']}
    for name, poses in selections.items():
        camera = crops['crops']['shell' if name == 'actions' else name]
        zoom = camera['zoom']
        bounds = tuple(n + crops['source_offset'] for n in camera['source_bounds'])
        width, height = (bounds[2] - bounds[0]) * zoom, (bounds[3] - bounds[1]) * zoom
        columns = min(camera['columns'], len(poses))
        rows = math.ceil(len(poses) / columns)
        sheet = Image.new('RGB', (columns * width, 2 * rows * height), background[:3])
        entries = []
        for stage_index, stage in enumerate(('before', 'after')):
            for index, (clip, at) in enumerate(poses):
                image = stages[stage][('idle' if clip == 'rest' else clip, at)]
                cell = Image.new('RGBA', image.size, background)
                cell.alpha_composite(image)
                cell = cell.crop(bounds).resize((width, height), Image.Resampling.NEAREST).convert('RGB')
                x, y = index % columns, stage_index * rows + index // columns
                sheet.paste(cell, (x * width, y * height))
                entries.append({'stage': stage, 'clip': clip, 'frame': at, 'column': x, 'row': y})
        path = 'before_after_' + name + '.png'
        sheet.save(output / path)
        metadata['sheets'][path] = entries
    metadata['sheet_sha256'] = {path: digest(output / path) for path in metadata['sheets']}
    write_json(output / 'contact_sheets.json', metadata)
    print(f'MAQUETTE CPU MATERIAL PROOF: PASS ({len(metadata["individual_shell_frames"])} Shell frames; 4 before/after sheets)')
    return metadata


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('before-case', 'after-case', 'before-samples', 'after-samples', 'crops', 'output'):
        parser.add_argument('--' + name, required=True, type=Path)
    args = parser.parse_args()
    generate(args.before_case, args.after_case, args.before_samples, args.after_samples, read_json(args.crops), args.output)


if __name__ == '__main__':
    main()
