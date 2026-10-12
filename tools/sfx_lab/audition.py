"""Generate a local/static audition page and normalized relative MP3 candidates."""
from __future__ import annotations

import argparse
import html
import json
from pathlib import Path
import sys

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.sfx_lab.common import (LabError, TakeLibrary, approved_value, cli, design_value,
    fade_in, fade_out, front_pair, load_design, normalize, read_json, safe_component,
    safe_path, sha256, write_json, write_text, SHORT_SECONDS, FADE_IN_MS, FADE_IN_CURVE, PITCH_MODE)
from tools.sfx_lab.build import encode_verified


AUDITION_LUFS = -20
AUDITION_SHORT_PEAK_DBFS = -14
AUDITION_FADE_OUT_MS = 30
KEY_FEATURES = ["duration", "peak_dbfs", "lufs", "loudness_method", "attack_seconds",
                "decay_seconds", "centroid_hz", "low_band_ratio", "high_band_ratio", "tonality"]
AUDITION_CSS = """
:root { --ink: #0c0a08; --text: #efe3c8; --secondary: #b5a58a; --accent: #c9a25e; --pick: #e8893a; }
body { background: var(--ink); color: var(--text); font: 16px system-ui, sans-serif; }
h1, h2 { font-family: ui-serif, serif; }
.candidate { display: grid; grid-template-columns: max-content max-content repeat(3, minmax(0, 1fr)) max-content; gap: 1em; align-items: center; }
.candidate audio { display: none; }
.candidate.picked { outline: thin solid var(--pick); }
.candidate:focus-visible { outline: auto; outline-color: var(--accent); }
button { font: inherit; color: var(--accent); background: var(--ink); border: thin solid var(--accent); cursor: pointer; }
input { accent-color: var(--pick); }
.waveform { width: 100%; height: 1em; overflow: visible; }
.waveform polyline { fill: none; stroke: var(--accent); vector-effect: non-scaling-stroke; }
.picked .waveform polyline { stroke: var(--pick); }
.features { display: flex; flex-wrap: wrap; gap: 0 1em; margin: 0; }
.features > div { display: flex; gap: 1ch; }
.features dd { margin: 0; }
.source { color: var(--secondary); font-size: small; overflow-wrap: anywhere; }
.licence { color: var(--secondary); }
textarea { display: block; width: 100%; box-sizing: border-box; font: inherit; color: var(--text); background: var(--ink); border: thin solid var(--accent); }
"""
KEYBOARD_SHORTCUTS = {"Space": {"action": "toggle_play"},
                      "Digit1": {"action": "play_label", "label": "A"},
                      "Digit2": {"action": "play_label", "label": "B"},
                      "Digit3": {"action": "play_label", "label": "C"},
                      "Digit4": {"action": "play_label", "label": "D"},
                      "KeyJ": {"action": "next_cue"}, "KeyK": {"action": "previous_cue"},
                      "KeyP": {"action": "toggle_pick"}}
PAGE_TITLE = "Escape the Umbra — Sound Audition"
PLAY_BUTTON_TEXT = "Play"


