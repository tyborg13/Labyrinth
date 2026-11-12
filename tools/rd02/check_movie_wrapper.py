"""Inspect wrapper argv with a temporary stub; never launch a window or engine."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def main():
    with tempfile.TemporaryDirectory(prefix='rd02-movie-wrapper-') as directory:
        work = Path(directory)
        stub = work / 'godot'
        argv_file = work / 'argv.json'
        stub.write_text('#!/usr/bin/env python3\nimport json,os,sys\n'
                        'open(os.environ["RD02_TEST_ARGV"], "w").write(json.dumps(sys.argv[1:]))\n')
        stub.chmod(0o755)
        environment = dict(os.environ, RD02_MOVIE_GODOT=str(stub), RD02_TEST_ARGV=str(argv_file))
        for user_args in [[], ['--', '--case', 'zekarion', '--clip']]:
            subprocess.run(['sh', 'tools/rd02/movie_capture.sh', '--script', 'tools/rd02/capture.gd',
                            *user_args], cwd=ROOT, env=environment, check=True, capture_output=True)
            argv = json.loads(argv_file.read_text())
            delimiter = argv.index('--')
            engine = argv[:delimiter]
            script = argv[delimiter + 1:]
            assert engine[engine.index('--fixed-fps') + 1] == '30'
            assert script[script.index('--fixed-fps') + 1] == '30'
            assert engine[engine.index('--write-movie') + 1].endswith('/movie.png')
            assert '--headless' not in engine
            assert engine[engine.index('--rendering-method') + 1] == 'mobile'
            assert engine[engine.index('--rendering-driver') + 1] == 'metal'
            for argument in user_args[1:]:
                assert argument in script
    print('RD02 MOVIE WRAPPER: PASS (engine and script fixed-fps=30; write-movie present; both delimiter forms)')


if __name__ == '__main__':
    main()
