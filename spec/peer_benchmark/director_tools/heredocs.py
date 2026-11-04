"""Extract the last `cat > <rel> <<'EOF'` heredoc body per file from a Codex session's exec commands, and list later in-place edits.
usage: heredocs.py <rollout.jsonl> <out dir> <relpath>..."""
import json, re, sys, os
log, out = sys.argv[1], sys.argv[2]; wanted = sys.argv[3:]
bodies = {}; edits = {w: 0 for w in wanted}
def cmd_strings(src):
    for m in re.finditer(r'cmd:\s*"', src):
        j = m.end() - 1; e = j + 1
        while e < len(src):
            if src[e] == '\\': e += 2; continue
            if src[e] == '"': break
            e += 1
        try: yield json.loads(src[j:e+1])
        except Exception: pass
for line in open(log):
    try: d = json.loads(line)
    except Exception: continue
    p = d.get('payload', {})
    if p.get('type') != 'custom_tool_call': continue
    for cmd in cmd_strings(p.get('input', '')):
        for m in re.finditer(r"cat > (\S+) <<'(\w+)'\n(.*?)\n\2(?:\n|$)", cmd, re.S):
            path = m.group(1)
            for w in wanted:
                if path == w or path.endswith('/' + w): bodies[w] = m.group(3); 
        for w in wanted:
            base = os.path.basename(w)
            if re.search(r"Path\(['\"][^'\"]*%s['\"]\)" % re.escape(base), cmd) and 'write_text' in cmd: edits[w] += 1
for w in wanted:
    if w in bodies:
        dst = os.path.join(out, w); os.makedirs(os.path.dirname(dst), exist_ok=True)
        open(dst, 'w').write(bodies[w] + '\n'); print('wrote', w, len(bodies[w]), 'later python edits:', edits[w])
    else: print('NOT FOUND', w, 'python edits:', edits[w])
