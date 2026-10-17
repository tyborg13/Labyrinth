"""Director helper for the Umbra Review Inbox artifact (see README.md).

  inbox.py extract LIVE.html STATE.json      # pull the state block out of the live page (after an Artifact read)
  inbox.py render STATE.json OUT.html [RESET] # fill template.html with the state (RESET = the skeleton's reset CSS)
  inbox.py reset LIVE.html                    # print the skeleton reset CSS the platform served

Items: {id, posted "YYYY-MM-DD HH:MM", area, title, look, questions[], command?, media[{type: video|image, url,
caption}], status: open|answered|done, response?{verdict: approved|changes|note, notes, at}, reply?}.
The owner's page publishes `response`/`status: answered`; the director sets `reply` and `status: done`.
"""
import json, re, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent


def extract(live: str) -> dict:
    m = re.search(r'<script type="application/json" id="inbox-state">(.*?)</script>', live, re.S)
    if not m:
        raise SystemExit("no inbox-state block found")
    return json.loads(m.group(1))


def reset_css(live: str) -> str:
    m = re.match(r"\s*<!doctype html><html><head>.*?<style>(.*?)</style></head><body>", live, re.S | re.I)
    return m.group(1) if m else ""


def render(state: dict, reset: str = "") -> str:
    page = (HERE / "template.html").read_text()
    page = page.replace("__STATE__", json.dumps(state, ensure_ascii=False).replace("<", "\\u003c"))
    if reset:
        page = page.replace('<script id="app-js">', '<script id="app-js" data-reset="%s">' % reset.replace("&", "&amp;").replace('"', "&quot;"), 1)
    return page


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "extract":
        Path(sys.argv[3]).write_text(json.dumps(extract(Path(sys.argv[2]).read_text()), indent=1, ensure_ascii=False))
    elif cmd == "render":
        reset = Path(sys.argv[4]).read_text() if len(sys.argv) > 4 else ""
        Path(sys.argv[3]).write_text(render(json.loads(Path(sys.argv[2]).read_text()), reset))
    elif cmd == "reset":
        print(reset_css(Path(sys.argv[2]).read_text()), end="")
