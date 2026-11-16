#!/usr/bin/env python3
"""Approved board backdrop/canon and freshly processed paint at art_scale 1."""
from pathlib import Path
import sys,json
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'))
from art_identity_gate import sheet_backdrop,render_board_row,compose_board_scales,canon_entries
OUTPUT=ROOT/'experiments/cutouts/emaciated_man/emac02/proof'

def main():
    backdrop,slots=sheet_backdrop(ROOT);canon=canon_entries(ROOT)
    paint=Image.open(ROOT/'assets/units/emaciated_man_cutout/front/rest.png').convert('RGBA')
    assert paint.getbbox()==(42,60,244,254),paint.getbbox()
    images=[Image.open(ROOT/canon[k]['path']).convert('RGBA') for k in ['hero_front','grave_surgeon_front']]
    subjects=[(images[0],1.0,'hero front'),(paint,1.0,'Emaciated Man — paint'),(images[1],1.0,'Grave Surgeon front')]
    row=render_board_row(backdrop,slots[:3],subjects)
    spacing=slots[1]['centre'][0]-slots[0]['centre'][0]
    row=row.crop((round(slots[0]['centre'][0]-spacing/2),0,round(slots[2]['centre'][0]+spacing/2),row.height))
    row.save(OUTPUT/'board_row_1x.png');row.resize((row.width*2,row.height*2),Image.Resampling.NEAREST).save(OUTPUT/'board_row_2x.png')
    compose_board_scales(row,OUTPUT/'board_comparison.png')
    report={'art_scale':1.0,'emaciated_bbox':list(paint.getbbox()),'root':[128,254-8*194/135],'pivot':[128,254],'hero_height':images[0].getbbox()[3]-images[0].getbbox()[1],'emaciated_height':194,'source':'normalized 1024 raw, BOX 2.783505154639175; never enlarged 255px paint'}
    (OUTPUT/'board_comparison.json').write_text(json.dumps(report,indent=2)+'\n')
    print('EMAC BOARD COMPARISON: PASS; height=194; art_scale=1.0; '+str(OUTPUT/'board_comparison.png'))
if __name__=='__main__':main()
