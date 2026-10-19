"""Trace posed joint pockets back to covered, same-piece source texels."""
import argparse
import numpy as np
from PIL import Image
from case import CASE, VIEWS, PIECES, read_json, write_json
from cpu_proof import CpuPose, state, prune_mask_triangles
from humanoid_cutout.anatomy import load
from humanoid_cutout.cpu_pose import sprite_transform, mesh_map
from humanoid_cutout.skin_layers import layer
from humanoid_cutout.anatomy import owner_ids
from humanoid_cutout.silhouette_gates import JOINT_BOUNDARY_FRACTION
from maquette_motion.features import source_pixels
from maquette_motion.pixels import PROOF_DEFAULTS
from maquette_motion.silhouette import dilate
import proof_records

RASTER_COVERAGE_MARGIN_PX = 1  # Pixel-square coverage on both sides, as rr-15/gait-01.


def trace(view, poses, capture=None):
    layout = read_json(CASE / f'layouts/{view}.json')
    anatomy = load(CASE)
    model = CpuPose(CASE, layout)
    visible = {p['logical_part']: source_pixels(CASE, p)[...,3] > 0 for p in layout['parts'] if not p.get('hidden_material')}
    covers = {name: np.logical_or.reduce([visible[b if a == name else a] for a,b in anatomy['seam_joins'] if name in (a,b)]) for name in PIECES}
    local_covers = covers
    covers = {name:np.logical_or.reduce([mask for other,mask in visible.items() if other!=name]) for name in PIECES}
    virtual = {}
    eligible_source = {}
    for name in PIECES:
        base=np.logical_or.reduce([source_pixels(CASE,part)[...,3]>0 for part in layout['parts'] if part['logical_part']==name])
        eligible_source[name]=covers[name] & ~visible[name] & dilate(base,2*anatomy['joint_continuations']['depth_px'],grid_distance=True)
    for part in layout['parts']:
        logical=part['logical_part']
        if not part.get('hidden_material') or logical not in anatomy['meshes']:continue
        mask=visible[logical]|local_covers[logical]
        y,x=np.nonzero(mask)
        bounds=[int(x.min()),int(y.min()),int(x.max())+1,int(y.max())+1]
        garment=next(p for p in layout['parts'] if p['name']==logical)
        virtual[part['name']]=layer({'name':part['name'],'bbox':bounds},logical,garment['bbox'],layout['joints'],part['z_index'],True,recipe=anatomy['meshes'][logical])
        prune_mask_triangles(virtual[part['name']],eligible_source[logical][bounds[1]:bounds[3],bounds[0]:bounds[2]])
    points = {name:set() for name in PIECES}
    failures = []
    native_rows = {}
    if capture is not None:
        from humanoid_cutout.silhouette_gates import posed_owners, joint_holes
        manifest=read_json(capture/'frames.json')
        for row in manifest['pieces']:
            native_rows.setdefault((row['view'],row['clip'],row['frame']),[]).append(row)
    for pose in poses:
        layers, maps, owners, defects = state(model, pose)
        if capture is not None:
            layers=[(row,np.asarray(Image.open(capture/row['file']).convert('RGBA')),
                     np.asarray(Image.open(capture/row['checks']).convert('RGBA')))
                    for row in native_rows[(pose['view'],pose['clip'],pose['frame'])]]
            owners=posed_owners(layers,layout['parts'],pose['bones'],PROOF_DEFAULTS['source_offset'],anatomy['ownership'])
            key=(pose['view'],pose['clip'],pose['frame'])
            seam=np.logical_or.reduce([np.asarray(Image.open(capture/row['file']))[...,3]>0 for row in manifest['joint_seams'] if (row['view'],row['clip'],row['frame'])==key])
            references=[np.asarray(Image.open(capture/row['file']))[...,3]>0 for row in manifest['rest_holes'] if (row['view'],row['clip'],row['frame'])==key]
            defects=joint_holes(owners>0,seam,owners,references,pocket_details=True)
        for defect in defects:
            left,top,right,bottom = defect['bbox']
            # Only exact background pixels in the pocket rectangle can seed a
            # continuation; neighbour margin handles native raster edge ties.
            occupied = np.logical_or.reduce([image[...,3]>0 for _,image,_ in layers])
            pocket = np.zeros_like(occupied);pocket[top:bottom,left:right] = ~occupied[top:bottom,left:right]
            target = dilate(pocket, RASTER_COVERAGE_MARGIN_PX)
            boundary=owners[dilate(pocket,1)&(owners>0)]
            ids=owner_ids(anatomy['ownership'])
            allowed=set()
            for first,second in anatomy['ownership']['joint_pairs']:
                if ids[first] in boundary and ids[second] in boundary:
                    if np.count_nonzero((boundary==ids[first])|(boundary==ids[second]))>=JOINT_BOUNDARY_FRACTION*len(boundary):
                        for bone in (first,second):
                            logical=next((name for name,segment in anatomy['ownership']['segments'].items() if bone in segment['owners']),bone)
                            allowed.add(logical)
            choices = []
            for part in layout['parts']:
                if not part.get('hidden_material'): continue
                name, logical = part['name'],part['logical_part']
                if logical not in allowed:continue
                if name in virtual:
                    if not virtual[name]['triangles']:continue
                    mapping = mesh_map(layout,pose,virtual[name])
                    keep = target[mapping.pixels[:,1],mapping.pixels[:,0]]
                    xy,uv = mapping.pixels[keep],mapping.texels[keep] + virtual[name]['bbox'][:2]
                else:
                    y,x = np.nonzero(target);xy = np.column_stack((x,y))
                    inverse = np.linalg.inv(sprite_transform(layout,pose,part))
                    uv = np.floor((xy+.5-PROOF_DEFAULTS['source_offset']) @ inverse[:2,:2].T + inverse[:2,2]).astype(int) + part['offset']
                u,v=uv.T
                valid=(u>=0)&(v>=0)&(u<255)&(v<255)
                uv,xy=uv[valid],xy[valid]
                eligible=eligible_source[logical][uv[:,1],uv[:,0]]
                uv,xy=uv[eligible],xy[eligible]
                if len(uv):
                    score=int(pocket[xy[:,1],xy[:,0]].sum())
                    if score: choices.append((score,logical,{tuple(p) for p in uv}))
            if choices:
                # Coverage determines the owner; deterministic anatomy order
                # resolves ties. These points remain under its declared covers.
                _,logical,source = max(choices,key=lambda row:row[0])
                points[logical].update(source)
            else: failures.append({'clip':pose['clip'],'frame':pose['frame'],'pocket':defect})
    return {name:[[int(v) for v in p] for p in sorted(source,key=lambda p:(p[1],p[0]))] for name,source in points.items() if source},failures


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--historical-native',type=__import__('pathlib').Path)
    parser.add_argument('--samples',type=__import__('pathlib').Path)
    args=parser.parse_args()
    samples=read_json(args.samples) if args.samples else proof_records.samples()
    recipes,uncovered={},{}
    for view in VIEWS:
        poses=[r for r in samples['samples'] if r['view']==view and r['kind']=='presented']
        if args.historical_native:
            import ast
            failed={ast.literal_eval(error.split(':')[0]) for error in read_json(CASE/'proof/native_gates.json')['errors'] if error.startswith('(') and 'joint-seam hole' in error}
            poses=[row for row in poses if (row['view'],row['clip'],row['frame']) in failed]
        recipes[view],uncovered[view]=trace(view,poses,args.historical_native)
        print('RR20 JOINT TRACE',view,{n:len(p) for n,p in recipes[view].items()},'uncovered',len(uncovered[view]),flush=True)
    path=CASE/'joint_continuations.json'
    old=read_json(path) if path.exists() else {v:{} for v in VIEWS}
    for view in VIEWS:
        for name,points in recipes[view].items():
            merged={tuple(p) for p in old[view].get(name,[])+points}
            old[view][name]=[[int(v) for v in p] for p in sorted(merged,key=lambda p:(p[1],p[0]))]
    write_json(path,old)
    write_json(CASE/'proof/logs/continuation_trace.json',{'native_pixels':False,'uncovered':uncovered})




