"""Uncovered-surface provenance on actual native pixels or labelled CPU frames.

Independent required source domains detect open tears as well as enclosed holes.
Source ownership and interior donor provenance prevent self-certifying masks:
foreign shaft/glove pixels cannot pass merely by riding a permitted layer.
"""
from pathlib import Path
import numpy as np
from PIL import Image
from rr37_case import CASE
from rr37_raster import CpuPose
from rr37_surfaces import INTERIOR_MARGIN_PX, interior
from cutout_pipeline.cases import read_json, digest
from humanoid_cutout.native_defects import packed
from humanoid_cutout.native_frames import load_frame, frame_digest
from maquette_motion import pixels
from maquette_motion.features import source_pixels
from maquette_motion.material_palette import rules

MAX_UNCOVERED_COMPONENT_PX = 3  # Director feedback 3.
REST_TRANSFORM_EPSILON = .0001  # Existing humanoid proof precision; diagnostic only.


from humanoid_cutout.uncovered_surfaces import UncoveredSurface as GenericUncoveredSurface


class UncoveredSurface(GenericUncoveredSurface):
    def __init__(self, contract_case, model):
        self.case, self.model = Path(contract_case), model
        self.view = model.layout['facing']
        self.canonical = read_json(self.case/f'layouts/{self.view}.json')
        self.parts = {p['name']: p for p in model.layout['parts']}
        # Historical rejection models deliberately contain retired paint.
        # Such a source cannot certify a tie against today's approved rig.
        self.native_tie_source_current = set(self.parts)=={p['name'] for p in self.canonical['parts']} and all(
            digest(model.case/p['file'])==self.canonical['proof_layers'][p['name']]['source_sha256']
            for p in model.layout['parts'])
        self.mapping_cache = {}
        self.support_cache = {}
        self.definition = rules(self.case, self.view)
        self.owners = np.full((255,255), '', dtype=object)
        self.palettes = {}
        self.part_palettes = {}
        for part in self.canonical['parts']:
            image = source_pixels(self.case, part)
            certificate=np.asarray(Image.open(self.case/f'uncovered/donor_{self.view}_{part["name"]}.png'))>0
            self.part_palettes[part['name']]=np.unique(packed(image)[certificate & (image[...,3]>0)])
            if not part.get('hidden_material'):
                self.owners[image[...,3]>0] = part['logical_part']
                seed = interior(image, self.definition)
                declared=part.get('continuation_donor_uvs')
                if declared is not None:
                    legal=np.zeros(seed.shape[:2],bool)
                    for u,v in declared:legal[v+part['offset'][1],u+part['offset'][0]]=True
                    seed[~legal]=0
                self.palettes[part['logical_part']] = np.unique(packed(seed)[seed[...,3]>0])
        self.occluders = ('arm_far', 'hand_far', 'spear')
        if self.view == 'front' and self.canonical.get('director_leg_underlay'):
            from rr41_uncovered import LEGS
            self.occluders += LEGS
        self.footprint = np.isin(self.owners, self.occluders)
        self.domains = {}
        for path in sorted((self.case/'uncovered').glob(self.view+'_*.png')):
            logical = path.stem[len(self.view)+1:]
            self.domains[logical] = np.asarray(Image.open(path)) > 0
        if not self.domains: raise ValueError('Missing independent uncovered-surface domains')
        forbidden = {}
        painted = {}
        for name, part in self.parts.items():
            path = self.case/f'uncovered/outer_{self.view}_{part["logical_part"]}.png'
            if part.get('hidden_material') and path.exists():
                outline = np.asarray(Image.open(path)) > 0
                yy, _ = np.indices(outline.shape)
                forbidden[name] = ~outline & (yy >= 80) & (yy <= 180)
            path = self.case/f'uncovered/painted_{self.view}_{name}.png'
            if path.exists(): painted[name] = np.asarray(Image.open(path)) > 0
        super().__init__(model, owners=self.owners, occluders=self.occluders,
            domains=self.domains, part_palettes=self.part_palettes,
            palettes=self.palettes, definition=self.definition, forbidden=forbidden,
            painted=painted, reference_bones=('root', 'torso'),
            max_component_px=MAX_UNCOVERED_COMPONENT_PX, rest_epsilon=REST_TRANSFORM_EPSILON)
        self.leg_paint = None
        if self.view == 'front' and self.canonical.get('director_leg_underlay'):
            from rr41_uncovered import LegPaint
            self.leg_paint = LegPaint(self)

    def transport(self, name, mask, pose):
        fallback=super().transport(name,mask,pose)
        native=getattr(self,'native_masks',None)
        if native is not None:
            sampled=native.transport(name,mask)
            if sampled is not None:
                result,matched=sampled
                return np.where(matched,result,fallback)
        return fallback

    def measure(self, pose, layers, maps=None, *, native_pixels=False):
        self.native_masks=None
        if native_pixels and self.leg_paint is not None and self.native_tie_source_current:
            from rr41_uncovered import NativeMasks
            self.native_masks=NativeMasks(self,pose,layers)
        metrics = super().measure(pose, layers, maps)
        if self.leg_paint is not None:
            from rr41_uncovered import METRIC
            invalid = self.leg_paint.measure(pose, layers)
            metrics[METRIC] = int(invalid.sum())
            self.last_masks['procedural_leg'] = invalid
            # The exact RGBA/UV certificate includes the director's ink. A
            # native nearest-UV choice can select that ink where a separately
            # transported boolean outline mask selects its neighbour.
            outline = self.last_masks.get('outline', np.zeros(invalid.shape,bool)) & ~self.leg_paint.last_painted
            metrics['uncovered_outline_pixels'] = int(outline.sum())
            self.last_masks['outline'] = outline
            missing = self.last_masks.get('missing', np.zeros(invalid.shape, bool)) | self.leg_paint.missing(pose, layers)
            metrics['uncovered_missing_pixels'] = int(missing.sum())
            self.last_masks['missing'] = missing
        self.native_masks=None
        return metrics


