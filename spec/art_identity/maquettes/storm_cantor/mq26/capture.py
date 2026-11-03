"""Bridge-only bounded clay/map/facing passes and two-label solos (mq-19's pass)."""
from pathlib import Path
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[5]))

if __name__ == '__main__':
    from spec.art_identity.maquettes.storm_cantor.mq19.capture import main
    raise SystemExit(main(*sys.argv[sys.argv.index('--') + 1:]))
