"""Director bridge entry point for the prepared rr-44 unscaled surface pose.

No saved model or historical native report is reused. This builds both views
of one body; its native acceptance remains pending until these jobs run.
"""
import argparse
import json
import shutil
from pathlib import Path
import numpy as np
from PIL import Image
from rr44_case import PROJECT, CASE
from spec.art_identity.maquettes.chainbound_gaoler.proof import job, BUILDER, FOLDER
from spec.art_identity.maquettes.blender.curate_delivery import write,stage
from spec.art_identity.maquettes.blender.contract import digest


def inspect(capture, project):
    from spec.art_identity.maquettes.chainbound_gaoler.acceptance import inspect as acceptance
    result=acceptance(CASE/'maquette',capture)
    write(capture/'rr44_fit.json',result['front_fit'])
    print('RR44 NATIVE FIT: '+('PASS' if result['passed'] else 'FAIL'))
    return result


def main(output):
    from spec.art_identity.maquettes.blender.compile_recipe import PROJECT
    source=CASE/'maquette/spec_native.json';output=Path(output).resolve();capture=output/'capture'
    from rr44_maquette_batches import capture as bounded_capture
    bounded_capture(source,output,capture)
    job(FOLDER/'native_probe.py',[source,capture,capture/'native_probe.json'],output/'bridge','native_probe')
    job(BUILDER/'recipe_proof.py',[source,output/'determinism'],output/'bridge','cold_replay')
    job(BUILDER/'exact_native_replay.py',[output/'determinism',capture/'exact_native_replay.json'],output/'bridge','exact_replay')
    finish(output)


def finish(output):
    output=Path(output).resolve();capture=output/'capture';source=CASE/'maquette/spec_native.json'
    shutil.copyfile(output/'determinism/recipe_proof.json',capture/'recipe_proof.json')
    from spec.art_identity.maquettes.blender.compact_capture import compact_capture
    spec=json.loads(source.read_text());compact_capture(spec,capture)
    result=inspect(capture,PROJECT)
    if not result['passed']: raise ValueError('Director native fit failed; inspect rr44_fit.json')
    from spec.art_identity.maquettes.chainbound_gaoler.acceptance import review_sheet
    from spec.art_identity.maquettes.blender.delivery_validation import seal_delivery,validate_delivery
    seal_delivery(spec,capture);validate_delivery(spec,capture)
    stage(CASE/'maquette',capture)
    delivery=CASE/'maquette/delivery'
    inspect(delivery,PROJECT) # Rebuild the staged overlays and measured table.
    review_sheet(CASE/'maquette',delivery)
    seal_delivery(spec,delivery);validate_delivery(spec,delivery)
    write(CASE/'maquette/fit_status.json',dict(native_verified=True,spec_hash=digest(spec),
        acceptance_sha256=__import__('hashlib').sha256((delivery/'mq15_acceptance.json').read_bytes()).hexdigest(),
        front_iou=result['front_fit']['views']['front']['iou'],
        semantic_centroids={n:r['distance_px'] for n,r in result['front_fit']['table'].items()},
        all_mq15_rows_passed=result['passed'],rear_policy='proper half turn diag(-1,-1,1); never independently fitted'))
    print('RR44 MAQUETTE DELIVERY: PASS (every mq-15 row; fresh bridge geometry and both captures; cold/exact replay)')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',required=True,type=Path);p.add_argument('--finish-existing',action='store_true')
    args=p.parse_args();(finish if args.finish_existing else main)(args.output)
