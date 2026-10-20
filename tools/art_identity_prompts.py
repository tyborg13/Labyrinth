"""Opt-in certification of a maquette's ordered base/revision prompt pair.

Jobs without revision fields keep their historical hash and validation rules.
"""
import hashlib
import json
from pathlib import Path

REVISION_FIELDS = ("revision_prompt_path", "revision_prompt_sha256", "revision_prompt_source")


def revision_binding(kit: dict) -> bytes:
    if not any(field in kit for field in REVISION_FIELDS):
        return b""
    # Ordered records also bind the source names and prevent swapping the base
    # and final revision while retaining an apparently valid generation hash.
    chain = [{"path": kit.get("prompt_path"), "source": kit.get("prompt_source"),
              "sha256": kit.get("prompt_sha256")},
             {"path": kit.get("revision_prompt_path"), "source": kit.get("revision_prompt_source"),
              "sha256": kit.get("revision_prompt_sha256")}]
    return b"\0prompt_chain\0" + json.dumps(chain, sort_keys=True, separators=(",", ":")).encode("utf-8")


def verify_revision(kit: dict, kit_path: Path, root: Path) -> None:
    if not revision_binding(kit):
        return
    if kit.get("kit_kind") != "maquette":
        raise ValueError("revision prompts require a maquette job")
    job = kit_path.parent.resolve()
    maquettes = (root / "spec/art_identity/maquettes").resolve()
    for prefix in ("prompt", "revision_prompt"):
        keys = (prefix + "_path", prefix + "_source", prefix + "_sha256")
        if any(not isinstance(kit.get(key), str) or not kit[key] for key in keys):
            raise ValueError(prefix + " binding is incomplete")
        local = Path(kit[keys[0]])
        source = Path(kit[keys[1]])
        captured = (job / local).resolve()
        original = (root / source).resolve()
        if local.is_absolute() or job not in captured.parents:
            raise ValueError(prefix + " must be job-relative")
        if source.is_absolute() or maquettes not in original.parents:
            raise ValueError(prefix + "_source must be under spec/art_identity/maquettes/")
        content = captured.read_bytes()
        if hashlib.sha256(content).hexdigest() != kit[keys[2]]:
            raise ValueError(prefix + " digest changed")
        if original.read_bytes() != content:
            raise ValueError(prefix + " source differs from captured prompt")
