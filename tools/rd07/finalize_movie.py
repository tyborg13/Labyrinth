"""Extract the final consecutive 90 native MovieWriter PNGs as a 3 s clip.

No pixels are transformed. Startup/fixture setup frames precede the final sweep;
Godot's movie writer records one frame per fixed 1/30 game second throughout.
"""
from pathlib import Path
import json
import re
import shutil
import struct

OUTPUT = Path('/private/tmp/labyrinth_codex/rd-07')
FRAMES = 90
FPS = 30
SIZE = (1920, 1080)


def main():
    metadata = json.loads((OUTPUT / 'clip/semantics.json').read_text())
    assert metadata['movie'] and metadata['fps'] == FPS and not metadata['failures']
    samples = metadata['samples']
    assert len(samples) == FRAMES
    assert samples[-1]['draw_frame'] - samples[0]['draw_frame'] == FRAMES-1
    assert all(abs(b['clock_usec']-a['clock_usec']-1_000_000/FPS) < 2
               for a, b in zip(samples, samples[1:]))
    movie_dir = Path(metadata['movie_path']).resolve().parent
    movie_dir.relative_to((OUTPUT / 'movie_raw').resolve())
    raw = sorted(p for p in movie_dir.glob('movie*.png')
                 if re.fullmatch(r'movie\d+\.png', p.name))
    assert len(raw) >= FRAMES, f'Expected MovieWriter frames, found {len(raw)}'
    dest = OUTPUT / 'clip/frames'
    dest.mkdir(parents=True, exist_ok=True)
    for index, source in enumerate(raw[-FRAMES:]):
        with source.open('rb') as stream:
            header = stream.read(24)
        assert header[:8] == b'\x89PNG\r\n\x1a\n' and struct.unpack('>II', header[16:24]) == SIZE
        shutil.copyfile(source, dest / f'hover_{index:03d}.png')
    (OUTPUT / 'clip/movie_manifest.json').write_text(json.dumps({
        'source': 'Godot --write-movie --fixed-fps 30', 'fps': FPS,
        'frames': FRAMES, 'seconds': FRAMES/FPS, 'size': list(SIZE),
        'startup_frames_removed': len(raw)-FRAMES, 'samples': samples,
    }, indent=2) + '\n')
    print(f'RD07 MOVIE: PASS ({FRAMES} native PNG frames, {FPS} fps, 3.0 game seconds); {dest}')


if __name__ == '__main__':
    main()
