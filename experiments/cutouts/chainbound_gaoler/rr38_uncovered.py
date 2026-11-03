"""Full vacated limb footprints; native UV ties and flat-fill diagnostics."""
from pathlib import Path
import numpy as np
from PIL import Image
from rr38_case import CASE
from cutout_pipeline.cases import read_json, digest
from humanoid_cutout.cpu_pose import CpuPose
from humanoid_cutout.uncovered_surfaces import UncoveredSurface as GenericUncoveredSurface
from humanoid_cutout.native_defects import packed
from humanoid_cutout.native_frames import load_frame, frame_digest
from maquette_motion.features import source_pixels
from maquette_motion.material_palette import rules
from maquette_motion.silhouette import components, dilate, holes
from maquette_motion import pixels
from rr38_surfaces import interior

# Diagnostic-only crop/variance defaults; director judgment decides underlays.
FLAT_VARIANCE_RATIO = 0.25
FLAT_MIN_REGION_PX = 4
FLAT_CONTEXT_PX = 3
CROP_ZOOM = 4
MAX_UNCOVERED_COMPONENT_PX = 3  # Existing native gate's tiny-component rule.
REST_TRANSFORM_EPSILON = .0001


class UncoveredSurface(GenericUncoveredSurface):
    def __init__(self, contract_case, model, *, include_intentionally_empty=False):
        self.case = Path(contract_case)
        canonical = read_json(self.case/f'layouts/{model.layout["facing"]}.json')
        owners=np.full((255,255),'',dtype=object)
        palettes,part_palettes={},{}
        definition=rules(self.case,canonical['facing'])
        for part in canonical['parts']:
            image=source_pixels(self.case,part)
            certificate=np.asarray(Image.open(self.case/f'uncovered/donor_{canonical["facing"]}_{part["name"]}.png'))>0
            part_palettes[part['name']]=np.unique(packed(image)[certificate&(image[...,3]>0)])
            if not part.get('hidden_material'):
                owners[image[...,3]>0]=part['logical_part']
                seed=interior(image,definition)
                palettes[part['logical_part']]=np.unique(packed(seed)[seed[...,3]>0])
        domains={n:np.asarray(Image.open(self.case/f'uncovered/{canonical["facing"]}_{n}.png'))>0 for n in palettes}
        # The director deliberately leaves these rear nodes unpainted. Their
        # maquette solos cannot require hypothetical unseen paint. Rear cowl
        # and source-emptiness gates independently enforce that decision.
        empty=read_json(self.case/'anatomy.json').get('intentionally_empty',{}).get(canonical['facing'],{})
        if not include_intentionally_empty:
            domains={n:mask for n,mask in domains.items() if n not in empty}
        self.native_tie_source_current=all(digest(model.case/p['file'])==canonical['proof_layers'][p['name']]['source_sha256'] for p in model.layout['parts'])
        occluders=('arm_near','arm_far','hand_near','hand_far','leg_near','leg_far','foot_near','foot_far','chain','coat_near','coat_far')
        super().__init__(model,owners=owners,occluders=occluders,domains=domains,
            palettes=palettes,part_palettes=part_palettes,definition=definition,
            reference_bones=('root','pelvis','torso'),max_component_px=MAX_UNCOVERED_COMPONENT_PX,
            rest_epsilon=REST_TRANSFORM_EPSILON,visible_occluders_only=True)

def arm_budget_gate(case, model, side):
    """The same strict gate, restricted to one arm's full rest footprint."""
    gate=UncoveredSurface(case,model)
    gate.occluders=('arm_'+side,'hand_'+side)
    gate.footprint=np.isin(gate.owners,gate.occluders)
    gate.domains={name:mask&gate.footprint for name,mask in gate.domains.items()}
    return gate


def bounds(mask):
    y,x=np.nonzero(mask)
    return [int(x.min()),int(y.min()),int(x.max())+1,int(y.max())+1]


