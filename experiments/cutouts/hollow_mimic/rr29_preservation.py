"""Only Mimic records may change in shared registration/density receipts."""
import json
from pathlib import Path
import subprocess
from rr29_build import ROOT,CASE,read_json,write_json,digest


def base(path):
    return json.loads(subprocess.check_output(['git','show','HEAD:'+str(path.relative_to(ROOT))],cwd=ROOT))


def verify():
    errors=[];checks={}
    identity=ROOT/'spec/art_identity/registry.json'
    before,after=base(identity),read_json(identity)
    unrelated=lambda d:[e for e in d['entries'] if not e['path'].startswith('assets/units/hollow_mimic_cutout/')]
    checks['identity_other_entries_identical']=unrelated(before)==unrelated(after)
    density=ROOT/'spec/assets/board_pixel_density/registry.json';before,after=base(density),read_json(density)
    filtered=lambda d:[e for e in d['entries'] if e['id']!='hollow_mimic_cutout']
    checks['density_other_entries_identical']=filtered(before)==filtered(after)
    ignored=lambda d:{k:v for k,v in d['excluded_paths'].items() if not k.startswith('assets/units/hollow_mimic_cutout/')}
    checks['density_other_exclusions_identical']=ignored(before)==ignored(after)
    outputs=ROOT/'spec/assets/board_pixel_density/outputs.json';before,after=base(outputs),read_json(outputs)
    # Receipt maps retain all fields outside this rig's owned path records.
    def remove_owned(value):
        if isinstance(value,dict):return {k:remove_owned(v) for k,v in value.items() if not k.startswith('assets/units/hollow_mimic_cutout/')}
        if isinstance(value,list):return [remove_owned(v) for v in value]
        return value
    checks['density_other_outputs_identical']=remove_owned(before)==remove_owned(after)
    changed=subprocess.check_output(['git','diff','--name-only'],cwd=ROOT,text=True).splitlines()
    units=[n for n in changed if n.startswith('assets/units/') and not n.startswith('assets/units/hollow_mimic_cutout/')]
    cases=[n for n in changed if n.startswith('experiments/cutouts/') and not n.startswith('experiments/cutouts/hollow_mimic/')]
    checks['other_figure_files_byte_identical']=not units and not cases
    errors=[name for name,ok in checks.items() if not ok]
    report={'ok':not errors,'errors':errors,'checks':checks,'other_figure_changes':units+cases}
    write_json(CASE/'proof/preservation.json',report)
    print(f'RR29 OTHER FIGURES: {"PASS" if not errors else "FAIL"} ({len(checks)} checks)')
    for e in errors:print(e)
    return report


if __name__=='__main__':raise SystemExit(int(not verify()['ok']))
