#!/bin/sh
# Front/rear zoomed clip strips stacked into one sheet per clip: pair_sheets.sh <work_dir> clip1 clip2 ...
W=$1; shift
for c in "$@"; do
  python3 tools/strip.py $W ${c}_front $W/zf.png 6 --clip --zoom >/dev/null && python3 tools/strip.py $W ${c}_rear $W/zr.png 6 --clip --zoom >/dev/null && \
  python3 -c "
from PIL import Image; a=Image.open('$W/zf.png'); b=Image.open('$W/zr.png'); s=Image.new('RGB',(max(a.width,b.width),a.height+b.height)); s.paste(a,(0,0)); s.paste(b,(0,a.height)); s.save('$W/pair_$c.png'); print('$W/pair_$c.png', s.size)"
done
