"""Register missing receiver UVs from the calibrated native archive, not witnesses."""
import numpy as np
from rr52_build import CASE
from rr52_surface import SurfacePolicy
from cutout_pipeline.cases import read_json,write_json,digest
from humanoid_cutout.canvas import for_case
from humanoid_cutout.cpu_pose import CpuPose
from humanoid_cutout.native_frames import load_frame


def run():
    proof=CASE/'proof';baseline=proof/'feedback2_before/production_case';capture=proof/'native';manifest=read_json(capture/'frames.json');calibration=read_json(proof/'feedback2_calibration.json')
    selected={(r['view'],r['clip'],r['frame']) for r in calibration['native_records']}
    poses={(r['view'],r['clip'],r['frame']):r for r in read_json(baseline/'proof/raster_samples.json')['samples']};requests=[]
    with for_case(baseline):
        for view in ('front','rear'):
            model=CpuPose(baseline,read_json(baseline/f'layouts/{view}.json'),native_skin=True,triangle_batch_size=128);policy=SurfacePolicy(model)
            for frame in manifest['frames']:
                key=(frame['view'],frame['clip'],frame['frame'])
                if key[0]!=view or key not in selected:continue
                image=np.asarray(load_frame(capture/frame['file']).convert('RGBA'));policy.space(image[...,3]>0,poses[key])
            requests+=list(policy.cap_requests.values())
    result={'cap_requests':requests,'native_pixels':True,'native_manifest_sha256':digest(capture/'frames.json'),'calibration_sha256':digest(proof/'feedback2_calibration.json'),'rule':'Only missing opaque director-underlay source UVs measured through each actual receiving skin/rigid inverse, at native hole pixels; no natural air requests.'}
    write_json(proof/'feedback2_native_cap_requests.json',result)
    print(f'RR52 NATIVE CAP REQUESTS: {len(requests)} exact opaque-underlay UVs')
    return result

if __name__=='__main__':run()
