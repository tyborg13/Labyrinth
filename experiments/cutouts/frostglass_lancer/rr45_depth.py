"""mq-14 depth oracle for the Lancer's depth-locked 2D cutout.

The animation changes projected transforms, not camera depth. Use the native
maquette's camera and mounted armour surfaces, not sprite z or screen-side
heuristics. Cloth depth follows the nearest registered vertex of its measured
3D panel; the painted silhouette supplies coverage, never depth. The shaft's
3D line is registered at its painted grip and floor end (including rear v2).
This is a cutout depth contract, not a new animated 3D maquette simulation.
"""
import numpy as np
from PIL import Image
from rr37_case import PROJECT, CASE
from cutout_pipeline.cases import read_json
from maquette_cutout import camera_view, projected
from spec.art_identity.maquettes.blender.ownership import cloak_owners

DEPTH_UNITS_PER_METRE = 100000  # Diagnostic encoding precision, 10 micrometres.
DEPTH_EPSILON_M = 1 / DEPTH_UNITS_PER_METRE
NEAREST_BATCH_PIXELS = 2048  # Bound diagnostic memory only.
OCCLUDERS = ('hand_far', 'arm_far', 'torso', 'cape_near', 'cape_far')
SURFACE_MOUNTS = {'hand_far': 'gauntlet_far', 'arm_far': 'vambrace_far', 'torso': 'breastplate'}


class DepthOracle:
    def __init__(self, layout):
        self.layout, self.view = layout, layout['facing']
        self.spec = read_json(PROJECT/'spec/art_identity/maquettes/frostglass_lancer/measurements.json')
        self.registration = read_json(CASE/f'{self.view}_baseline/registered/{self.view}_registration.json')
        matrix, target, azimuth, elevation, _, distance = camera_view(self.spec, self.view)
        self.matrix, self.target, self.distance = matrix, target, distance
        self.axis = np.array([np.cos(elevation)*np.cos(azimuth),
            np.cos(elevation)*np.sin(azimuth), np.sin(elevation)])
        yy, xx = np.indices((255, 255))
        self.xy = np.stack((xx+.5, yy+.5), axis=-1)
        grip = np.asarray(layout['held_items']['spear']['source_grip'])
        floor = np.asarray(layout['held_items']['spear']['floor_end'])
        shaft = self.piece('spear_shaft')
        hand = np.asarray(self.spec['joints']['hand_far'])
        along = ((self.xy-grip) @ (floor-grip)) / np.dot(floor-grip, floor-grip)
        self.shaft = self.depth(hand + along[..., None]*(np.asarray(shaft['path'][0])-hand))
        self.surfaces = {}
        self.mounts = {}
        for name, mount in SURFACE_MOUNTS.items():
            piece = self.piece(mount)
            point = np.asarray(self.spec['joints'][piece['at']]) + piece['offset']
            self.surfaces[name] = np.full((255,255), self.depth(point))
            self.mounts[name] = {'piece':mount, 'point_3d':point.tolist(), 'camera_depth_m':float(self.depth(point))}
        self.cloth()
        self.encoded_surfaces = {name:self.encode(depth,np.ones((255,255),bool))
            for name,depth in self.surfaces.items()}
        self._shaft_sources = {}

    def piece(self, name):
        return next(p for p in self.spec['pieces'] if p['id'] == name)

    def depth(self, points):
        points = np.asarray(points)
        world = points @ self.matrix[:3,:3].T + self.matrix[:3,3]
        return self.distance - (world-self.target) @ self.axis

    def cloth(self):
        points = np.array([p for row in self.piece('cloak')['pattern']['rows'] for p in row['points']])
        joints = self.spec['joints']
        owners = np.array(cloak_owners(points,
            (np.asarray(joints['shoulder_near'])+joints['shoulder_far'])/2,
            [1,0,0], [0,0,1], joints['shoulder_near'], joints['shoulder_far']))
        scale, offset = np.array(self.registration['scale']), np.array(self.registration['offset'])
        for name in ('cape_near','cape_far'):
            selected = points[owners == name]
            screen = np.array([projected(self.spec,p,self.view) for p in selected])*scale+offset
            depth = self.depth(selected)
            nearest = []
            flat = self.xy.reshape(-1,2)
            for start in range(0,len(flat),NEAREST_BATCH_PIXELS):
                distances = ((flat[start:start+NEAREST_BATCH_PIXELS,None]-screen)**2).sum(-1)
                nearest.extend(depth[distances.argmin(axis=1)])
            self.surfaces[name] = np.asarray(nearest).reshape(255,255)

    def encode(self, values, alpha):
        number = np.rint(values*DEPTH_UNITS_PER_METRE).astype(np.uint32)
        image = np.zeros((*values.shape,4),np.uint8)
        for channel, shift in enumerate((16,8,0)): image[...,channel] = (number>>shift)&255
        image[...,3] = np.where(alpha,255,0)
        return image

    @staticmethod
    def decode(image):
        image = image.astype(np.uint32)
        return ((image[...,0]<<16)|(image[...,1]<<8)|image[...,2])/DEPTH_UNITS_PER_METRE

    def shaft_source(self, case):
        # The existing certified feature mask excludes the crystal, without
        # inventing a new paint boundary or editing any texture.
        if case in self._shaft_sources: return self._shaft_sources[case]
        feature = next(f for f in self.layout['features'] if f['name']=='crystal_spearhead')
        crystal = np.asarray(Image.open(case/feature['mask'])) > 0
        self._shaft_sources[case] = self.encode(self.shaft, ~crystal)
        return self._shaft_sources[case]
