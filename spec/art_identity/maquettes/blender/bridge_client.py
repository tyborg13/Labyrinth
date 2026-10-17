"""Owner-approved, serial Blender bridge. Never launches Blender in the sandbox."""
import argparse
try:
    import fcntl
except ImportError:
    fcntl = None
import json
from pathlib import Path
import time
import uuid

BRIDGE_DEFAULTS = {'root': '/private/tmp/labyrinth_codex/blender_bridge',
                   'timeout_s': 120, 'response_timeout_s': 120, 'poll_s': 1}
SCRIPT_ROOT = Path(__file__).resolve().parents[1]
ARG_ROOTS = [SCRIPT_ROOT.parents[2], Path('/private/tmp/labyrinth_codex')]


def submit(script, args, timeout_s=120, root=None):
    script = Path(script).resolve()
    if not script.is_relative_to(SCRIPT_ROOT) or script.suffix != '.py' or not script.is_file():
        raise ValueError('Bridge script must be a maquette Python file in this worktree')
    if not 1 <= timeout_s <= 1800:
        raise ValueError('Bridge timeout must be in [1, 1800] seconds')
    for value in args:
        if str(value).startswith('/') and not any(Path(value).resolve().is_relative_to(p) for p in ARG_ROOTS):
            raise ValueError('Bridge path argument outside allowed roots: ' + str(value))
    root = Path(root or BRIDGE_DEFAULTS['root'])
    queue = root / 'queue'
    if not queue.is_dir():
        raise ValueError('Director Blender bridge queue is unavailable: ' + str(queue))
    identifier = 'mq03-' + uuid.uuid4().hex
    temporary = queue / (identifier + '.tmp')
    temporary.write_text(json.dumps({'script': str(script), 'args': [str(a) for a in args],
                                     'timeout_s': timeout_s}, indent=2) + '\n')
    temporary.replace(queue / (identifier + '.json'))
    return identifier


def wait(identifier, timeout_s=120, root=None):
    root = Path(root or BRIDGE_DEFAULTS['root'])
    path = root / 'done' / (identifier + '.json')
    deadline = time.monotonic() + min(timeout_s, BRIDGE_DEFAULTS['response_timeout_s'])
    while not path.is_file():
        if time.monotonic() >= deadline:
            raise TimeoutError('Bridge result not received; job remains queued/running: ' + identifier)
        time.sleep(BRIDGE_DEFAULTS['poll_s'])
    result = json.loads(path.read_text())
    log = root / 'done' / (identifier + '.log')
    result['id'] = identifier
    result['log_path'] = str(log)
    result['stdout'] = log.read_text() if log.exists() else str(result.get('refused', result.get('log', '')))
    result.setdefault('seconds', 0)
    return result


def run_job(script, args, timeout_s=120, root=None):
    if fcntl is None:
        raise ValueError('The director bridge requires its POSIX shared-filesystem lease')
    bridge_root = Path(root or BRIDGE_DEFAULTS['root'])
    with (bridge_root / 'mq03-client.lock').open('a') as lease:
        fcntl.flock(lease, fcntl.LOCK_EX)
        identifier = submit(script, args, timeout_s, root)
        print('BLENDER_BRIDGE_SUBMITTED: ' + identifier, flush=True)
        return wait(identifier, timeout_s, root)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--timeout', type=int, default=BRIDGE_DEFAULTS['timeout_s'])
    parser.add_argument('--submit-only', action='store_true')
    parser.add_argument('--wait')
    parser.add_argument('script', nargs='?')
    parser.add_argument('args', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.wait:
        result = wait(args.wait, args.timeout)
    else:
        if not args.script:
            parser.error('script or --wait is required')
        values = args.args[1:] if args.args[:1] == ['--'] else args.args
        if args.submit_only:
            identifier = submit(args.script, values, args.timeout)
            print('BLENDER_BRIDGE_SUBMITTED: ' + identifier, flush=True)
            return 0
        result = run_job(args.script, values, args.timeout)
    print(result['stdout'])
    print(f"BLENDER_BRIDGE_RESULT: exit={result['exit']}; seconds={result['seconds']}; log={result['log_path']}")
    return result['exit']


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (ValueError, TimeoutError, OSError) as error:
        print('BLENDER_BRIDGE_ERROR: ' + str(error))
        raise SystemExit(2)
