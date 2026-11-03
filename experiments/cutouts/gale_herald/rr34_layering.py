"""Owner's rr-34 overlap correction; preserve the approved near-thigh overlap.

The front painting puts the near thigh in front of the tabard. Only the far
thigh/tabard ordering was reversed in the native categorical depth recipe.
Their adjacent occupied depths can be exchanged without moving another item.
The rear already puts its tabard above both thighs and must stay unchanged.
"""


def front_depths(depths):
    if depths['tabard'] < depths['leg_far']:
        depths['tabard'], depths['leg_far'] = depths['leg_far'], depths['tabard']
    if not depths['leg_far'] < depths['tabard'] < depths['leg_near']:
        raise ValueError('Front cloth must draw between the far and near thighs')


def errors(layout):
    findings = []
    depths = {p['name']: p['z_index'] for p in layout['parts']}
    if layout['facing'] == 'front':
        if depths['tabard'] <= depths['leg_far']:
            findings.append('front tabard must draw above leg_far')
        if depths['tabard'] >= depths['leg_near']:
            findings.append('front near thigh must retain its painted overlap above tabard')
    for mesh in layout['joint_meshes']:
        if mesh['z_index'] != depths[mesh['name']]:
            findings.append('painted mesh depth differs: ' + mesh['name'])
    for name, proof in layout.get('proof_layers', {}).items():
        if proof['z_index'] != depths[name]:
            findings.append('proof layer depth differs: ' + name)
    return findings


def apply():
    """Repair current case/production metadata without rebuilding any paint."""
    from rr32_case import CASE, ASSETS, PROJECT
    import sys
    sys.path.insert(0, str(PROJECT / 'tools'))
    from cutout_pipeline.cases import read_json, write_json, digest
    for path in (CASE / 'layouts/front.json', ASSETS / 'humanoid_v2/front.json', ASSETS / 'front.json'):
        layout = read_json(path)
        depths = {p['name']: p['z_index'] for p in layout['parts']}
        front_depths(depths)
        for part in layout['parts'] + layout['joint_meshes']:
            part['z_index'] = depths[part['name']]
        for name, proof in layout.get('proof_layers', {}).items():
            proof['z_index'] = depths[name]
        findings = errors(layout)
        if findings: raise ValueError('; '.join(findings))
        write_json(path, layout)
    path = ASSETS / 'integration.json'
    entry = read_json(path)
    for name in ('front.json', 'humanoid_v2/front.json'):
        entry['files'][name] = digest(ASSETS / name)
    write_json(path, entry)
    print('RR34 LAYERING: PASS (front leg_far < tabard < leg_near; rear and paint untouched)')


if __name__ == '__main__': apply()
