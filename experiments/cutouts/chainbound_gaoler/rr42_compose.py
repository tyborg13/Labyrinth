"""Compose unchanged director-native frames with explicit retained provenance."""
import argparse
from pathlib import Path
from rr42_retained import verify,current
from humanoid_cutout.proof import compose


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('mode',choices=('current','sheets','review','idle'))
    p.add_argument('--case',required=True,type=Path);p.add_argument('--capture',required=True,type=Path)
    p.add_argument('--output',type=Path);p.add_argument('--diagnostic',action='store_true')
    a=p.parse_args()
    if a.mode=='current':
        valid=current(a.case,a.capture)
        print('RR42 NATIVE PROVENANCE: '+('CURRENT OR VERIFIED RETAINED' if valid else 'RECAPTURE REQUIRED'))
        raise SystemExit(not valid)
    if a.output is None:p.error('--output is required for composition')
    result=compose(a.case,a.capture,a.output,a.mode,diagnostic=a.diagnostic,retained_binding_validator=verify)
    raise SystemExit(not result['ok'])
