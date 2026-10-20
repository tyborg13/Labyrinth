#!/usr/bin/env python3
"""Compose verified native 60fps pairs with the director's exact repeat plan."""
import argparse
from pathlib import Path
import subprocess
import sys
from PIL import Image
from cutout_pipeline.cases import read_json, write_json, digest
from maquette_motion.gates import native_errors
from maquette_cutout_polish import gate as pixel_gate
from maquette_motion import certificates
from humanoid_cutout.native_frames import load_frame
FPS = 60
SIZE = (1920,1080)
DEATH_HOLD_FRAMES = FPS
ENCODER_THREADS = 2
ENCODER_CRF = 16
ENCODER_PRESET = "medium"

def plan(compiled, authored_order=None):
    # JSON canonicalization sorts dictionary keys; playback order comes from
    # the protected director file, with idle/move first and death last.
    middle=[clip for clip in (authored_order or compiled['clips']) if clip not in ('idle','move','death')]
    order=['idle','move',*middle,'death']
    return [(clip,3 if clip in ('idle','move') else 1 if clip=='death' else 2) for clip in order if clip in compiled['clips']]

def compose(case, capture, output):
    errors=native_errors(case,capture)
    if errors:raise ValueError('Native verification failed: '+str(errors[:10]))
    pixel_report=pixel_gate(case,capture/'pixel_samples.json',capture)
    if pixel_report['ok']:
        certificates.save(case, pixel_report)
    write_json(capture/'pixel_gates.json',pixel_report)
    if not pixel_report['ok']:raise ValueError('Pixel/feature verification failed: '+str(pixel_report['errors'][:10]))
    compiled=read_json(case/'compiled_motion.json')
    authored_order=list(read_json(case/'director_motion.json')[compiled['creature']]['clips'])
    review_plan=plan(compiled,authored_order)
    output.parent.mkdir(parents=True,exist_ok=True)
    command=['ffmpeg','-v','error','-y','-f','rawvideo','-pix_fmt','rgb24','-s','1920x1080','-r',str(FPS),'-i','-',
             '-threads',str(ENCODER_THREADS),'-c:v','libx264','-crf',str(ENCODER_CRF),'-preset',ENCODER_PRESET,'-pix_fmt','yuv420p',str(output)]
    process=subprocess.Popen(command,stdin=subprocess.PIPE)
    total=0
    try:
        for clip,loops in review_plan:
            count=round(compiled['clips'][clip]['seconds']*FPS)
            sequence=list(range(count))*loops+([count-1]*DEATH_HOLD_FRAMES if clip=='death' else [])
            for frame in sequence:
                image=load_frame(capture/f'pair_{clip}/frame_{frame:04d}.png').convert('RGB')
                if image.size!=SIZE:raise ValueError('Native pair must be 1920x1080')
                process.stdin.write(image.tobytes());total+=1
    finally:
        process.stdin.close()
    if process.wait():raise ValueError('ffmpeg failed')
    write_json(output.with_suffix('.json'),{'ok':True,'fps':FPS,'frames':total,'seconds':total/FPS,'plan':review_plan,
        'death_hold_seconds':1,'capture':str(capture),'native_manifest_sha256':digest(capture/'frames.json'),'video_sha256':digest(output)})
    print(f'MAQUETTE REVIEW: PASS ({total} frames, {total/FPS:g}s at 60fps): {output}')

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--case',type=Path,required=True);p.add_argument('--capture',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--render',action='store_true');p.add_argument('--task-id',default='rr-05');a=p.parse_args()
    if a.render:
        a.capture.mkdir(parents=True,exist_ok=True)
        subprocess.run([sys.executable,'tools/godot_task_runner.py','--task-id',a.task_id,'--stream','--','godot','--headless','--path','.','--script','tests/maquette_cutout/pixel_samples.gd','--','--case',str(a.case.resolve()),'--output',str((a.capture/'pixel_samples.json').resolve())],check=True)
        subprocess.run([sys.executable,'tools/visual_probe_runner.py','--task-id',a.task_id,'--no-headless','--display-driver','macos','--audio-driver','Dummy','--timeout','900','--expect-size','1920x1080','--proof-contract','tests/maquette_cutout/'+read_json(a.case/'compiled_motion.json')['creature']+'_render_contract.json','tests/maquette_cutout/native_capture.gd','--','--case',str(a.case.resolve()),'--output',str(a.capture.resolve())],check=True)
    compose(a.case,a.capture,a.output)
if __name__=='__main__':main()
