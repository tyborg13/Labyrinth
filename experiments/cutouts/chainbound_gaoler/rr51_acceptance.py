"""rr-51 director acceptance (2026-10-29), bound to the Gaoler's live art_scale.

1. The 1.10 `move` flat-region inventory is the ratchet baseline for the move
   clip only. At 0.90 the rr-44 feedback-2 inventory stays the move baseline
   (history); every other clip always keeps rr-44's baselines. Any other scale
   has no accepted move baseline and fails closed.
2. The 28 move frames whose 1-10 uncertified painted texels were accepted as
   found. Any other or additional texel, part or exposed pixel still fails.

The ratchet rule is rr44_authority.flat_errors's, unchanged: a new region, or
a corresponding group more than 2px larger, fails. It is restated below for a
selectable baseline so rr44_authority.py stays byte-identical (the round-0
native calibration receipt binds it); tests prove the two agree. The CPU sweep
and the native exact-source gate both read these two files.

  PYTHONPATH=tools python3 -B experiments/cutouts/chainbound_gaoler/rr51_acceptance.py freeze --sweep <rr44_sweep.json>
"""
import argparse
from collections import defaultdict
from functools import lru_cache
import json
from pathlib import Path
import numpy as np
from rr44_case import STAGED
from cutout_pipeline.cases import read_json, digest

MOVE_FLAT = STAGED / 'rr51_move_flat_baseline_1p10.json'
PAINTED = STAGED / 'rr51_move_painted_exceptions_1p10.json'
MOVE_FLAT_SHA256 = 'b150057d377a30398ad0d15bcddad7706e8ba64361d4effcf10e028d76c59273'
PAINTED_SHA256 = '0bf63394c63c9007033803b890c1fd1e2ca5dabe70dfd2988a8edf1fffbb0088'
CLIP = 'move'
ACCEPTED_SCALE = 1.1
HISTORY_SCALE = 0.9
MAXIMUM_GROWTH_PX = 2
FLAT_NOTE = 'rr-51: same motion, shorter source-px stride at 1.10; total move flat area −24%; director-accepted 2026-10-29'
PAINTED_NOTE = ('rr-51: 28 move frames with 1-10 uncertified painted texels at 1.10, accepted as found '
                '(view, frame and texel coordinates); director-accepted 2026-10-29. Any other or additional '
                'uncertified texel still fails.')
REGION_FIELDS = ('view', 'clip', 'frame', 'piece', 'pixels', 'bbox')


@lru_cache(maxsize=1)
def live_scale():
    """The game value, through the case's declared scale source (as rr51_scale reads it)."""
    from rr44_case import CASE, PROJECT
    scale = read_json(CASE / 'anatomy.json')['integration']['scale']
    definition = read_json(PROJECT / scale['file'])[scale['key']]
    return float(definition.get(scale['field'], scale['default']))


def bound_inputs():
    """What the CPU sweep and native exact shards bind: this module, both files and the live scale."""
    return {**{path.name: digest(path) for path in (Path(__file__), MOVE_FLAT, PAINTED)},
            'rr51_live_art_scale': repr(live_scale())}


def _bound(path, expected, note):
    if digest(path) != expected:
        raise ValueError('Changed rr-51 director acceptance: ' + path.name)
    data = read_json(path)
    if data.get('art_scale') != ACCEPTED_SCALE or data.get('clip') != CLIP or data.get('note') != note:
        raise ValueError('Unbound rr-51 director acceptance: ' + path.name)
    return data


@lru_cache(maxsize=1)
def move_flat_baseline():
    return _bound(MOVE_FLAT, MOVE_FLAT_SHA256, FLAT_NOTE)


@lru_cache(maxsize=1)
def painted_exceptions():
    data = _bound(PAINTED, PAINTED_SHA256, PAINTED_NOTE)
    return {(row['view'], row['clip'], row['frame']): row for row in data['frames']}


def binding():
    """Both files verified; recorded by the gates so a stale acceptance is visible."""
    return dict(move_flat=dict(path=str(MOVE_FLAT.name), sha256=MOVE_FLAT_SHA256, regions=len(move_flat_baseline()['regions'])),
                painted=dict(path=str(PAINTED.name), sha256=PAINTED_SHA256, frames=len(painted_exceptions())),
                art_scale=live_scale())


def ratchet(rows, regions, maximum_growth):
    """rr44_authority.flat_errors's rule against an explicit baseline."""
    groups = defaultdict(list); current = defaultdict(list)
    key = lambda r: tuple(r[k] for k in ('view', 'clip', 'frame', 'piece'))
    for row in regions: groups[key(row)].append(row)
    for row in rows: current[key(row)].append(row)
    errors = []
    for identity, found in current.items():
        previous = groups[identity]; links = {i: set() for i in range(len(found))}
        for i, row in enumerate(found):
            a = np.asarray(row['bbox'])
            for j, old in enumerate(previous):
                b = np.asarray(old['bbox'])
                if np.all(np.minimum(a[2:], b[2:]) > np.maximum(a[:2], b[:2])): links[i].add(j)
        remaining = set(links)
        while remaining:
            seed = min(remaining); new = {seed}; old = set(); pending = {seed}
            while pending:
                index = pending.pop(); old |= links[index]
                neighbours = {i for i in remaining if links[i] & old} - new
                pending |= neighbours; new |= neighbours
            remaining -= new
            if not old:
                errors.extend(dict(found[i], reason='new flat region') for i in sorted(new)); continue
            if sum(found[i]['pixels'] for i in new) > sum(previous[j]['pixels'] for j in old) + maximum_growth:
                errors.extend(dict(found[i], reason='flat region grew more than 2px') for i in sorted(new))
    return errors


