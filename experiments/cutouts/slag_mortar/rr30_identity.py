"""Replay the director's supplied mq11 paintings; never paint or generate art."""
from pathlib import Path
import hashlib
import json
import shutil
import sys

from rr22_case import PROJECT
from cutout_pipeline.cases import read_json, write_json
from art_identity_gate import (pixel_digest, process_raw, recorded_ref_digests,
                               validate_kit_entry, rear_consistency)
from PIL import Image

JOBS = PROJECT / 'spec/art_identity/jobs/slag_mortar'
STAGED = PROJECT / 'spec/peer_benchmark/staged'
JOB_SIZE_CLASS = {'front': 'medium', 'rear': 'large'}  # Existing drawn-height bands, no art rescaling.
METHOD = 'mq-11 maquette paint-over (belt and loincloth only), composited below y 560 into the approved mq9 painting'


def build():
    # Invalidate old verdicts before touching their bound pixels. A failed
    # replay must never leave the previous generation's PASS on disk.
    pending = dict(verdict='PENDING_CERTIFICATION', date='2026-10-20', method=METHOD)
    for view in ('front', 'rear'):
        write_json(JOBS / ('mq11_' + view) / 'judge.json', pending)
    registry = read_json(PROJECT / 'spec/art_identity/registry.json')
    replace_entries([dict(e, judge=pending) for e in registry['entries']
                     if e['path'] in {job_path(v) + '/processed.png' for v in ('front', 'rear')}])
    for view in ('front', 'rear'):
        job = JOBS / ('mq11_' + view)
        (job / 'refs').mkdir(parents=True, exist_ok=True)
        revision = 'mq11b' if view == 'rear' else 'mq11'
        prompt = STAGED / ('paintovers/slag_mortar_' + view + '_' + revision + '.md')
        shutil.copyfile(prompt, job / 'prompt.md')
        refs = []
        for source in sorted((STAGED / ('mq11/paint/refs_slag_mortar_' + view + ('_mq11b' if view == 'rear' else ''))).glob('*.png')):
            target = job / 'refs' / source.name
            shutil.copyfile(source, target)
            role = 'maquette_parts' if '01_maquette' in source.name else 'maquette_clay' if '02_maquette' in source.name else 'identity'
            refs.append(dict(file=str(target.relative_to(job)), source_file=str(source.relative_to(PROJECT)),
                             pixel_sha256=pixel_digest(Image.open(source)), role=role,
                             canon_id='mq11_' + view + '_' + source.stem))
        prompt_record = PROJECT / ('spec/art_identity/maquettes/slag_mortar/rr30_mq11_' + view + '_prompt.md')
        shutil.copyfile(prompt, prompt_record)
        # These required maquette-namespace prompt records are part of the
        # Mortar's curated inventory, without changing its native delivery.
        manifest = prompt_record.parent / 'COMMIT_MANIFEST.txt'
        lines = manifest.read_text().splitlines()
        if prompt_record.name not in lines:
            lines.append(prompt_record.name)
            manifest.write_text('\n'.join(lines) + '\n')
        kit = read_json(JOBS / ('mq9_' + view) / 'kit.json')
        kit.update(job_id='mq-slag_mortar-' + view + '-mq11', method=METHOD, refs=refs,
                   prompt_source=str(prompt_record.relative_to(PROJECT)),
                   provided_prompt_source=str(prompt.relative_to(PROJECT)),
                   size_class=JOB_SIZE_CLASS[view],
                   prompt_sha256=hashlib.sha256(prompt.read_bytes()).hexdigest())
        kit['peers'] = ['frostglass_lancer_front', 'slag_mortar_front']
        kit['kit_version'] = hashlib.sha256(prompt.read_bytes() + ''.join(r['pixel_sha256'] for r in refs).encode()).hexdigest()
        if view == 'rear':
            kit['match_reference'] = dict(job_path='spec/art_identity/jobs/slag_mortar/mq11_front/kit.json',
                                        pixel_sha256=read_json(JOBS / 'mq11_front/processed.json')['pixel_sha256'])
        write_json(job / 'kit.json', kit)
        raw = STAGED / ('mq11/paint/slag_mortar_' + view + '_mq11_raw.png')
        shutil.copyfile(raw, job / 'refs/raw_approved.png')
        process_raw(raw, job / 'kit.json', job / 'processed.png', outline=True)
    # Keep the established source landmarks, no new director annotations.
    from rr30_identity_sheet import make_sheet
    make_sheet(JOBS / 'mq11_front/processed.png', JOBS / 'mq11_rear/processed.png',
        JOBS / 'mq11_front/kit.json', JOBS / 'mq11_front/sheet.png', 1.04,
        read_json(JOBS / 'mq9_landmarks_pair.json'), PROJECT)
    shutil.copyfile(JOBS / 'mq11_front/sheet.png', JOBS / 'mq11_rear/sheet.png')
    record_certified(job_entries())
    print('RR30 IDENTITY JOBS: PASS (K=4; strict certification passed; supplied director verdict recorded; fresh judge reserved for design owner)')


