#!/usr/bin/env python3
"""Owner-only proof setup: copy census driver at 1920x1080, 100% UI scale."""
import argparse
from pathlib import Path
from replay import stage


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', required=True, type=Path)
    parser.add_argument('--baseline-project', type=Path, help='optional baseline replay snapshot for the three product files')
    args = parser.parse_args()
    stage(args.project)
    if args.baseline_project:
        for relative in ('scripts/asset_loader.gd', 'scripts/menu_run_transition.gd',
                         'scripts/run_loading_texture_manifest.gd'):
            (args.project / relative).write_bytes((args.baseline_project / relative).read_bytes())
    for relative in ('tools/hitch_census/driver.gd', 'tools/hitch_census/viewport.gd',
                     'tools/hitch_census/demo/route.gd'):
        path = args.project / relative
        source = path.read_text().replace('1.15', '1.0').replace('1280, 800', '1920, 1080').replace('1280x800', '1920x1080')
        path.write_text(source)
    override = args.project / 'override.cfg'
    if override.is_symlink():
        override.unlink()
    override.write_text('; Owner proof configuration only.\n[display]\nwindow/dpi/allow_hidpi=false\n')
    print('PERF126 CAPTURE PROJECT: ' + str(args.project))


if __name__ == '__main__':
    main()
