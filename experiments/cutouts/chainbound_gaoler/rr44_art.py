"""Register director files byte for byte, with a read-only numerical replay."""
import hashlib
import shutil
from PIL import Image
from rr44_case import PROJECT, STAGED, JOBS, VIEWS, protected
from cutout_pipeline.cases import read_json, write_json, digest
from art_identity_gate import pixel_digest, process_raw, verify_job_recipe, prompt_kit_version


def build():
    protected()
    for view, (old, new) in VIEWS.items():
        folder = JOBS/new
        folder.mkdir(parents=True, exist_ok=True)
        refs = folder/'refs'; refs.mkdir(exist_ok=True)
        original = read_json(JOBS/old/'kit.json')
        # Preserve the generation-time canon/maquette reference inventory.
        for ref in original['refs']:
            source = JOBS/old/ref['file']
            target = folder/ref['file']; target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
        copies = {'raw': (STAGED/f'{view}_r1_raw_1024.png', refs/'raw_approved.png'),
                  'approved': (JOBS/old/'processed.png', refs/'approved.png'),
                  'recipe': (STAGED/'compose_arm.py', refs/'compose_arm.py')}
        if view == 'front':
            copies['mask'] = (STAGED.parent/'rr-42/front_far_arm_footprint_mask.png', refs/'old_arm_mask.png')
        bindings = {}
        for name, (source, target) in copies.items():
            shutil.copyfile(source, target)
            bindings[name] = dict(path=str(target.relative_to(folder)), sha256=digest(target))
        prompt = STAGED/f'prompt_{view}_chain_arm_r1.md'
        shutil.copyfile(prompt, folder/'prompt.md')
        kit = {k: original[k] for k in ('K','anatomy','id','kind','kit_kind','peers','refs','size_class','target_h','view')}
        kit.update(job_id='rr44-gaoler-'+view+'-arm-r1',
                   method=f'director arm repaint (rr-44): image edit of {old}, region composite by compose_arm.py',
                   prompt_path='prompt.md', prompt_source=str(prompt.relative_to(PROJECT)), prompt_sha256=digest(prompt),
                   match_reference=dict(path='refs/approved.png',
                                        pixel_sha256=pixel_digest(Image.open(JOBS/old/'processed.png'))),
                   raw_steps=[dict(kind='gaoler_arm_rr44', parameters=dict(side='left' if view=='front' else 'right'),
                                   inputs=bindings, output_raw_pixel_sha256=pixel_digest(Image.open(STAGED/f'{view}_r1_processed.png')))])
        kit['kit_version'] = prompt_kit_version(kit, (folder/'prompt.md').read_bytes())
        write_json(folder/'kit.json', kit)
        process_raw(None, folder/'kit.json', folder/'processed.png')
        if pixel_digest(Image.open(folder/'processed.png')) != pixel_digest(Image.open(STAGED/f'{view}_r1_processed.png')):
            raise ValueError('Director replay differs: '+view)
        shutil.copyfile(STAGED/f'{view}_r1_processed.png', folder/'processed.png')
        if (JOBS/old/'landmarks_pair.json').exists():
            shutil.copyfile(JOBS/old/'landmarks_pair.json', folder/'landmarks_pair.json')
        print('RR44 ART '+view.upper()+': PASS (protected bytes; '+str(verify_job_recipe(folder/'kit.json', require_inputs=True))+')')


if __name__ == '__main__': build()
