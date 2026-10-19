"""Remove Thrall guards in memory; require assertions, never launch failures."""
import inspect
import io
import sys
import textwrap
import unittest
from unittest.mock import patch

from rr24_build import PROJECT,RECIPE,write_json
sys.path.insert(0,str(PROJECT))
import rr24_check
import rr24_seams
from tests import test_rr24_thrall as regressions
from tests import test_rr24_policies as policies


def main():
    source_mutations=[
        ('collar_attachment',"errors.append('collar must remain rigid torso')",'test_reassigning_collar_to_head_is_caught'),
        ('skirt_depth',"errors.append('skirt must cover both thighs')",'test_reversing_skirt_depth_is_caught_in_both_views'),
        ('cloth_chain',"errors.append('skirt chain differs')",'test_cloth_chain_and_motion_cannot_be_silently_changed'),
        ('own_skin',"errors.append('hidden fill must use own skin: '+part['name'])",'test_foreign_hidden_thigh_fill_is_rejected')]
    cases=[(name,rr24_check.source_errors,rr24_check,'source_errors',old,'pass',regressions,
            'ThrallOwnerFixTests.'+test) for name,old,test in source_mutations]
    cases += [
        ('hem_limit',rr24_check.hem_report,regressions,'hem_report','maximum <= 4 + FLOAT_TOLERANCE_PX','True',regressions,
         'ThrallOwnerFixTests.test_hem_limit_settling_and_excessive_follow_through_mutation'),
        ('head_ownership',rr24_seams.head_ownership,rr24_check,'head_ownership','covered = contact & (owned != 1)',
         'covered = np.zeros_like(contact)',regressions,'ThrallOwnerFixTests.test_contact_allowed_but_reversed_head_ownership_is_caught'),
        ('paint_or_tuck',rr24_seams.SkirtAirPolicy.classify,rr24_seams.SkirtAirPolicy,'classify','blocked[indices[painted]] = True',
         'blocked[indices[painted]] = False',policies,'ThrallAirTests.test_holes_through_cloth_skin_and_joint_fail'),
        ('native_paint_or_tuck',rr24_seams.SkirtAirPolicy.classify,rr24_seams.SkirtAirPolicy,'classify','blocked |= painted',
         'blocked |= False',policies,'ThrallAirTests.test_native_mask_path_rejects_painted_holes'),
        ('air_scope',rr24_seams.SkirtAirPolicy.report,rr24_seams.SkirtAirPolicy,'report',
         "eligible = (bool(surrounding & self.skirt) and bool(surrounding & self.legs)\n                    and surrounding <= self.skirt | self.legs)",
         'eligible = True',policies,'ThrallAirTests.test_policy_does_not_allow_torso_belt_air')]
    records=[]
    for name,original,owner,attribute,old,new,module,test in cases:
        source=textwrap.dedent(inspect.getsource(original))
        if source.count(old)!=1:raise ValueError('Mutation target differs: '+name)
        namespace=dict(original.__globals__)
        exec(compile(source.replace(old,new),'<rr24-mutation-'+name+'>','exec'),namespace)
        suite=unittest.defaultTestLoader.loadTestsFromName(test,module)
        # source_errors is imported by the regression module; patch that
        # reference as well as the production namespace, without editing files.
        target=regressions if attribute=='source_errors' else owner
        with patch.object(target,attribute,namespace[original.__name__]):
            result=unittest.TextTestRunner(stream=io.StringIO()).run(suite)
        caught=bool(result.failures) and not result.errors
        records.append({'guard':name,'caught_by_assertion':caught,'errors':len(result.errors),
                        'failures':len(result.failures),'restored':'in-memory patch only'})
        print('RR24 MUTATION '+name+': '+('CAUGHT' if caught else 'FAIL'))
    write_json(RECIPE/'mutations.json',{'ok':all(r['caught_by_assertion']for r in records),'mutations':records})
    return int(not all(r['caught_by_assertion']for r in records))


if __name__=='__main__':raise SystemExit(main())