PAGE_SCRIPT = r"""
const state = JSON.parse(document.getElementById('page-data').textContent);
let focusedEntry = null;
let lastPlayedEntry = null;
function focusCandidate(entry) {
  focusedEntry = entry;
  document.getElementById(entry.row_id).focus();
}
function playCandidate(entry) {
  const audio = document.getElementById(entry.audio_id);
  document.querySelectorAll('audio').forEach(other => { if (other !== audio) other.pause(); });
  focusCandidate(entry);
  lastPlayedEntry = entry;
  audio.currentTime = 0;
  audio.play().catch(error => { document.getElementById('export').value = String(error); });
}
function updatePicks() {
  state.entries.forEach(entry => {
    document.getElementById(entry.row_id).classList.toggle('picked', document.getElementById(entry.radio_id).checked);
  });
}
function moveCue(step) {
  const current = focusedEntry ? state.cue_order.indexOf(focusedEntry.cue_id) : -1;
  const next = current < 0 ? 0 : Math.max(0, Math.min(state.cue_order.length - 1, current + step));
  if (next === current) return;
  const entry = state.entries.find(item => item.cue_id === state.cue_order[next]);
  if (entry) focusCandidate(entry);
}
document.querySelectorAll('[data-play]').forEach(button => {
  button.addEventListener('click', () => {
    const entry = state.entries.find(item => item.audio_id === button.dataset.play);
    if (entry) playCandidate(entry);
  });
});
document.addEventListener('focusin', event => {
  const row = event.target.closest?.('[data-entry]');
  if (row) focusedEntry = state.entries.find(item => item.row_id === row.id) || null;
});
document.addEventListener('change', updatePicks);
document.addEventListener('keydown', event => {
  if (event.repeat || event.ctrlKey || event.metaKey || event.altKey ||
      event.target.isContentEditable || ['TEXTAREA', 'SELECT'].includes(event.target.tagName) ||
      (event.target.tagName === 'INPUT' && event.target.type !== 'radio')) return;
  const shortcut = state.keyboard_shortcuts[event.code];
  if (!shortcut) return;
  if (shortcut.action === 'toggle_play') {
    // Keep Space's native button action when focus is outside a candidate.
    if (!focusedEntry || (event.target.tagName === 'BUTTON' && !event.target.closest?.('[data-entry]'))) return;
    event.preventDefault();
    const audio = document.getElementById(focusedEntry.audio_id);
    if (!audio.paused && !audio.ended) { audio.pause(); audio.currentTime = 0; }
    else playCandidate(focusedEntry);
  } else if (shortcut.action === 'play_label') {
    if (!focusedEntry) return;
    const entry = state.entries.find(item => item.cue_id === focusedEntry.cue_id && item.label === shortcut.label);
    if (!entry) return;
    event.preventDefault();
    playCandidate(entry);
  } else if (shortcut.action === 'next_cue' || shortcut.action === 'previous_cue') {
    event.preventDefault();
    moveCue(shortcut.action === 'next_cue' ? 1 : -1);
  } else if (shortcut.action === 'toggle_pick') {
    if (!lastPlayedEntry) return;
    event.preventDefault();
    const radio = document.getElementById(lastPlayedEntry.radio_id);
    radio.checked = !radio.checked;
    updatePicks();
  }
});
document.getElementById('copy-picks').addEventListener('click', async () => {
  const selected = {};
  for (const entry of state.entries) {
    if (document.getElementById(entry.radio_id).checked) {
      selected[entry.cue_id] = {note: state.picks[entry.cue_id].note, candidates: [entry.candidate]};
    }
  }
  const text = JSON.stringify(selected, null, 2);
  const output = document.getElementById('export');
  output.value = text;
  output.focus();
  output.select();
  try {
    if (navigator.clipboard && window.isSecureContext) await navigator.clipboard.writeText(text);
    else document.execCommand('copy');
  } catch (_) {
    // Selection remains usable on file:// and hosts that deny clipboard access.
    output.focus();
    output.select();
  }
});
"""


def sparkline(envelope: list[float]) -> str:
    points = " ".join(f"{index},{1 - value:.6f}" for index, value in enumerate(envelope))
    return (f'<svg class="waveform" viewBox="0 0 {len(envelope) - 1} 1" preserveAspectRatio="none" '
            f'role="img" aria-label="64-point envelope"><polyline points="{points}"></polyline></svg>')


def page(picks: dict, entries: list[dict], design: dict) -> str:
    escape = html.escape
    shortcuts = approved_value(design, "keyboard_shortcuts", KEYBOARD_SHORTCUTS)
    css = approved_value(design, "audition_css", AUDITION_CSS)
    title = escape(approved_value(design, "page_title", PAGE_TITLE))
    button_text = escape(approved_value(design, "play_button_text", PLAY_BUTTON_TEXT))
    sections = []
    for cue_id, cue in sorted(picks.items()):
        candidates = []
        for entry in entries:
            if entry["cue_id"] != cue_id:
                continue
            features = "".join(f"<div><dt>{escape(key)}</dt><dd>{escape(str(entry['features'][key]))}</dd></div>"
                               for key in KEY_FEATURES)
            candidates.append(f'''<article class="candidate" id="{entry['row_id']}" data-entry tabindex="0">
<audio id="{entry['audio_id']}" preload="none" src="{escape(entry['audio_path'], quote=True)}"></audio>
<label><input type="radio" id="{entry['radio_id']}" name="{escape(cue_id, quote=True)}" value="{escape(entry['label'], quote=True)}">{escape(entry['label'])}</label>
<button type="button" data-play="{entry['audio_id']}" aria-label="{button_text} {escape(entry['label'], quote=True)}">{button_text}</button>
{sparkline(entry['envelope'])}<dl class="features">{features}</dl>
<p class="source">{escape(entry['source_path'])}</p><p class="licence">{escape(entry['licence_id'])}</p>
</article>''')
        sections.append(f"<section><h2>{escape(cue_id)}</h2><p>{escape(cue.get('note', ''))}</p>"
                        + "".join(candidates) + "</section>")
    payload = json.dumps({"picks": picks, "entries": entries, "cue_order": sorted(picks), "keyboard_shortcuts": shortcuts},
                         sort_keys=True, ensure_ascii=False, allow_nan=False).replace("<", "\\u003c")
    return f'''<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title><style>{css}</style></head><body>
<h1>{title}</h1>{''.join(sections)}
<button type="button" id="copy-picks">Copy picks</button><textarea id="export" aria-label="Copy picks" readonly></textarea>
<script type="application/json" id="page-data">{payload}</script><script>{PAGE_SCRIPT}</script>
</body></html>
'''


