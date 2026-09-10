"""Retain native RunScene proof and encode its recorded wall-clock timing."""
from pathlib import Path
import argparse,json,shutil,subprocess,hashlib
from fractions import Fraction
p=argparse.ArgumentParser();p.add_argument('--input',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--runner-result',type=Path,required=True);a=p.parse_args()
assert not a.output.exists(),'Choose a fresh proof output'
manifest=json.loads((a.input/'manifest.json').read_text());assert manifest['ok'],manifest['errors']
shutil.copytree(a.input,a.output);shutil.copy2(a.runner_result,a.output/'visual_probe_result.json')
video_root=a.output/'videos';video_root.mkdir();reports=[]
for clip in manifest['clips']:
 folder=a.output/clip['label'];samples=clip['samples'];frames=sorted(folder.glob('frame_*.jpg'));assert len(frames)==len(samples) and frames
 times=[s['seconds'] for s in samples];assert all(y>x for x,y in zip(times,times[1:])),times
 durations=[times[i+1]-times[i] for i in range(len(times)-1)];durations.append(durations[-1] if durations else 1/30)
 duration=sum(durations);concat=folder/'frames.ffconcat'
 concat.write_text('ffconcat version 1.0\n'+''.join("file '%s'\nduration %.9f\n"%(f.name,d) for f,d in zip(frames,durations))+"file '%s'\n"%frames[-1].name)
 video=video_root/(clip['label']+'.mp4')
 subprocess.run(['ffmpeg','-v','error','-y','-f','concat','-safe','0','-i',str(concat),'-t',str(duration),'-an','-vf','fps=60','-c:v','libx264','-preset','fast','-crf','20','-pix_fmt','yuv420p','-movflags','+faststart',str(video)],check=True)
 meta=json.loads(subprocess.check_output(['ffprobe','-v','error','-select_streams','v:0','-count_frames','-show_entries','stream=nb_read_frames,avg_frame_rate,width,height','-of','json',str(video)],text=True))['streams'][0]
 encoded=int(meta['nb_read_frames'])/float(Fraction(meta['avg_frame_rate']));assert abs(duration-encoded)<=1/60+1e-6,(clip['label'],duration,encoded)
 reports.append({'file':str(video.relative_to(a.output)),'source_frames':len(frames),'captured_seconds':duration,'encoded_seconds':encoded,'error_seconds':encoded-duration})
concat=video_root/'clips.ffconcat';concat.write_text('ffconcat version 1.0\n'+''.join("file '%s'\n"%Path(r['file']).name for r in reports))
reel=video_root/'gaoler_gameplay_review.mp4'
subprocess.run(['ffmpeg','-v','error','-y','-f','concat','-safe','0','-i',str(concat),'-c','copy','-movflags','+faststart',str(reel)],check=True)
subprocess.run(['ffmpeg','-v','error','-i',str(reel),'-f','null','-'],check=True)
(video_root/'encoding.json').write_text(json.dumps({'clips':reports,'reel':str(reel.relative_to(a.output)),'timing':'Actual captured monotonic sample intervals, held at 60fps without synthesizing poses; at most one-frame duration rounding','full_decode':'PASS'},indent=2)+'\n')
(a.output/'proof_sha256.json').write_text(json.dumps({str(f.relative_to(a.output)):hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(a.output.rglob('*')) if f.is_file()},indent=2)+'\n')
print(json.dumps({'ok':True,'clips':len(reports),'reel':str(reel)},indent=2))
