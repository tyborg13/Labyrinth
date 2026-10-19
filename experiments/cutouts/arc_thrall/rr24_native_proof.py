"""Use the unchanged approved composer with the Thrall native validator.

The function keeps its original bytecode and all composition/encoding values.
A private globals dictionary injects the case validator without changing the
shared module, bypassing validation, or affecting another figure.
"""
import argparse
from pathlib import Path
from types import FunctionType

from rr24_native_gates import errors
from tools.humanoid_cutout import proof

compose = FunctionType(proof.compose.__code__,dict(proof.compose.__globals__,native_errors=errors),
                       name='compose',argdefs=proof.compose.__defaults__)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode',choices=['sheets','review'])
    parser.add_argument('--case',type=Path,required=True)
    parser.add_argument('--capture',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();compose(args.case,args.capture,args.output,args.mode)
