"""Keep frozen pre-gait art/layout records useful across the motion migration."""
import hashlib
import json
import subprocess


PRESERVATION_REVISION = '80d5ec39bfa4b79c176835a02c6137044a7de75e'

def assert_preserved(test, project, path, expected):
    current=(project/path).read_bytes()
    if hashlib.sha256(current).hexdigest()==expected:
        return
    baseline=subprocess.check_output(['git','show',PRESERVATION_REVISION+':'+path],cwd=project)
    test.assertEqual(hashlib.sha256(baseline).hexdigest(),expected,path)
    old,new=json.loads(baseline),json.loads(current)
    if path.endswith('compiled_motion.json'):
        for view in old['view_tracks']:
            for clip in old['clips']:
                if clip!='move':
                    test.assertEqual(old['view_tracks'][view][clip],new['view_tracks'][view][clip],path)
                    test.assertEqual(old['clips'][clip],new['clips'][clip],path)
    elif path.endswith('director_motion.json'):
        for creature in old:
            if not isinstance(old[creature], dict) or 'clips' not in old[creature]: continue
            for clip,definition in old[creature]['clips'].items():
                if clip!='move':test.assertEqual(definition,new[creature]['clips'][clip],path)
    elif path.endswith('anatomy.json'):
        old.pop('leg_roles',None)
        new['integration']['binding_folders'].remove('tests/gait01')
        test.assertEqual(old.pop('planted_bones'), ['foot_stride'])
        test.assertEqual(new.pop('planted_bones'), ['foot_support'])
        test.assertEqual(new.pop('channel_aliases'), {'front': {'foot_support':'foot_near','foot_trailing':'foot_far'}, 'rear': {'foot_support':'foot_far','foot_trailing':'foot_near'}})
        test.assertEqual(old,new,path)
    else:
        test.assertIn('joints',old,path)
        old.pop('leg_roles',None)
        new.pop('leg_roles',None)  # Legacy top-level layouts keep the retired field; v2 layouts drop it.
        new.pop('gait_leg_scale_max',None)
        new.pop('gait_continuations',None)  # Gait-only edge-coordinate recipes; original paint remains frozen.
        test.assertEqual(old,new,path)
