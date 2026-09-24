#!/usr/bin/env python3
"""Thorns in the Dark v02: violin ensemble revision, preserving prior auditions."""
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

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'project.godot').exists())
CASE = Path(__file__).resolve().parents[1]
STRINGS = ROOT / 'output/original_soundtracks/string_ensemble_revisions'
sys.path.insert(0, str(STRINGS / 'scripts'))
import build_strings as strings
engine, v01, RATE = strings.engine, strings.v01, strings.RATE
OLD = strings.OLD
SLUG = '01_thorns_in_the_dark_v02'
PARENTS = {SLUG: ROOT / 'output/original_soundtracks/combat_set_02/versions/v01/02_thorns_in_the_dark'}


def arrange(slug=SLUG):
    parent = json.loads((PARENTS[slug] / 'score.json').read_text())
    s = copy.deepcopy(parent)
    s.update({'slug': slug, 'version': 'v02', 'lead_instrument': 'violin_1',
              'based_on': str((PARENTS[slug] / 'score.json').relative_to(ROOT)),
              'revision': ['Lead raised one octave with all melodic events otherwise intact.',
                           'Same procedural bowed violin/viola texture as the previous string revisions.',
                           'Longer second-violin responses and moving viola support the fast plucked pulse.',
                           'Lead sits back; original percussion, bass and pluck events are retained.']})
    s['patches'].pop('shadow_lead')
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
            'lowpass_hz': 3200 if name == 'violin_1' else 2900}
    s['notes'], pad_onsets = [], set()
    for original in sorted(parent['notes'], key=lambda n: (n['beat'], n['pitch'])):
        n = copy.deepcopy(original)
        if n['instrument'] == 'answer_viol':
            continue
        if n['instrument'] == 'shadow_lead':
            n['instrument'], n['pitch'] = 'violin_1', n['pitch'] + 12
        elif n['instrument'] == 'bowed_veil':
            if n['beat'] in pad_onsets:
                continue
            pad_onsets.add(n['beat'])
        s['notes'].append(n)
    strings.line(s, 'violin_2', [
        '0:Eb4:1.5 2:G4:.75 3:Eb4:.75', '0:Eb4:1.5 2:D4:.75 2.75:Eb4:1.1',
        '0:C4:1.75 2:Eb4:.75 3:G4:.75', '0:D4:1.5 2:F4:.75 2.75:B3:1.1',
        '0:Eb4:1.5 2:G4:1.75', '0:C4:1.5 2:Ab4:.75 2.75:F4:1.1',
        '0:Ab4:1.5 2:F4:.75 2.75:Db4:1.1', '0:D4:1.5 2:B3:.75 2.75:G3:1.1',
        '0:Ab3:2 2:C4:1.75', '0:C4:1.75 2:Ab3:1.75',
        '0:Ab3:1.5 2:Db4:1.75', '0:B3:1.5 2:D4:.75 2.75:F4:1.1',
        '0:Eb4:1.5 2:C4:.75 2.75:Eb4:1.1', '0:C4:1.5 2:Ab4:1.75',
        '0:C4:1.75 2:D4:.75 3:F4:.75', '0:D4:1.5 2:F4:.75 2.75:B3:1.1',
        '0:G4:1.5 2:Eb4:1.75', '0:Eb4:1.5 2:G4:.75 2.75:Eb4:1.1',
        '0:C4:1.5 2:Eb4:.75 3:G4:.75', '0:F4:1.5 2:D4:.75 2.75:B3:1.1',
        '0:Ab3:1.5 2:C4:.75 2.75:Ab3:1.1', '0:F4:1.5 2:Db4:.75 2.75:Ab3:1.1',
        '0:C4:1.5 2:D4:.75 2.75:F4:1.1', '0:F4:1.25 1.5:D4:.75 2.5:B3:1.25',
    ], 65)
    strings.line(s, 'viola', [
        '0:G3:2.75 3:Eb3:.8', '0:Eb3:1.75 2:D3:.75 3:Eb3:.8',
        '0:Ab3:2 2:G3:1.75', '0:B3:1.75 2:G3:1.75',
        '0:G3:2 2:Eb3:1.75', '0:Ab3:1.75 2:G3:.75 3:F3:.8',
        '0:F3:2 2:Ab3:1.75', '0:G3:1.75 2:F3:.75 3:D3:.8',
        '0:F3:3.75', '0:Ab3:3.75', '0:F3:1.75 2:Ab3:1.75', '0:G3:3.75',
        '0:Ab3:2 2:G3:1.75', '0:F3:1.75 2:Ab3:1.75',
        '0:G3:2.75 3:F3:.8', '0:B3:1.75 2:G3:1.75',
        '0:Eb3:2 2:G3:1.75', '0:G3:1.75 2:F3:.75 3:Eb3:.8',
        '0:Ab3:2 2:G3:1.75', '0:G3:1.75 2:B3:1.75',
        '0:F3:2 2:Ab3:1.75', '0:Ab3:2 2:F3:1.75',
        '0:G3:2.75 3:F3:.8', '0:G3:1.75 2:F3:.75 3:B3:.8',
    ], 61)
    for n in s['notes']:
        if n['instrument'] in ['violin_2', 'viola'] and 32 <= n['beat'] < 48:
            n['velocity'] -= 8
    s['notes'].sort(key=lambda n: (n['beat'], n['instrument'], n['pitch']))
    return s


