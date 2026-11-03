"""Fail-closed director native gates; reports do not turn missing paint into a pass."""
import argparse
from pathlib import Path
from rr48_build import CASE
from humanoid_cutout.gates import native_errors
from humanoid_cutout.canvas import for_case
from cutout_pipeline.cases import write_json
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--case',type=Path,default=CASE);p.add_argument('--native',type=Path,required=True);args=p.parse_args()
surface=None
if (args.case/'feedback3_policy.json').exists():
 from rr48_feedback3_native import NativeDirectorPolicy
 surface=NativeDirectorPolicy
with for_case(args.case):errors=native_errors(args.case,args.native,surface_policy_factory=surface)
from rr48_feedback_gates import native_floor_errors
floor=native_floor_errors(args.case,args.native);errors+=floor['errors']
write_json(args.case/'proof/native_gates.json',{'ok':not errors,'errors':errors,'painted_floor':floor,'native_pixels':True})
print(f'RR48 NATIVE GATES: {"FAIL" if errors else "PASS"} ({len(errors)} errors)')
for e in errors[:30]:print(e)
raise SystemExit(int(bool(errors)))
