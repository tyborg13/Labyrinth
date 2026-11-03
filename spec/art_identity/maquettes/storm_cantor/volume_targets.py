"""Director-supplied volume revisions; historical inputs remain immutable."""
import json
from pathlib import Path


def targets(folder=None):
    folder=Path(folder or Path(__file__).resolve().parent)
    original=json.loads((folder/'feedback1_dimensions.json').read_text())
    revision=json.loads((folder/'feedback3_dimensions.json').read_text())
    return {**original,**revision}
