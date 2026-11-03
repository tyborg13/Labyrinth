"""Opened-mesh rear coverage, cloak seam tuck and near-arm order (mq-19 rules).

Adapted from mq19/occlusion.py: identical rays, gates and thresholds; only the
seam supports are the take-three hood mantle and pauldron caps.
"""
import math
import numpy as np
from ..mq19.occlusion import OCCLUSION_DEFAULTS, coverage_acceptance

SUPPORTS = ('hood_mantle', 'hood_cowl', 'pauldron_far', 'pauldron_near')
CLOTH_COVER = ('hood_mantle', 'hood_cowl')


def observe(spec,objects):
    """mq-19's rear coverage, seam tuck and near-arm order on the take-three supports."""
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    from spec.art_identity.maquettes.raster import camera,project
    vertices=[];faces=[];owners=[];without=[];without_owners=[];torso=[];cloth=[];new_cloth=[];supports=[]
    for obj in objects:
        offset=len(vertices)
        vertices.extend(obj.matrix_world@v.co for v in obj.data.vertices)
        polygons=[[offset+i for i in f.vertices] for f in obj.data.polygons]
        faces.extend(polygons);owners.extend([obj.get('piece_id')]*len(polygons))
        if obj.get('part')!='cloak':
            without.extend(polygons);without_owners.extend([obj.get('piece_id')]*len(polygons))
        if obj.get('part')=='torso':torso.extend(polygons)
        if obj.get('piece_id') in SUPPORTS:supports.extend(polygons)
        if obj.get('part')=='cloak':new_cloth.extend(polygons)
        if obj.get('part')=='cloak' or obj.get('piece_id') in CLOTH_COVER:cloth.extend(polygons)
    full=BVHTree.FromPolygons(vertices,faces);bare=BVHTree.FromPolygons(vertices,without)
    torso_tree=BVHTree.FromPolygons(vertices,torso);cloth_tree=BVHTree.FromPolygons(vertices,cloth);new_cloth_tree=BVHTree.FromPolygons(vertices,new_cloth)
    n=spec['mq19']['capture_px'];matrix,target,basis,scale=camera(spec,'rear')
    rotation=matrix[:3,:3];centre=Vector((rotation.T@(target-matrix[:3,3])).tolist())
    right,up,toward=(Vector((axis@rotation).tolist()) for axis in basis)
    torso_vertices=[obj.matrix_world@v.co for obj in objects if obj.get('part')=='torso' for v in obj.data.vertices]
    xy=np.asarray([project(spec,list(v),'rear',n)[:2] for v in torso_vertices])
    x0,y0=np.floor(xy.min(0)).astype(int);x1,y1=np.ceil(xy.max(0)).astype(int)
    far,near=(project(spec,spec['joints']['shoulder_'+s],'rear',n)[:2] for s in ('far','near'))
    samples=covered=visible=new_covered=0;uncovered=[]
    screen_samples=screen_covered=0
    shoulder_z=(spec['joints']['shoulder_near'][2]+spec['joints']['shoulder_far'][2])/2
    for py in range(max(0,y0),min(n,y1+1)):
        for px in range(max(0,x0),min(n,x1+1)):
            shoulder_y=far[1]+(near[1]-far[1])*(px+.5-far[0])/(near[0]-far[0])
            point=centre+right*((px+.5)/n-.5)*scale+up*(.5-(py+.5)/n)*scale
            origin=point+toward*OCCLUSION_DEFAULTS['ray_distance_m']
            hit,normal,index,depth=torso_tree.ray_cast(origin,-toward)
            if hit is None:continue
            ch,cn,ci,cd=cloth_tree.ray_cast(origin,-toward)
            cover=ch is not None and cd<depth+OCCLUSION_DEFAULTS['ray_epsilon_m']
            if py+.5>=shoulder_y:
                screen_samples+=1;screen_covered+=int(cover)
            if hit.z>shoulder_z:continue
            samples+=1;covered+=int(cover)
            nh,nn,ni,nd=new_cloth_tree.ray_cast(origin,-toward)
            new_covered+=int(nh is not None and nd<depth+OCCLUSION_DEFAULTS['ray_epsilon_m'])
            fh,fn,fi,fd=full.ray_cast(origin,-toward)
            visible+=int(fi is not None and owners[fi]=='full_back_cloak')
            if not cover:uncovered.append([px,py])
    coverage=covered/max(1,samples)
    matrix,_,basis,_=camera(spec,'front');front=Vector((basis[2]@matrix[:3,:3]).tolist()).normalized()
    def owner(tree,labels,point):
        hit,normal,index,distance=tree.ray_cast(point+front*OCCLUSION_DEFAULTS['ray_distance_m'],-front)
        return labels[index] if hit is not None else None
    arm=[]
    for obj in objects:
        if obj.get('part') in ('upper_near','fore_near','hand_near'):
            for vertex in obj.data.vertices:
                point=obj.matrix_world@vertex.co
                if owner(bare,without_owners,point)==obj.get('piece_id'):
                    arm.append(owner(full,owners,point)!='full_back_cloak')
    supports_tree=BVHTree.FromPolygons(vertices,supports)
    cloak=next(o for o in objects if o.get('piece_id')=='full_back_cloak')
    layout=spec['mq19']['cloak_layout'];count=layout['paired_vertices'];H=spec['mq19']['gauge_H_m']
    from .garments import sampler_factory,hem_sources
    native_points={o.name:[list(o.matrix_world@v.co) for v in o.data.vertices] for o in objects}
    source_attachment=sampler_factory(hem_sources(spec))(spec,native_points)
    attachment=[]
    for i,u in zip(layout['shoulder_indices'],layout['shoulder_us']):
        point=cloak.matrix_world@((cloak.data.vertices[i].co+cloak.data.vertices[i+count].co)/2)
        support=source_attachment(u);radial=Vector(support['radial'].tolist())
        hit,normal,index,distance=supports_tree.find_nearest(point)
        buried=[]
        for skin in (i,i+count):
            skin_point=cloak.matrix_world@cloak.data.vertices[skin].co
            h,n,face,d=supports_tree.ray_cast(skin_point-radial*1e-6,radial,.04*H)
            buried.append(h is not None)
        attachment.append({'index':i,'support':support['support'],'distance_over_H':float(distance/H),
            'lap_over_H':float(point.z/H-support['hem'][2]),'both_skins_concealed_radially':all(buried)})
    attachment_views={}
    for view in ('front','rear'):
        matrix,_,basis,_=camera(spec,view)
        toward=Vector((basis[2]@matrix[:3,:3]).tolist()).normalized()
        exposed=[]
        for i,u in zip(layout['shoulder_indices'],layout['shoulder_us']):
            for skin in (i,i+count):
                point=cloak.matrix_world@cloak.data.vertices[skin].co
                hit,normal,index,distance=bare.ray_cast(point+toward*OCCLUSION_DEFAULTS['ray_distance_m'],-toward)
                if hit is None or distance>=OCCLUSION_DEFAULTS['ray_distance_m']-OCCLUSION_DEFAULTS['ray_epsilon_m']:
                    exposed.append({'u':u,'index':skin,'pixel':list(map(float,project(spec,list(point),view,spec['mq19']['capture_px'])[:2]))})
        total=2*len(layout['shoulder_indices'])
        attachment_views[view]={'top_skin_points':total,'hidden_by_non_cloak_geometry':total-len(exposed),'exposed':exposed}
    domain=spec['mq19']['design']['cloak'].get('coverage_domain')
    checks={'shoulder_attachment_tucked_001H':bool(attachment) and all(abs(v['lap_over_H']-.01)<=1e-6 and v['both_skins_concealed_radially'] for v in attachment),
            'cloak_stays_behind_near_arm':bool(arm) and all(arm)}
    checks.update(coverage_acceptance(domain,coverage,screen_covered/max(1,screen_samples)))
    return {'passed':all(checks.values()),'checks':checks,
        'coverage_domain':domain,'coverage_acceptance':'pending director selection' if not checks['coverage_definition_resolved'] else 'selected domain',
        'definition':'Native rear pixel-centre rays through torso solo. Two cutoff domains are reported without choosing one: opened torso hits below the 3D level-shoulder plane, and pixels below the 2D projected shoulder line. New cloak plus its retained overlapping hood cape/scarf must be closer than or on the torso. The torso denominator includes those garments. New-cloak-only 3D-plane coverage is reported separately. Tears count as uncovered. No hole fill or surface-vertex weighting.',
        'shoulder_plane_z_m':shoulder_z,'projected_line_proxy':{'pixels':screen_samples,'covered':screen_covered,'coverage':screen_covered/max(1,screen_samples)},
        'rear_torso_silhouette_pixels':samples,'rear_cloak_covered_pixels':covered,
        'new_cloak_only_covered_pixels':new_covered,'new_cloak_only_coverage':new_covered/max(1,samples),
        'rear_visible_cloak_pixels':visible,'rear_torso_silhouette_coverage':coverage,
        'uncovered_torso_pixels':uncovered,'shoulder_line_px':[list(map(float,far)),list(map(float,near))],
        'attachment':{'maximum_distance_over_H':max(v['distance_over_H'] for v in attachment),
            'camera_visibility_observations':attachment_views,
            'lap_definition':'world Z above opened native local hem; both skins have a real outward support ray hit',
            'minimum_lap_over_H':min(v['lap_over_H'] for v in attachment),
            'maximum_lap_over_H':max(v['lap_over_H'] for v in attachment),'live_top_vertices':len(attachment),
            'trimmed_top_vertices':len(layout['us'])-len(attachment),
            'failed_tuck_vertices':[v for v in attachment if abs(v['lap_over_H']-.01)>1e-6 or not v['both_skins_concealed_radially']]},
        'front_near_arm_samples':len(arm),'front_unobscured_near_arm_samples':sum(arm)}