def flat_errors(rows, *, render_mode='cpu', art_scale=None):
    from rr44_authority import flat_errors as rr44_flat_errors
    scale = live_scale() if art_scale is None else art_scale
    other = [r for r in rows if r['clip'] != CLIP]
    move = [r for r in rows if r['clip'] == CLIP]
    errors = rr44_flat_errors(other, render_mode=render_mode) if other else []
    if not move: return errors
    if scale == HISTORY_SCALE: return errors + rr44_flat_errors(move, render_mode=render_mode)
    if scale != ACCEPTED_SCALE:
        return errors + [dict(r, reason='no director-accepted move flat baseline at art_scale %s' % scale) for r in move]
    baseline = move_flat_baseline()
    return errors + ratchet(move, baseline['regions'], baseline['maximum_growth_px'])


def painted_excused(view, clip, frame, provenance, rows, texels, *, art_scale=None, hidden_parts=None):
    """True only for an accepted frame whose exposure is a subset of what was found."""
    scale = live_scale() if art_scale is None else art_scale
    entry = painted_exceptions().get((view, clip, frame)) if scale == ACCEPTED_SCALE else None
    if entry is None or provenance.get('painted_missing_texels', 0) != 0:
        return False
    if provenance.get('uncovered_procedural_texels', 0) > entry['uncovered_procedural_texels']:
        return False
    if {row['part'] for row in rows} - set(entry['parts']):
        return False
    return {tuple(t) for t in texels} <= {tuple(t) for t in entry['texels']}


def freeze(sweep_path):
    """Write both acceptance files once from the 1.10 CPU sweep the director judged."""
    if MOVE_FLAT.exists() or PAINTED.exists(): raise ValueError('Never overwrite a director acceptance')
    sweep = read_json(sweep_path)
    from rr44_authority import FLAT_SHA256
    history = [r for r in read_json(STAGED / 'feedback2_flat_baseline.json')['regions'] if r['clip'] == CLIP]
    regions, frames = [], []
    for row in sorted(sweep['frames'], key=lambda r: (r['view'], r['clip'], r['frame'])):
        if row['clip'] != CLIP: continue
        regions += [{k: region[k] for k in REGION_FIELDS} for region in row['flat_regions']]
        if 'painted_exposure' in row['kinds']:
            frames.append(dict(view=row['view'], clip=row['clip'], frame=row['frame'],
                               parts=sorted({r['part'] for r in row['painted_regions']}),
                               texels=sorted([t['part'], *t['uv']] for t in row['uncertified_source_texels']),
                               uncovered_procedural_texels=row['metrics']['uncovered_procedural_texels'],
                               painted_missing_texels=row['metrics']['painted_missing_texels'],
                               painted_regions=sorted({json.dumps(r, sort_keys=True) for r in row['painted_regions']})))
    samples = dict(samples_sha256=sweep['samples_sha256'], frames=sum(r['clip'] == CLIP for r in sweep['frames']))
    flat = dict(note=FLAT_NOTE, clip=CLIP, art_scale=ACCEPTED_SCALE, maximum_growth_px=MAXIMUM_GROWTH_PX,
                provenance='director acceptance 2026-10-29 (rr-51): the Gaoler move clip at art_scale 1.10 only; '
                           'every other clip keeps feedback2_flat_baseline.json / feedback2_native_flat_baseline.json',
                history=dict(path='feedback2_flat_baseline.json', sha256=FLAT_SHA256, art_scale=HISTORY_SCALE,
                             move_regions=len(history), move_pixels=sum(r['pixels'] for r in history)),
                source=samples, move_pixels=sum(r['pixels'] for r in regions), regions=regions)
    painted = dict(note=PAINTED_NOTE, clip=CLIP, art_scale=ACCEPTED_SCALE, source=samples,
                   frames=[dict(row, painted_regions=[json.loads(r) for r in row['painted_regions']]) for row in frames])
    for path, data in ((MOVE_FLAT, flat), (PAINTED, painted)):
        path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n')
        print('RR51 ACCEPTANCE FROZEN: %s %s' % (path.name, digest(path)))
    print('RR51 ACCEPTANCE: %d move regions (%d px; history %d px); %d painted frames, %d texels' %
          (len(regions), flat['move_pixels'], flat['history']['move_pixels'], len(frames), sum(len(f['texels']) for f in frames)))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['freeze'])
    parser.add_argument('--sweep', type=Path, required=True)
    freeze(parser.parse_args().sweep)
