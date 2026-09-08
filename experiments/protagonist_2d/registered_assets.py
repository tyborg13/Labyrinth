"""Manual native-coordinate segmentation for the sixth Reaver experiment.

A full new painting is registered once, then hand-traced semantic masks copy its
pixels without per-part scaling. ImageGen does not choose atlas dimensions.
Unassigned pixels are reported and shown rather than silently claimed as torso.
"""
from __future__ import annotations
import hashlib,json,math
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
HERE=Path(__file__).resolve().parent

def digest(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def split_source(facing):
    path=HERE/f'references/pass6/{facing}_master.png'
    source=Image.open(path).convert('RGBA')
    definitions=json.loads((HERE/f'references/pass6/{facing}_ownership.json').read_text())
    out=HERE/'assets/pass6'/facing/'source';out.mkdir(parents=True,exist_ok=True)
    masks={};owner={};colors={};parts=[]
    for index,(name,polygon) in enumerate(definitions['priority_polygons']):
        mask=Image.new('L',source.size);ImageDraw.Draw(mask).polygon([tuple(p) for p in polygon],fill=255)
        if name not in masks: masks[name]=Image.new('L',source.size)
        colors[name]=((index*83+71)%200+40,(index*137+41)%200+40,(index*61+91)%200+40,255)
        mp=masks[name].load();sp=source.load()
        for y in range(source.height):
            for x in range(source.width):
                if mask.getpixel((x,y)) and sp[x,y][3] and (x,y) not in owner:
                    owner[x,y]=name;mp[x,y]=255
    for override in definitions.get('pixel_overrides', []):
        point=tuple(override['point']);name=override['name']
        if not source.getpixel(point)[3]: raise ValueError('Override targets a transparent pixel')
        previous=owner.get(point)
        if previous: masks[previous].putpixel(point,0)
        masks[name].putpixel(point,255);owner[point]=name
    unassigned=[(x,y) for y in range(source.height) for x in range(source.width) if source.getpixel((x,y))[3] and (x,y) not in owner]
    overview=Image.new('RGBA',source.size)
    for point,name in owner.items(): overview.putpixel(point,colors[name])
    for point in unassigned: overview.putpixel(point,(255,0,255,255))
    reconstruction=Image.new('RGBA',source.size)
    for name,mask in masks.items():
        image=source.copy();image.putalpha(mask);bbox=image.getbbox()
        if not bbox: raise ValueError('Empty mask '+name)
        image.crop(bbox).save(out/(name+'.png'))
        reconstruction.alpha_composite(image)
        parts.append({'name':name,'file':str((out/(name+'.png')).relative_to(HERE)),'offset':list(bbox[:2]),'bbox':list(bbox),'pixels':sum(1 for a in mask.getdata() if a)})
    overview.save(out/'ownership.png');reconstruction.save(out/'reconstructed.png')
    review=Image.new('RGBA',(1530,820),(45,48,51,255));d=ImageDraw.Draw(review)
    for col,img in enumerate([source,overview,reconstruction]):review.alpha_composite(img.resize((510,510),Image.Resampling.NEAREST),(510*col,20))
    d.text((6,6),f'{facing}: new full paint / ownership (magenta=unassigned) / recomposed source',fill='white')
    for i,part in enumerate(parts):
        img=Image.open(HERE/part['file']).convert('RGBA');x=(i%9)*170;y=550+(i//9)*130
        d.text((x+4,y),part['name'],fill='white')
        # Every crop uses the same 1x native scale, so part size remains visible.
        review.alpha_composite(img,(x+4,y+18))
    review.convert('RGB').save(out/'segmentation_review.png')
    report={'source':str(path.relative_to(HERE)),'source_sha256':digest(path),'parts':parts,'unassigned_pixels':len(unassigned),'unassigned_coordinates':unassigned,'registered_coordinates_preserved':True}
    (out/'segmentation.json').write_text(json.dumps(report,indent=2)+'\n')
    return report


# All component paint is new in this revision. The original Reaver is a visual
# target only. These inputs are either traced pieces of one registered master,
# or a single generated component fitted using the landmarks recorded here.
GENERATED = {
    'front_torso': '6d696f78-20a8-4c2d-90e9-6cc2227db570',
    'rear_torso': '4a276ba6-9dd2-4645-b063-44f678e35ca1',
    'front_boot': 'c2a5943b-cb79-4a04-9b30-f4fef9b3641e',
    'rear_boot': 'b94122ee-a13e-4f6d-be06-dee716c66034',
    'rear_leg': 'dbb3217e-d7fe-4511-bec0-421b8bb26697',
    'front_cape': 'a30489aa-0ac8-4c80-8b6b-44bf2be87de9',
    'rear_cape': '6681ae7c-6e28-4d6a-85b4-b0487883e79e',
    'weapon': 'a559d9c3-8547-4859-9421-1fe5d3886ef3',
    'pelvis': '1d6324bb-20c4-4f8a-a060-fd4747b950c0',
    'cap_r': 'd0c9af23-bb8f-4b0f-845c-b3338fbec444',
    'cap_l': '27b75714-acd1-49d9-a069-8610dfff1537',
}
POSITIONS = {
    'front': [[128,211],[128,135],[128,112],[129,81],[128,67],
              [100,97],[95,114],[86,132],[161,107],[168,123],[168,143],
              [112,144],[112,167],[109,184],[143,150],[151,176],[161,204],
              [153,82],[175,127],[196,174],[86,135]],
    'rear': [[128,211],[128,137],[129,109],[128,75],[128,56],
             [151,93],[159,115],[170,143],[94,100],[88,116],[87,132],
             [142,149],[143,174],[145,202],[111,149],[100,170],[97,192],
             [132,85],[103,127],[71,172],[170,147]],
}
BONE_NAMES = ['root','hips','torso','neck','head','arm_r','forearm_r','hand_r',
              'arm_l','forearm_l','hand_l','thigh_r','shin_r','foot_r',
              'thigh_l','shin_l','foot_l','cape_root','cape_mid','cape_tip','weapon_r']
PARENTS = [None,'root','hips','torso','neck','torso','arm_r','forearm_r',
           'torso','arm_l','forearm_l','hips','thigh_r','shin_r',
           'hips','thigh_l','shin_l','torso','cape_root','cape_mid','hand_r']

def keyed(path):
    im=Image.open(path).convert('RGBA')
    im.putdata([(0,0,0,0) if r>g+35 and b>g+35 or a<128 else(r,g,b,255) for r,g,b,a in im.getdata()])
    return im

def input_image(name, height=None):
    im=keyed(HERE/f'references/pass6/components/{name}.png'); im=im.crop(im.getbbox())
    if height: im=im.resize((round(im.width*height/im.height),height),Image.Resampling.NEAREST)
    return im

def full(im, offset):
    result=Image.new('RGBA',(255,255)); result.alpha_composite(im,tuple(offset));return result

def smooth(v):
    v=min(1.0,max(0.0,v));return v*v*(3-2*v)

def mesh(part, influences, family):
    image=Image.open(HERE/part['file']);x0,y0=part['offset']
    xs=sorted(set([x0,x0+image.width]+list(range((x0//3+1)*3,x0+image.width,3))))
    ys=list(range(y0,y0+image.height+1))
    vertices=[[x,y] for y in ys for x in xs]
    weight_rows=[influences(x,y) for x,y in vertices]
    names=list(weight_rows[0]); weights={name:[round(row[name],8) for row in weight_rows] for name in names}
    tris=[]
    for r in range(len(ys)-1):
        for c in range(len(xs)-1):
            i=r*len(xs)+c;tris.extend([[i,i+1,i+len(xs)+1],[i,i+len(xs)+1,i+len(xs)]])
    return {'equipment_slot':part.get('equipment_slot','chest'),'name':'Skin_'+part['name'],'replaces_part':part['name'],'file':part['file'],
            'offset':part['offset'],'bbox':[x0,y0,x0+image.width,y0+image.height],
            'z_index':part['z_index'],'vertices':vertices,'uvs':[[x-x0,y-y0] for x,y in vertices],
            'triangles':tris,'weights':weights,'family':family,
            'coordinate_space':'registered source pixels; crop-local UV pixels'}

def two_point_art(name, source_points, target_points):
    """Uniform scale/rotation of a generated sleeve cap; no atlas normalization."""
    source=keyed(HERE/f'references/pass6/components/{name}.png')
    (ax,ay),(bx,by)=source_points;(tx,ty),(ux,uy)=target_points
    dx,dy=bx-ax,by-ay;vx,vy=ux-tx,uy-ty;den=dx*dx+dy*dy
    a=(vx*dx+vy*dy)/den;b=(vy*dx-vx*dy)/den;d=a*a+b*b
    # Inverse of target = complex(a,b) * (source - source_origin) + target_origin.
    inverse=(a/d,b/d,ax-(a*tx+b*ty)/d,-b/d,a/d,ay-(-b*tx+a*ty)/d)
    return source.transform((255,255),Image.Transform.AFFINE,inverse,Image.Resampling.NEAREST)

def register_weapon():
    """Fit grip, guard and broad blade widths of one generated weapon.

    The generated body is too narrow at a common height. This per-component
    dimension correction preserves its paint and 116px length: grip ~6px,
    guard ~32px, broad blade ~25px. It introduces no colors or drawn geometry.
    """
    source=input_image('weapon',116)
    result=Image.new('RGBA',(38,116));center=(source.width-1)/2
    for y in range(116):
        if y<17: width_scale=.80
        elif y<22: width_scale=.80+(y-17)*.45/5
        elif y<27: width_scale=1.25+(y-22)*.15/5
        else: width_scale=1.40
        for x in range(38):
            sx=round(center+(x-19)/width_scale)
            if 0<=sx<source.width:result.putpixel((x,y),source.getpixel((sx,y)))
    return result

def register_rear_leg():
    """Fit this individually generated rear view at hip/knee/ankle landmarks.

    Its raw calf is too long. A recorded piecewise affine registration corrects
    that projection; the boot is supplied by the coherent rear master painting.
    """
    raw=keyed(HERE/'references/pass6/components/rear_leg.png'); result=Image.new('RGBA',(255,255))
    points=[(284,137,457,142),(380,149,457,142),(655,174,514,143),(1190,202,518,145)]
    scale_x=.075
    for (sy0,dy0,sx0,dx0),(sy1,dy1,sx1,dx1) in zip(points,points[1:]):
        for y in range(dy0,dy1):
            t=(y-dy0)/(dy1-dy0);sy=round(sy0+(sy1-sy0)*t);sx=sx0+(sx1-sx0)*t;dx=dx0+(dx1-dx0)*t
            for x in range(115,173):
                px=round(sx+(x-dx)/scale_x)
                if 0<=px<raw.width and 0<=sy<raw.height:result.putpixel((x,y),raw.getpixel((px,sy)))
    return result

def build_registered(facing):
    report=split_source(facing);source_parts={p['name']:p for p in report['parts']}
    src={name:full(Image.open(HERE/p['file']).convert('RGBA'),p['offset']) for name,p in source_parts.items()}
    suffix='' if facing=='front' else '_rear'
    identity_source='../../assets/placeholders/units/player_reaver.png' if facing=='front' else 'references/rear.png'
    joints={n:{'parent':parent,'position':point} for n,parent,point in zip(BONE_NAMES,PARENTS,POSITIONS[facing])}
    folder=HERE/'assets/pass6'/facing;folder.mkdir(parents=True,exist_ok=True)
    parts=[];skins=[]
    def save(name,canvas,bone,z):
        bbox=canvas.getbbox()
        if not bbox:raise ValueError(name+' is empty')
        path=folder/(name+'.png');canvas.crop(bbox).save(path)
        slot=('cloak' if name.startswith('mantle_') or name=='cape_drape' else 'head' if name=='head' else 'neck' if name=='scarf' else 'gloves' if name.startswith('hand_') else 'boots' if name.startswith('foot_') else 'weapon' if name=='weapon_r' else 'legs' if name.startswith(('thigh_','shin_','pelvis_')) or name=='hips' else 'chest')
        part={'equipment_slot':slot,'name':name,'file':str(path.relative_to(HERE)),'offset':list(bbox[:2]),'bone':bone,'z_index':z}
        parts.append(part);return part
    torso=input_image(facing+'_torso').resize((64,44) if facing=='front' else (57,43),Image.Resampling.NEAREST)
    under=full(torso,[99,83] if facing=='front' else [98,74]);under.alpha_composite(src['torso']);src['torso']=under
    for name,bone,z in [('head','head',80),('scarf','neck',75),('torso','torso',40),('hips','hips',42)]:save(name,src[name],bone,z)
    # Pants fill hidden hip sockets under the original new master belt/flaps.
    pelvis=input_image('pelvis');pelvis=pelvis.resize((58,54),Image.Resampling.NEAREST).crop((0,0,58,34))
    pelvis_full=full(pelvis,[99,124] if facing=='front' else [97,126]);save('pelvis_underlay',pelvis_full,'hips',9)
    # Correct boot camera views. Cropping the rear shaft retains the original
    # master's calf and uses the new rear-facing heel/toe drawing below it.
    if facing=='front':src['foot_l']=full(input_image('front_boot',36),[134,189])
    else:
        boot=input_image('rear_boot',32).crop((0,10,33,32));src['foot_l']=full(boot,[87,181])
    for side in ['r','l']:
        armnames=['arm_'+side,'forearm_'+side,'hand_'+side]
        arm=Image.new('RGBA',(255,255))
        if facing=='front':
            raw_points=([[714,481],[535,786]] if side=='r' else [[510,427],[725,784]])
        else:
            raw_points=([[510,427],[725,784]] if side=='r' else [[714,481],[535,786]])
        cap_name='cap_'+(side if facing=='front' else ('l' if side=='r' else 'r'))
        cap=two_point_art(cap_name,raw_points,[joints[n]['position'] for n in armnames[:2]])
        # Only extend the rounded proximal end; keep every visible master pixel.
        shoulder_y=joints[armnames[0]]['position'][1]
        for y in range(255):
            for x in range(255):
                if y>shoulder_y+8:cap.putpixel((x,y),(0,0,0,0))
        arm.alpha_composite(cap)
        for n in armnames:arm.alpha_composite(src[n])
        elbow=joints[armnames[1]]['position'][1]
        # The rigid hand begins at the top of its actual painted cuff, not at
        # the anatomical wrist landmark; overlap is fully bound to the hand.
        end=src[armnames[2]].getbbox()[1]
        arm=arm.crop((0,0,255,min(255,end+5)))
        arm=full(arm,[0,0])
        z=(46 if side=='r' else 48) if facing=='front' else (58 if side=='r' else 7)
        p=save(armnames[0],arm,armnames[0],z)
        def arm_weights(x,y,names=armnames,mid=elbow,terminal=end):
            bend=smooth((y-mid+12)/24);distal=smooth((y-terminal+8)/8)
            return {names[0]:(1-bend)*(1-distal),names[1]:bend*(1-distal),names[2]:distal}
        skins.append(mesh(p,arm_weights,'arm_'+side))
        save(armnames[2],src[armnames[2]],armnames[2],67 if side=='r' else z+1)
        legnames=['thigh_'+side,'shin_'+side,'foot_'+side]
        leg=Image.new('RGBA',(255,255))
        # Newly painted hidden pants material under the moving thigh roots.
        hip=joints[legnames[0]]['position'];capbox=(hip[0]-12,hip[1]-10,hip[0]+13,hip[1]+8)
        leg.alpha_composite(pelvis_full.crop(capbox),capbox[:2])
        if facing=='rear' and side=='r':leg.alpha_composite(register_rear_leg())
        else:
            for n in legnames[:2]:leg.alpha_composite(src[n])
        # Duplicate five native rows of the actual boot collar, on its own
        # bone throughout the overlap. The main boot remains rigid.
        boot=src[legnames[2]];end=boot.getbbox()[1]
        # The existing calf underlaps the new boot; no toe pixels are duplicated onto the shin.
        z=20 if (side=='l')==(facing=='front') else 10
        # Overlapping painted knee symbols preserve leather volume through
        # the isometric bend. Each has actual material beyond its pivot;
        # rotating the complete segments avoids pinching a short thick calf.
        knee=joints[legnames[1]]['position'][1]
        upper=full(leg.crop((0,0,255,knee+6)),[0,0])
        lower=full(leg.crop((0,knee-8,255,joints[legnames[2]]['position'][1]+2)),[0,knee-8])
        save(legnames[0],upper,legnames[0],z)
        save(legnames[1],lower,legnames[1],z+1)
        save(legnames[2],boot,legnames[2],z+2)
    # Shoulder cloth is a separate item layer following its shoulder and torso.
    # It never shares the entire hanging cape's fixed foreground draw plane.
    for name,side in [('mantle_far','r' if facing=='front' else 'l'),('mantle_near','l' if facing=='front' else 'r')]:
        p=save(name,src[name],'torso',70)
        shoulder=joints['arm_'+side]['position'];neck=joints['neck']['position']
        def mantle_weights(x,y,side=side,shoulder=shoulder,neck=neck):
            distance=abs(x-neck[0]);span=max(1,abs(shoulder[0]-neck[0]));amount=.35*smooth(distance/span)*smooth((y-neck[1]+5)/20)
            return {'torso':1-amount,'arm_'+side:amount}
        skins.append(mesh(p,mantle_weights,'mantle_'+side))
    cloak=input_image(facing+'_cape',120 if facing=='front' else 106)
    cp=save('cape_drape',full(cloak,[143,78] if facing=='front' else [51,83]),'cape_root',0 if facing=='front' else 50)
    def cape_weights(x,y):
        middle=smooth((y-98)/46);end=smooth((y-140)/44)
        return {'cape_root':1-middle,'cape_mid':middle*(1-end),'cape_tip':middle*end}
    cape=mesh(cp,cape_weights,'cape');parts.remove(cp)
    # Same flat weapon in both views, independent of the closed hand transform.
    sword=register_weapon();angle=-55 if facing=='front' else 55
    old_center=(sword.width/2,sword.height/2);pivot=(19,14)
    rot=sword.rotate(angle,Image.Resampling.NEAREST,expand=True)
    a=math.radians(-angle);dx,dy=pivot[0]-old_center[0],pivot[1]-old_center[1]
    pivot_rot=(rot.width/2+dx*math.cos(a)-dy*math.sin(a),rot.height/2+dx*math.sin(a)+dy*math.cos(a))
    grip=joints['weapon_r']['position'];offset=[round(grip[i]-pivot_rot[i]) for i in range(2)]
    save('weapon_r',full(rot,offset),'weapon_r',66)
    tip=[round(grip[0]+101*math.sin(math.radians(angle))),round(grip[1]+101*math.cos(math.radians(angle)))]
    layout={'version':6,'facing':facing,'canvas_size':[255,255],'source':identity_source,
            'source_sha256':digest(HERE/identity_source),'identity_source':identity_source,
            'rest_source':f'references/pass6/{facing}_assembled_rest.png','joints':joints,
            'parts':parts,'joint_meshes':skins,'cape_mesh':cape,'new_registered_anatomy':True,
            'equipment_slots':{slot:[p['name'] for p in parts+[cp] if p['equipment_slot']==slot] for slot in ['head','neck','chest','legs','gloves','boots','cloak','weapon']},
            'master_source':report['source'],'master_source_sha256':report['source_sha256'],
            'weapon_grip':{'assembled':grip,'tip':tip},
            'notes':['All character paint is new. Canonical sprite is a concept reference only.',
                     'Visible body/head/limb pieces are manually traced from one uniformly registered whole-character painting.',
                     'Separately generated shoulder caps, hidden pants, cloak, sword and alternate rear knee/boot views are fitted to recorded landmarks.',
                     'The source ownership reconstruction proves segmentation, not the quality of the modified assembled character.']}
    canvas=Image.new('RGBA',(255,255));without=Image.new('RGBA',(255,255))
    for part in sorted(parts+[cp],key=lambda p:p['z_index']):
        im=Image.open(HERE/part['file']).convert('RGBA');canvas.alpha_composite(im,part['offset'])
        if not part['name'].startswith('mantle_') and part['name']!='cape_drape':without.alpha_composite(im,part['offset'])
    canvas.save(HERE/layout['rest_source']);without.save(HERE/f'references/pass6/{facing}_without_cloak.png')
    layout['rest_source_sha256']=digest(HERE/layout['rest_source'])
    (HERE/f'cutout_layout{suffix}.json').write_text(json.dumps(layout,indent=2)+'\n')
    return layout

def main():
    layouts=[build_registered(f) for f in ['front','rear']]
    sheet=Image.new('RGBA',(1530,1080),(47,50,54,255));draw=ImageDraw.Draw(sheet)
    for row,layout in enumerate(layouts):
        f=layout['facing']
        for col,(label,path) in enumerate([('Canonical front concept' if f=='front' else 'Earlier rear concept view',layout['identity_source']),('New assembly without cloak',f'references/pass6/{f}_without_cloak.png'),('New assembly with cloak',layout['rest_source'])]):
            im=Image.open(HERE/path).convert('RGBA');sheet.alpha_composite(im.resize((510,510),Image.Resampling.NEAREST),(col*510,row*540+24));draw.text((col*510+6,row*540+8),f+' / '+label,fill='white')
    sheet.convert('RGB').save(HERE/'references/pass6/assembly_review.png')
    print('Sixth-pass registered rigs built for front and rear.')

if __name__=='__main__':main()
