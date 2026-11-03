"""Director volume revisions: armour, barrel, sewn cloth and domed shells.

The approved armature is immutable. Thickness is added around its surfaces,
including behind the near thigh's approved forward envelope so the wrist
clearance and all original pose constraints remain unchanged.
"""
import math
import numpy as np
from spec.art_identity.maquettes.blender.closed_loft import loft,sweep
from .forms import shell,oval,cord,normal_sheet,armour_limb,dome,union,TOPOLOGY
from .sweep_volume import resize,centers

VOLUME_TOPOLOGY={'cloth_columns':25,'cloth_rows':17,'ring_columns':48,'barrel_rows':25,
                 'rib_stations':65,'spike_stations':9}


def apply(spec,dimensions,approved):
    H=max(v[2] for p in spec['pieces'] if p['id'].startswith('helm_tine_') for v in p['vertices'])
    u=spec['mq17']['source_unit_m_per_px']
    c=spec['source_calipers'];j=spec['joints'];d=dimensions
    if d['pauldron_sizing']!='outward_domes':raise ValueError(d['pauldron_sizing'])
    if d['fork_tine_profile']!='maximum':raise ValueError(d['fork_tine_profile'])
    spec['feedback1']=d;spec['volume_layout']={'cloth_pairs':{},'spike_rings':{},'limb_axes':{}}
    spec['volume_layout']['reference_height_m']=H
    spec['volume_layout']['pauldron_across_axis']=1
    replacements={}
    def add(piece):replacements[piece['id']]=piece;return piece
    def fabric(piece):
        spec['volume_layout']['cloth_pairs'][piece['id']]=len(piece['vertices'])//2
        return add(piece)
    # Volumes below replace the old source-envelope placeholders in place.
    for side,sign in [('near',1),('far',-1)]:
        for part,a,b in [('upper','shoulder','elbow'),('fore','elbow','hand'),('thigh','hip','knee'),('shin','knee','ankle')]:
            start,end=np.asarray(j[a+'_'+side]),np.asarray(j[b+'_'+side])
            piece=armour_limb(part+'_plate_'+side,part+'_'+side,a+'_'+side,start,end,d[part+'_diameter']*H)
            if part=='thigh':
                shift=approved['thigh_front_m'][side]-max(v[0] for v in piece['vertices'])
                piece['vertices']=[[x+shift,y,z] for x,y,z in piece['vertices']]
            add(piece)
            axis=(end-start)/np.linalg.norm(end-start)
            first=np.cross(axis,[0,1,0]);first/=np.linalg.norm(first);second=np.cross(axis,first)
            spec['volume_layout']['limb_axes'][piece['id']]=[first.tolist(),second.tolist()]
        for joint,owner in [('elbow','fore'),('knee','shin')]:
            add(oval(joint+'_joint_'+side,owner+'_'+side,joint+'_'+side,j[joint+'_'+side],[d['joint_diameter']*H/2]*3))
        # Broad toe cap: source toe landmark plus exactly the director's reach.
        ankle=np.asarray(j['ankle_'+side]);toe=np.asarray(j['foot_tip_'+side]);h=ankle[2]
        tip=toe[0]+d['sabatons_past_toes']*H
        heel=ankle[0]-c['foot_width_px']*u/2
        xvalues=[heel,ankle[0],toe[0],tip-(tip-toe[0])/2,tip]
        sections=[]
        for x,ry,rz in zip(xvalues,[.55,1,.85,.55,.01],[.55,1,.75,.4,.01]):
            sections.append([x,ankle[1],h/2,c['foot_width_px']*u/2*ry,h/2*rz])
        v,f,flat=loft({'sections':sections,'axes':[[0,1,0],[0,0,1]],'samples':32})
        add(shell('pointed_sabaton_'+side,'foot_'+side,'ankle_'+side,v,f,flat))
        # Round gauntlet plate, preserving the long source fingers' proportions.
        hand=np.asarray(j['hand_'+side]);scale=(d['gauntlet_width']*H)/(2*c['hand_radius_px'][1]*u)
        r=np.asarray(c['hand_radius_px'])*u*scale
        add(oval('gauntlet_'+side,'hand_'+side,'hand_'+side,hand,r))
        for finger in range(4):
            y=(finger-1.5)*1.8*u*scale;point=hand+[r[0]*.4,y,-r[2]*.5];path=[point.tolist()]
            for k,length in enumerate(c['finger_lengths_px']):
                angle=math.radians(k*spec['pose']['near_finger_knuckle_degrees'] if side=='near' else k*65)
                point=point+np.array([math.sin(angle),0,-math.cos(angle)])*length*u*scale;path.append(point.tolist())
            add(cord('finger_'+side+'_'+str(finger),'hand_'+side,'hand_'+side,path,d['finger_diameter']*H/2))
        add(cord('thumb_'+side,'hand_'+side,'hand_'+side,
            [(hand+[0,sign*r[1],0]).tolist(),(hand+[r[0],sign*r[1]*.4,-r[2]*.4]).tolist(),
             (hand+[r[0]*1.2,0,-r[2]*.6]).tolist()],d['finger_diameter']*H/2))
        # Existing wraps now follow the shin armour rather than the old sticks.
        a=np.asarray(j['ankle_'+side]);b=np.asarray(j['knee_'+side]);radius=d['shin_diameter']*H/2
        for k in range(3):
            centre=a+(b-a)*(.22+k*.14)
            rings=[[*(centre+[0,0,dz]),radius,radius] for dz in [-u,u]]
            v,f,flat=loft({'sections':rings,'samples':24})
            add(shell('shin_wrap_'+side+'_'+str(k),'shin_'+side,'ankle_'+side,v,f,flat))
        shoulder=np.asarray(j['shoulder_'+side]);offset=np.array([0,sign*d['pauldron_outward_offset']*H,0])
        centre=shoulder+[0,0,.015]
        ry=d['pauldron_dome_across']*H/2
        radii=np.asarray(c['pauldron_radius_px'])/c['pauldron_radius_px'][1]*ry
        centre+=offset
        add(dome('pauldron_'+side,'pauldron_'+side,'shoulder_'+side,centre,radii,c['backplate_thickness_px']*u))
        # One flared, open-bottom lame curves around the proximal upper arm.
        arm=np.subtract(j['elbow_'+side],shoulder);arm/=np.linalg.norm(arm)
        first=np.cross(arm,[0,1,0]);first/=np.linalg.norm(first);second=np.cross(arm,first)
        angles=np.linspace(0,math.tau,VOLUME_TOPOLOGY['ring_columns'],endpoint=False)
        rows=[]
        for t in np.linspace(0,1,7):
            origin=shoulder+offset+arm*(radii[2]/2+t*radii[2]/2)
            radius=(1-t)*radii[1]+t*d['upper_diameter']*H/2
            rows.append([(origin+radius*(math.cos(a)*first+math.sin(a)*second)).tolist() for a in angles])
        lame=normal_sheet('pauldron_lame_'+side,'pauldron_'+side,'shoulder_'+side,rows,c['backplate_thickness_px']*u,True)
        # The lame follows its dome outward. Its normal offsets must fit within
        # the specified cap envelope rather than enlarging the 0.36 H span.
        points=np.asarray(lame['vertices']);reach=max(abs(points[:,1]-centre[1]))
        if reach>ry:points[:,1]=centre[1]+(points[:,1]-centre[1])*ry/reach
        lame['vertices']=points.tolist();add(lame)
        for k in range(d['pauldron_spikes_per_side']):
            x=(k-1)*radii[0]*.6;root=centre+[x,0,radii[2]*math.sqrt(1-(x/radii[0])**2)]
            t=np.linspace(0,1,VOLUME_TOPOLOGY['spike_stations'])
            relative=np.array([[-d['source_shape_ratios']['spike_back_to_up']*v*v,0,v] for v in t])
            length=np.linalg.norm(np.diff(relative,axis=0),axis=1).sum()
            path=root+relative*(d['pauldron_spike_length']*H/length)
            v,f,flat=sweep(path,[1.7*u*(1-taper)+.0001*taper for taper in t],12)
            piece=add(shell('shoulder_spike_'+side+'_'+str(k),'pauldron_'+side,'shoulder_'+side,v,f,flat))
            spec['volume_layout']['spike_rings'][piece['id']]=12
    # The bell's radial volume changes around its existing hook. Height,
    # hanging pivot, topology, owner and joint remain approved inputs.
    bell=next(p for p in spec['pieces'] if p['id']=='bell')
    vertices=np.asarray(bell['vertices']);hook=np.asarray(j['bell_hook'])
    factor=d['bell_mouth']*H/np.ptp(vertices[:,1])
    vertices[:,:2]=hook[:2]+(vertices[:,:2]-hook[:2])*factor
    bell['vertices']=np.round(vertices,TOPOLOGY['coordinate_digits']).tolist();add(bell)
    barrel(spec,d,add)
    support=[p for p in replacements.values() if p['id'].startswith('thigh_plate_')]
    support+=[next(p for p in spec['pieces'] if p['id']=='pelvis_plate')]
    cloth(spec,d,approved,add,fabric,support)
    # Replace all old slabs and four horizontal front-only bars.
    omitted={'rib_'+str(k) for k in range(4)}|{'hood_scarf','hood_back_cape','front_tabard','tabard_sigils',
        'near_cloak_streamer','waist_sash','medallion','closed_back_plate','spine_ridge','sternum_hook','lower_abdomen'}
    spec['pieces']=[p for p in spec['pieces'] if p['id'] not in replacements and p['id'] not in omitted]
    spec['pieces']+=list(replacements.values())
    spec['native_features']['ribs']['objects']=['rib_'+str(k) for k in range(d['rib_count'])]
    # Helm/tines and every approved joint are byte-for-byte construction inputs.
    assert spec['joints']==approved['joints']
    assert all(next(p for p in spec['pieces'] if p['id']==name)==piece for name,piece in approved['protected_pieces'].items() if name!='bell')
    staff=next(p for p in spec['pieces'] if p['id']=='staff')
    for name,(a,b) in spec['mq17']['staff_components'].items():
        if name=='pennant':continue
        before=staff['vertices'][a:b]
        diameter=d['staff_shaft_diameter'] if name=='shaft' else d['fork_tine_diameter']
        profile='constant' if name=='shaft' else d['fork_tine_profile']
        staff['vertices'][a:b]=resize(before,diameter*H,profile)
        assert np.allclose(centers(before),centers(staff['vertices'][a:b]),atol=10**-TOPOLOGY['coordinate_digits'])


