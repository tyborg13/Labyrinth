"""Crawler v01 registration/ownership recipe; never edits the accepted front source.

Run only in this fresh case. Maintained segment/skin commands own extraction and meshes.
The polygons name semantic paint; missing pixel ownership is an error, never a torso fill.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
from PIL import Image, ImageDraw, ImageChops

CASE = Path(__file__).resolve().parent
REPO = CASE.parents[3]

def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + '\n')

OWNERS = {
 'front': [
  ['head', [[47,103],[57,84],[77,72],[96,75],[110,88],[115,110],[113,131],[99,149],[80,153],[63,145],[54,130],[48,121]]],
  ['claw_near', [[118,151],[136,151],[137,164],[147,178],[160,182],[159,189],[140,187],[129,178],[126,169],[125,185],[111,188],[106,181],[108,165]]],
  ['arm_near', [[128,103],[142,106],[153,110],[166,109],[183,106],[184,117],[179,126],[148,144],[136,156],[119,160],[116,150],[130,136],[158,122],[150,122],[136,122],[128,117]]],
  ['claw_far', [[40,146],[54,143],[65,145],[68,155],[67,169],[59,170],[57,162],[55,168],[62,177],[59,182],[46,179],[38,169],[37,154]]],
  ['arm_far', [[57,126],[72,124],[79,136],[68,150],[59,155],[41,152],[45,140]]],
  ['foot_near', [[169,180],[191,178],[204,181],[207,197],[199,204],[174,209],[162,205],[162,192]]],
  ['leg_near', [[177,122],[197,117],[208,145],[207,177],[202,186],[187,191],[177,182],[182,166],[168,171],[165,158],[167,144]]],
  ['foot_far', [[87,168],[112,168],[122,176],[124,183],[110,190],[92,188],[79,188],[78,177]]],
  ['leg_far', [[106,133],[126,126],[141,134],[128,159],[118,174],[109,177],[97,172],[100,162],[91,162],[91,147]]],
  ['body', [[59,80],[77,63],[101,37],[119,29],[153,29],[177,41],[196,60],[205,87],[211,117],[209,151],[201,171],[158,169],[128,164],[97,159],[72,144],[50,125],[45,101]]],
  ['head', [[66,144],[99,142],[99,164],[78,164],[73,171],[65,171]]],
  ['claw_far', [[36,140],[79,140],[79,186],[36,186]]],
  ['claw_near', [[106,151],[162,151],[162,194],[106,194]]],
  ['foot_far', [[77,168],[109,168],[109,195],[77,195]]],
  ['foot_near', [[160,177],[208,177],[208,211],[160,211]]],
  ['leg_near', [[170,164],[191,164],[191,184],[170,184]]],
 ],
 'rear': [
  ['head', [[153,43],[169,43],[187,58],[194,79],[194,92],[184,105],[179,103],[176,90],[165,77],[155,68],[149,60]]],
  ['claw_near', [[181,132],[199,130],[207,139],[214,153],[224,163],[225,179],[207,182],[205,171],[199,166],[197,173],[181,181],[179,172],[187,164],[187,147]]],
  ['arm_near', [[143,74],[154,72],[165,80],[173,93],[175,109],[181,122],[191,129],[193,143],[177,141],[168,135],[168,125],[161,114],[154,99],[143,93]]],
  ['claw_far', [[136,124],[150,125],[162,135],[165,146],[158,155],[145,158],[145,151],[149,146],[147,137],[142,145],[136,147],[132,141]]],
  ['arm_far', [[139,107],[155,112],[151,124],[142,136],[137,137],[133,129],[135,119]]],
  ['foot_near', [[97,185],[114,183],[130,189],[139,198],[138,210],[121,213],[109,205],[99,206],[94,197]]],
  ['leg_near', [[92,116],[109,117],[125,128],[140,149],[141,163],[126,172],[108,178],[112,191],[100,196],[91,183],[92,174],[103,160],[96,151],[90,131]]],
  ['foot_far', [[35,170],[49,167],[61,170],[70,176],[73,186],[65,192],[54,189],[44,184],[32,182]]],
  ['leg_far', [[52,130],[79,128],[80,148],[68,157],[52,162],[50,175],[39,179],[35,170],[39,156],[46,145]]],
  ['body', [[41,111],[57,83],[79,55],[103,36],[122,29],[145,32],[166,47],[178,64],[177,102],[162,117],[152,132],[135,145],[115,154],[97,158],[72,159],[49,146],[40,130]]],
  ['head', [[163,42],[197,42],[197,107],[177,112],[172,102],[171,80],[155,65]]],
  ['arm_near', [[159,106],[180,106],[202,130],[202,144],[164,141],[157,123]]],
  ['claw_far', [[129,122],[168,122],[168,158],[129,158]]],
  ['claw_near', [[177,137],[227,137],[227,184],[177,184]]],
  ['leg_near', [[90,146],[142,146],[142,182],[90,197]]],
  ['foot_near', [[91,184],[141,184],[141,214],[91,214]]],
  ['leg_far', [[32,146],[83,146],[83,171],[32,180]]],
  ['foot_far', [[31,168],[75,168],[75,195],[31,195]]],
 ]
}
POINTS = {
 'front': {'root':(128,192),'body':(145,130),'head':(96,106),
  'upper_near':(136,111),'fore_near':(173,118),'claw_near':(126,155),
  'upper_far':(72,126),'fore_far':(57,139),'claw_far':(53,151),
  'thigh_near':(183,135),'shin_near':(181,164),'foot_near':(190,185),
  'thigh_far':(117,138),'shin_far':(105,155),'foot_far':(108,175)},
 'rear': {'root':(128,192),'body':(108,119),'head':(166,69),
  'upper_near':(152,85),'fore_near':(171,124),'claw_near':(189,138),
  'upper_far':(146,110),'fore_far':(141,122),'claw_far':(142,133),
  'thigh_near':(106,131),'shin_near':(128,158),'foot_near':(105,190),
  'thigh_far':(67,139),'shin_far':(45,157),'foot_far':(45,175)}
}
SOLES = {'front':{'claw_near':(146,185),'claw_far':(51,177),'foot_near':(182,203),'foot_far':(101,185)},
         'rear':{'claw_near':(209,176),'claw_far':(155,151),'foot_near':(120,205),'foot_far':(55,185)}}

def cli(*args):
    result=subprocess.run([sys.executable,str(REPO/'tools/cutout_workflow.py'),*map(str,args)],capture_output=True,text=True,cwd=REPO)
    print(args[0], 'PASS' if result.returncode==0 else 'FAIL', str(args[-1]))
    if result.returncode: print(result.stderr); raise RuntimeError('See retained command output JSON for unassigned coordinates')

def main():
    mode=sys.argv[1] if len(sys.argv)>1 else 'segment'
    if mode=='segment':
        for facing, entries in OWNERS.items():
            if len(sys.argv)>2 and facing != sys.argv[2]: continue
            overrides=[{'point':p,'name':'leg_far'} for p in [[97,165],[98,165],[89,167],[90,167],[91,167],[92,167],[98,167]]] + [{'point':[169,171],'name':'leg_near'}] if facing=='front' else [{'point':[175,142],'name':'arm_near'},{'point':[176,142],'name':'arm_near'}]
            save(CASE/f'source/{facing}_ownership.json', {'priority_polygons':entries,'pixel_overrides':overrides})
            cli('segment','--source',CASE/f'source/{facing}_registered.png','--ownership',CASE/f'source/{facing}_ownership.json','--output',CASE/f'segmented/{facing}')
        return
    if mode != 'layout': raise ValueError(mode)
    config=json.loads((CASE/'cutout.json').read_text())
    coverage=[]
    for facing, points in POINTS.items():
        original=Image.open(CASE/f'source/{facing}_registered.png').convert('RGBA')
        joints={}
        for name,position in points.items():
            parent=None if name=='root' else 'root' if name=='body' else 'body'
            for side in ['near','far']:
                if name==f'fore_{side}':parent=f'upper_{side}'
                if name==f'claw_{side}':parent=f'fore_{side}'
                if name==f'shin_{side}':parent=f'thigh_{side}'
                if name==f'foot_{side}':parent=f'shin_{side}'
            joints[name]={'position':position,'parent':parent}
        report=json.loads((CASE/f'segmented/{facing}/segmentation.json').read_text())
        if not report['ok']: raise ValueError('Unassigned source paint')
        parts=[]
        for part in report['parts']:
            name=part['name'];bone=name.replace('arm_','upper_').replace('leg_','thigh_')
            z=30 if name=='head' else 10 if name=='body' else 20 if name.endswith('near') else 2
            parts.append({'name':name,'file':f'segmented/{facing}/{name}.png','offset':part['offset'],'bone':bone,'z_index':z})
        # The accepted source paint stays intact. Narrow generated concealed shafts
        # close the missing far-limb intervals and share each limb's weight field.
        hidden=Image.open(CASE/'source/hidden_transparent.png').convert('RGBA')
        crop=(500,790,760,850) # dark underside, not the broad highlight on the back
        tile=hidden.crop(crop).resize((37,9),Image.Resampling.NEAREST)
        flesh=Image.new('RGBA',(255,255))
        for y in range(0,255,tile.height):
            for x in range(0,255,tile.width):flesh.paste(tile,(x,y))
        for side in ['near','far']:
            for family,root,lower,terminal,radius in [('arm','upper','fore','claw',6),('leg','thigh','shin','foot',8)]:
                name=f'{family}_fill_{side}';mask=Image.new('L',(255,255));d=ImageDraw.Draw(mask)
                for joint in [f'{root}_{side}',f'{lower}_{side}']:
                    x,y=points[joint];d.ellipse((x-radius,y-radius,x+radius,y+radius),fill=255)
                d.line([points[f'{root}_{side}'],points[f'{lower}_{side}'],points[f'{terminal}_{side}']],fill=255,width=8 if family=='arm' else 10)
                bbox=mask.getbbox();paint=flesh.copy();paint.putalpha(ImageChops.multiply(mask,paint.getchannel('A')))
                path=CASE/f'assets/{facing}/{name}.png';path.parent.mkdir(parents=True,exist_ok=True);paint.crop(bbox).save(path)
                parts.append({'name':name,'file':str(path.relative_to(CASE)),'offset':list(bbox[:2]),'bone':f'{root}_{side}','z_index':-3})
                coverage.append({'facing':facing,'part':name,'source':'source/hidden_transparent.png','source_crop':crop,'texture_registration':'nearest 37x9 tile; preserved generated alpha; repeated for concealed native flesh texture','mask':'complete concealed limb shafts plus proximal/middle caps','radius':radius,'width':8 if family=='arm' else 10,'joints':[f'{root}_{side}',f'{lower}_{side}',f'{terminal}_{side}']})
        pocket = [[129,104],[141,105],[145,117],[132,122],[127,114]] if facing=='front' else [[145,77],[159,77],[163,87],[155,94],[143,90]]
        mask=Image.new('L',(255,255));ImageDraw.Draw(mask).polygon(pocket,fill=255)
        mask=ImageChops.multiply(mask,original.getchannel('A').point(lambda a:255 if a>=(255 if facing=='front' else 240) else 0))
        paint=flesh.resize((255,255),Image.Resampling.NEAREST);paint.putalpha(ImageChops.multiply(mask,paint.getchannel('A')));bbox=paint.getbbox()
        path=CASE/f'assets/{facing}/shoulder_pocket.png';paint.crop(bbox).save(path)
        parts.append({'name':'shoulder_pocket','file':str(path.relative_to(CASE)),'offset':list(bbox[:2]),'bone':'body','z_index':-5})
        coverage.append({'facing':facing,'part':'shoulder_pocket','source':'source/hidden_transparent.png','source_crop':crop,'polygon':pocket,'bone':'body'})
        layout={'canvas_size':[255,255],'facing':facing,'joints':joints,'parts':parts,'joint_meshes':[],
                'landmarks':{'contacts':SOLES[facing],'projection':'2:1; distinct near/far ground rows'}}
        save(CASE/f'layouts/{facing}.json',layout)
        fields=[]
        for side in ['near','far']:
            for family,a,b,c,width in [('arm','upper','fore','claw',9),('leg','thigh','shin','foot',10)]:
                lower=points[f'{b}_{side}'];terminal=points[f'{c}_{side}']
                # Blend by the distal direction; the folded front elbow uses a
                # custom field below to keep its rib-side upper segment on the shoulder.
                axis=[terminal[0]-lower[0],terminal[1]-lower[1]]
                first_band={'center':lower,'axis':axis,'width':width}
                if facing=='front' and family=='arm' and side=='near':
                    first_band={'center':[173,123],'axis':[0,1],'width':8}
                fields.append({'name':f'{facing}_{family}_{side}','parts':[f'{family}_{side}',f'{family}_fill_{side}'],
                 'bones':[f'{a}_{side}',f'{b}_{side}',f'{c}_{side}'],'grid':[2,1],
                 'bands':[first_band,{'center':terminal,'axis':axis,'width':8}]})
        recipe={'facing':facing,'input_layout':f'layouts/{facing}.json','output_layout':f'layouts/{facing}_skinned.json','fields':fields}
        save(CASE/f'recipes/{facing}_skinned.skin.json',recipe)
        config['layouts'][facing]=f'layouts/{facing}.json'
    config.update({'clips':{'idle':{'frames':24,'duration':1.4,'loop':True,'preview_cycles':2},
        'walk':{'frames':32,'duration':0.34,'loop':True,'preview_cycles':2,'travel':'motion'},
        'attack':{'frames':32,'duration':0.6,'loop':False},'lunge':{'frames':40,'duration':0.75,'loop':False},
        'coil':{'frames':24,'duration':0.48,'loop':False}},
        'rigid_bones':['head','claw_near','claw_far','foot_near','foot_far'],
        'contact_feet':['claw_near','claw_far','foot_near','foot_far'],
        'source_baseline':{'kind':'new_character','art_status':'accepted front plus matched generated rear; original design preserved'}})
    for action in ['attack','lunge']:
        config['clips'][action]['phase_curve']=[[0,0],[.42*.72,.30],[.42*.90,.40],[.42,.52],[.42+.58*.32,.65],[1,1]]
    config['sources']=sorted(str(p.relative_to(CASE)) for folder in ['source','recipes'] for p in (CASE/folder).rglob('*') if p.is_file())+['author.py','verify_poses.gd','recipes/hidden_coverage.json']
    save(CASE/'cutout.json',config)
    save(CASE/'recipes/hidden_coverage.json',coverage)
    for facing in POINTS: cli('skin',CASE,'--recipe',CASE/f'recipes/{facing}_skinned.skin.json')

if __name__=='__main__':main()