def record_certified(entries):
    try:
        certify(entries)
    except (ValueError, KeyError, OSError) as error:
        failed = dict(verdict='FAILED_CERTIFICATION', date='2026-10-20', method=METHOD, errors=[str(error)])
        for entry in entries:
            write_json(PROJECT / job_path(entry['facing']) / 'judge.json', failed)
        replace_entries([dict(e, judge=failed) for e in entries])
        raise ValueError('RR30 IDENTITY CERTIFICATION: FAIL; director verdict not recorded: ' + str(error)) from error
    for entry in entries:
        write_json(PROJECT / job_path(entry['facing']) / 'judge.json', entry['judge'])
    replace_entries(entries)


def job_path(view):
    return 'spec/art_identity/jobs/slag_mortar/mq11_' + view


def job_entries():
    entries = []
    landmarks = read_json(JOBS / 'mq9_landmarks_pair.json')
    for view in ('front', 'rear'):
        job = JOBS / ('mq11_' + view)
        local = str(job.relative_to(PROJECT))
        kit, processed = read_json(job / 'kit.json'), read_json(job / 'processed.json')
        entry = dict(id='slag_mortar', path=local + '/processed.png', entry_kind='kit', facing=view,
            kind=kit['kind'], anatomy=kit['anatomy'], size_class=kit['size_class'], art_scale=1.04,
            kit_path=local + '/kit.json', kit_version=kit['kit_version'], job_id=kit['job_id'],
            prompt_path=local + '/prompt.md', prompt_sha256=kit['prompt_sha256'],
            raw_path=local + '/refs/raw_approved.png', raw_sha256=processed['raw_sha256'],
            ref_pixel_sha256=recorded_ref_digests(kit), pixel_sha256=processed['pixel_sha256'],
            source_path=local + '/processed.png', source_pixel_sha256=processed['pixel_sha256'],
            post_steps=processed['post_steps'], landmarks=landmarks[view], sheet_path=local+'/sheet.png',
            judge=dict(verdict='PASS', date='2026-10-20',
                authority='Director judge supplied by rr-30 brief; re-judging before merge belongs to design owner',
                method=METHOD, sheet_path=local+'/sheet.png',
                certified_pixel_sha256=processed['pixel_sha256']),
            owner_approval='Director supplied PASS, 2026-10-20; record only after strict certification; re-judge before merge per rr-30 brief.')
        entries.append(entry)
    return entries


def certify(entries):
    """Apply the strict registry checks before persisting the supplied verdict.

    The candidate's supplied director verdict exists only in memory until its
    recipe, provenance, measurements and pair consistency all pass.
    """
    bands = read_json(PROJECT / 'spec/art_identity/bands.json')
    errors = []
    for entry in entries:
        failures, warnings = validate_kit_entry(entry, PROJECT, bands, {})
        errors.extend(entry['facing'] + ': ' + e for e in failures)
        errors.extend(entry['facing'] + ': strict: ' + w for w in warnings if w.startswith('SKIP '))
    pair = {e['facing']: e for e in entries}
    for metric, value in rear_consistency(PROJECT / pair['front']['source_path'], PROJECT / pair['rear']['source_path']).items():
        limit = bands['rear_consistency'][metric + '_max']
        if value > limit:
            errors.append('rear_consistency.%s=%.6f exceeds %s' % (metric, value, limit))
    if errors: raise ValueError('; '.join(errors))


def replace_entries(replacements):
    path = PROJECT / 'spec/art_identity/registry.json'
    text = path.read_text()
    data = read_json(path)
    entries = []
    for entry in replacements:
        old = next((e for e in data['entries'] if e['path']==entry['path']), None)
        if old is not None:
            # Replace only this owned record, retaining unrelated JSON bytes.
            decoder, cursor = json.JSONDecoder(), text.index('"entries": [') + len('"entries": [')
            while True:
                while text[cursor].isspace() or text[cursor]==',': cursor+=1
                item,end=decoder.raw_decode(text,cursor)
                if item.get('path')==entry['path']:
                    text=text[:cursor]+json.dumps(entry,indent=2).replace('\n','\n    ')+text[end:]
                    break
                cursor=end
        else: entries.append(entry)
    if entries:
        end = text.rfind('\n  ]')
        text=text[:end]+',\n'+',\n'.join('    '+json.dumps(e,indent=2).replace('\n','\n    ') for e in entries)+text[end:]
    path.write_text(text)


if __name__ == '__main__': build()
