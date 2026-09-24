#!/usr/bin/env python3
"""Violin/viola revisions of two existing original combat auditions."""
from collections import Counter
import argparse
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

import numpy as np
import mido
import bowed_strings

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'project.godot').exists())
CASE = Path(__file__).resolve().parents[1]
OLD = ROOT / 'output/original_soundtracks/umbra_three_sketches'
sys.path.insert(0, str(OLD / 'scripts'))
import build_v02 as engine
v01 = engine.v01
RATE = v01.RATE
PARENTS = {
    '01_ashen_pursuit_v03': OLD / 'versions/v02/03_ashen_pursuit',
    '02_iron_procession_v02': ROOT / 'output/original_soundtracks/combat_set_02/versions/v01/01_iron_procession',
}


def line(s, name, bars, velocity):
    assert len(bars) == s['bars']
    for bar, text in enumerate(bars):
        for i, token in enumerate(text.split()):
            onset, pitch, duration = token.split(':')
            v01.add(s, name, bar, float(onset), float(duration), pitch, velocity - 3 * (i % 2))


def arrange(slug):
    parent = json.loads((PARENTS[slug] / 'score.json').read_text())
    s = copy.deepcopy(parent)
    s.update({'slug': slug, 'version': 'v03' if 'ashen' in slug else 'v02',
              'based_on': str((PARENTS[slug] / 'score.json').relative_to(ROOT)),
              'lead_instrument': 'violin_1', 'revision': [
                  'Original lead pitches raised one octave; all onsets, gates and velocities retained.',
                  'New bowed violin synthesis with body resonances, subtle bow noise and independent vibrato.',
                  'Lead sits farther into the ensemble; second violin and viola supply an active middle layer.',
                  'Percussion notes retained and mixed more quietly; original harmonic sequence and tempo retained.']})
    s['patches'].pop('grave_lead')
    s['patches'].pop('answer_viol')
    for name, pan, voice, vib, rate in [('violin_1', -.12, 'violin', 10, 4.9),
                                       ('violin_2', .24, 'violin', 8, 5.15),
                                       ('viola', -.30, 'viola', 6, 4.65)]:
        s['patches'][name] = {'program': 41 if voice == 'viola' else 40, 'voice': voice,
            'pan': pan, 'wet': .24 if name == 'violin_1' else .27,
            'attack_seconds': .048 if name == 'violin_1' else .065,
            'release_seconds': .16 if name == 'violin_1' else .22,
            'vibrato_cents': vib, 'vibrato_hz': rate,
            'bow_noise': .0038 if voice == 'violin' else .0028,
            'lowpass_hz': 3500 if name == 'violin_1' else 2900}
    # Keep one sustained pad voice; the new viola supplies the missing inner voice.
    pad_onsets = set()
    s['notes'] = []
    for original in sorted(parent['notes'], key=lambda n: (n['beat'], n['pitch'])):
        n = copy.deepcopy(original)
        if n['instrument'] == 'answer_viol':
            continue
        if n['instrument'] == 'grave_lead':
            n['instrument'], n['pitch'] = 'violin_1', n['pitch'] + 12
        elif n['instrument'] == 'bowed_veil':
            if n['beat'] in pad_onsets:
                continue
            pad_onsets.add(n['beat'])
        s['notes'].append(n)
    if 'ashen' in slug:
        line(s, 'violin_2', [
            '1:A3:1 2:F4:1.7', '0:D4:1.4 2:C4:.5 2.5:A3:1.25',
            '0:Bb3:1.4 2:F4:1.75', '0:A3:1.5 2:Bb3:.75 2.75:D4:1.1',
            '0:Bb3:1.5 2:G4:1.75', '0:D4:1.25 1.5:Bb3:1 2.75:D4:1',
            '0:C#4:1.5 2:E4:.75 2.75:D4:.5 3.25:C#4:.6', '0:C#4:1.5 2:E4:.75 2.75:G4:1.1',
            '0:Bb3:2 2:D4:1.75', '0:D4:1.5 2:Bb3:.8 3:A3:.75',
            '0:Bb3:1.5 2:Eb4:1.75', '0:D4:1.25 1.5:Bb3:1 2.75:G3:1',
            '0:D4:1.5 2:G4:1 3:F4:.8', '0:F4:1.5 2:D4:.75 3:Bb3:.75',
            '0:C#4:1 1:E4:1.5 2.75:G4:1', '0:G4:1.5 2:E4:.75 2.75:C#4:1.1',
            '0:F4:1.5 2:A4:1.75', '0:F4:1.5 2:E4:.5 2.5:F4:1.25',
            '0:D4:1.5 2:F4:1.75', '0:F4:1.5 2:D4:.75 2.75:Bb3:1.1',
            '0:D4:1.5 2:G4:1.75', '0:D4:1.5 2:Bb3:.75 2.75:F4:1.1',
            '0:C#4:1.5 2:E4:.75 2.75:G4:1.1', '0:G4:1.25 1.5:E4:1 2.75:C#4:1',
        ], 66)
        line(s, 'viola', [
            '0:F3:2.75 3:A3:.8', '0:F3:1.75 2:E3:.75 3:F3:.8',
            '0:D3:2 2:F3:1.75', '0:F3:2.75 3:D3:.8',
            '0:G3:2.75 3:Bb3:.8', '0:G3:1.75 2:F3:.75 3:G3:.8',
            '0:E3:2 2:G3:1.75', '0:E3:2.75 3:C#3:.8',
            '0:G3:3.75', '0:Bb3:1.75 2:A3:.75 3:G3:.8',
            '0:G3:3.75', '0:Bb3:1.75 2:G3:1.75',
            '0:Bb3:2.75 3:G3:.8', '0:D3:1.75 2:F3:1.75',
            '0:E3:2.75 3:G3:.8', '0:G3:1.75 2:E3:.75 3:C#3:.8',
            '0:A3:2 2:F3:1.75', '0:A3:1.75 2:G3:.75 3:F3:.8',
            '0:F3:2 2:D3:1.75', '0:D3:2.75 3:F3:.8',
            '0:Bb3:2 2:G3:1.75', '0:F3:2.75 3:D3:.8',
            '0:E3:2 2:G3:1.75', '0:E3:2.75 3:C#3:.8',
        ], 61)
    else:
        line(s, 'violin_2', [
            '1:D4:1 2:F4:.75 3:D4:.75', '0:G4:1.5 2:F4:.75 2.75:D4:1.1',
            '0:Eb4:1.5 2:G4:1.75', '0:F#4:1.5 2:E4:.5 2.5:D4:1.25',
            '0:D4:1.5 2:G4:1.75', '0:G4:1.5 2:Eb4:.75 2.75:C4:1.1',
            '0:Eb4:1.5 2:G4:1.75', '0:F#4:1.5 2:D4:.75 3:C4:.75',
            '0:Eb4:2 2:G4:1.75', '0:Eb4:1.5 2:D4:.75 3:C4:.75',
            '0:Eb4:1.5 2:C4:1 3:Eb4:.75', '0:D4:1.5 2:F#4:.75 2.75:E4:.5 3.25:D4:.6',
            '0:Bb4:1.5 2:F4:.75 3:D4:.75', '0:G4:1.5 2:Bb4:1.75',
            '0:G4:1.5 2:Eb4:.75 2.75:G4:1.1', '0:F#4:1.5 2:E4:.75 2.75:D4:1.1',
            '0:G4:1.5 2:D4:1.75', '0:Eb4:1.5 2:G4:1.75',
            '0:D4:1.5 2:C4:.75 3:A3:.75', '0:D4:1.25 1.5:C4:.75 2.5:A3:.75 3.25:F#4:.6',
        ], 65)
        line(s, 'viola', [
            '0:Bb3:2.75 3:A3:.8', '0:Bb3:1.75 2:A3:.75 3:G3:.8',
            '0:G3:2.75 3:Bb3:.8', '0:A3:1.75 2:F#3:1.75',
            '0:Bb3:2 2:D4:1.75', '0:Eb3:2 2:G3:1.75',
            '0:Bb3:2 2:G3:1.75', '0:A3:1.75 2:F#3:1.75',
            '0:G3:3.75', '0:G3:1.75 2:Eb3:1.75',
            '0:C4:1.75 2:Ab3:1.75', '0:A3:2.75 3:F#3:.8',
            '0:Bb3:2 2:D4:1.75', '0:Bb3:2 2:G3:1.75',
            '0:Eb3:2 2:G3:1.75', '0:A3:1.75 2:F#3:1.75',
            '0:Bb3:2.75 3:G3:.8', '0:G3:1.75 2:Bb3:1.75',
            '0:G3:2 2:C4:1.75', '0:A3:1.75 2:F#3:1.75',
        ], 61)
    s['notes'].sort(key=lambda n: (n['beat'], n['instrument'], n['pitch']))
    return s


