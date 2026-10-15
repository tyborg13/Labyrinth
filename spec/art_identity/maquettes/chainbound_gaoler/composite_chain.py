"""Director step (2026-10-15): take only the chain region from a chain-fix edit and paste it onto the approved raw.

The image edits redrew the chain correctly but also disturbed pixels elsewhere; the approved painting stays authoritative
outside BOX. Usage: python3 composite_chain.py APPROVED_RAW EDIT OUT x0 y0 x1 y1   (box in 1024-px raw coordinates)
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[4] / "tools"))
from art_identity_gate import composite_region, rgba  # noqa: E402


if __name__ == "__main__":
    composite_region(rgba(Path(sys.argv[1])), rgba(Path(sys.argv[2])),
                     [int(v) for v in sys.argv[4:8]]).save(sys.argv[3])