def flat_regions(gate, pose, layers, output=None, *, moving_extra=None, reference_domains=None):
    """Compare exposed continuation texture with its own surrounding painting.

    Full vacated footprints include both walking legs and every action. Flat
    surfaces are flagged, never silently accepted as director-approved paint.
    """
    occupied=np.zeros(layers[0][1].shape[:2],bool)
    moving=np.zeros_like(occupied)
    composite=np.zeros_like(layers[0][1])
    for part,image,_ in sorted(layers,key=lambda r:r[0]['z_index']):
        alpha=image[...,3]>0;composite[alpha]=image[alpha]
        if part['logical_part'] in gate.occluders and not part.get('hidden_material'):moving|=alpha
    if moving_extra is not None:moving |= moving_extra
    vacated=gate.vacated(pose,moving)
    rows=[]
    for part,image,_ in sorted(layers,key=lambda r:r[0]['z_index'],reverse=True):
        alpha=image[...,3]>0;exposed=alpha&~occupied&vacated;occupied|=alpha
        if not part.get('hidden_material') or not exposed.any():continue
        labels,groups=components(exposed,8)
        original=next(p for p in gate.model.layout['parts'] if p['name']==part['logical_part'])
        source=source_pixels(gate.model.case,original)
        seed=interior(source,gate.definition)
        for label,count in groups:
            if count<FLAT_MIN_REGION_PX:continue
            mask=labels==label
            # The source-domain neighborhood is independent of the fill alpha.
            domain=(gate.domains if reference_domains is None else reference_domains)[part['logical_part']]
            context=dilate(domain,FLAT_CONTEXT_PX)&(seed[...,3]>0)
            if not context.any():context=seed[...,3]>0
            if not context.any():continue
            reference=float(np.asarray(seed[context,:3],float).var(axis=0).mean())
            actual=float(np.asarray(image[mask,:3],float).var(axis=0).mean())
            # A constant donor cannot establish that a constant continuation
            # has texture. Retain it for judgment instead of treating missing
            # reference variation as an exemption (the rear far trouser has
            # only one eligible interior texel).
            if reference>0 and actual>=reference*FLAT_VARIANCE_RATIO:continue
            if reference<=0 and actual>0:continue
            row={'view':pose['view'],'clip':pose['clip'],'frame':pose['frame'],'piece':part['logical_part'],
                'pixels':count,'bbox':bounds(mask),'variance':actual,'source_variance':reference,
                'ratio':actual/reference if reference>0 else None,
                'reference_texture':'measured' if reference>0 else 'constant donor; comparative texture unavailable',
                'decision':'director underlay judgment pending'}
            if output:
                output=Path(output);output.mkdir(parents=True,exist_ok=True)
                x0,y0,x1,y1=row['bbox'];padding=FLAT_CONTEXT_PX
                box=(max(0,x0-padding),max(0,y0-padding),min(image.shape[1],x1+padding),min(image.shape[0],y1+padding))
                path=output/f'{pose["view"]}_{pose["clip"]}_{pose["frame"]:04d}_{part["name"]}_{label}.png'
                crop=Image.fromarray(composite).crop(box);crop.resize((crop.width*CROP_ZOOM,crop.height*CROP_ZOOM),Image.Resampling.NEAREST).save(path)
                row['crop']=str(path)
            rows.append(row)
    return rows
def native_report(capture, case, models=None, poses=None, selection=False, joint_pockets=None):
    from humanoid_cutout.canvas import for_case
    with for_case(case):
        return _native_report(capture,case,models,poses,selection,joint_pockets)


