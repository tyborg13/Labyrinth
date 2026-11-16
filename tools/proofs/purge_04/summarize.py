#!/usr/bin/env python3
"""Assemble the task's native before/after sheet and numeric frame table."""
import argparse
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--before', type=Path, required=True)
    parser.add_argument('--after', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    lines = ['| Run | Case | Frame | Confirmation x,y,w,h | Composite x,y,w,h | Max error px |',
             '| --- | --- | ---: | --- | --- | ---: |']
    native = True
    for stage, folder in [('Before', args.before), ('After', args.after)]:
        data = json.loads((folder / 'rects.json').read_text())
        native = native and data['native']
        for row in data['measurements']:
            expected = ', '.join(f'{v:.6f}' for v in row['expected'])
            actual = ', '.join(f'{v:.6f}' for v in row['actual'])
            lines.append(f"| {stage} | {row['case']} | {row['frame']} | {expected} | {actual} | {row['max_error_px']:.6f} |")
    (args.output / 'measurements.md').write_text('\n'.join(lines) + '\n')
    if native:
        # Pillow is an existing project tooling dependency; no art or fonts are
        # created here. Every tile retains its exact captured pixel dimensions.
        from PIL import Image
        with Image.open(args.before / 'ui100_burn/contact_sheet.png') as before:
            with Image.open(args.after / 'ui100_burn/contact_sheet.png') as after:
                if before.size != after.size:
                    raise ValueError('Before and after sheet dimensions differ')
                sheet = Image.new('RGB', (before.width, before.height * 2))
                sheet.paste(before, (0, 0))
                sheet.paste(after, (0, before.height))
                sheet.save(args.output / 'before_after_native.png')
    print(f"PURGE-04 SUMMARY: native={native} output={args.output}")


if __name__ == '__main__':
    main()
