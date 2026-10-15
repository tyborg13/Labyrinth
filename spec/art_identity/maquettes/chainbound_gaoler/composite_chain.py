"""Director step (2026-10-15): take only the chain region from a chain-fix edit and paste it onto the approved raw.

The image edits redrew the chain correctly but also disturbed pixels elsewhere; the approved painting stays authoritative
outside BOX. Usage: python3 composite_chain.py APPROVED_RAW EDIT OUT x0 y0 x1 y1   (box in 1024-px raw coordinates)
"""
import sys

from PIL import Image

approved = Image.open(sys.argv[1]).convert("RGB")
edit = Image.open(sys.argv[2]).convert("RGB")
if edit.size != approved.size:
    edit = edit.resize(approved.size, Image.LANCZOS)  # the front edit came back at 1254 px
x0, y0, x1, y1 = (int(v) for v in sys.argv[4:8])
approved.paste(edit.crop((x0, y0, x1, y1)), (x0, y0))
approved.save(sys.argv[3])
