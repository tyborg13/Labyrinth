"""3-way JSON merge for registry-style files. usage: json3way.py <path in repo> (run in the worktree mid-merge)."""
import json, subprocess, sys
path = sys.argv[1]
def show(ref):
    r = subprocess.run(["git", "show", f"{ref}:{path}"], capture_output=True, text=True)
    return json.loads(r.stdout) if r.returncode == 0 else None
base, ours, theirs = show(":1"), show(":2"), show(":3")
KEYS = ("path", "id", "key", "actor", "clip", "unit_type", "kind", "name", "file")
conflicts = []
def keyof(x):
    if isinstance(x, dict):
        k = tuple((n, json.dumps(x.get(n), sort_keys=True)) for n in KEYS if n in x)
        return k or None
    return None
def merge(b, o, t, where):
    if o == t: return o
    if b == o: return t
    if b == t: return o
    if isinstance(o, dict) and isinstance(t, dict):
        b = b if isinstance(b, dict) else {}
        out = {}
        for k in list(o.keys()) + [k for k in t.keys() if k not in o]:
            if k in o and k in t: out[k] = merge(b.get(k), o[k], t[k], where + "/" + str(k))
            elif k in o:
                if k in b and b[k] == o[k]: continue  # deleted in theirs
                out[k] = o[k]
            else:
                if k in b and b[k] == t[k]: continue  # deleted in ours
                out[k] = t[k]
        return out
    if isinstance(o, list) and isinstance(t, list) and all(keyof(x) for x in o + t):
        b = b if isinstance(b, list) else []
        bm = {keyof(x): x for x in b}; om = {keyof(x): x for x in o}; tm = {keyof(x): x for x in t}
        order = [keyof(x) for x in o] + [keyof(x) for x in t if keyof(x) not in om]
        out = []
        for k in order:
            if k in om and k in tm: out.append(merge(bm.get(k), om[k], tm[k], where + str(k)))
            elif k in om:
                if k in bm and bm[k] == om[k]: continue
                out.append(om[k])
            else:
                if k in bm and bm[k] == tm[k]: continue
                out.append(tm[k])
        return out
    conflicts.append(where); return o
result = merge(base, ours, theirs, "")
if conflicts:
    print("CONFLICTS:", conflicts[:10]); sys.exit(2)
raw = subprocess.run(["git", "show", f":2:{path}"], capture_output=True, text=True).stdout
indent = 2 if '\n  "' in raw[:200] else (1 if '\n "' in raw[:200] else None)
text = json.dumps(result, indent=indent, ensure_ascii=False) + ("\n" if raw.endswith("\n") else "")
open(path, "w").write(text); print("merged", path)
