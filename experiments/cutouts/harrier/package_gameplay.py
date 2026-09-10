"""Encode native gameplay captures at their recorded times; retain all source frames."""
from pathlib import Path
from fractions import Fraction
import argparse, hashlib, json, subprocess
p=argparse.ArgumentParser();p.add_argument('capture',type=Path);args=p.parse_args()
root=args.capture.resolve();manifest=json.loads((root/'manifest.json').read_text());assert manifest['ok'] and not manifest['errors']
video=root/'videos';video.mkdir(exist_ok=False)
records=[]
source_hashes={}
for clip in manifest['clips']:
    name=clip['label'];samples=clip['samples'];folder=root/name
    images=sorted(folder.glob('frame_*.jpg'));assert len(images)==len(samples) and images,name
    source_hashes.update({str(path.relative_to(root)):hashlib.sha256(path.read_bytes()).hexdigest() for path in images})
    times=[s['seconds'] for s in samples];tail=times[-1]-times[-2] if len(times)>1 else 1/30
    durations=[b-a for a,b in zip(times,times[1:])]+[tail]
    # Repeat the most recently observed native frame at each 60Hz output time.
    # No optical flow, blended poses, or assumed uniform capture cadence.
    count=round(sum(durations)*60);index=0;indices=[]
    for frame in range(count):
        time=frame/60
        while index+1<len(times) and times[index+1]-times[0]<=time:index+=1
        indices.append(index)
    output=video/(name+'.mp4')
    command=['ffmpeg','-v','error','-f','image2pipe','-framerate','60','-vcodec','mjpeg','-i','-','-an','-c:v','libx264','-threads','2','-preset','fast','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(output)]
    proc=subprocess.Popen(command,stdin=subprocess.PIPE)
    previous=-1;data=b''
    for index in indices:
        if index!=previous:data=images[index].read_bytes();previous=index
        proc.stdin.write(data)
    proc.stdin.close();assert proc.wait()==0
    metadata=json.loads(subprocess.check_output(['ffprobe','-v','error','-count_frames','-select_streams','v:0','-show_entries','stream=nb_read_frames,avg_frame_rate,width,height','-of','json',str(output)],text=True))['streams'][0]
    actual=int(metadata['nb_read_frames'])/float(Fraction(metadata['avg_frame_rate']));expected=sum(durations)
    assert metadata['width']==1920 and metadata['height']==1080 and abs(actual-expected)<=1/60+1e-6
    records.append({'label':name,'source_frames':len(images),'source_seconds':expected,'encoded_seconds':actual,'durations':durations,'native_frame_indices':indices})
concat=video/'clips.ffconcat';concat.write_text('ffconcat version 1.0\n'+''.join("file '"+c['label']+".mp4'\n" for c in records))
reel=video/'harrier_gameplay_review.mp4';subprocess.run(['ffmpeg','-v','error','-f','concat','-safe','0','-i',str(concat),'-c','copy','-movflags','+faststart',str(reel)],check=True)
subprocess.run(['ffmpeg','-v','error','-i',str(reel),'-f','null','-'],check=True)
(root/'video_timeline.json').write_text(json.dumps({'clips':records,'timing':'Recorded sample intervals; repeat native frames at 60Hz; no interpolated poses; at most 1/60 second duration rounding per clip.','full_decode':'PASS'},indent=2)+'\n')
(root/'raw_frame_sha256.json').write_text(json.dumps(source_hashes,indent=2)+'\n')
print('Encoded',len(records),'native gameplay clips;',sum(c['encoded_seconds'] for c in records),'seconds')
