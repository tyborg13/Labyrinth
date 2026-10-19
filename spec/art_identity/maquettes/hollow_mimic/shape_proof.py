"""Bind feedback-3 shape measurements to native geometry and delivered pixels."""
import json
from pathlib import Path
from .shape_measurements import spike_tips
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import sha,write

SHAPE_DEFAULTS={'hair_centre_1024_px':[500,284], 'minimum_hair_tips':8,
                'maximum_vessel_ratio':.8, 'minimum_band_width_ratio':.04}


def finish(folder,spec,capture,native=None):
    folder,capture=Path(folder),Path(capture)
    build=json.loads((capture/'build_report.json').read_text())
    if native and (native['id']!=spec['id'] or native['spec_hash']!=digest(spec) or
                   native['cold_mesh_hash']!=build['combined_mesh_hash']):
        raise ValueError('Native shape measurement belongs to a different build')
    report=dict(native or {},id=spec['id'],spec_hash=digest(spec),cold_mesh_hash=build['combined_mesh_hash'])
    checks={}
    if spec['id']=='hollow_mimic':
        path=capture/'front_solo_head.png'
        report['hair']=spike_tips(path,SHAPE_DEFAULTS['hair_centre_1024_px'])
        report['front_head_sha256']=sha(path)
        checks['eight_separate_front_silhouette_tips']=report['hair']['count']>=SHAPE_DEFAULTS['minimum_hair_tips']
    if spec['id']=='briar_weaver':
        recipe=json.loads((folder/'measurements.json').read_text());measurement=recipe['shape_measurements']
        hood=report['rear_hood'];hood['painting_top_px']=measurement['rear_hood_top_source_px']*4
        hood['top_error_px']=abs(hood['top_px']-hood['painting_top_px'])
        hood['painting_sha256']=recipe['source_sha256']['rear']
        checks['rear_hood_top_matches_painting']=hood['top_error_px']<=measurement['rear_hood_top_tolerance_1024_px']
        checks['rear_hood_has_native_layered_leaves']=hood['referenced_vertices']['rear_hood_leaf_clumps']>1000
    if spec['id']=='slag_mortar':
        cup=report['vessel'];checks['squat_vessel_including_rolled_rim']=cup['height_diameter_ratio']<=SHAPE_DEFAULTS['maximum_vessel_ratio']
        checks['two_raised_bands']=cup['band_count']==2 and all(b['raised_m']>0 for b in cup['bands'])
        checks['band_width_at_least_four_percent']=all(b['width_height_ratio']>=SHAPE_DEFAULTS['minimum_band_width_ratio'] for b in cup['bands'])
        checks['both_bands_visible_in_both_views']=all(min(b['visible_outer_samples'].values())>0 for b in cup['bands'])
    report.update(checks=checks,passed=bool(checks) and all(checks.values()))
    write(capture/'shape_measurements.json',report)
    print('MQ09_SHAPE: '+('PASS' if report['passed'] else 'FAIL')+'; '+spec['id']+'; '+json.dumps(checks,sort_keys=True),flush=True)
    if not report['passed']:raise ValueError('Director feedback-3 measured shape gate failed: '+spec['id'])
    return report


def validate(folder,spec,native):
    delivery=folder/'delivery';report=json.loads((delivery/'validation/shape_measurements.json').read_text())
    if (report.get('passed') is not True or not all(report['checks'].values()) or
            report['spec_hash']!=digest(spec) or report['cold_mesh_hash']!=native['cold_mesh_hash']):
        raise ValueError('Missing, failed or stale native shape evidence')
    if spec['id']=='hollow_mimic':
        path=delivery/'front_solo_head.png'
        if sha(path)!=report['front_head_sha256'] or spike_tips(path,SHAPE_DEFAULTS['hair_centre_1024_px'])!=report['hair']:
            raise ValueError('Stale rendered hair silhouette measurement')
    return report
