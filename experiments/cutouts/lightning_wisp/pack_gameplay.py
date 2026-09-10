"""Encode actual native gameplay samples at their recorded wall-clock intervals.
Keeps selected native PNGs, structured samples and decoded, timing-checked video.
Raw JPEG capture remains at the isolated runner path; no poses are synthesized.
"""
from pathlib import Path
import json,shutil,subprocess,sys
from fractions import Fraction
raw=Path(sys.argv[1]);dest=Path(sys.argv[2]);dest.mkdir(parents=True,exist_ok=False)
manifest=json.loads((raw/'manifest.json').read_text())
if manifest.get('errors'):raise SystemExit(str(manifest['errors']))
for p in raw.glob('*.png'):shutil.copyfile(p,dest/p.name)
shutil.copyfile(raw/'manifest.json',dest/'manifest.json')
videos=dest/'videos';videos.mkdir()
records=[]
def cmd(*args):subprocess.run(list(args),check=True)
def quote(p):return str(p).replace("'","'\\''")
for clip in manifest['clips']:
 label=clip['label'];samples=clip['samples'];source_frames=[raw/label/f'frame_{i:04d}.jpg' for i in range(len(samples))]
 durations=[samples[i+1]['seconds']-samples[i]['seconds'] for i in range(len(samples)-1)];durations.append(durations[-1] if durations else 1/30)
 duration=sum(durations)
 listing=videos/(label+'.ffconcat')
 listing.write_text('ffconcat version 1.0\n'+''.join(f"file '{quote(p)}'\nduration {dt:.9f}\n" for p,dt in zip(source_frames,durations))+f"file '{quote(source_frames[-1])}'\n")
 output=videos/(label+'.mp4')
 frames=round(duration*60)
 cmd('ffmpeg','-v','error','-y','-f','concat','-safe','0','-i',str(listing),'-an','-vf','fps=60','-frames:v',str(frames),'-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(output))
 listing.unlink()
 meta=json.loads(subprocess.check_output(['ffprobe','-v','error','-select_streams','v:0','-count_frames','-show_entries','stream=nb_read_frames,avg_frame_rate,width,height','-of','json',str(output)],text=True))['streams'][0]
 seconds=int(meta['nb_read_frames'])/float(Fraction(meta['avg_frame_rate']))
 if abs(seconds-duration)>1/60+.000001:raise SystemExit('Timing mismatch '+label)
 records.append({'label':label,'file':str(output.relative_to(dest)),'source_frames':len(samples),'source_seconds':duration,'encoded_frames':int(meta['nb_read_frames']),'encoded_seconds':seconds,'duration_error_seconds':seconds-duration})
def reel(name,selected):
 listing=videos/(name+'.ffconcat');listing.write_text('ffconcat version 1.0\n'+''.join(f"file '{Path(r['file']).name}'\n" for r in selected))
 out=dest/(name+'.mp4');cmd('ffmpeg','-v','error','-y','-f','concat','-safe','0','-i',str(listing),'-c','copy','-movflags','+faststart',str(out));cmd('ffmpeg','-v','error','-i',str(out),'-f','null','-');return str(out.relative_to(dest))
full=reel('lightning_wisp_gameplay_full_speed',records)
preview=reel('lightning_wisp_preview',[r for r in records if r['label'] in ['00_idle_southwest','01_spark_dart_southwest','static_lash_southwest','blinding_arc_northeast','09_lightning_wisp_death']])
(dest/'video_timeline.json').write_text(json.dumps({'clips':records,'full_reel':full,'preview':preview,'full_decode':'PASS','timing':'Recorded wall-clock intervals; 60fps repetition, no synthesized poses; at most one 60fps boundary rounding per clip'},indent=2)+'\n')
print(json.dumps({'clips':len(records),'seconds':sum(r['encoded_seconds'] for r in records),'preview':str(dest/preview)},indent=2))
