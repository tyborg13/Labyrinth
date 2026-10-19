"""Disable one acceptance guard in memory; require its regression to fail."""
from pathlib import Path
import inspect
import io
import sys
import unittest
from unittest.mock import patch
from rr18_case import PROJECT, CASE
sys.path.insert(0,str(PROJECT))
from tests import test_rr18_humanoid as tests
from cutout_pipeline.cases import write_json

MUTATIONS = (
    ('production rest identity', 'production_rest_report', 'if mismatch else []',
     'if False else []', 'test_mutation_production_treatment_cannot_hide_rest_mismatch'),
    ('idle rigidity', 'bone_errors', 'if not np.allclose(transform[:2, :2], np.eye(2), atol=EPSILON, rtol=0):',
     'if False:', 'test_mutation_idle_rotation_is_caught'),
    ('rest RGBA', 'source_errors', 'if not np.array_equal(np.asarray(rest),approved):',
     'if False:', 'test_mutation_visible_source_rgba_is_caught'),
    ('required direction coverage', 'direction_report', 'for clip in required_clips(layout):',
     'for clip in []:', 'test_mutation_zero_forward_loses_required_coverage'),
    ('every swing minimum', 'knee_report', "if record['peak_bend_deg']+EPSILON < 15:",
     'if False:', 'test_mutation_second_swing_no_knee_is_caught'),
    ('support stationarity', 'support_report', 'if change!=0:',
     'if False:', 'test_mutation_action_support_slide_is_caught'),
)


def main():
    records=[]
    for name,function,before,after,regression in MUTATIONS:
        original=getattr(tests,function)
        source=inspect.getsource(original)
        if before not in source: raise ValueError('Mutation guard moved: '+name)
        namespace=dict(original.__globals__)
        exec(compile(source.replace(before,after,1),inspect.getsourcefile(original),'exec'),namespace)
        mutated=namespace[original.__name__]
        output=io.StringIO()
        with patch.object(tests,function,mutated):
            result=unittest.TextTestRunner(stream=output,verbosity=2).run(unittest.TestSuite([tests.MirrorTests(regression)]))
        caught=len(result.failures)==1 and not result.errors
        records.append({'guard':name,'regression':regression,'caught':caught,'failures':len(result.failures),'errors':len(result.errors),'restored':'in-memory only; source bytes untouched'})
        print('RR18 MUTATION '+name+': '+('CAUGHT' if caught else 'FAIL'))
        if not caught: print(output.getvalue())
    write_json(CASE/'proof/mutations.json',{'ok':all(r['caught'] for r in records),'mutations':records})
    return int(not all(r['caught'] for r in records))

if __name__=='__main__': raise SystemExit(main())
