"""Retain a completed task-safe probe and optionally encode real gameplay time."""
from pathlib import Path
import argparse, hashlib, json, shutil, subprocess
from compact_gameplay import compact

p=argparse.ArgumentParser()
p.add_argument('runner',type=Path)
p.add_argument('output',type=Path)
p.add_argument('--inputs',type=Path)
p.add_argument('--gameplay',action='store_true')
a=p.parse_args()
r=json.loads(a.runner.read_text())
if not r.get('ok'): raise SystemExit('Refusing failed native proof')
if a.output.exists(): raise SystemExit('Choose a fresh output')
if a.inputs:
 project=Path(__file__).resolve().parents[3]
 roots={'project':project,'case':project/'experiments/cutouts/vaeloryx/v01'}
 for key,digest in json.loads(a.inputs.read_text()).items():
  scope,relative=key.split(':',1)
  path=roots[scope]/relative
  if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest()!=digest:
   raise SystemExit('Capture input changed: '+key)
images=r['images']
raw=Path(images[0]['path']).parent
while not (raw/'manifest.json').exists() and not (raw/'comparison.json').exists():
 if raw==raw.parent: raise SystemExit('Native output manifest not found')
 raw=raw.parent
shutil.copytree(raw,a.output)
shutil.copyfile(a.runner,a.output/'native_runner.json')
if a.inputs: shutil.copyfile(a.inputs,a.output/'capture_input_sha256.json')
if a.gameplay:
 m=json.loads((a.output/'manifest.json').read_text())
 videos=a.output/'videos';videos.mkdir()
 reports=[]
 for clip in m['clips']:
  samples=clip['samples'];folder=a.output/clip['label']
  source=sum((samples[i+1]['seconds']-s['seconds']) if i+1<len(samples) else 1/30 for i,s in enumerate(samples))
  listing=folder/'playback.ffconcat'
  listing.write_text('ffconcat version 1.0\n'+''.join("file 'frame_%04d.jpg'\nduration %.9f\n"%(i,(samples[i+1]['seconds']-s['seconds']) if i+1<len(samples) else 1/30) for i,s in enumerate(samples)))
  video=videos/(clip['label']+'.mp4')
  subprocess.run(['ffmpeg','-v','error','-y','-f','concat','-safe','0','-i',str(listing),'-an','-vf','fps=60','-c:v','libx264','-preset','fast','-crf','20','-pix_fmt','yuv420p','-movflags','+faststart',str(video)],check=True)
  info=json.loads(subprocess.check_output(['ffprobe','-v','error','-count_frames','-select_streams','v:0','-show_entries','stream=nb_read_frames,avg_frame_rate,width,height','-of','json',str(video)]))['streams'][0]
  duration=int(info['nb_read_frames'])/60
  if abs(duration-source)>0.06: raise SystemExit('Gameplay playback duration mismatch: '+clip['label'])
  reports.append({'clip':clip['label'],'wall_seconds':source,'encoded_seconds':duration,'encoded_frames':int(info['nb_read_frames'])})
 concat=videos/'clips.ffconcat'
 concat.write_text('ffconcat version 1.0\n'+''.join("file '%s.mp4'\n"%c['label'] for c in m['clips']))
 subprocess.run(['ffmpeg','-v','error','-y','-f','concat','-safe','0','-i',str(concat),'-c','copy','-movflags','+faststart',str(videos/'gameplay_review.mp4')],check=True)
 subprocess.run(['ffmpeg','-v','error','-i',str(videos/'gameplay_review.mp4'),'-f','null','-'],check=True)
 (videos/'encoding.json').write_text(json.dumps({'clips':reports,'full_decode':'PASS','timing':'Captured monotonic wall-clock intervals; repeated source frames, no synthesized poses. ffconcat timebase rounding <=0.06 seconds per clip.'},indent=2)+'\n')
 compact(a.output,raw)
(a.output/'proof_sha256.json').write_text(json.dumps({str(f.relative_to(a.output)):hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(a.output.rglob('*')) if f.is_file() and f.name!='proof_sha256.json'},indent=2)+'\n')
print(a.output)