def string_stem(s, name):
    stem = np.zeros((round(s['bars'] * 240 / s['bpm'] * RATE), 2))
    groups = []
    for n in (n for n in s['notes'] if n['instrument'] == name):
        if not groups or n['beat'] > groups[-1][-1]['beat'] + groups[-1][-1]['duration'] + 1e-5:
            groups.append([])
        groups[-1].append(n)
    for notes in groups:
        wave = bowed_strings.phrase(notes, s['bpm'], s['patches'][name])
        v01.circular_add(stem, wave, round(notes[0]['beat'] * 60 / s['bpm'] * RATE), s['patches'][name]['pan'])
    return engine.circular_lowpass(stem, s['patches'][name]['lowpass_hz'])


def measured(signal, path):
    v01.write_stereo_wave(path, signal, RATE)
    return float(v01.loudness(path)['input_i'])


def mix_and_render(s, destination, samples, waves):
    parent = json.loads((PARENTS[s['slug']] / 'score.json').read_text())
    with tempfile.TemporaryDirectory(prefix='umbra-strings-') as td:
        wav = Path(td) / 'measure.wav'
        old_stems = {name: engine.make_stem(parent, name, samples, waves)
                     for name in sorted({n['instrument'] for n in parent['notes']})}
        old_levels = {name: measured(stem, wav) for name, stem in old_stems.items()}
        old_wet = {name: v01.circular_dark_echo(stem, parent['patches'][name]['wet'], 60 / s['bpm'])
                   for name, stem in old_stems.items()}
        old_mix_level = measured(sum(old_wet.values()), wav)
        old_audible = {name: measured(stem, wav) - old_mix_level - 20 for name, stem in old_wet.items()}
        targets = {name: old_levels[name] - (1.5 if name in ['drums', 'bowed_veil'] else 1)
                   for name in ['drums', 'bowed_veil', 'hollow_bass', 'thread_pluck']}
        targets.update({'violin_1': old_levels['grave_lead'] - 4,
                        'violin_2': old_levels['grave_lead'] - 7,
                        'viola': old_levels['grave_lead'] - 8.5})
        dry, wet, gains = {}, {}, {}
        for name in sorted(targets):
            stem = string_stem(s, name) if name in ['violin_1', 'violin_2', 'viola'] else engine.make_stem(s, name, samples, waves)
            level = measured(stem, wav)
            gains[name] = 10 ** ((targets[name] - level) / 20)
            dry[name] = stem * gains[name]
            wet[name] = v01.circular_dark_echo(dry[name], s['patches'][name]['wet'], 60 / s['bpm'])
        mix = sum(wet.values())
        level = measured(mix, wav)
        master_gain = 10 ** ((-20 - level) / 20)
        # Exact bar period is retained. Taper only the last/first 2 ms to the same
        # zero boundary, preventing codec startup/padding from creating a click.
        fade = round(.002 * RATE)
        boundary = np.ones(len(mix))
        boundary[:fade] = np.sin(np.linspace(0, np.pi / 2, fade)) ** 2
        boundary[-fade:] = boundary[:fade][::-1]
        mix *= master_gain * boundary[:, None]
        if np.max(np.abs(mix)) > 10 ** (-3 / 20):
            raise ValueError('Unexpected peak; revise mix instead of clipping')
        v01.write_stereo_wave(wav, mix, RATE)
        for suffix, codec in [('flac', ['-c:a', 'flac', '-compression_level', '8']),
                              ('ogg', ['-c:a', 'vorbis', '-strict', 'experimental', '-q:a', '5']),
                              ('mp3', ['-c:a', 'libmp3lame', '-b:a', '192k'])]:
            subprocess.run(['ffmpeg', '-v', 'error', '-nostdin', '-i', str(wav), '-map_metadata', '-1',
                            *codec, str(destination / f'preview.{suffix}')], check=True)
        serial = int(hashlib.sha256((s['slug'] + 'string-ensemble-v1').encode()).hexdigest()[:8], 16)
        v01.normalize_ogg_serial(destination / 'preview.ogg', serial)
        new_audible = {name: measured(stem, wav) - level - 20 for name, stem in wet.items()}
        middle = measured(wet['violin_2'] + wet['viola'], wav) - level - 20
        balance = {'prior_stem_lufs_in_matched_mix': old_audible,
                   'revised_stem_lufs_in_matched_mix': new_audible,
                   'revised_middle_layer_lufs_in_matched_mix': middle,
                   'lead_change_lu': new_audible['violin_1'] - old_audible['grave_lead'],
                   'percussion_change_lu': new_audible['drums'] - old_audible['drums'],
                   'lead_above_middle_lu': new_audible['violin_1'] - middle}
        return {'version': s['version'], 'sample_rate': RATE, 'frames': len(mix),
                'duration_seconds': len(mix) / RATE, 'target_lufs': -20,
                'note_counts': dict(Counter(n['instrument'] for n in s['notes'])),
                'stem_calibration_gains': gains, 'master_gain': master_gain,
                'balance': balance, 'loop_method': 'circular tails/echo/filter; exact bar length; 2 ms endpoint taper'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path, default=CASE / 'versions/v01')
    args = parser.parse_args()
    destination = args.output_dir.resolve()
    if destination.exists():
        raise SystemExit(f'Refusing to replace an audition directory: {destination}')
    samples, waves = engine.load_bank()
    sources = list((CASE / 'scripts').glob('*.py')) + [CASE / 'README.md', CASE / 'PROVENANCE.md', CASE / 'requirements.txt']
    sources += [OLD / 'scripts' / p for p in ['build.py', 'build_v02.py', 'verify.py']]
    sources += [engine.BANK / 'bank_manifest.json', *(engine.BANK / s['path'] for s in samples.values())]
    sources += [ROOT / 'tools/classical_soundtrack_pipeline' / p for p in ['common.py', 'render.py', 'verify.py']]
    sources += [p / 'score.json' for p in PARENTS.values()]
    destination.mkdir(parents=True)
    v01.write_json(destination / 'SOURCES.json', {'version': 'v01', 'source_kind': 'original_authored_symbolic_composition',
        'approval_status': 'awaiting_user_audition', 'inputs_sha256': {str(p.relative_to(ROOT)): v01.sha256(p) for p in sorted(sources)},
        'python_version': sys.version.split()[0], 'numpy_version': np.__version__, 'mido_version': str(mido.version_info),
        'ffmpeg_version': subprocess.check_output(['ffmpeg', '-version'], text=True).splitlines()[0]})
    for slug in PARENTS:
        s = arrange(slug)
        folder = destination / slug
        folder.mkdir()
        v01.write_json(folder / 'score.json', s)
        engine.midi(s, folder / 'arrangement.mid')
        report = mix_and_render(s, folder, samples, waves)
        report['artifacts_sha256'] = {p.name: v01.sha256(p) for p in sorted(folder.iterdir())}
        v01.write_json(folder / 'render.json', report)
        print(f"Rendered {s['title']} {s['version']}: {report['duration_seconds']:.2f}s; {report['balance']}", flush=True)


if __name__ == '__main__':
    main()
