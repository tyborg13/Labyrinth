#!/usr/bin/env python3
"""Verify source, preserved themes, new middle voices, audio and mix evidence."""
import argparse
from collections import Counter
import json
from pathlib import Path

import build_thorns as build
import verify as checks


def notes(s, part):
    return sorted((n for n in s['notes'] if n['instrument'] == part), key=lambda n: (n['beat'], n['pitch']))


def structure(s):
    parent = json.loads((build.PARENTS[s['slug']] / 'score.json').read_text())
    expected = [dict(n, instrument='violin_1', pitch=n['pitch'] + 12) for n in notes(parent, 'shadow_lead')]
    checks.require(notes(s, 'violin_1') == expected, 'Lead differs beyond documented octave and instrument move')
    for part in ['drums', 'hollow_bass', 'thread_pluck']:
        checks.require(notes(s, part) == notes(parent, part), f'{part} pulse events changed')
    checks.require(s['bpm'] == parent['bpm'] and s['bars'] == parent['bars'] and s['harmony'] == parent['harmony'], 'Form or harmony drift')
    events = []
    for n in s['notes']:
        checks.require(0 <= n['beat'] < s['bars'] * 4 and n['duration'] > 0 and
                       n['beat'] + n['duration'] <= s['bars'] * 4 + 1e-6, 'Invalid note bounds')
        checks.require(0 <= n['pitch'] <= 127 and 1 <= n['velocity'] <= 127, 'Invalid MIDI note')
        if n['instrument'] != 'drums':
            events += [(n['beat'], 1), (n['beat'] + n['duration'], -1)]
    active = peak = 0
    for _, delta in sorted(events):
        active += delta
        peak = max(peak, active)
    checks.require(peak <= 6, 'Too many simultaneous melodic gates')
    voices = {}
    for part in ['violin_1', 'violin_2', 'viola']:
        sequence = notes(s, part)
        gaps = [round(b['beat'] - a['beat'] - a['duration'], 6) for a, b in zip(sequence, sequence[1:])]
        checks.require(min(gaps) >= 0, f'{part} is not monophonic')
        checks.require(min(n['pitch'] for n in sequence) >= (48 if part == 'viola' else 55), 'Below string range')
        coverage = sum(n['duration'] for n in sequence) / (s['bars'] * 4)
        if part != 'violin_1':
            checks.require(coverage >= .65, 'Middle layer is too sparse')
            # Harmonic support need not use seven different pitches; check that
            # it moves and has its own rhythm rather than duplicating the lead.
            checks.require(any(a['pitch'] != b['pitch'] for a, b in zip(sequence, sequence[1:])), 'Middle voice is a static pitch')
            checks.require([n['beat'] for n in sequence] != [n['beat'] for n in notes(s, 'violin_1')], 'Middle rhythm duplicates lead')
        voices[part] = {'notes': len(sequence), 'unique_pitches': len({n['pitch'] for n in sequence}), 'gate_coverage': coverage,
                        'detached_transitions': sum(g > .05 for g in gaps),
                        'touching_transitions': sum(g == 0 for g in gaps)}
    return {'melody_identity': 'Exact notes/onsets/gates/velocities; one octave higher',
            'percussion_events': 'unchanged', 'max_melodic_gates': peak, 'voices': voices}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    manifest = json.loads((args.directory / 'SOURCES.json').read_text())
    for path, expected in manifest['inputs_sha256'].items():
        checks.require(build.v01.sha256(build.ROOT / path) == expected, f'Source drift: {path}')
    folders = sorted(p for p in args.directory.iterdir() if p.is_dir())
    checks.require([p.name for p in folders] == sorted(build.PARENTS), 'Wrong audition inventory')
    report = {'status': 'passed', 'source_hashes_checked': len(manifest['inputs_sha256']),
              'listening_review': 'User audition pending; numeric proof does not establish perceived violin realism or musical quality.', 'tracks': {}}
    for folder in folders:
        s = json.loads((folder / 'score.json').read_text())
        checks.require(s == build.arrange(folder.name), 'Expanded score differs from authored arrangement')
        render = json.loads((folder / 'render.json').read_text())
        checks.require(set(render['artifacts_sha256']) == {'score.json', 'arrangement.mid', 'preview.flac', 'preview.ogg', 'preview.mp3'}, 'Incomplete output inventory')
        for name, expected in render['artifacts_sha256'].items():
            checks.require(build.v01.sha256(folder / name) == expected, f'Artifact drift: {name}')
        checks.require(render['note_counts'] == dict(Counter(n['instrument'] for n in s['notes'])), 'Note count drift')
        midi = checks.check_midi(folder / 'arrangement.mid', s)
        music = structure(s)
        balance = render['balance']
        checks.require(balance['lead_change_lu'] <= -2, 'Lead did not sit back in matched mix')
        checks.require(balance['percussion_change_lu'] <= .25, 'Percussion was brought forward')
        checks.require(-2 <= balance['lead_above_middle_lu'] <= 4, 'Middle strings are buried or overpowering')
        audio = {}
        for suffix in ['flac', 'ogg', 'mp3']:
            path = folder / f'preview.{suffix}'
            checks._strict_decode(path)
            streams = checks._probe(path)['streams']
            checks.require(len(streams) == 1 and streams[0]['channels'] == 2 and int(streams[0]['sample_rate']) == 32000, 'Wrong audio format')
            metrics = checks._decoded_metrics(path, 32000)
            checks.require(abs(metrics['duration_seconds'] - s['bars'] * 240 / s['bpm']) < .005, 'Duration drift')
            checks.require(not checks._long_silences(path, .5), 'Unexpected silence')
            if suffix != 'mp3':
                checks._validate_loop_seam(metrics, 1.5, str(path))
            metrics.update(checks.loudness(path))
            checks.require(-21 <= metrics['integrated_lufs'] <= -19, 'Unmatched loudness')
            checks.require(metrics['peak_dbfs'] < -1 and metrics['true_peak_dbtp'] < -1, 'Insufficient headroom')
            audio[suffix] = metrics
        report['tracks'][s['title']] = {'structure': music, 'midi': midi, 'audio': audio, 'balance': balance}
        print(f"PASS {s['title']} {s['version']}: {audio['flac']['integrated_lufs']} LUFS; lead {balance['lead_change_lu']:.2f} LU; drums {balance['percussion_change_lu']:.2f} LU", flush=True)
    if args.report:
        build.v01.write_json(args.report, report)


if __name__ == '__main__':
    main()
