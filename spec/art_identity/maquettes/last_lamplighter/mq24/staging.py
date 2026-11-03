"""Promote verified mq24 proof without retaining stale diagnostic verdicts.

Archive the previous delivery byte-for-byte and preserve its existing Godot
import settings wherever the accepted source occupies the same res:// path.
Never stage saved models, native caches or the copied compiler project.
"""
from pathlib import Path
import shutil
import tarfile
from spec.art_identity.maquettes.blender.curate_delivery import write,sha
from spec.art_identity.maquettes.blender.delivery_validation import seal_delivery
from .recipe import FOLDER,compile_spec
from .delivery import acceptance,proof_images

STAGING_DEFAULTS={'archive':'history/feedback2_delivery_before_acceptance.tar.gz',
    'receipt':'feedback2_validation/staging.json'}


def stage(capture,regeneration,destination=None,archive=None):
    from .proof import verify,seal
    capture=Path(capture).resolve();regeneration=Path(regeneration).resolve()
    destination=Path(destination or FOLDER/'delivery').resolve()
    archive=Path(archive or FOLDER/STAGING_DEFAULTS['archive']).resolve()
    # No existing delivery byte is touched before both proof chains verify.
    verify(capture,regeneration)
    sidecars={p.relative_to(destination):p.read_bytes() for p in destination.rglob('*.import')} if destination.exists() else {}
    if destination.exists():
        if archive.exists():raise ValueError('Refusing to overwrite the previous-delivery archive')
        archive.parent.mkdir(parents=True,exist_ok=True)
        with tarfile.open(archive,'w:gz') as saved:saved.add(destination,arcname='delivery')
        shutil.rmtree(destination)
    shutil.copytree(capture,destination)
    validation=destination/'validation/regeneration';validation.mkdir(parents=True)
    for name in ('regeneration.json','clean_input_sha256.json','compile.log','native_probe.json'):
        shutil.copyfile(regeneration/name,validation/name)
    for name in ('capture','bridge'):shutil.copytree(regeneration/name,validation/name)
    for relative,raw in sidecars.items():
        target=destination/relative
        if Path(str(target).removesuffix('.import')).is_file():target.write_bytes(raw)
    spec=compile_spec();proof_images(destination)
    if not acceptance(spec,destination)['accepted']:raise ValueError('Staged acceptance failed')
    seal_delivery(spec,destination);seal(destination);verify(destination,validation)
    write(FOLDER/STAGING_DEFAULTS['receipt'],{'accepted':True,'capture':str(capture),
        'regeneration':str(regeneration),'destination':str(destination),'archive':str(archive),
        'archive_sha256':sha(archive) if archive.is_file() else None,
        'existing_sidecars_preserved':sum((destination/n).is_file() for n in sidecars)})
    print('MQ24_ACCEPTED_DELIVERY_STAGE: PASS; accepted=true',flush=True)
    return destination
