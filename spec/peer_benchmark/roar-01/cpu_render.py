#!/usr/bin/env python3
"""CPU diagnostic of existing source paint, calibrated by seam_check.py.

Uses the repository's native-format skin positions, nearest-UV ties and fixed
subpixel triangle raster. This is iteration evidence, never native approval.
"""
from __future__ import annotations
import argparse
import copy
import hashlib
import json
import sys
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tools'))
import humanoid_cutout.cpu_pose as skin_raster
from humanoid_cutout.cpu_pose import mesh_map
from humanoid_cutout.gates import matrix
from maquette_motion.raster import nearest_quad
from seam_check import IDS

# Conservative nearest-UV ambiguity interval. Raster-edge flag coverage is
# calibrated separately; this diagnostic does not claim RGBA pixel parity.
UV_TIE_EPSILON = 1 / 128
SAMPLER_VARIANTS = 5
INTERVAL_VARIANTS = 2
skin_raster.SUBTEXEL_TIE_EPSILON = UV_TIE_EPSILON
SIZE = 512

def mirror(array):
    # Renderer places the reflected rig at x=383, not x=384. Reflect pixel
    # centers about that same source-canvas origin, leaving the last column air.
    value = np.zeros_like(array)
    value[:, :-1] = array[:, -2::-1]
    return value

OFFSET = 128


class Renderer:
    def __init__(self, dragon):
        self.base = ROOT / 'assets/units' / (dragon + '_cutout')
        self.layout = json.loads((self.base / 'front.json').read_text())
        self.images = {}
        self.meshes = self.layout.get('joint_meshes', [])
        replaced = {m['replaces_part'] for m in self.meshes}
        self.parts = {p['name']: p for p in self.layout['parts'] if p['name'] not in replaced}

    def image(self, path):
        if path not in self.images:
            self.images[path] = np.asarray(Image.open(self.base / path).convert('RGBA'))
        return self.images[path]

    def layers(self, pose, ties=False):
        result = []
        for z, name, values in self._layers(pose, UV_TIE_EPSILON):
            # Independent nearest-UV ties may choose different neighbours at
            # different fragments. Include both interval extremes alongside
            # every actual sampler; neither extreme replaces those samplers.
            result.append((z, name, np.concatenate((values, values.min(axis=0)[None], values.max(axis=0)[None]))))
        return result

    def _layers(self, pose, epsilon):
        skin_raster.SUBTEXEL_TIE_EPSILON = epsilon
        result = []
        for sprite in pose['sprites']:
            part = self.parts[sprite['name']]
            paint = self.image(part['file'])
            transform = matrix(sprite['transform'])
            transform[:2, 2] += OFFSET
            # Rasterize encoded source coordinates to retain real nearest-UV
            # choices. Global min-alpha masks can open a real enclosed hole and
            # must never be used to decide the native thin-hole count.
            yy, xx = np.indices(paint.shape[:2], dtype=np.uint16)
            encoded = np.stack(((xx+1) & 255, (xx+1) >> 8, (yy+1) & 255, (yy+1) >> 8), axis=-1).astype(np.uint8)
            mapping = nearest_quad(encoded, transform, (0, 0, SIZE, SIZE), with_ties=True, tie_epsilon=epsilon)
            uv = []
            for values in (mapping.default, mapping.alternative):
                value = values.astype(np.int32)
                uv.append(np.stack((value[...,0]+256*value[...,1]-1, value[...,2]+256*value[...,3]-1),axis=-1))
            low = np.minimum(*uv); high = np.maximum(*uv)
            variants = [uv[0], low, np.stack((high[...,0],low[...,1]),axis=-1), np.stack((low[...,0],high[...,1]),axis=-1), high]
            valid = (uv[0][...,0] >= 0) & (uv[0][...,1] >= 0)
            rasters = []
            for xy in variants:
                u=np.clip(xy[...,0],0,paint.shape[1]-1);v=np.clip(xy[...,1],0,paint.shape[0]-1)
                rasters.append(np.where(valid,paint[v,u,3],0).astype(np.uint8))
            result.append((sprite['z_index'], part['name'], np.stack(rasters)))
        for mesh in self.meshes:
            mappings=[mesh_map(self.layout,pose,mesh,with_ties=True,native_skin=True,triangle_batch_size=2048)]
            paint=self.image(mesh['file']);rasters=[]
            for mapping in mappings:
                low=np.minimum(mapping.texels,mapping.alternatives[-1]);high=np.maximum(mapping.texels,mapping.alternatives[-1])
                variants=[mapping.texels,low,np.column_stack((high[:,0],low[:,1])),np.column_stack((low[:,0],high[:,1])),high]
                xs,ys=mapping.pixels.T
                for uv in variants:
                    u=np.clip(uv[:,0],0,paint.shape[1]-1);v=np.clip(uv[:,1],0,paint.shape[0]-1)
                    transmission=np.ones((SIZE,SIZE),float)
                    np.multiply.at(transmission,(ys,xs),1.0-paint[v,u,3].astype(float)/255.0)
                    rasters.append(np.rint((1.0-transmission)*255).astype(np.uint8))
            result.append((int(mesh.get('z_index',3)),mesh['replaces_part'],np.stack(rasters)))
        return sorted(result,key=lambda a:a[0])

    def render(self, pose, ties=False):
        images = np.zeros((SAMPLER_VARIANTS+INTERVAL_VARIANTS,SIZE,SIZE),float)
        layers = {}
        self.part_variants = {}
        for _z,name,variants in self.layers(pose,ties):
            value=variants.astype(float)/255.0
            images=value+images*(1.0-value)
            layers[name]=variants[-1]
            self.part_variants[name]=variants
        self.variants=np.rint(images*255).astype(np.uint8)
        self.lower=self.variants.min(axis=0)
        self.upper=self.variants.max(axis=0)
        return self.variants[-1],self.upper,layers

    def attachment(self, pose, rest):
        # Witness only paint at the existing body/tail join. This catches open
        # seams, which are outside the enclosed-thin-hole metric by definition.
        tail_bone = next((n for n in ('tail_base', 'tail') if n in self.layout['joints']), None)
        body_bone = 'torso' if 'torso' in self.layout['joints'] else 'body'
        if tail_bone is None: return np.zeros((SIZE, SIZE), bool)
        joint = self.layout['joints']
        body = matrix(pose['bones'][body_bone]['global'])
        bind = np.asarray(joint[tail_bone]['position']) - np.asarray(joint[body_bone]['position'])
        desired = (body @ np.r_[bind, 1])[:2]
        actual = matrix(pose['bones'][tail_bone]['global'])[:2, 2]
        delta = desired - actual
        ideal = copy.deepcopy(pose)
        def descendant(name):
            while name is not None:
                if name == tail_bone: return True
                name = joint[name]['parent']
            return False
        for name in ideal['bones']:
            if descendant(name):
                ideal['bones'][name]['global'][4] += float(delta[0])
                ideal['bones'][name]['global'][5] += float(delta[1])
        for sprite in ideal['sprites']:
            part = self.parts[sprite['name']]
            if descendant(part['bone']):
                sprite['transform'][4] += float(delta[0])
                sprite['transform'][5] += float(delta[1])
        layers = {name: variants.min(axis=0) for _z, name, variants in self.layers(ideal, ties=True)}
        body_part = 'torso' if 'torso' in rest else 'body'
        if body_part not in rest or 'tail' not in rest or 'tail' not in layers:
            return np.zeros((SIZE, SIZE), bool)
        from PIL import ImageFilter
        body_mask = Image.fromarray((rest[body_part] > 16).astype(np.uint8) * 255)
        join = (np.asarray(body_mask.filter(ImageFilter.MaxFilter(5))) > 0) & (rest['tail'] > 16)
        # Transport the neutral join domain with the body, in the fixed canvas.
        transform = body.copy()
        origin = np.asarray(joint[body_bone]['position']) + OFFSET
        transform[:2, 2] += OFFSET - transform[:2, :2] @ origin
        canvas = np.full((SIZE, SIZE, 4), 255, np.uint8)
        canvas[..., 3] = join.astype(np.uint8) * 255
        domain = nearest_quad(canvas, transform, (0, 0, SIZE, SIZE))[..., 3] > 0
        return domain & (layers['tail'] > 16)