def barrel(spec,d,add):
    H=spec['volume_layout']['reference_height_m'];u=spec['mq17']['source_unit_m_per_px'];c=spec['source_calipers'];j=spec['joints']
    waist=j['pelvis'][2];neck=j['head'][2];wire=d['rib_diameter']*H/2
    width=d['barrel_width']*H/2-c['backplate_thickness_px']*u/2
    # Keep the enlarged bell inside the cage, with its approved pivot fixed.
    depth=max(width*c['ribcage_radius_px'][0]/c['ribcage_radius_px'][1],
              abs(j['bell_hook'][0])+H*spec['pose']['bell_mouth_over_H']/2+wire)
    low=(c['sole_y']-c['rib_levels_y'][-1])*u
    high=(c['sole_y']-c['rib_levels_y'][0])*u
    def profile(z):
        t=np.clip((z-waist)/(neck-waist),0,1)
        bulge=math.sin(math.pi*t)
        return (c['sash_radius_px'][0]*u+(depth-c['sash_radius_px'][0]*u)*bulge,
                c['sash_radius_px'][1]*u+(width-c['sash_radius_px'][1]*u)*bulge)
    spec['volume_layout']['barrel_rib_ids']=['rib_'+str(k) for k in range(d['rib_count'])]
    for k,z in enumerate(np.linspace(low,high,d['rib_count'])):
        path=[]
        for a in np.linspace(0,math.tau,VOLUME_TOPOLOGY['rib_stations'])[:-1]:
            zz=z+wire*(1-math.cos(a))
            rx,ry=profile(zz)
            path.append([(rx-wire)*math.cos(a),(ry-wire)*math.sin(a),zz])
        path.append(path[0]);add(cord('rib_'+str(k),'torso','torso',path,wire))
    # Curved closed back plate follows the same barrel; no straight frame posts.
    # Size the open sternum window to the bell mouth. The curved side plate
    # covers the far flank seen in the proper rear turn, without frame posts.
    opening=math.asin((H*spec['pose']['bell_mouth_over_H']/2)/(width-wire))
    angles=np.linspace(math.pi/2,math.tau-opening,49)
    rows=[]
    for z in np.linspace(waist+.02,neck-.03,VOLUME_TOPOLOGY['barrel_rows']):
        rx,ry=profile(z)
        rows.append([[rx*math.cos(a),ry*math.sin(a),z] for a in angles])
    add(normal_sheet('closed_back_plate','torso','torso',rows,c['backplate_thickness_px']*u))
    path=[]
    for z in np.linspace(waist+.03,neck-.04,17):
        rx,_=profile(z);path.append([-rx-c['backplate_thickness_px']*u/2,0,z])
    add(cord('spine_ridge','torso','torso',path,1.5*u))
    sections=[]
    for z in np.linspace(waist,low,13):
        rx,ry=profile(z);sections.append([0,0,z,rx,ry])
    v,f,flat=loft({'sections':sections,'samples':48})
    add(shell('lower_abdomen','torso','torso',v,f,flat))
    hook=np.asarray(j['bell_hook']);front=profile(high)[0]-wire
    add(cord('sternum_hook','torso','torso',[[front,0,high],[front,0,hook[2]+wire],hook.tolist()],u))


