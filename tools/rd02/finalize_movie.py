"""Keep the final 90 MovieWriter frames, without transforming their pixels."""
import json
from pathlib import Path
import re
import shutil
import struct

OUTPUT = Path('/private/tmp/labyrinth_codex/rd-02')
FRAMES = 90
FPS = 30
SIZE = (1920, 1080)


def main():
    clip = OUTPUT / 'clip/walk'
    metadata = json.loads((clip / 'semantics.json').read_text())
    assert metadata['movie'] and metadata['fps'] == FPS and not metadata['failures']
    samples = metadata['samples']
    assert len(samples) == FRAMES
    assert samples[-1]['draw_frame'] - samples[0]['draw_frame'] == FRAMES - 1
    assert all(abs(b['clock_usec'] - a['clock_usec'] - 1_000_000 / FPS) < 2
               for a, b in zip(samples, samples[1:]))
    hero_alphas = [next((row['alpha'] for row in frame['active'] if row['key'] == 'player'), 0.0)
                   for frame in samples]
    assert samples[0]['team']['player']['visible'] and samples[-1]['team']['player']['visible'], 'Normal team rim before and after occlusion'
    assert any(not frame['team']['player']['visible'] and frame['team']['player']['xray_alpha'] >= .8 for frame in samples), 'X-ray must replace normal rim'
    assert max(hero_alphas) == 1.0 and min(hero_alphas) == 0.0, 'Hero must enter and leave occlusion'
    assert any(0.0 < value < 1.0 for value in hero_alphas), 'Threshold fade must be visible'
    assert any(frame['hero_pose'].get('clip') == 'walk' for frame in samples), 'Production walk cycle required'
    movie_dir = Path(metadata['movie_path']).resolve().parent
    movie_dir.relative_to((OUTPUT / 'movie_raw').resolve())
    raw = sorted(path for path in movie_dir.glob('movie*.png') if re.fullmatch(r'movie\d+\.png', path.name))
    assert len(raw) >= FRAMES
    dest = clip / 'frames'
    dest.mkdir(parents=True, exist_ok=True)
    for index, source in enumerate(raw[-FRAMES:]):
        header = source.read_bytes()[:24]
        assert header[:8] == b'\x89PNG\r\n\x1a\n' and struct.unpack('>II', header[16:24]) == SIZE
        shutil.copyfile(source, dest / f'walk_{index:03d}.png')
    (clip / 'movie_manifest.json').write_text(json.dumps({
        'source': 'Godot --write-movie --fixed-fps 30', 'fps': FPS,
        'frames': FRAMES, 'seconds': FRAMES / FPS, 'size': SIZE,
        'startup_frames_removed': len(raw) - FRAMES, 'samples': samples,
    }, indent=2) + '\n')
    print(f'RD02 MOVIE: PASS ({FRAMES} native frames, {FPS} fps, 3.0 game seconds); {dest}')


if __name__ == '__main__':
    main()