def _native_report(capture, case, models, poses, selection, joint_pockets):
    manifest = read_json(capture/'frames.json')
    if not manifest['native_pixels']: raise ValueError('Uncovered gate requires native pixel evidence')
    if not selection:
        from humanoid_cutout.gates import bindings
        if manifest['inputs']!=bindings(case): raise ValueError('Stale uncovered-surface native proof')
    if poses is None: poses = read_json(case/'proof/logs/samples.json')['samples']
    poses = {(r['view'],r['clip'],r['frame']):r for r in poses if r['kind']=='presented'}
    if models is None: models={v:CpuPose(case,read_json(case/f'layouts/{v}.json')) for v in ('front','rear')}
    gates={v:UncoveredSurface(case,m) for v,m in models.items()}
    inventory={}
    for row in manifest['pieces']:inventory.setdefault((row['view'],row['clip'],row['frame']),[]).append(row)
    results=[];errors=[]
    known_pockets=None if joint_pockets is None else {
        (r['view'],r['clip'],r['frame']):r['pockets'] for r in joint_pockets}
    from humanoid_cutout.source_space import bounds
    from maquette_motion.silhouette import holes
    for row in manifest['frames']:
        key=(row['view'],row['clip'],row['frame']);model=models[row['view']]
        layers=[];parts={p['name']:p for p in model.layout['parts']}
        if frame_digest(capture/row['file'])!=row['sha256']:raise ValueError('Changed uncovered native frame')
        for piece in inventory[key]:
            if frame_digest(capture/piece['file'])!=piece['sha256']:raise ValueError('Changed uncovered native layer')
            layers.append((dict(parts[piece['name']],z_index=piece['z_index']),np.asarray(load_frame(capture/piece['file']).convert('RGBA')),None))
        if {p['name'] for p,_,_ in layers}!=set(parts) or len(layers)!=len(parts):raise ValueError('Incomplete uncovered native inventory')
        from rr38_acceptance import rear_cowl_errors
        errors += rear_cowl_errors(model.layout,layers,poses[key])
        composite=np.zeros_like(layers[0][1])
        for _,image,_ in sorted(layers,key=lambda r:r[0]['z_index']):composite[image[...,3]>0]=image[image[...,3]>0]
        actual=np.asarray(load_frame(capture/row['file']).convert('RGBA'))
        if pixels.changed(actual,composite).any():raise ValueError('Native uncovered frame differs from isolated native layers')
        metrics=gates[row['view']].measure(poses[key],layers)
        if known_pockets is None:
            from humanoid_cutout.silhouette_gates import posed_owners,joint_holes
            from humanoid_cutout.anatomy import load
            def masks(field):
                result=[]
                for reference in manifest[field]:
                    if (reference['view'],reference['clip'],reference['frame'])!=key:continue
                    if frame_digest(capture/reference['file'])!=reference['sha256']:raise ValueError('Changed native surface reference')
                    result.append(np.asarray(load_frame(capture/reference['file']).convert('RGBA'))[...,3]>0)
                return result
            seams=masks('joint_seams')
            seam=np.logical_or.reduce(seams) if seams else np.zeros(actual.shape[:2],bool)
            owners=posed_owners(layers,model.layout['parts'],poses[key]['bones'],pixels.PROOF_DEFAULTS['source_offset'],load(case)['ownership'])
            pockets=joint_holes(actual[...,3]>0,seam,owners,masks('rest_holes'),pocket_details=True)
        else:pockets=known_pockets.get(key,[])
        if pockets:
            # The same native joint-boundary rule also covers enclosed tears;
            # the independent surface domains catch open tears and bad fills.
            gate=gates[row['view']]
            if not hasattr(gate,'last_masks'):gate.last_masks={}
            missing=gate.last_masks.get('missing',np.zeros(actual.shape[:2],bool)).copy()
            boxes={tuple(p['bbox']) for p in pockets}
            for pocket in holes(actual[...,3]>0):
                if tuple(bounds(pocket)) in boxes:missing |= pocket
            gates[row['view']].last_masks['missing']=missing
            metrics['uncovered_missing_pixels']=int(missing.sum())
        from humanoid_cutout.uncovered_ties import resolve
        ties={}
        if gates[row['view']].native_tie_source_current:
            metrics,ties=resolve(gates[row['view']],poses[key],layers,metrics,pockets)
        record=dict(view=key[0],clip=key[1],frame=key[2],metrics=metrics)
        if ties:record['raster_ties']=ties
        if pockets:record['native_joint_pockets']=pockets
        if any(metrics.values()):record['diagnostics']=gates[row['view']].diagnostics()
        record['flat_regions']=flat_regions(gates[row['view']],poses[key],layers,case/'proof/logs/flat_native')
        results.append(record)
        errors += [str(key)+': '+name+': '+str(n) for name,n in metrics.items() if n]
    tie_counts={name:sum(len(r.get('raster_ties',{}).get(name,[])) for r in results)
                for name in ('uncovered_outline_pixels','uncovered_missing_pixels')}
    return {'ok':not errors,'errors':errors,'frames':results,'native_pixels':True,'raster_tie_counts':tie_counts,
            'source_manifest_sha256':digest(capture/'frames.json')}
