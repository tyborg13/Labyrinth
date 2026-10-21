"""Register the director's mq11 PASS; build the sheet for their re-judgment."""
from copy import deepcopy
from PIL import Image
from rr29_build import ROOT, CASE, ASSETS, VIEWS, read_json, write_json
from density import replace_owned_entries
from art_identity_gate import pixel_digest, make_sheet, measure, recorded_ref_digests


def register():
    registry = ROOT/'spec/art_identity/registry.json'
    records = []
    pair_landmarks = {view: {side: read_json(CASE/f'layouts/{view}.json')['joints']['foot_'+side]['position']
                            for side in ('near','far')} for view in VIEWS}
    for view in VIEWS:
        job = ROOT/f'spec/art_identity/jobs/hollow_mimic/mq11_{view}'
        kit, processed = read_json(job/'kit.json'), read_json(job/'processed.json')
        layout = read_json(CASE/f'layouts/{view}.json')
        landmarks = {side: layout['joints']['foot_'+side]['position'] for side in ('near','far')}
        write_json(job/'landmarks.json', landmarks)
        make_sheet(ROOT/'spec/art_identity/jobs/hollow_mimic/mq11_front/processed.png',
            ROOT/'spec/art_identity/jobs/hollow_mimic/mq11_rear/processed.png', job/'kit.json',
            job/'sheet_pair.png', 1.0, pair_landmarks)
        judge = {'verdict':'PASS','date':'2026-10-20',
            'log':str((job/'director_verdict.md').relative_to(ROOT))}
        (job/'director_verdict.md').write_text('Director verdict: PASS, 2026-10-20.\n\n'
            'Transcribed from the rr-29 implementation brief. The director re-judges this generated sheet before merge; '
            'no implementation-engineer or independent-agent art judgment is claimed.\n')
        rest = ASSETS/view/'rest.png'
        entry = dict(id='hollow_mimic',path=str(rest.relative_to(ROOT)),kind='creature',entry_kind='kit',
            anatomy='biped',boss=False,art_scale=1.0,size_class=kit['size_class'],facing=view,
            kit_path=str((job/'kit.json').relative_to(ROOT)),job_id=kit['job_id'],kit_version=kit['kit_version'],
            prompt_path=str((job/'prompt.md').relative_to(ROOT)),prompt_sha256=kit['prompt_sha256'],
            ref_pixel_sha256=recorded_ref_digests(kit),raw_path=str((job/'refs/raw_approved.png').relative_to(ROOT)),
            raw_sha256=processed['raw_sha256'],post_steps=processed['post_steps'],
            source_path=str((job/'processed.png').relative_to(ROOT)),source_pixel_sha256=processed['pixel_sha256'],
            pixel_sha256=pixel_digest(Image.open(rest)),sheet_path=str((job/'sheet_pair.png').relative_to(ROOT)),
            landmarks=landmarks,judge=judge,owner_approval='rr-29 director-approved mq11 hair paintings; director sheet re-judgment before merge',
            metrics=measure(rest,1.0,'creature','biped'))
        records.append(entry)
    registry.write_text(replace_owned_entries(registry.read_text(),records))
    print('RR29 IDENTITY: registered both mq11 jobs; director PASS 2026-10-20; sheet re-judgment pending')


if __name__ == '__main__': register()
