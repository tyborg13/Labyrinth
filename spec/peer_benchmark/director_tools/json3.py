"""3-way JSON merge of a conflicted path: git stages 1 (base), 2 (ours), 3 (theirs)."""
import json, subprocess, sys
def stage(n, p):
    r = subprocess.run(['git', 'show', f':{n}:{p}'], capture_output=True, text=True)
    return json.loads(r.stdout) if r.returncode == 0 else None
K = lambda x: json.dumps(x, sort_keys=True)
conflicts = []
def merge(b, o, t, where=''):
    if K(o) == K(t): return o
    if K(b) == K(o): return t
    if K(b) == K(t): return o
    if isinstance(o, dict) and isinstance(t, dict):
        b = b if isinstance(b, dict) else {}
        out = {}
        for k in list(o) + [k for k in t if k not in o]:
            if k in o and k in t: out[k] = merge(b.get(k), o[k], t[k], where + '/' + k)
            elif k in o:
                if k in b and K(b[k]) == K(o[k]): continue      # theirs deleted, ours unchanged
                out[k] = o[k]
            else:
                if k in b and K(b[k]) == K(t[k]): continue      # ours deleted
                out[k] = t[k]
        return out
    if isinstance(o, list) and isinstance(t, list):
        b = b if isinstance(b, list) else []
        bk = {K(x) for x in b}; tk = {K(x) for x in t}; ok = {K(x) for x in o}
        out = [x for x in o if not (K(x) in bk and K(x) not in tk)]
        out += [x for x in t if K(x) not in bk and K(x) not in ok]
        return out
    conflicts.append(where); return o
for p in sys.argv[1:]:
    conflicts.clear()
    res = merge(stage(1, p), stage(2, p), stage(3, p))
    raw = subprocess.run(['git', 'show', f':2:{p}'], capture_output=True, text=True).stdout
    indent = 2 if '\n  "' in raw[:200] or '\n  {' in raw[:200] else (1 if '\n "' in raw[:200] else 2)
    open(p, 'w').write(json.dumps(res, indent=indent) + ('\n' if raw.endswith('\n') else ''))
    print(p, 'scalar conflicts kept ours:', conflicts or 'none')
