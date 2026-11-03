"""Promote only the mq27 Grub and its owned density/identity/approval records."""
import hashlib
import json
import re
import shutil
from prepare import *
from registration import ART_SCALE

ASSETS = PROJECT / 'assets/units/burrow_grub_cutout'
PREFIX = str(ASSETS.relative_to(PROJECT)) + '/'
APPROVAL = ('rr-55: owner approved mq27 repaint 2026-11-01, inbox grub-paint-v3; '
            'scale 0.64 per v2/README.md; native production rebake remains director-owned.')


def identity():
    from art_identity_gate import measure, pixel_digest
    path = PROJECT / 'spec/art_identity/registry.json'
    registry = read_json(path)
    for entry in registry['entries']:
        if entry.get('id') != CREATURE: continue
        if not entry['path'].startswith(PREFIX):
            # Keep historical static bytes for data-path coverage, but retire
            # their old kit from current-art approval and production routing.
            entry['entry_kind'] = 'legacy'
            entry['retired'] = 'rr-55: historical static fallback; all live Grub surfaces use mq27 cutout'
            continue
        view = Path(entry['path']).parent.name
        job = job_for(CREATURE, view)
        kit = read_json(job / 'kit.json')
        entry.update(art_scale=ART_SCALE, anatomy=kit['anatomy'], size_class=kit['size_class'],
            pixel_sha256=pixel_digest(Image.open(PROJECT / entry['path'])),
            source_path=str(job.relative_to(PROJECT)) + '/processed.png',
            source_pixel_sha256=read_json(job / 'processed.json')['pixel_sha256'],
            kit_path=str(job.relative_to(PROJECT)) + '/kit.json',
            sheet_path='spec/art_identity/jobs/burrow_grub/sheet_pair_mq27.png',
            owner_approval=APPROVAL)
        entry['metrics'] = measure(PROJECT / entry['path'], ART_SCALE, 'creature', kit['anatomy'])
        # Existing explicit metric-exception format; never change global bands.
        entry['exceptions'] = [
            {'metric': 'art_scale', 'value': ART_SCALE, 'reason': APPROVAL},
            {'metric': 'height_drawn', 'value': entry['metrics']['height_drawn'], 'reason': APPROVAL}]
    write_json(path, registry)


def density():
    import process_board_density as tool
    paths = sorted({PREFIX + p['file'] for v in inputs.VIEWS for p in read_json(ASSETS / (v + '.json'))['parts']})
    rests = [PREFIX + v + '/rest.png' for v in inputs.VIEWS]
    # Repaint adoption must replace old same-name source baselines, not merely
    # adopt missing files. Always start from the freshly promoted exact case.
    tool.adopt(paths + rests, True)
    with adapters():
        result = release.register_density(CREATURE)
    registry = tool.load_registry()
    for entry in registry['entries']:
        if entry['id'] in (CREATURE, CREATURE + '_rear'):
            entry['r'] = ART_SCALE
            entry['override'] = ('rr-55: retired static fallback, never drawn; preserves historical clean-mode paint '
                                 'and grids at prior 0.85. Live burrow_grub_cutout derives at owner art_scale 0.64.')
    active = set(paths + rests)
    registry['excluded_paths'] = {p: value for p,value in registry['excluded_paths'].items()
        if not p.startswith(PREFIX) or (PROJECT / p).exists()}
    write_json(tool.REGISTRY, registry)
    manifest = read_json(tool.MANIFEST)
    manifest = {p:r for p,r in manifest.items() if not p.startswith(PREFIX) or p in active}
    # These changed-source snapshots are offline only. Native records from mq5
    # must be invalidated, never rebound to a renderer we cannot run.
    for p in rests: manifest.pop(p, None)
    write_json(tool.MANIFEST, manifest)
    source_dir = tool.SOURCES / PREFIX
    for path in source_dir.rglob('*.png'):
        if str(path.relative_to(tool.SOURCES)) not in active:
            path.unlink()
    print('MQ27 DENSITY: processed; native rest records pending', result)


