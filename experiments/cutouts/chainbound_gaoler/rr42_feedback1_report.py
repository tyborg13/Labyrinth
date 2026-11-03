"""Current feedback-1 receipts; keep the committed round-0 evidence historical."""
from collections import Counter
from pathlib import Path
import shutil
from rr42_underlay import CASE, PROJECT
from rr42_density import PROOF_CASE
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.gates import bindings
from rr42_sweep import (diagnostic_bindings, SHARD_FRAMES, SHARD_WORKERS,
                        SHARD_TIMEOUT_SECONDS, CROP_CONTEXT_PX, CROP_ZOOM)
from rr42_angle_budget import STEP, BATCH_TIMEOUT_SECONDS

LOG_NAMES = ('build', 'density', 'rest', 'samples', 'sweep', 'focused', 'mutations',
             'references', 'runtime', 'canvas', 'registration',
             'shadow', 'density-check', 'source-gates', 'all-gates')
ATTEMPT_LOGS = {
    'unpaired-sweep': ('rr42-f1-unpaired-sweep.log', 'Same-layer UV pairing corrected; final sweep has zero findings.'),
    'mutation-fixture': ('rr42-f1-mutation-fixture-failure.log', 'Selected UV was inside another footprint; corrected outside-footprint UV passes the mutation test.'),
    'helper-entrypoint': ('rr42-f1-final-geometry.log', 'Direct RefCounted helper invocation timed out; the prepared-canvas entry point passed all 88 geometry cases.'),
    'reference-sidecars': ('rr42-f1-references.log', 'Generated candidate proof outputs scoped in the case ignore file; final sidecar/focused group passes.')}


def collect():
    sweep_path = PROOF_CASE/'proof/logs/rr42_sweep.json'
    sweep = read_json(sweep_path)
    if sweep['inputs'] != bindings(PROOF_CASE):
        raise ValueError('Current sweep is stale')
    if sweep['diagnostic_inputs'] != diagnostic_bindings():
        raise ValueError('Current diagnostic implementation differs')
    if sweep['samples_sha256'] != digest(PROOF_CASE/'proof/logs/samples.json'):
        raise ValueError('Current sweep samples differ')
    repairs_path = CASE.parent/'rr42_feedback1_repairs.json'
    repairs = read_json(repairs_path)['texels']
    partition = read_json(CASE/'proof/partition.json')
    fragments = [dict(row, view=view) for view, data in partition['views'].items()
                 for row in data['fragments']]
    clamps = read_json(CASE.parent/'rr42_feedback1_clamps.json')['channels']
    gates = read_json(PROOF_CASE/'proof/gates.json')
    if gates['sweep_sha256'] != digest(sweep_path):
        raise ValueError('Gate bundle refers to another sweep')
    result = dict(native_pixels=False, painted_exposure=sweep['all_rounding'],
                  frames=len(sweep['frames']), findings=len(sweep['errors']),
                  sweep_sha256=digest(sweep_path), headless_ok=sweep['ok'] and gates['ok'],
                  native_acceptance='pending director windowed proof',
                  fragment_decisions=fragments, motion_clamps=clamps,
                  repair_receipt=str(repairs_path.relative_to(PROJECT)),
                  repair_sha256=digest(repairs_path), repair_texels=len(repairs),
                  repair_decisions=dict(Counter(row['decision'] for row in repairs)),
                  chosen_defaults=dict(SHARD_FRAMES=SHARD_FRAMES, SHARD_WORKERS=SHARD_WORKERS,
                                       SHARD_TIMEOUT_SECONDS=SHARD_TIMEOUT_SECONDS,
                                       CROP_CONTEXT_PX=CROP_CONTEXT_PX, CROP_ZOOM=CROP_ZOOM,
                                       CHANNEL_SEARCH_STEP=STEP,
                                       BATCH_TIMEOUT_SECONDS=BATCH_TIMEOUT_SECONDS,
                                       triangle_batch_size=128),
                  logs={})
    for row in clamps:
        path=CASE/row['receipt']
        row['search_receipt_sha256']=digest(path)
    output=CASE/'proof/logs/feedback1_final'
    output.mkdir(parents=True, exist_ok=True)
    for name in LOG_NAMES:
        source=Path('/private/tmp')/('rr42-f1-final-'+name+'.log')
        if not source.exists():raise ValueError('Missing final log: '+str(source))
        target=output/(name+'.log');shutil.copyfile(source,target)
        lines=target.read_text(errors='replace').splitlines()
        markers=('Ran ', 'FAILED', 'PASS (', 'CHECK-OK', 'GEOMETRY:',
                 'CANVAS RESULT:', 'REGISTRATION AUDIT:', 'CALIBRATION:', 'TIES:')
        important=[line for line in lines if line=='OK' or any(m in line for m in markers)]
        result['logs'][name]=dict(file=str(target.relative_to(CASE)),
                                 sha256=digest(target), result_lines=important[-16:])
    result['resolved_attempts']={}
    for name,(filename,resolution) in ATTEMPT_LOGS.items():
        source=Path('/private/tmp')/filename
        if not source.exists():continue
        target=output/(name+'.log');shutil.copyfile(source,target)
        result['resolved_attempts'][name]=dict(file=str(target.relative_to(CASE)),
                                             sha256=digest(target),resolution=resolution)
    write_json(CASE/'proof/feedback1_receipts.json',result)
    print('RR42 FEEDBACK1 RECEIPTS: WRITTEN (headless_ok=%s; native_pixels=False)'%result['headless_ok'])


if __name__=='__main__':collect()