def derivation_errors(layout):
    """Verify every added joint texel against the exact rr-15 donor/domain rule."""
    from humanoid_cutout.joint_continuations import domains
    from maquette_motion.bleed import edge_texels
    from maquette_motion.material_palette import rules
    from residue import clean_piece, feature_mask
    anatomy = load(CASE)
    visible = {}
    hidden = {}
    for name in PIECES:
        source = CASE / 'residue_source' / layout['facing']
        visible[name] = np.asarray(Image.open(source / (name + '_visible.png')).convert('RGBA'))
        hidden[name] = np.asarray(Image.open(CASE / 'joint_source' / layout['facing'] / (name + '.png')).convert('RGBA')).copy()
    recipes = read_json(CASE / 'joint_continuations.json')[layout['facing']]
    joins = {name:{'covers':[other for other in PIECES if other!=name],'source_points':points} for name,points in recipes.items()}
    for name,target in domains(visible, hidden, joins, **anatomy['joint_continuations']).items():
        missing=target & (hidden[name][...,3]==0)
        replacement=edge_texels(visible[name],missing,rules(CASE,layout['facing']))
        hidden[name][missing]=replacement[missing]
    from underlaps import apply as source_underlaps
    source_underlaps(visible, hidden, layout['facing'])
    errors=[]
    for name in PIECES:
        actual=np.asarray(Image.open(CASE/'residue_source'/layout['facing']/(name+'_hidden.png')).convert('RGBA'))
        if not np.array_equal(actual,hidden[name]): errors.append(layout['facing']+'/'+name+': joint continuation differs from own edge texels')
    return errors


if __name__=='__main__':main()
