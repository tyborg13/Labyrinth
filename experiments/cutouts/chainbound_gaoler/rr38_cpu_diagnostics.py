"""The native pixel-gate rules applied to CPU surfaces, without exceptions.

No native findings are supplied to this evaluator. The separate calibration
fixture only checks its output. Ground truth remains the director's captures.
"""
import numpy as np
from PIL import Image
from cutout_pipeline.cases import read_json
from humanoid_cutout.anatomy import load
from humanoid_cutout.gates import clean_metrics
from humanoid_cutout.held_release import ComponentPolicy
from humanoid_cutout.source_space import DetachedSource,pocket_report,bounds
from humanoid_cutout.silhouette_gates import posed_owners,joint_holes
from maquette_motion.silhouette import components,holes
from maquette_motion.material_palette import rules
from maquette_motion import pixels
from rr38_uncovered import UncoveredSurface


class Diagnostics:
    def __init__(self,case,model):
        self.case,self.model=case,model
        self.layout=model.layout
        self.anatomy=load(case)
        self.motion=read_json(case/'compiled_motion.json')
        self.definition=rules(case,self.layout['facing'])
        self.surface=UncoveredSurface(case,model)
        rest=np.asarray(Image.open(case/self.layout['rest_source']).convert('RGBA'))
        self.release=ComponentPolicy(self.anatomy,self.motion,self.layout,len(components(rest[...,3]>0,8)[1]))
        self.detached=DetachedSource(case,self.layout)

    def measure(self,pose,layers,maps):
        occupied=np.logical_or.reduce([image[...,3]>0 for _,image,_ in layers])
        seams=self.model.masks(pose,self.layout.get('proof_joint_seams',[]),maps)
        references=self.model.masks(pose,self.layout.get('proof_rest_holes',[]),maps)
        seam=np.logical_or.reduce(seams) if seams else np.zeros(occupied.shape,bool)
        ownership=self.anatomy['ownership']
        if hasattr(self.release,'boundary_ownership'):ownership=self.release.boundary_ownership(ownership,pose['clip'],pose['phase'])
        owners=posed_owners(layers,self.layout['parts'],pose['bones'],pixels.PROOF_DEFAULTS['source_offset'],ownership)
        tears=joint_holes(occupied,seam,owners,references,pocket_details=True)
        space=pocket_report(layers,tears)
        release=self.release.report(occupied,layers,pose['clip'],pose['phase'])
        transforms={name:row['transform'] for name,row in pose['parts'].items()}
        detached=self.detached.report(layers,transforms,release['masks'])
        clean=clean_metrics(layers,self.definition)
        clean.update(detached['metrics'])
        metrics=self.surface.measure(pose,layers,maps)
        missing=self.surface.last_masks.get('missing',np.zeros(occupied.shape,bool)).copy()
        boxes={tuple(p['bbox']) for p in space['failures']}
        for pocket in holes(occupied):
            if tuple(bounds(pocket)) in boxes:missing|=pocket
        metrics['uncovered_missing_pixels']=int(missing.sum())
        kinds=[]
        if space['failures']:kinds.append('seam')
        if clean['stray_components']:kinds.append('detached')
        if release['errors']:kinds.append('floating')
        if metrics['uncovered_missing_pixels']:kinds.append('missing')
        if metrics['uncovered_tiny_components']:kinds.append('tiny')
        return {'kinds':sorted(kinds),'metrics':metrics,'clean':clean,'joint_tears':tears,
            'source_space':space,'components':{k:v for k,v in release.items() if k!='masks'},
            'detached':detached,'diagnostics':self.surface.diagnostics()}
