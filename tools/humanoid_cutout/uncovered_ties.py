"""Exact real-source UV ties for the optional native uncovered-surface gate.

No error budget is used. Only an outer-edge pixel actually produced by a
nearest-source candidate can be normalized to the independent CPU reference.
The CPU gate and the normalized native gate must both be clean. Components,
joint pockets and all other defect classes retain their original failures.
"""
import numpy as np
from .cpu_pose import mesh_map, mapped, sprite_transform
from .gait_continuations import texture
from maquette_motion import pixels, native_ties
from maquette_motion.silhouette import components, dilate

FIELDS = {'uncovered_missing_pixels':'missing', 'uncovered_outline_pixels':'outline'}


def composite(layers):
    result = np.zeros_like(layers[0][1])
    for _, image, _ in sorted(layers,key=lambda row:row[0]['z_index']):
        result[image[...,3]>0] = image[image[...,3]>0]
    return result


def body_components(image):
    occupied = image[...,3]>0
    labels, groups = components(occupied,8)
    body = labels==groups[0][0] if groups else np.zeros(occupied.shape,bool)
    return body, len(groups)


def source_edge(source):
    """The existing four-connected outer-air/paint boundary, in source UVs."""
    alpha = np.pad(source[...,3]>0,1)
    background, _ = components(~alpha,4)
    boundary = dilate(background==background[0,0],1) & alpha
    result = np.zeros_like(source)
    result[boundary[1:-1,1:-1]] = 255
    return result


def samples(model, pose, part):
    source = texture(model.case,model.layout,part,gait=pose['clip']=='move',clip=pose['clip'])
    name = part['name']
    if name in model.meshes:
        result = []
        # Evaluate both the registered source weights and their native UNORM16
        # encoding. Each uses the unchanged UV tie band; both CPU and native
        # colours must belong to the SAME candidate family at that pixel.
        for label,native in (('source_weights',False),('native_packed_weights',True)):
            mapping = mesh_map(model.layout,pose,model.meshes[name],with_ties=True,native_skin=native)
            result.append((label,mapped(source,mapping,with_ties=True),mapped(source_edge(source),mapping,with_ties=True)))
        return result
    transform = sprite_transform(model.layout,pose,part)
    return [('rigid',pixels.render(source,transform,with_ties=True),pixels.render(source_edge(source),transform,with_ties=True))]


def resolve(gate, pose, layers, metrics, joint_pockets=()):
    """Return remaining metrics and separately reported, certified edge ties."""
    if joint_pockets or not any(metrics.values()) or any(n for k,n in metrics.items() if k not in FIELDS):
        return metrics, {}
    original = gate.last_masks
    cpu, maps = gate.model.layers(pose)
    cpu_metrics = gate.measure(pose,cpu,maps)
    gate.last_masks = original
    if any(cpu_metrics.values()): return metrics, {}
    native_body, native_count = body_components(composite(layers))
    cpu_body, cpu_count = body_components(composite(cpu))
    if native_count != cpu_count: return metrics, {}
    body = native_body | cpu_body
    expected = {p['name']:image for p,image,_ in cpu}
    corrected, choices = [], {}
    legal = np.zeros(body.shape,bool)
    unexplained = np.zeros(body.shape,bool)
    for part, actual, checks in layers:
        name = part['name']
        difference = pixels.changed(actual,expected[name])
        if not difference.any():
            corrected.append((part,actual,checks)); continue
        families = []
        allowed = np.zeros(body.shape,bool)
        for label,candidates,edges in samples(gate.model,pose,part):
            selected, _ = native_ties.select(actual,candidates)
            alpha = [candidate[...,3]>0 for candidate in candidates.candidates]
            # Exact painted/air UV pairs and source-boundary outline texels
            # also cover a hem over another garment. Interior colour ties
            # away from the source boundary cannot waive a defect.
            edge = np.logical_or.reduce(alpha) & ~np.logical_and.reduce(alpha)
            for candidate, boundary in zip(candidates.candidates,edges.candidates):
                edge |= np.all(actual==candidate,axis=-1) & (boundary[...,3]>0)
            cpu_matches = np.logical_or.reduce([~pixels.changed(expected[name],c) for c in candidates.candidates])
            match = difference & body & edge & candidates.ties & cpu_matches & ~pixels.changed(actual,selected)
            allowed |= match
            families.append((label,candidates,match))
        image = actual.copy()
        image[allowed] = expected[name][allowed]
        corrected.append((part,image,checks))
        legal |= allowed
        unexplained |= difference & ~allowed
        choices[name] = (allowed,families)
    # An occluded layer's valid tie must never conceal another layer's CPU
    # disagreement at that same pixel.
    legal &= ~unexplained
    if not legal.any(): return metrics, {}
    normalized = gate.measure(pose,corrected,maps)
    gate.last_masks = original
    if any(normalized.values()): return metrics, {}
    remaining, ties = dict(metrics), {}
    for metric, field in FIELDS.items():
        resolved = original[field] & legal
        if not resolved.any(): continue
        records = []
        for y,x in np.argwhere(resolved):
            pieces = []
            for part,actual,_ in layers:
                name = part['name']
                if name not in choices or not choices[name][0][y,x]: continue
                label,candidates,_ = next(f for f in choices[name][1] if f[2][y,x])
                index = next(i for i,c in enumerate(candidates.candidates)
                    if np.array_equal(actual[y,x],c[y,x]) or actual[y,x,3]==c[y,x,3]==0)
                pieces.append({'name':name,'geometry':label,'candidate':index,'rgba':actual[y,x].tolist(),
                               'cpu_rgba':expected[name][y,x].tolist()})
            records.append({'xy':[int(x),int(y)],'pieces':pieces})
        ties[metric] = records
        remaining[metric] -= len(records)
    gate.last_masks = dict(original,**{field:original[field] & ~legal for field in FIELDS.values()})
    return remaining, ties
