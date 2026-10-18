"""Stateless, portable value noise for repeatable native displacement weights.

Explicit vertex weights remove procedural texture state from the build inputs
while retaining an editable native Displace modifier and subdivided geometry.
"""
import math

RELIEF_DEFAULTS = {'corner_hash': (73856093,19349663,83492791),
                   'hash_mask': 0xffffffff, 'octave_frequency': 2,
                   'octave_amplitude': .5}


def lattice(x,y,z):
    a,b,c=RELIEF_DEFAULTS['corner_hash']
    value=((x*a)^(y*b)^(z*c))&RELIEF_DEFAULTS['hash_mask']
    value=(value^(value>>13))*1274126177&RELIEF_DEFAULTS['hash_mask']
    return value/RELIEF_DEFAULTS['hash_mask']


def value_noise(point):
    cell=[math.floor(v) for v in point]
    fraction=[v-c for v,c in zip(point,cell)]
    weights=[v*v*(3-2*v) for v in fraction]
    result=0.
    for x in (0,1):
        for y in (0,1):
            for z in (0,1):
                weight=1.
                for corner,w in zip((x,y,z),weights):weight*=w if corner else 1-w
                result+=weight*lattice(cell[0]+x,cell[1]+y,cell[2]+z)
    return result


def relief_weight(point,scale,depth):
    result,total,amplitude,frequency=0.,0.,1.,1.
    for octave in range(depth+1):
        result+=amplitude*value_noise([v*frequency/scale for v in point])
        total+=amplitude
        amplitude*=RELIEF_DEFAULTS['octave_amplitude'];frequency*=RELIEF_DEFAULTS['octave_frequency']
    return result/total
