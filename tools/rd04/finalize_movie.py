"""Extract the last 90 consecutive native MovieWriter frames, without resampling."""
from pathlib import Path
import json
import re
import shutil
import struct

OUTPUT = Path('/private/tmp/labyrinth_codex/rd-04/feedback2')
FRAMES = 90
FPS = 30
SIZE = (1920, 1080)


def main():
    metadata = json.loads((OUTPUT / 'clip/proof.json').read_text())
    assert not metadata['failures'] and metadata['fps'] == FPS and not metadata['check_only']
    samples = metadata['movie_samples']
    assert len(samples) == FRAMES
    assert samples[-1]['draw_frame'] - samples[0]['draw_frame'] == FRAMES - 1
    assert all(abs(b['clock_usec'] - a['clock_usec'] - 1_000_000 / FPS) < 2
               for a, b in zip(samples, samples[1:]))
    raw_dir = Path(metadata['movie_path']).resolve().parent
    raw_dir.relative_to((OUTPUT / 'movie_raw').resolve())
    raw = sorted(p for p in raw_dir.glob('movie*.png') if re.fullmatch(r'movie\d+\.png', p.name))
    assert len(raw) >= FRAMES
    target = OUTPUT / 'clip/frames'
    target.mkdir(parents=True, exist_ok=True)
    for index, source in enumerate(raw[-FRAMES:]):
        with source.open('rb') as stream:
            header = stream.read(24)
        assert header[:8] == b'\x89PNG\r\n\x1a\n' and struct.unpack('>II', header[16:24]) == SIZE
        shutil.copyfile(source, target / f'sweep_{index:03d}.png')
    (target.parent / 'movie_manifest.json').write_text(json.dumps({
        'frames': FRAMES, 'fps': FPS, 'seconds': FRAMES / FPS,
        'size': SIZE, 'samples': samples, 'startup_frames_removed': len(raw) - FRAMES,
    }, indent=2) + '\n')
    print(f'RD04 MOVIE: PASS ({FRAMES} native PNG frames, {FPS} fps, 3.0 seconds); {target}')


if __name__ == '__main__':
    main()
