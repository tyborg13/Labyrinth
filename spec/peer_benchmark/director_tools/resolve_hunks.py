"""Replace the Nth conflict block (0-based) in a file with given text. usage: resolve_hunks.py FILE N RESOLUTION_FILE"""
import re, sys
path, n, res = sys.argv[1], int(sys.argv[2]), open(sys.argv[3]).read()
text = open(path).read()
blocks = list(re.finditer(r'^<<<<<<< [^\n]*\n.*?^>>>>>>> [^\n]*\n', text, re.S | re.M))
b = blocks[n]
open(path, 'w').write(text[:b.start()] + res + text[b.end():])
print(f'{path}: resolved hunk {n} of {len(blocks)}')
