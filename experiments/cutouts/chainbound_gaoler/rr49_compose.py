"""Gaoler proof composition uses the same strict release oracle as its gates.

The generic default policy still treats the released grip as a body seam.
Passing the existing exact-source policy retires only the declared chain/fist
adjacency; all real body joints and source/component checks remain active.
"""
import argparse
from pathlib import Path
from rr42_retained import verify,current
from rr44_gates import NativeRigidSourcePolicy
from humanoid_cutout.proof import compose


def compose_native(mode,case,capture,output,*,diagnostic=False):
    return compose(case,capture,output,mode,diagnostic=diagnostic,
                   retained_binding_validator=verify,release_policy_factory=NativeRigidSourcePolicy)


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('mode',choices=('current','sheets','review','idle'))
    p.add_argument('--case',required=True,type=Path);p.add_argument('--capture',required=True,type=Path)
    p.add_argument('--output',type=Path);p.add_argument('--diagnostic',action='store_true');a=p.parse_args()
    if a.mode=='current':
        valid=current(a.case,a.capture)
        print('RR49 NATIVE PROVENANCE: '+('CURRENT OR VERIFIED RETAINED' if valid else 'RECAPTURE REQUIRED'))
        raise SystemExit(not valid)
    if a.output is None:p.error('--output is required for composition')
    raise SystemExit(not compose_native(a.mode,a.case,a.capture,a.output,diagnostic=a.diagnostic)['ok'])