def native_report(capture, case, models=None, poses=None, selection=False, joint_pockets=None, frame_keys=None):
    from humanoid_cutout.canvas import for_case
    with for_case(case):
        return _native_report(capture,case,models,poses,selection,joint_pockets,frame_keys)


def _native_report(capture, case, models, poses, selection, joint_pockets, frame_keys=None):
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
        if frame_keys is not None and (row['view'],row['clip'],row['frame']) not in frame_keys: continue
        key=(row['view'],row['clip'],row['frame']);model=models[row['view']]
        layers=[];parts={p['name']:p for p in model.layout['parts']}
        if frame_digest(capture/row['file'])!=row['sha256']:raise ValueError('Changed uncovered native frame')
        for piece in inventory[key]:
            if frame_digest(capture/piece['file'])!=piece['sha256']:raise ValueError('Changed uncovered native layer')
            layers.append((dict(parts[piece['name']],z_index=piece['z_index']),np.asarray(load_frame(capture/piece['file']).convert('RGBA')),None))
        if {p['name'] for p,_,_ in layers}!=set(parts) or len(layers)!=len(parts):raise ValueError('Incomplete uncovered native inventory')
        composite=np.zeros_like(layers[0][1])
        for _,image,_ in sorted(layers,key=lambda r:r[0]['z_index']):composite[image[...,3]>0]=image[image[...,3]>0]
        actual=np.asarray(load_frame(capture/row['file']).convert('RGBA'))
        if pixels.changed(actual,composite).any():raise ValueError('Native uncovered frame differs from isolated native layers')
        native_maps=None
        if gates[row['view']].leg_paint is not None:
            # Godot stores skin weights as UNORM16. Transport the Lancer's
            # required/certified masks with that same known native geometry,
            # rather than treating the CPU weight field as the captured one.
            from humanoid_cutout.cpu_pose import mesh_map
            native_maps={name:mesh_map(model.layout,poses[key],mesh,native_skin=True)
                         for name,mesh in model.meshes.items()}
        metrics=gates[row['view']].measure(poses[key],layers,native_maps,native_pixels=True)
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
        results.append(record)
        errors += [str(key)+': '+name+': '+str(n) for name,n in metrics.items() if n]
    tie_counts={name:sum(len(r.get('raster_ties',{}).get(name,[])) for r in results)
                for name in ('uncovered_outline_pixels','uncovered_missing_pixels')}
    return {'ok':not errors,'errors':errors,'frames':results,'native_pixels':True,'raster_tie_counts':tie_counts,
            'source_manifest_sha256':digest(capture/'frames.json')}
