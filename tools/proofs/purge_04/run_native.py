#!/usr/bin/env python3
"""Owner-only native capture, validation, sheets and crash-report inventory."""
import argparse
import os
from pathlib import Path
import shlex
import subprocess
import sys
import time

PROJECT = Path(__file__).resolve().parents[3]
DEFAULT_OUTPUT = Path('/private/tmp/purge-04-native')
PROOF = 'tools/proofs/purge_04'
CAPTURE_TIMEOUT_SECONDS = 180
AUDIT_TIMEOUT_SECONDS = 90
STARTUP_TIMEOUT_SECONDS = 45


def commands(output):
    yield [sys.executable, 'tools/cel_look.py', 'build', '--if-stale']
    for width, height in [(1920, 1080), (1280, 800)]:
        for stage in ['before', 'after']:
            stem = f'{stage}_{width}'
            command = [sys.executable, 'tools/visual_probe_runner.py', '--task-id', 'purge-04',
                       '--no-headless', '--display-driver', 'macos', '--audio-driver', 'Dummy',
                       '--timeout', str(CAPTURE_TIMEOUT_SECONDS), '--startup-timeout', str(STARTUP_TIMEOUT_SECONDS),
                       '--expect-size', f'{width}x{height}', '--proof-contract', f'{PROOF}/capture_{width}.json',
                       '--result-manifest', str(output / f'{stem}_manifest.json'), f'{PROOF}/capture.gd', '--',
                       f'--output={output / stem}']
            if stage == 'before': command.append('--baseline')
            if width == 1280: command.append('--deck')
            yield command
    yield [sys.executable, 'tools/visual_probe_runner.py', '--task-id', 'purge-04',
           '--no-headless', '--display-driver', 'macos', '--audio-driver', 'Dummy',
           '--timeout', str(AUDIT_TIMEOUT_SECONDS), '--startup-timeout', str(STARTUP_TIMEOUT_SECONDS),
           '--expect-size', '1920x1080', '--proof-contract', f'{PROOF}/audit.json',
           '--result-manifest', str(output / 'audit_manifest.json'), f'{PROOF}/audit.gd', '--',
           f'--output={output / "audit"}']
    for width in [1920, 1280]:
        yield [sys.executable, f'{PROOF}/summarize.py', '--before', str(output / f'before_{width}'),
               '--after', str(output / f'after_{width}'), '--output', str(output / f'summary_{width}')]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument('--print-commands', action='store_true')
    args = parser.parse_args()
    output = args.output.resolve()
    started = time.time()
    try:
        for command in commands(output):
            print(f'cd {shlex.quote(str(PROJECT))} && LABYRINTH_CEL_LOOK=all {shlex.join(command)}', flush=True)
            if not args.print_commands:
                subprocess.run(command, cwd=PROJECT, env=dict(os.environ, LABYRINTH_CEL_LOOK='all'), check=True)
    finally:
        if not args.print_commands:
            reports = Path.home() / 'Library/Logs/DiagnosticReports'
            recent = [p for p in reports.glob('*') if p.is_file() and p.stat().st_mtime >= started]
            for report in sorted(recent): print(f'NEW DIAGNOSTIC REPORT: {report}')
            if not recent: print(f'DIAGNOSTIC REPORTS: no new reports in {reports}')


if __name__ == '__main__':
    main()
