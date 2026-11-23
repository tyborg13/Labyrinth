"""pla-04's approved supersession of the Burst-family glossary identities.

Read-only test expectations: the director's staged copy and goldens stay
protected. Burst replaces Detonate, Discharge and Shatter Illusion (one verb,
one shape); Terrain Burst's remaining enemy use is Craghide's Groundsplit; the
Storm Capacitor's Arc Burst is Arc Lash. The approved copy lives in
tests/fixtures/pla04_burst_copy.json.
"""
import json
from pathlib import Path

_COPY = json.loads((Path(__file__).resolve().parent / "fixtures/pla04_burst_copy.json").read_text())
# pla-06 (Ice merge) supersedes further records the same way; its approved
# copy lives in tests/fixtures/pla06_ice_copy.json and layers over pla-04's.
PLA06_COPY = json.loads((Path(__file__).resolve().parent / "fixtures/pla06_ice_copy.json").read_text())
for _key in ("relic_descriptions", "glossary_definitions", "glossary_names", "glossary_aliases", "grimoire_titles", "grimoire_bodies", "panel_titles"):
    _COPY[_key] = dict(_COPY[_key]) | PLA06_COPY[_key]
for _key in ("retired_glossary_terms", "retired_grimoire_entries"):
    _COPY[_key] = list(_COPY[_key]) + PLA06_COPY[_key]
PLA07_COPY = json.loads((Path(__file__).resolve().parent / "fixtures/pla07_status_copy.json").read_text())
for _key in ("grimoire_bodies", "relic_descriptions"):
    _COPY[_key].update(PLA07_COPY[_key])
for _key in ("retired_glossary_terms", "retired_grimoire_entries"):
    _COPY[_key].extend(PLA07_COPY[_key])
_PLA09_COPY = json.loads((Path(__file__).resolve().parent / "fixtures/pla09_card_copy.json").read_text())
_COPY["glossary_definitions"].update(_PLA09_COPY["glossary_definitions"])
for _owner, _lines in _PLA09_COPY["grimoire_lines"].items():
    for _index, _line in _lines.items():
        _COPY["grimoire_bodies"][_owner][int(_index)] = _line
PLAYABILITY_COPY = _COPY
BURST_RETIRED = set(_COPY["retired_glossary_terms"])
BURST_DEFINITIONS = dict(_COPY["glossary_definitions"])
BURST_NAMES = dict(_COPY["glossary_names"])
BURST_ALIASES = dict(_COPY["glossary_aliases"])
BURST_GRIMOIRE_BODIES = dict(_COPY["grimoire_bodies"])
BURST_GRIMOIRE_TITLES = dict(_COPY["grimoire_titles"])
BURST_RETIRED_ENTRIES = set(_COPY["retired_grimoire_entries"])


def burst_metadata_supersession(metadata):
    result = []
    for entry in metadata:
        if entry["id"] in BURST_RETIRED:
            continue
        entry = dict(entry)
        if entry["id"] in BURST_NAMES:
            entry["name"] = BURST_NAMES[entry["id"]]
            entry["aliases"] = list(BURST_ALIASES[entry["id"]])
        result.append(entry)
    return result
