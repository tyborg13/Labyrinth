"""Only Mimic records may change in shared registration/density receipts."""
import json
import subprocess
from rr29_build import ROOT,CASE,read_json,write_json

INTEGRATION_BASE='8b6cf8d063bf4a8a5de973bae2e28251c4f57f0a'


def base(path,project,revision):
    return json.loads(subprocess.check_output(['git','show',revision+':'+str(path.relative_to(project))],cwd=project))


def preservation_report(project=ROOT,revision=INTEGRATION_BASE):
    """Compare the complete task delta, including commits, to integration.

    The revision argument exists for disposable committed-mutation fixtures;
    production verification always uses the immutable integration base.
    """
    errors=[];checks={}
    identity=project/'spec/art_identity/registry.json'
    before,after=base(identity,project,revision),read_json(identity)
    unrelated=lambda d:[e for e in d['entries'] if not e['path'].startswith('assets/units/hollow_mimic_cutout/')]
    checks['identity_other_entries_identical']=unrelated(before)==unrelated(after)
    density=project/'spec/assets/board_pixel_density/registry.json';before,after=base(density,project,revision),read_json(density)
    filtered=lambda d:[e for e in d['entries'] if e['id']!='hollow_mimic_cutout']
    checks['density_other_entries_identical']=filtered(before)==filtered(after)
    ignored=lambda d:{k:v for k,v in d['excluded_paths'].items() if not k.startswith('assets/units/hollow_mimic_cutout/')}
    checks['density_other_exclusions_identical']=ignored(before)==ignored(after)
    outputs=project/'spec/assets/board_pixel_density/outputs.json';before,after=base(outputs,project,revision),read_json(outputs)
    # Receipt maps retain all fields outside this rig's owned path records.
    def remove_owned(value):
        if isinstance(value,dict):return {k:remove_owned(v) for k,v in value.items() if not k.startswith('assets/units/hollow_mimic_cutout/')}
        if isinstance(value,list):return [remove_owned(v) for v in value]
        return value
    checks['density_other_outputs_identical']=remove_owned(before)==remove_owned(after)
    # Diffing only the working tree against HEAD silently forgave committed
    # violations. Include committed, staged, unstaged and new figure files.
    changed=set(subprocess.check_output(['git','diff',revision,'--name-only','-z'],cwd=project).decode().split('\0'))
    changed.update(subprocess.check_output(['git','ls-files','--others','--exclude-standard','-z'],cwd=project).decode().split('\0'))
    changed=sorted(changed-{''})
    units=[n for n in changed if n.startswith('assets/units/') and not n.startswith('assets/units/hollow_mimic_cutout/')]
    cases=[n for n in changed if n.startswith('experiments/cutouts/') and not n.startswith('experiments/cutouts/hollow_mimic/')]
    checks['other_figure_files_byte_identical']=not units and not cases
    errors=[name for name,ok in checks.items() if not ok]
    return {'ok':not errors,'errors':errors,'checks':checks,'other_figure_changes':units+cases,'integration_base':revision}


def verify():
    report=preservation_report()
    write_json(CASE/'proof/preservation.json',report)
    print(f'RR29 OTHER FIGURES: {"PASS" if report["ok"] else "FAIL"} ({len(report["checks"])} checks)')
    for e in report['errors']:print(e)
    return report


if __name__=='__main__':raise SystemExit(int(not verify()['ok']))
