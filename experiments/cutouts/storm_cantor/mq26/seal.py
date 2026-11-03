"""Refresh only Cantor asset pins and cel inventory, never certify native proof."""
import hashlib
import re
import json
from PIL import Image
from build import ROOT, CASE, ASSETS, VIEWS
from cutout_pipeline.cases import read_json,write_json,digest
from cel_look_inventory import inventory

def update_pins_text(path,manifest):
    # The shared inventory contains retained duplicate image records. Preserve
    # its exact unrelated bytes instead of normalizing other owners' entries.
    text=path.read_text();decoder=json.JSONDecoder()
    def value_span(text,key,start=0):
        at=text.index(json.dumps(key)+":",start)+len(json.dumps(key))+1
        while text[at].isspace():at+=1
        _,end=decoder.raw_decode(text,at)
        return at,end
    def top_span(text,key):
        match=list(re.finditer(r'^  '+re.escape(json.dumps(key))+r':\s*',text,re.MULTILINE))[-1]
        _,end=decoder.raw_decode(text,match.end())
        return match.end(),end
    for section in ('files','images','registration','enemy_art'):
        start,end=top_span(text,section)
        body=text[start:end]
        updates={k:v for k,v in manifest[section].items() if k=='storm_cantor' or k.startswith('assets/units/storm_cantor_cutout/')}
        for key,value in updates.items():
            encoded=json.dumps(value,indent=2)
            encoded=encoded.replace('\n','\n    ')
            if json.dumps(key)+":" in body:
                a,b=value_span(body,key);body=body[:a]+encoded+body[b:]
            else:
                body=body[:-1].rstrip()+',\n    '+json.dumps(key)+': '+encoded+'\n  }'
        text=text[:start]+body+text[end:]
    start,end=top_span(text,'roster');at=start+1
    while at<end:
        while text[at].isspace() or text[at]==',':at+=1
        if text[at]==']':break
        row,stop=decoder.raw_decode(text,at)
        if row['actor']=='storm_cantor':
            value=next(r for r in manifest['roster'] if r['actor']=='storm_cantor')
            encoded=json.dumps(value,indent=2).replace('\n','\n    ')
            text=text[:at]+encoded+text[stop:];break
        at=stop
    parsed=json.loads(text)
    assert all(parsed[k]==manifest[k] for k in ('files','images','registration','enemy_art','roster'))
    path.write_text(text)

def seal():
    integration_path=ASSETS/'integration.json';integration=read_json(integration_path)
    integration['director_sha256']=digest(CASE/'director_motion.json')
    for name in ('action_adapter.gd','humanoid_v2/compiled_motion.json','humanoid_v2/director_motion.json'):
        integration['files'][name]=digest(ASSETS/name)
    write_json(integration_path,integration)
    path=ROOT/'tests/approved_asset_pins.json';manifest=read_json(path)
    prefix='assets/units/storm_cantor_cutout/'
    for p in sorted(ASSETS.rglob('*')):
        if not p.is_file() or p.suffix not in ('.json','.png'):continue
        name=str(p.relative_to(ROOT));raw=p.read_bytes();manifest['files'][name]=hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
        if p.suffix=='.png':
            with Image.open(p) as im:manifest['images'][name]={'size':list(im.size),'alpha_bounds':list(im.convert('RGBA').getchannel('A').getbbox() or ())}
    row=next(r for r in manifest['roster'] if r['actor']=='storm_cantor')
    row.update(layout_root=prefix+'humanoid_v2',layouts={v:prefix+f'humanoid_v2/{v}.json' for v in VIEWS},
               rig_script=prefix+'rig.gd',motion=prefix+'humanoid_v2/compiled_motion.json',clips=list(read_json(CASE/'compiled_motion.json')['clips']))
    # Motion-only ports use the committed rest registration. The ignored art
    # build report need not exist in a fresh worktree; never rebuild approved
    # paint merely to refresh its motion pins.
    build_path=CASE/'proof/build.json'
    if build_path.exists():
        build=read_json(build_path)['views']
        manifest['registration']['storm_cantor']={**{v:build[v]['anchor'] for v in VIEWS},'height':[build[v]['anchor'][1]-build[v]['head_top'] for v in VIEWS]}
    manifest['enemy_art']['storm_cantor']['art_scale']=1.0
    # Verify other owners' pin values are untouched; only Cantor can change here.
    update_pins_text(path,manifest)
    entries,_=inventory(ROOT);owned=[e for e in entries if e['path'].startswith(prefix)]
    write_json(CASE/'cel_record.json',{'scope':'actors','entries':owned,'source_sha256':{e['path']:digest(ROOT/e['path']) for e in owned},
               'native_proof':'pending LABYRINTH_CEL_LOOK=all production/depth and real fight; rig stages use off'})
    print(f'RR56 APPROVED PINS / CEL INVENTORY: PASS ({len(owned)} cel inputs; Cantor roster only)')
if __name__=='__main__':seal()