def measured(signal, path):
    if not np.isfinite(signal).all() or np.max(np.abs(signal)) >= 1:
        raise ValueError('Invalid or clipping loudness measurement input')
    return strings.measured(signal, path)


def render(s, destination, samples, waves):
    # Versioned adaptation of the reviewed string mixer for Thorns' shadow lead.
    parent = json.loads((PARENTS[s['slug']] / 'score.json').read_text())
    with tempfile.TemporaryDirectory(prefix='umbra-thorns-strings-') as td:
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
        targets.update({'violin_1': old_levels['shadow_lead'] - 4,
                        'violin_2': old_levels['shadow_lead'] - 7,
                        'viola': old_levels['shadow_lead'] - 8.5})
        wet, gains = {}, {}
        for name in sorted(targets):
            stem = strings.string_stem(s, name) if name in ['violin_1', 'violin_2', 'viola'] else engine.make_stem(s, name, samples, waves)
            gains[name] = 10 ** ((targets[name] - measured(stem, wav)) / 20)
            wet[name] = v01.circular_dark_echo(stem * gains[name], s['patches'][name]['wet'], 60 / s['bpm'])
        mix = sum(wet.values())
        level = measured(mix, wav)
        master_gain = 10 ** ((-20 - level) / 20)
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
        return {'version': s['version'], 'sample_rate': RATE, 'frames': len(mix),
                'duration_seconds': len(mix) / RATE, 'target_lufs': -20,
                'note_counts': dict(Counter(n['instrument'] for n in s['notes'])),
                'stem_calibration_gains': gains, 'master_gain': master_gain,
                'balance': {'prior_stem_lufs_in_matched_mix': old_audible,
                            'revised_stem_lufs_in_matched_mix': new_audible,
                            'revised_middle_layer_lufs_in_matched_mix': middle,
                            'lead_change_lu': new_audible['violin_1'] - old_audible['shadow_lead'],
                            'percussion_change_lu': new_audible['drums'] - old_audible['drums'],
                            'lead_above_middle_lu': new_audible['violin_1'] - middle},
                'loop_method': 'circular tails/echo/filter; exact bar length; 2 ms endpoint taper'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path, default=CASE / 'versions/v02')
    args = parser.parse_args()
    destination = args.output_dir.resolve()
    if destination.exists():
        raise SystemExit(f'Refusing to replace an audition directory: {destination}')
    samples, waves = engine.load_bank()
    sources = [CASE / 'scripts' / p for p in ['build_thorns.py', 'verify_thorns.py']]
    sources += [CASE / p for p in ['README.md', 'PROVENANCE.md', 'requirements.txt']]
    sources += [STRINGS / 'scripts' / p for p in ['build_strings.py', 'bowed_strings.py']]
    sources += [OLD / 'scripts' / p for p in ['build.py', 'build_v02.py', 'verify.py']]
    sources += [engine.BANK / 'bank_manifest.json', *(engine.BANK / s['path'] for s in samples.values())]
    sources += [ROOT / 'tools/classical_soundtrack_pipeline' / p for p in ['common.py', 'render.py', 'verify.py']]
    sources += [PARENTS[SLUG] / 'score.json']
    destination.mkdir(parents=True)
    v01.write_json(destination / 'SOURCES.json', {'version': 'v02', 'source_kind': 'original_authored_symbolic_composition',
        'approval_status': 'awaiting_user_audition', 'inputs_sha256': {str(p.relative_to(ROOT)): v01.sha256(p) for p in sorted(sources)},
        'python_version': sys.version.split()[0], 'numpy_version': np.__version__, 'mido_version': str(mido.version_info),
        'ffmpeg_version': subprocess.check_output(['ffmpeg', '-version'], text=True).splitlines()[0]})
    s = arrange()
    folder = destination / SLUG
    folder.mkdir()
    v01.write_json(folder / 'score.json', s)
    engine.midi(s, folder / 'arrangement.mid')
    report = render(s, folder, samples, waves)
    report['artifacts_sha256'] = {p.name: v01.sha256(p) for p in sorted(folder.iterdir())}
    v01.write_json(folder / 'render.json', report)
    print(f"Rendered {s['title']} {s['version']}: {report['duration_seconds']:.2f}s; {report['balance']}", flush=True)


if __name__ == '__main__':
    main()
