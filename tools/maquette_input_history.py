"""Read a unit's declared regeneration closure without adopting later inputs.

The independent Git inventory defines the required paths, never the receipt
being verified. Foreign/shared builder sources retain their unit-end bytes;
current own geometry/pose inputs remain live so stale-source mutations fail.
Current compiled specifications, native reports and all delivered pixels are
validated separately by each figure's delivery checks (int-04's contract).
"""
from functools import lru_cache
import gzip
import hashlib
import json
from pathlib import Path

from tools.unit_preservation import read_bytes

PROJECT = Path(__file__).resolve().parents[1]
PREFIX = 'spec/art_identity/maquettes/'


@lru_cache(maxsize=None)
def historical_bytes(revision, relative):
    return read_bytes(PROJECT, revision, relative)


@lru_cache(maxsize=None)
def declared_inventory(revision, relative):
    raw = historical_bytes(revision, relative)
    if relative.endswith('.gz'):
        raw = gzip.decompress(raw)
    return json.loads(raw)


def input_paths(source, revision, inventory):
    root = Path(source).parents[3]
    return {name: root / name for name in declared_inventory(revision, inventory)}


def input_bytes(source, revision, inventory, validation_modules):
    figure = Path(source).name
    own = PREFIX + figure + '/'
    result = {}
    for name, path in input_paths(source, revision, inventory).items():
        # Verification code cannot affect pixels and must not self-reseal its
        # own historical hash. All other declared own inputs stay live.
        live = name.startswith(own) and Path(name).name not in validation_modules
        raw = path.read_bytes() if live else historical_bytes(revision, name)
        result[name] = raw
    return result


def input_hashes(source, revision, inventory, validation_modules):
    return {name: hashlib.sha256(raw).hexdigest()
            for name, raw in input_bytes(source, revision, inventory, validation_modules).items()}


def materialize_inputs(project, source, revision, inventory, validation_modules):
    """Copy the validation closure and verify its actual bytes before execution."""
    project = Path(project)
    for name, raw in input_bytes(source, revision, inventory, validation_modules).items():
        destination = project / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(raw)
    copied = {str(path.relative_to(project)): hashlib.sha256(path.read_bytes()).hexdigest()
              for path in sorted(project.rglob('*')) if path.is_file()}
    if copied != input_hashes(source, revision, inventory, validation_modules):
        raise ValueError('Copied clean inputs differ from selected sources')
    return copied
