"""Validate immutable native evidence independently of the edited worktree."""
from cutout_pipeline.cases import read_json,digest
from humanoid_cutout.native_frames import frame_digest


def verify(root,capture):
    case=root/'production_case';saved=read_json(root/'capture_binding.json');manifest=read_json(capture/'frames.json')
    if saved['manifest_sha256']!=digest(capture/'frames.json') or saved['inputs']!=manifest['inputs']:raise ValueError('Changed archive manifest')
    for key,expected in saved['inputs'].items():
        if digest(root/'bound'/key.replace(':','/'))!=expected:raise ValueError('Changed frozen binding: '+key)
        if ':' not in key and digest(case/key)!=expected:raise ValueError('Changed frozen case: '+key)
    for kind in ('frames','pieces','joint_seams','rest_holes','pairs'):
        for row in manifest.get(kind,[]):
            if frame_digest(capture/row['file'])!=row['sha256']:raise ValueError('Changed native pixels: '+row['file'])
    return case,manifest