def pins():
    path = PROJECT / 'tests/approved_asset_pins.json'
    original = path.read_text()
    manifest = read_json(path)
    files, images = {}, {}
    scopes = manifest['approval_source']['inventory_scopes']
    for scope, suffixes in scopes.items():
        if not str(ASSETS.relative_to(PROJECT)).startswith(scope): continue
        for file in sorted(ASSETS.rglob('*')):
            if not file.is_file() or file.suffix not in suffixes: continue
            relative = str(file.relative_to(PROJECT))
            data = file.read_bytes()
            files[relative] = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
            if file.suffix == '.png':
                image = Image.open(file).convert('RGBA')
                images[relative] = {'alpha_bounds': list(image.getchannel('A').getbbox() or ()), 'size': list(image.size)}
    # Preserve all unrelated entries' bytes, including their compact formatting.
    for key, replacement in (('files', files), ('images', images)):
        marker = '  "' + key + '": {'
        start = original.index(marker) + len(marker)
        end = original.index('\n  }', start)
        lines = original[start:end].splitlines()
        indices = [i for i,line in enumerate(lines) if '"' + PREFIX in line]
        if not indices: raise CutoutError('Missing Grub approval section: ' + key)
        at = indices[0]
        lines = [line for i,line in enumerate(lines) if i not in indices]
        generated = ['    ' + json.dumps(p) + ': ' + json.dumps(v, separators=(',', ':')) + ',' for p,v in sorted(replacement.items())]
        lines[at:at] = generated
        original = original[:start] + '\n'.join(lines) + original[end:]
    # Profile and capsule pins remain independent source-space oracles.
    registration = read_json(CASE / 'proof/registration.json')['views']
    entry = {v: registration[v]['floor_anchor'] for v in inputs.VIEWS}
    entry['height'] = [registration[v]['height'] for v in inputs.VIEWS]
    enemy = dict(manifest['enemy_art'][CREATURE], art_scale=ART_SCALE)
    for section, value in (('registration', entry), ('enemy_art', enemy),
                           ('ground_contact', {v:registration[v]['shadow'] for v in inputs.VIEWS})):
        position = original.index('  "' + section + '":')
        key = original.index('    "burrow_grub":', position)
        begin = original.index('{', key)
        _, length = json.JSONDecoder().raw_decode(original[begin:])
        formatted = json.dumps(value, indent=2).replace('\n', '\n    ')
        original = original[:begin] + formatted + original[begin + length:]
    json.loads(original)
    path.write_text(original)
    print('MQ27 APPROVED PINS:', len(files), 'files;', len(images), 'images')


def sidecars():
    for folder in (ASSETS, PROJECT / 'spec/assets/board_pixel_density/sources' / PREFIX):
        for path in folder.rglob('*.png.import'):
            if not Path(str(path).removesuffix('.import')).exists(): path.unlink()
        for path in folder.rglob('*.png'):
            target = Path(str(path) + '.import')
            if not target.exists(): target.write_text('[remap]\n\nimporter="keep"\n')
    with adapters(): release.refresh_headless(CREATURE)
    pins()


def promote():
    with adapters():
        release.promote(CREATURE)
    identity()
    density()
    identity()
    sidecars()


def seal():
    # Match rr12_release's seal-density adapter: the generic rr04 ledger has
    # no Grub entry. Keep its source override local, then bind mq27 identity.
    with adapters(), patch.object(release.release, 'SOURCE', inputs.DIRECTOR):
        # Check actual native density records before updating the integration.
        result = release.release.seal_density(CREATURE)
    identity()
    pins()
    print('MQ27 DENSITY SEAL: PASS (' + result['density_entry'] + ')')


if __name__ == '__main__':
    {'promote': promote, 'pins': pins, 'identity': identity, 'seal': seal, 'sidecars': sidecars}[sys.argv[1]]()
