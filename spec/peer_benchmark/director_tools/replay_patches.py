"""Rebuild files a Codex session created, by replaying its apply_patch calls in order.
usage: replay_patches.py <rollout.jsonl> <worktree prefix> <out dir> <relpath>..."""
import json, re, sys, os
log, prefix, out = sys.argv[1], sys.argv[2].rstrip('/') + '/', sys.argv[3]
wanted = set(sys.argv[4:])
def js_strings(src):
    i = 0
    while True:
        k = src.find('tools.apply_patch(', i)
        if k < 0: return
        j = k + len('tools.apply_patch(')
        while src[j] in ' \n': j += 1
        q = src[j]
        if q not in '"`\'': i = j; continue
        e = j + 1
        while e < len(src):
            if src[e] == '\\': e += 2; continue
            if src[e] == q: break
            e += 1
        lit = src[j:e+1]
        if q == '"': yield json.loads(lit)
        elif q == "'": yield json.loads('"' + lit[1:-1].replace('\\\'', "'").replace('"', '\\"') + '"')
        else: yield lit[1:-1]
        i = e + 1
files = {}
def apply(patch):
    lines = patch.split('\n'); n = 0; cur = None; mode = None; hunks = []
    def flush():
        if cur is None or cur not in files and mode == 'update': return
        if mode == 'update':
            text = files[cur]
            for h in hunks:
                old = '\n'.join(l[1:] for l in h if l[:1] in (' ', '-'))
                new = '\n'.join(l[1:] for l in h if l[:1] in (' ', '+'))
                if old in text: text = text.replace(old, new, 1)
                else: print('HUNK MISS', cur, repr(old[:80]), file=sys.stderr)
            files[cur] = text
    while n < len(lines):
        l = lines[n]
        if l.startswith('*** Add File: ') or l.startswith('*** Update File: ') or l.startswith('*** Delete File: ') or l.startswith('*** End Patch'):
            flush(); hunks = []; cur = None
            if l.startswith('*** Add File: '):
                cur = l[len('*** Add File: '):].strip(); mode = 'add'; body = []
                n += 1
                while n < len(lines) and not lines[n].startswith('*** '):
                    body.append(lines[n][1:] if lines[n].startswith('+') else lines[n]); n += 1
                files[cur] = '\n'.join(body); cur = None; continue
            if l.startswith('*** Update File: '):
                cur = l[len('*** Update File: '):].strip(); mode = 'update'
            if l.startswith('*** Delete File: '):
                files.pop(l[len('*** Delete File: '):].strip(), None)
        elif cur is not None and mode == 'update':
            if l.startswith('*** Move to: '):
                new = l[len('*** Move to: '):].strip(); files[new] = files.pop(cur, ''); cur = new
            elif l.startswith('@@'): hunks.append([])
            elif l[:1] in (' ', '-', '+') or l == '':
                if not hunks: hunks.append([])
                hunks[-1].append(l if l else ' ')
        n += 1
    flush()
for line in open(log):
    try: d = json.loads(line)
    except Exception: continue
    p = d.get('payload', {})
    if p.get('type') == 'custom_tool_call':
        for patch in js_strings(p.get('input', '')): apply(patch)
for path, text in files.items():
    rel = path[len(prefix):] if path.startswith(prefix) else path
    if rel in wanted:
        dst = os.path.join(out, rel); os.makedirs(os.path.dirname(dst), exist_ok=True)
        open(dst, 'w').write(text if text.endswith('\n') else text + '\n'); print('wrote', rel, len(text))
missing = wanted - {(p[len(prefix):] if p.startswith(prefix) else p) for p in files}
for m in sorted(missing): print('NOT FOUND', m)
