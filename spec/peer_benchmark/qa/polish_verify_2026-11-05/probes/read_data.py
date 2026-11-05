"""Read-only ledger evidence. Uses existing fontTools/ffmpeg, writes report evidence only."""
import array
import base64
import io
import json
import math
from pathlib import Path
import re
import subprocess
from fontTools.ttLib import TTFont

BASE = Path(__file__).resolve().parents[1]
cards = json.loads(Path('data/cards.json').read_text())
ids = ['quick_stab', 'updraft', 'crosswind', 'razor_gale', 'eye_of_the_storm', 'cinder_fusillade', 'firebrand_volley', 'searing_light', 'stoke', 'tempest_form']
fonts = []
for path in sorted(Path('fonts').glob('LabyrinthCrumble-*.tres')):
    match = re.search(r'data = PackedByteArray\("([^"]+)"\)', path.read_text())
    font = TTFont(io.BytesIO(base64.b64decode(match[1])))
    cmap = font.getBestCmap()
    units = font['head'].unitsPerEm
    metrics = {c: font['hmtx'].metrics[cmap[ord(c)]][0] for c in [' ', 'n']}
    fonts.append({'path': str(path), 'unitsPerEm': units, 'advances': metrics, 'em': {c: v / units for c, v in metrics.items()}})
report = {'cards': {key: cards[key] for key in ids}, 'fonts': fonts,
          'glossary': json.loads(Path('data/glossary.json').read_text()),
          'run_end_text': json.loads(Path('data/run_end_text.json').read_text())}
(BASE / 'evidence/data.json').write_text(json.dumps(report, indent=2) + '\n')
cues = json.loads(Path('data/sfx_cues.json').read_text())['cues']
entries = [(key, value['variants'][0], value.get('volume_db', 0)) for key, value in cues.items() if key in ['card.hover', 'card.select', 'hit.blade.light', 'surface.fire', 'dragon.roar']]
entries.append(('card_play_take', 'res://assets/audio/sfx/card_play_take.wav', 0))
audio = []
for cue, source, volume in entries:
    path = source.replace('res://', '')
    meta = subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'a:0', '-show_entries', 'stream=channels,sample_rate', '-of', 'json', path], capture_output=True, text=True, check=True)
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', path, '-f', 'f32le', '-acodec', 'pcm_f32le', '-'], capture_output=True, check=True)
    samples = array.array('f')
    samples.frombytes(raw.stdout)
    peak = max(abs(v) for v in samples)
    rms = math.sqrt(sum(v * v for v in samples) / len(samples))
    channels = json.loads(meta.stdout)['streams'][0]['channels']
    audio.append({'cue': cue, 'path': path, 'cue_volume_db': volume, 'channels': channels,
                  'peak_dbfs': 20 * math.log10(max(peak, 1e-12)),
                  'rms_per_channel_dbfs': 20 * math.log10(max(rms, 1e-12)),
                  'sum_channel_power_dbfs': 20 * math.log10(max(rms, 1e-12)) + 10 * math.log10(channels)})
(BASE / 'evidence/audio.json').write_text(json.dumps(audio, indent=2) + '\n')
for row in fonts:
    print('FONT_METRICS', row['path'], 'space_em=%.3f n_em=%.3f' % (row['em'][' '], row['em']['n']))
for row in audio:
    print('AUDIO_METRICS %s channels=%d peak_dbfs=%.3f rms_per_channel_dbfs=%.3f gain_db=%.3f' % (row['cue'], row['channels'], row['peak_dbfs'], row['rms_per_channel_dbfs'], row['cue_volume_db']))
print('QA52 DATA AUDIT COMPLETE cards=%d fonts=%d audio_files=%d' % (len(ids), len(fonts), len(audio)))
