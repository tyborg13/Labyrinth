"""atk-02: cut the native MovieWriter frames from the capture's START marker to
the end and encode them unchanged (30 fps, 1920x1080) as an H.264 MP4.

  python3 tools/atk02/finalize_movie.py --log <capture log> --out <mp4>
"""
from pathlib import Path
import argparse
import re
import struct
import subprocess


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--log', required=True)
    parser.add_argument('--out', required=True)
    args = parser.parse_args()
    text = Path(args.log).read_text(errors='replace')
    run = Path(re.search(r'^(/private/tmp/labyrinth_codex/atk-02/movie_raw/run\.\w+)$', text, re.M).group(1))
    start = int(re.search(r'ATK02 CAPTURE START frame=(\d+)', text).group(1))
    frames = sorted(p for p in run.glob('movie*.png') if re.fullmatch(r'movie\d+\.png', p.name))
    numbers = [int(p.stem[5:]) for p in frames]
    first = max(start, numbers[0])
    count = numbers[-1] - first + 1
    with frames[0].open('rb') as stream:
        header = stream.read(24)
    assert header[:8] == b'\x89PNG\r\n\x1a\n' and struct.unpack('>II', header[16:24]) == (1920, 1080), 'MovieWriter frames are not 1920x1080'
    digits = len(frames[0].stem) - 5
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-threads', '2', '-framerate', '30', '-start_number', str(first),
                    '-i', str(run / f'movie%0{digits}d.png'), '-frames:v', str(count), '-c:v', 'libx264', '-threads', '2',
                    '-pix_fmt', 'yuv420p', '-crf', '18', args.out], check=True)
    print(f'ATK02 MOVIE: {count} native frames ({count / 30:.1f} s at 30 fps) from frame {first} of {run} -> {args.out}')


if __name__ == '__main__':
    main()