def audition(picks_path: Path, out: Path, features: Path, sources: Path | None = None,
             design: dict | None = None) -> list[dict]:
    design = design or {}
    out = safe_path(out)
    picks = read_json(picks_path)
    if not isinstance(picks, dict) or not picks:
        raise LabError("picks.json must contain cue objects")
    library = TakeLibrary(features, sources)
    entries = []
    jobs = []
    for cue_id, cue in sorted(picks.items()):
        safe_component(cue_id)
        labels = set()
        if not cue["candidates"]:
            raise LabError(f"No candidates for {cue_id}")
        for candidate in cue["candidates"]:
            label = safe_component(candidate["label"])
            if label in labels:
                raise LabError(f"Duplicate candidate label in {cue_id}: {label}")
            labels.add(label)
            jobs.append((cue_id, label, candidate, library.get(candidate)))
    for number, (cue_id, label, candidate, row) in enumerate(jobs):
        design_value(design, "pitch_mode")
        data, rate, parameters = library.excerpt(row, candidate)
        data, channel_parameters = front_pair(data)
        parameters.update({**channel_parameters, "channels": data.shape[1]})
        data = fade_in(data, rate)
        data = fade_out(data, rate, AUDITION_FADE_OUT_MS, design)
        # The peak target only applies to short sounds, not long auditions.
        peak_target = AUDITION_SHORT_PEAK_DBFS if len(data) / rate < SHORT_SECONDS else None
        data, normalization = normalize(data, rate, AUDITION_LUFS, peak_target, candidate.get("gain_db", 0))
        parameters.update(normalization)
        parameters.update({"fade_out_ms": AUDITION_FADE_OUT_MS, "fade_curve": design_value(design, "fade_curve"),
                           "fade_in_ms": FADE_IN_MS, "fade_in_curve": FADE_IN_CURVE, "pitch_mode": PITCH_MODE})
        relative = f"audio/{cue_id}/{label}.mp3"
        path = safe_path(out / relative)
        parameters.update(encode_verified(path, data, rate, parameters, "mp3"))
        entries.append({"cue_id": cue_id, "label": label, "candidate": candidate,
                        "audio_id": f"audio-{number}", "radio_id": f"choice-{number}",
                        "row_id": f"candidate-{number}", "envelope": row["envelope"],
                        "audio_path": relative, "source_path": row["source_path"],
                        "licence_id": row["licence_id"], "source_sha256": row["source_sha256"],
                        "output_sha256": sha256(path), "take_start_seconds": row["start_seconds"],
                        "take_end_seconds": row["end_seconds"],
                        "features": {key: row[key] for key in KEY_FEATURES}, "processing": parameters})
    write_text(out / "index.html", page(picks, entries, design))
    write_json(out / "audition.json", {"schema_version": 1, "entries": entries,
                                      "design_pending": []})
    return entries


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--picks", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--features", type=Path, default=Path("features.jsonl"))
    parser.add_argument("--sources", type=Path)
    parser.add_argument("--design-config", type=Path)
    args = parser.parse_args()
    result = audition(args.picks, args.out, args.features, args.sources, load_design(args.design_config))
    print(f"AUDITION candidates={len(result)} page={args.out / 'index.html'}")


if __name__ == "__main__":
    cli(main)
