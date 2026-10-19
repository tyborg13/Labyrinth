"""Remove rr-24 guards in memory and require assertion failures, never crashes."""
import inspect
import io
import sys
import unittest
from unittest.mock import patch

from rr24_build import PROJECT, RECIPE, write_json
sys.path.insert(0,str(PROJECT))
import rr24_check
from tests import test_rr24_thrall as regressions

MUTATIONS = [
    ('collar_attachment','source_errors',"errors.append('collar must remain rigid torso')",'pass',
     'test_reassigning_collar_to_head_is_caught'),
    ('skirt_depth','source_errors',"errors.append('skirt must cover both thighs')",'pass',
     'test_reversing_skirt_depth_is_caught_in_both_views'),
    ('cloth_chain','source_errors',"errors.append('skirt chain differs')",'pass',
     'test_cloth_chain_and_motion_cannot_be_silently_changed'),
    ('collar_contact','collar_report','overlaps = int((jaw & collar).sum())','overlaps = 0',
     'test_death_contact_is_reported_and_remains_a_design_todo'),
    ('hem_limit','hem_report','maximum <= 4 + FLOAT_TOLERANCE_PX','True',
     'test_hem_limit_settling_and_excessive_follow_through_mutation'),
    ('own_skin','source_errors',"errors.append('hidden fill must use own skin: '+part['name'])",'pass',
     'test_foreign_hidden_thigh_fill_is_rejected'),
]


def main():
    records=[]
    for name,function,old,new,test in MUTATIONS:
        original=getattr(rr24_check,function)
        source=inspect.getsource(original)
        if source.count(old)!=1: raise ValueError('Mutation target differs: '+name)
        namespace=dict(rr24_check.__dict__)
        exec(compile(source.replace(old,new),'<rr24-mutation-'+name+'>','exec'),namespace)
        suite=unittest.defaultTestLoader.loadTestsFromName('ThrallOwnerFixTests.'+test,regressions)
        with patch.object(regressions,function,namespace[function]):
            result=unittest.TextTestRunner(stream=io.StringIO()).run(suite)
        caught=bool(result.failures) and not result.errors
        records.append({'guard':name,'caught_by_assertion':caught,'errors':len(result.errors),
                        'failures':len(result.failures),'restored':'in-memory patch only'})
        print('RR24 MUTATION '+name+': '+('CAUGHT' if caught else 'FAIL'))
    write_json(RECIPE/'mutations.json',{'ok':all(r['caught_by_assertion'] for r in records),'mutations':records})
    return int(not all(r['caught_by_assertion'] for r in records))


if __name__=='__main__':raise SystemExit(main())