def cloth(spec,d,approved,add,fabric,support):
    H=spec['volume_layout']['reference_height_m'];u=spec['mq17']['source_unit_m_per_px'];c=spec['source_calipers'];j=spec['joints']
    thick=d['cloth_min_thickness']*H;waist=j['pelvis'][2];neck=j['head'][2]
    n=VOLUME_TOPOLOGY['cloth_columns'];nr=VOLUME_TOPOLOGY['cloth_rows']
    # The roll's volume changes; the approved drape layout remains independent.
    roll=d['scarf_roll_thickness']*H/2
    from .recipe import FOLDER
    import json
    layout=json.loads((FOLDER/'feedback1_dimensions.json').read_text())
    layout_roll=layout['scarf_roll_thickness']*H/2
    rx,ry=np.asarray(c['scarf_top_radius_px'])*u
    sections=[[0,0,neck-.03+roll*math.sin(a),rx+roll*math.cos(a),ry+roll*math.cos(a)]
              for a in np.linspace(0,math.tau,24,endpoint=False)]
    v,f,flat=loft({'sections':sections,'samples':48,'periodic':True})
    add(shell('neck_roll','torso','torso',v,f,flat))
    spec['volume_layout']['neck_roll_shape']=[24,48]
    # Soft shoulder drape, with a rolled neck and curved cloth rather than a cone.
    rows=[];outer=np.asarray(c['scarf_shoulder_radius_px'])*u
    for t in np.linspace(0,1,9):
        row=[]
        for a in np.linspace(0,math.tau,48,endpoint=False):
            radius=(1-t)*np.array([rx,ry])+t*outer
            x=radius[0]*math.cos(a);y=radius[1]*math.sin(a)
            z=(1-t)*(neck-.03)+t*j['shoulder_near'][2]+layout_roll*math.sin(math.pi*t)
            z+=thick*math.sin(3*a)*math.sin(math.pi*t)
            row.append([x-spec['mq17']['shoulder_shear']*y,y,z])
        rows.append(row)
    fabric(normal_sheet('hood_scarf','torso','torso',rows,thick,True))
    # Short cape falls from the roll down to the shoulder blades, with folds.
    rows=[]
    for t in np.linspace(0,1,9):
        row=[]
        for s in np.linspace(-1,1,n):
            cape_width=ry+(layout['barrel_width']*H/2-ry)*math.sin(math.pi*t)
            y=s*cape_width
            z=neck-.03-t*(neck-.03-(neck-.31))+thick*s*s*t
            x=-rx-thick-math.sin(math.pi*t)*layout_roll-thick*math.cos(3*math.pi*s)*t
            row.append([x-spec['mq17']['shoulder_shear']*y,y,z])
        rows.append(row)
    fabric(normal_sheet('hood_back_cape','torso','torso',rows,thick))
    # Soft sash: elliptical, rounded wrap with a real cloth knot at the front.
    sr=np.asarray(c['sash_radius_px'])*u
    sections=[[0,0,waist+c['sash_height_px']*u/2*math.sin(a),sr[0]+thick/2*math.cos(a),sr[1]+thick/2*math.cos(a)]
              for a in np.linspace(0,math.tau,24,endpoint=False)]
    v,f,flat=loft({'sections':sections,'samples':48,'periodic':True})
    add(shell('waist_sash','sash','pelvis',v,f,flat))
    midshin=(j['knee_near'][2]+j['ankle_near'][2])/2
    triangles=[]
    for piece in support:
        vertices=np.asarray(piece['vertices'])
        for face in piece['faces']:
            for k in range(1,len(face)-1):triangles.append(vertices[[face[0],face[k],face[k+1]]])
    triangles=np.asarray(triangles)
    def front_surface(y,z):
        a,b,c=triangles[:,0],triangles[:,1],triangles[:,2]
        e=b-a;f=c-a;det=e[:,1]*f[:,2]-e[:,2]*f[:,1]
        valid=abs(det)>1e-10;safe=np.where(valid,det,1)
        q=(y-a[:,1])*f[:,2]-(z-a[:,2])*f[:,1]
        r=e[:,1]*(z-a[:,2])-e[:,2]*(y-a[:,1]);q/=safe;r/=safe
        hit=valid&(q>=0)&(r>=0)&(q+r<=1)
        return float(np.max(a[hit,0]+q[hit]*e[hit,0]+r[hit]*f[hit,0])) if hit.any() else 0.
    rows=[]
    source_hem=np.asarray(c['tabard_hem_y']);source_u=np.linspace(-1,1,len(source_hem))
    supported=0.
    for t in np.linspace(0,1,nr):
        row=[];zs=[];hits=[]
        for s in np.linspace(-1,1,n):
            rag=(max(source_hem)-np.interp(s,source_u,source_hem))*u
            z=(1-t)*waist+t*(midshin+rag)
            zs.append(z);hits.append(front_surface(s*d['tabard_width']*H/2,z))
        supported=max(supported,max(hits))
        for k,s in enumerate(np.linspace(-1,1,n)):
            base=max(hits[k],supported-thick*math.sin(math.pi*s/2)**2)+thick
            fold=thick*(1-math.cos(3*math.pi*(s+1)))*math.sin(math.pi*t/2)
            row.append([base+fold,s*d['tabard_width']*H/2,zs[k]])
        rows.append(row)
    fabric(normal_sheet('front_tabard','tabard','pelvis',rows,thick))
    spec['volume_layout']['tabard_grid']=[nr,n]
    path=[]
    for x,y in c['sigil_trace_source_px']:
        z=(c['sole_y']-y)*u;s=(x-126)*u/(d['tabard_width']*H/2)
        t=np.clip((waist-z)/(waist-midshin),0,1)
        # Interpolate the actual drafted fold, rather than an unrelated plane.
        grid=np.asarray(rows)
        along=[np.interp(s,np.linspace(-1,1,n),r[:,0]) for r in grid]
        path.append([float(np.interp(t,np.linspace(0,1,nr),along))+thick,(x-126)*u,z])
    add(cord('tabard_sigils','tabard','pelvis',path,.45*u))
    front=rows[0][n//2][0]+thick
    knot=[]
    for side in (-1,1):
        path=[]
        for a in np.linspace(0,math.tau,33):
            path.append([front+thick*math.cos(a),side*thick+thick*math.cos(a),waist+thick*math.sin(a)])
        knot.append(cord('knot_loop_'+str(side),'sash','pelvis',path,thick/2))
    add(union('sash_knot','sash','pelvis',knot))
    medallion_z=waist-thick-c['medallion_radius_px']*u
    add(cord('medallion_hanger','sash','pelvis',[[front,0,waist],[front,0,medallion_z]],u))
    add(oval('medallion','sash','pelvis',[front+thick,0,medallion_z],
             [u,c['medallion_radius_px']*u,c['medallion_radius_px']*u]))
    # One continuous folded streamer; the three tails share the upper mesh.
    shoulder=np.asarray(j['shoulder_near']);rows=[]
    for t in np.linspace(0,1,nr):
        row=[]
        for s in np.linspace(-1,1,n):
            width=d['cloak_top_width']*H*((1-t)+t*d['source_shape_ratios']['cloak_hem_to_top_width'])
            tail=(1+math.cos(3*math.pi*(s+1)))/2
            hem=j['knee_near'][2]+tail*(max(c['cloak_hem_y'])-min(c['cloak_hem_y']))*u
            z=(1-t)*(shoulder[2]+.015)+t*hem
            x=shoulder[0]-.09-.03*t-thick*math.sin(math.pi*t)-thick*math.cos(3*math.pi*(s+1))*t
            row.append([x,shoulder[1]+s*width/2,z])
        rows.append(row)
    fabric(normal_sheet('near_cloak_streamer','cloak','torso',rows,thick))
    spec['volume_layout']['cloak_grid']=[nr,n]
    # The held shaft/fork remain identical. Only its cloth gets the required
    # thickness and a shallow vertical drape; Y/Z tie, length and width remain.
    staff=next(p for p in spec['pieces'] if p['id']=='staff')
    a,b=spec['mq17']['staff_components']['pennant'];old=np.asarray(staff['vertices'][a:b]);count=len(old)//2
    mid=(old[:count]+old[count:])/2;grid=mid.reshape(3,7,3)
    for k,s in enumerate(np.linspace(0,1,7)):grid[:,k,0]+=thick*math.sin(math.pi*s)
    cloth_piece=normal_sheet('pennant','staff','hand_far',grid,thick)
    staff['vertices'][a:b]=cloth_piece['vertices'];add(staff)
    spec['volume_layout']['pennant_pairs']=[a,count]
    ornaments=next(p for p in spec['pieces'] if p['id']=='pennant_sigils');points=np.asarray(ornaments['vertices'])
    for sign,part in [(-1,points[:len(points)//2]),(1,points[len(points)//2:])]:
        # Each ring follows the curved, now thickened pennant surface.
        centers=part.reshape(-1,12,3).mean(axis=1)
        for k,center in enumerate(centers):
            s=np.clip((spec['mq17']['staff']['tie'][1]-center[1])/(spec['pose']['pennant_width_over_H']*H),0,1)
            x=float(grid[0,0,0])+thick*math.sin(math.pi*s)+sign*(thick/2+.45*u)
            part[k*12:(k+1)*12,0]+=x-center[0]
    ornaments['vertices']=points.tolist();add(ornaments)
