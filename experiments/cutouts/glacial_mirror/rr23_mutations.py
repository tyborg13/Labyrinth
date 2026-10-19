"""Prove the new owner-fix regressions reject disabled guards."""
import inspect
import io
import sys
import unittest
from unittest.mock import patch

from rr18_case import CASE, PROJECT
from cutout_pipeline.cases import write_json
sys.path.insert(0,str(PROJECT))
from tests import test_rr18_humanoid as preservation
from tests import test_rr23_owner_fixes as owner

MUTATIONS=(
    ('committed protection',preservation,preservation.MirrorTests,'protected_changes',
     "'--name-only', '-z', baseline, '--'", "'--name-only', '-z', '--'",
     'test_committed_protected_mutation_is_caught'),
    ('all-clip ankle attachment',owner,owner.OwnerFixTests,'ankle_report',
     'if distance > MAX_RIGID_AIR_PX + EPSILON:', 'if False:',
     'test_disconnected_non_walk_ankle_mutation_is_caught'),
    ('front guard depth',owner,owner.OwnerFixTests,'arm_report',
     "if parts[name]['z_index']<=parts[body]['z_index']:", 'if False:',
     'test_wrong_front_guard_depth_mutation_is_caught'),
    ('rest order stop',owner,owner.OwnerFixTests,'front_arm_order',
     'if mismatch:', 'if False:',
     'test_order_change_that_alters_rest_stops_with_design_placeholder'),
)


def main():
    records=[]
    for name,module,cls,function,before,after,regression in MUTATIONS:
        original=getattr(module,function)
        source=inspect.getsource(original)
        if before not in source:raise ValueError('Mutation guard moved: '+name)
        namespace=dict(original.__globals__)
        exec(compile(source.replace(before,after,1),inspect.getsourcefile(original),'exec'),namespace)
        output=io.StringIO()
        with patch.object(module,function,namespace[original.__name__]):
            result=unittest.TextTestRunner(stream=output,verbosity=2).run(unittest.TestSuite([cls(regression)]))
        caught=len(result.failures)==1 and not result.errors
        records.append({'guard':name,'regression':regression,'caught':caught,
                        'failures':len(result.failures),'errors':len(result.errors),'scope':'in-memory only'})
        print('RR23 MUTATION '+name+': '+('CAUGHT' if caught else 'FAIL'),flush=True)
        if not caught:print(output.getvalue())
    write_json(CASE/'proof/rr23_mutations.json',{'ok':all(r['caught'] for r in records),'mutations':records})
    return int(not all(r['caught'] for r in records))


if __name__=='__main__':raise SystemExit(main())
