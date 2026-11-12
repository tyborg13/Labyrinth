"""Exercise owner_proof.sh with stubbed Python commands, without launching Godot."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def main():
    with tempfile.TemporaryDirectory(prefix='rd02-owner-sequence-') as directory:
        work = Path(directory)
        trace = work / 'commands.jsonl'
        stub = work / 'python3'
        stub.write_text('#!' + sys.executable + '\n' + '''import json, os, sys
args = sys.argv[1:]
with open(os.environ['RD02_SEQUENCE_TRACE'], 'a') as stream:
    stream.write(json.dumps(args) + '\\n')
if 'tools/rd02/performance.gd' in args:
    for pair in range(1, 4): print('STUB_COMPLETED_PAIR_' + str(pair), flush=True)
    raise SystemExit(1)  # Cost gate failed after all measurements were printed.
if '--godot' in args and 'tools/rd02/movie_capture.sh' in args:
    print('STUB_LATER_MOVIE_FAILURE', flush=True)
    raise SystemExit(1)
''')
        stub.chmod(0o755)
        environment = dict(os.environ, PATH=str(work) + os.pathsep + os.environ['PATH'],
                           RD02_SEQUENCE_TRACE=str(trace))
        result = subprocess.run(['sh', 'tools/rd02/owner_proof.sh'], cwd=ROOT, env=environment,
                                text=True, capture_output=True)
        assert result.returncode == 1, 'Later failures must retain a failed overall result'
        calls = [json.loads(line) for line in trace.read_text().splitlines()]
        native = [args for args in calls if args[0] == 'tools/visual_probe_runner.py']
        assert [args[args.index('--case') + 1] for args in native[:7]] == ['standard', 'warband', 'zekarion_arena', 'vyraketh_arena', 'hero', 'zekarion', 'vyraketh']
        assert 'tools/rd02/performance.gd' in native[7], 'A/B follows all stills'
        assert 'tools/rd02/movie_capture.sh' in native[8], 'Movie follows A/B even if its cost gate failed'
        for args in native:
            assert args[args.index('--timeout') + 1] == '300'
            assert args[args.index('--rendering-driver') + 1] == 'metal'
            assert args[args.index('--rendering-method') + 1] == 'mobile'
        for pair in range(1, 4):
            assert result.stdout.index('STUB_COMPLETED_PAIR_' + str(pair)) < result.stdout.index('STUB_LATER_MOVIE_FAILURE')
    print('RD02 OWNER SEQUENCE: PASS (stills -> A/B -> movie; simulated later failures preserve pair output; Metal/mobile)')


if __name__ == '__main__':
    main()