def save_alpha(alpha, path):
    rgba = np.full((*alpha.shape, 4), 255, np.uint8)
    rgba[..., 3] = alpha
    Image.fromarray(rgba).save(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--poses', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--ties', action='store_true', help='Record conservative nearest-UV calibration; sampler bounds are always active')
    args = parser.parse_args()
    poses = json.loads(args.poses.read_text())
    manifest = []
    for dragon in IDS:
        renderer = Renderer(dragon)
        folder = args.output / dragon
        folder.mkdir(parents=True, exist_ok=True)
        samples = [p for p in poses['records'] if p['dragon'] == dragon]
        _low, _high, rest_layers = renderer.render(samples[0], args.ties)
        roar_index = 0
        for pose in samples:
            alpha, upper, layers = renderer.render(pose, args.ties)
            variants = renderer.variants.copy()
            lower = renderer.lower.copy()
            part_variants = dict(renderer.part_variants)
            attachment = renderer.attachment(pose, rest_layers)
            label = f'{roar_index:02d}_{str(pose["phase"]).replace(".", "p")}' if pose['clip'] == 'roar' else 'baseline_' + pose['clip'] + '_' + str(pose['phase']).replace('.', 'p')
            if pose['clip'] == 'roar': roar_index += 1
            for view in ('front', 'mirrored_front'):
                value = alpha if view == 'front' else mirror(alpha)
                path = folder / (view + '_' + label + '.png')
                save_alpha(value, path)
                manifest.append({'dragon': dragon, 'clip': pose['clip'], 'phase': pose['phase'], 'view': view, 'file': str(path)})
            # Separate painted-part alpha fields allow the topology gate to
            # distinguish a tear inside one part from a gap between parts.
            np.savez_compressed(folder / ('parts_' + label + '.npz'), **part_variants)
            np.savez_compressed(folder / ('bounds_' + label + '.npz'), lower=lower, upper=upper, variants=variants, attachment=attachment)
        print('CPU RENDER', dragon, len(samples), 'poses', flush=True)
    (args.output / 'frames.json').write_text(json.dumps({'records': manifest, 'poses': str(args.poses), 'ties': args.ties, 'sources': poses.get('sources', {}), 'cpu_sources': {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in (Path(__file__), Path(__file__).with_name('cpu_check.py'), Path(__file__).with_name('seam_check.py'))}}, indent=2) + '\n')
    print('ROAR CPU RENDER: PASS (diagnostic only)', args.output)

if __name__ == '__main__': main()
