"""Executable review regressions; synthetic changes never alter authoring files."""
from copy import deepcopy
from unittest.mock import patch
import numpy as np
from . import mq21_recipe as recipe
from .mq21_checks import observe
from spec.art_identity.maquettes.blender.contract import digest

MUTATION_DEFAULTS={'segment_multiplier':1.02,'finger_detachment_m':.2}


def report():
    spec=recipe.compile_spec();original=observe(spec);table=[]
    def row(name,result,check,authoring_caught=None):
        record={'mutation':name,'caught':result['checks'][check] is False,'semantic_gate':check,
                'fresh_mesh_digest':digest(result['observed_mesh_hashes'])}
        if authoring_caught is not None:record['authoring_caught']=authoring_caught
        table.append(record)
    for group,key,value,check in (
        ('legs','depth_over_width',.6,'shin_near_station_1_depth_over_width'),
        ('legs','calf_bulge_fraction_from_knee',.65,'calf_near_bulge_fraction'),
        ('helm','crest_thickness_over_H',.028,'crest_thickness_over_H'),
        ('grip','guard_gap_over_H',.05,'guard_gap_over_H'),
        ('pauldrons','outward_tilt_up_degrees',10,'pauldron_near_tilt_up_degrees')):
        pose,forms=recipe.read_design();forms[group][key]=value;caught=False
        with patch.object(recipe,'read_design',return_value=(pose,forms)):
            try:recipe.compile_spec()
            except ValueError:caught=True
            with patch.object(recipe,'require_design'):wrong=recipe.compile_spec()
        row(group+'.'+key,observe(wrong),check,caught)
    for key,value,check in (('foot_span_over_shoulder_span',1.6,'near_leg_soft_target_optimality_m'),
        ('near_step_over_leg_length',.25,'near_leg_soft_target_optimality_m'),
        ('knee_bend_degrees',{'near':10,'far':10},'knee_near_degrees')):
        pose,forms=recipe.read_design();pose[key]=value;caught=False
        with patch.object(recipe,'read_design',return_value=(pose,forms)):
            try:recipe.compile_spec()
            except ValueError:caught=True
            with patch.object(recipe,'require_design'):wrong=recipe.compile_spec()
        row('pose.'+key,observe(wrong),check,caught)
    for side in ('near','far'):
        for name,a,b in (('upper_arm','shoulder','elbow'),('forearm','elbow','hand'),('thigh','hip','knee'),('shin','knee','ankle')):
            wrong=deepcopy(spec);start=np.asarray(wrong['joints'][a+'_'+side]);end=np.asarray(wrong['joints'][b+'_'+side])
            wrong['joints'][b+'_'+side]=(start+MUTATION_DEFAULTS['segment_multiplier']*(end-start)).tolist()
            row(side+'_'+name+' +2%',observe(wrong),side+'_'+name+'_source_length_ratio')
    q={p['id']:np.asarray(p['vertices']) for p in spec['pieces']};faces={p['id']:p['faces'] for p in spec['pieces']}
    direction=np.asarray(spec['mq16']['falchion']['direction']);hand=np.asarray(spec['joints']['hand_far'])
    centre=q['finger_far_1'].reshape(-1,12,3).mean((0,1));radial=centre-hand-direction*np.dot(centre-hand,direction)
    for name,shift,check in (('finger_1 through handle',-radial,'hand_hilt_penetration'),
                             ('finger_1 detached 0.2m',radial/np.linalg.norm(radial)*MUTATION_DEFAULTS['finger_detachment_m'],'finger_far_1_hilt_contact')):
        wrong=dict(q);wrong['finger_far_1']=q['finger_far_1']+shift
        result=observe(spec,wrong,spec['joints'],faces);row(name,result,check)
        table[-1]['hash_changed']=result['observed_mesh_hashes']['finger_far_1']!=original['observed_mesh_hashes']['finger_far_1']
        table[-1]['finger_1_mesh_sha256']=result['observed_mesh_hashes']['finger_far_1']
    result={'spec_hash':digest(spec),'passed':all(r['caught'] and r.get('authoring_caught',True) and r.get('hash_changed',True) for r in table),
            'caught':sum(r['caught'] for r in table),'survived':sum(not r['caught'] for r in table),'mutations':table}
    if not result['passed']:raise ValueError('Surviving mq-23 mutations: '+str([r['mutation'] for r in table if not r['caught']]))
    return result
