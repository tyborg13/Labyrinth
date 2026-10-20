"""Compile only the two mq-11 accessory replacements from owner-filled data."""
from copy import deepcopy
import hashlib
import json

from spec.art_identity.maquettes.blender.accessory_geometry.forms import (
    complete, hair_piece, belt_piece, flap_piece)
from spec.art_identity.maquettes.blender.compile_recipe import PROJECT, compile_recipe
from spec.art_identity.maquettes.blender.contract import validate

ROOT = PROJECT / 'spec/art_identity/maquettes'
FIGURES = ('hollow_mimic', 'slag_mortar')
# All visible ratios and gate thresholds below are transcribed from mq-11. The director
# lengthened the front flap from mid-thigh (.5) to the knee (1.25) to match the source art, and holds
# each flap's median central centre line to +/-12 px at 1024 (3 game px): the rear flap's cloth settles
# ~11 px toward a thigh, which still reads as centred; the defect this guards is a flap off one hip.
GATES = {'native_size': 1024, 'iou': {'front': .70, 'rear': .65},
         'scalp_skull_width': 1.25, 'tuft_count': 16, 'fringe_count': 4,
         'tuft_length_head_height': [.3, .9], 'rear_height_head_height_max': .5,
         'fringe_mask_top_fraction': .2, 'flap_hip_width': .5,
         'front_thigh_fraction': 1.25, 'flap_centre_error_px_max': 12}


def folder(name):
    if name not in FIGURES:
        raise ValueError('mq-11 owns only: ' + ', '.join(FIGURES))
    return ROOT / name


def design_path(name):
    return folder(name) / 'owner_review/design.json'


def compile_candidate(name):
    path = design_path(name)
    document = json.loads(path.read_text())
    return compile_document(name, document)


def compile_document(name, document):
    base = folder(name) / 'measurements.json'
    if (document['schema'] != 1 or document['id'] != name or
            document['base_recipe_sha256'] != hashlib.sha256(base.read_bytes()).hexdigest()):
        raise ValueError('Owner-review data does not match its protected base recipe')
    complete(document['design'])
    recipe = json.loads(base.read_text())
    spec = compile_recipe(recipe)
    original = deepcopy(spec)
    if name == 'hollow_mimic':
        target = next(p for p in spec['pieces'] if p['id'] == 'hair_crown')
        replacement = hair_piece(target, document['design'], GATES)
        spec['pieces'] = [replacement if p['id'] == target['id'] else p for p in spec['pieces']]
    else:
        design = document['design']
        targets = {p['id']: p for p in spec['pieces'] if p['id'] in ('leather_apron', 'rear_leather_apron')}
        belt = belt_piece(spec, design['belt'], 'apron', targets['leather_apron']['thick'])
        replacements = [belt] + [flap_piece(targets[identifier], spec, design[side], design['belt'], side, GATES)
                                 for side, identifier in (('front', 'leather_apron'), ('rear', 'rear_leather_apron'))]
        spec['pieces'] = replacements + [p for p in spec['pieces'] if p['id'] not in targets]
    spec['source_recipe'] = name + '/owner_review/design.json'
    spec['mq11'] = {'design': deepcopy(document['design']), 'gates': deepcopy(GATES),
                    'base_recipe_sha256': document['base_recipe_sha256']}
    validate(spec)
    assert_preserved(original, spec)
    return spec


def assert_preserved(before, after):
    changed = {'hair_crown'} if before['id'] == 'hollow_mimic' else {'leather_apron', 'rear_leather_apron', 'leather_belt'}
    for spec in (before, after):
        if spec.get('rear_body') or spec.get('per_view_cloth_pose') or any('capture_view' in p for p in spec['pieces']):
            raise ValueError('mq-11 requires one posed body and a true camera turn')
    if [p for p in before['pieces'] if p['id'] not in changed] != [p for p in after['pieces'] if p['id'] not in changed]:
        raise ValueError('An unowned accessory changed')
    ignored = {'pieces', 'source_recipe', 'mq11'}
    if {k: v for k, v in before.items() if k not in ignored} != {k: v for k, v in after.items() if k not in ignored}:
        raise ValueError('Body, mask, joints, labels, source art or pose changed')
