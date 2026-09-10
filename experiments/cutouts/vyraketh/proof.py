"""Retain and verify Vyraketh's native proof without changing captured poses."""
import argparse, hashlib, json, shutil, subprocess, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[2]
sys.path.insert(0, str(REPO / 'tools'))
from cutout_pipeline.proof import input_hashes

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p, value): p.write_text(json.dumps(value, indent=2) + '\n')
def inputs():
    result = input_hashes(ROOT / 'v01')
    paths = [REPO / 'export_presets.cfg', ROOT / 'proof.py']
    for pattern in ['tests/vyraketh*.gd', 'tests/suites/vyraketh*.gd', 'tests/fixtures/vyraketh*.gd']:
        paths.extend(REPO.glob(pattern))
    paths.extend(REPO / 'tools' / n for n in ['visual_probe_runner.py', 'godot_task_runner.py'])
    result.update({'project:' + str(p.relative_to(REPO)): sha(p) for p in paths})
    return result

def retain(result_path, target):
    result = json.loads(result_path.read_text())
    assert result['ok'], result
    raw = Path(result['images'][0]['path']).parent
    assert not target.exists(), target
    shutil.copytree(raw, target)
    write(target / 'runner_result.json', result)

def pack(folder):
    manifest = json.loads((folder / 'manifest.json').read_text())
    assert manifest['ok'], manifest['errors']
    videos = folder / 'videos'
    videos.mkdir(exist_ok=True)
    encoded = []
    for clip in manifest['clips']:
        label = clip['label']
        samples = clip['samples']
        assert len(samples) >= 2, label
        frames = sorted((folder / label).glob('frame_*.jpg'))
        assert len(frames) == len(samples)
        durations = [samples[i+1]['seconds']-samples[i]['seconds'] for i in range(len(samples)-1)]
        durations.append(1/30)
        listing = videos / (label + '.ffconcat')
        listing.write_text('ffconcat version 1.0\n' + ''.join("file '../%s/%s'\nduration %.9f\n" % (label, frame.name, duration) for frame, duration in zip(frames,durations)) + "file '../%s/%s'\n" % (label,frames[-1].name))
        video = videos / (label + '.mp4')
        subprocess.run(['ffmpeg','-v','error','-y','-f','concat','-safe','0','-i',str(listing),'-an','-vf','fps=60','-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(video)],check=True)
        metadata = json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','json',str(video)],text=True))
        seconds = float(metadata['format']['duration'])
        assert abs(seconds-sum(durations)) < .10, (label,seconds,sum(durations))
        subprocess.run(['ffmpeg','-v','error','-i',str(video),'-f','null','-'],check=True)
        encoded.append({'label':label,'source_seconds':sum(durations),'encoded_seconds':seconds,'source_frames':len(frames),'video':str(video.relative_to(folder))})
        walks = [i for i,s in enumerate(samples) if s['animation'].get('clip') == 'walk']
        if walks: shutil.copyfile(frames[walks[len(walks)//2]],folder/(label+'_mid_walk.jpg'))
    selected = ['00_idle_southwest','01_maw_southwest','05_kindle_ground','05_crownfire','05_cinderfall']
    listing = videos / 'review.ffconcat'
    listing.write_text('ffconcat version 1.0\n'+''.join("file '%s.mp4'\n" % n for n in selected))
    subprocess.run(['ffmpeg','-v','error','-y','-f','concat','-safe','0','-i',str(listing),'-c','copy','-movflags','+faststart',str(videos/'gameplay_review.mp4')],check=True)
    write(videos/'encoding.json',{'timing':'Actual wall-clock sample intervals, rounded to 60fps by frame repetition only; no interpolation, retiming, or synthesized poses. Last sample held 1/30 second.','full_decode':'PASS','clips':encoded})

p=argparse.ArgumentParser()
p.add_argument('command',choices=['snapshot','retain','pack','seal','verify'])
p.add_argument('folder',type=Path)
p.add_argument('--result',type=Path)
a=p.parse_args()
if a.command=='snapshot':
    assert not (a.folder/'capture_input_sha256.json').exists()
    write(a.folder/'capture_input_sha256.json',inputs())
elif a.command=='retain': retain(a.result,a.folder)
elif a.command=='pack': pack(a.folder)
else:
    assert json.loads((a.folder/'capture_input_sha256.json').read_text()) == inputs(), 'Proof inputs changed'
    if a.command=='seal': write(a.folder/'proof_sha256.json',{str(f.relative_to(a.folder)):sha(f) for f in sorted(a.folder.rglob('*')) if f.is_file() and f.name!='proof_sha256.json'})
    else:
        expected=json.loads((a.folder/'proof_sha256.json').read_text())
        for name,digest in expected.items(): assert sha(a.folder/name)==digest,name
        print('VYRAKETH RUNTIME PROOF: PASS (%d inputs, %d outputs)' % (len(inputs()),len(expected)))
