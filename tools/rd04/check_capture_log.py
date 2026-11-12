"""Reject native proof if any approved cel-look asset fell back to original art."""
from pathlib import Path
import sys


def main():
    log = Path(sys.argv[1])
    if 'Cel look variant unavailable' in log.read_text():
        print(f'error: cel-look fallback detected; native proof rejected: {log}', file=sys.stderr)
        return 1
    print('RD04 CAPTURE CEL LOOK: PASS (no unavailable variants)')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
