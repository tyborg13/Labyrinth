"""Independent director pins; neither authoring nor compiled targets are authority."""
import json
from pathlib import Path


def load():
    return json.loads((Path(__file__).resolve().parent.parent/'mq21_contract.json').read_text())


def validate_authoring(pose,forms):
    fixed=load()
    if pose!=fixed['pose']:
        raise ValueError('Director brief value changed: pose')
    actual={k:v for k,v in forms.items() if k not in ('authority','preservation')}
    if actual!=fixed['forms'] or forms.get('preservation')!=fixed['accepted_round2']:
        raise ValueError('Director brief value changed: forms')
    return fixed
