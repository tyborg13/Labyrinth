"""Director constraints in body space: +X forward, +Y near, +Z up."""
import math
import numpy as np

NUMERICAL_DEFAULTS={'leg_length_gauge_m':1.,'constraint_iterations':60,
                    'pole_control_gauge_over_L':.1,'forward_search_degrees':[-80,80],'epsilon':1e-9}


def bend_joint(start,end,upper,lower,pole):
    start,end=np.asarray(start),np.asarray(end);delta=end-start;distance=np.linalg.norm(delta)
    if not abs(upper-lower)<distance<upper+lower:raise ValueError('Two-bone target out of reach')
    axis=delta/distance;along=(upper*upper-lower*lower+distance*distance)/(2*distance)
    bend=np.asarray(pole)-axis*np.dot(axis,pole);bend/=np.linalg.norm(bend)
    return start+axis*along+bend*math.sqrt(max(0,upper*upper-along*along))


def _solve(c,p,H,L,u,W,d):
    hip_half=c['hip_width_px']*u/2
    shear=(.5-p['shoulder_rise_per_projected_span'])/(.5+p['shoulder_rise_per_projected_span'])
    ankle_z=c['ankle_height_px']*u;ankle_half=W*p['ankle_span_over_shoulders']/2
    step=p['near_step_over_L']*L/2
    # Straight hip-to-sole L, with sole directly below its ankle centre.
    hip_z=math.sqrt(L*L-(step+shear*hip_half)**2-(ankle_half-hip_half)**2)
    waist=(c['sole_y']-c['waist_y'])*u;shoulder_z=(c['sole_y']-c['shoulder_y'])*u
    neck_z=(c['sole_y']-c['neck_y'])*u
    lean=math.tan(math.radians(p['hip_lean_degrees']))
    centre_hip=np.array([0.,0,hip_z])
    def centre(z):return np.array([(z-hip_z)*lean,0,z])
    j={'root':[0,0,0],'pelvis':centre(waist).tolist(),'torso':centre((waist+neck_z)/2).tolist(),
       'head':centre(neck_z).tolist()}
    pitch=math.radians(p['hip_lean_degrees']+p['head_additional_pitch_degrees'])
    j['head_tip']=(centre(neck_z)+np.array([math.sin(pitch),0,math.cos(pitch)])*c['hood_height_px']*u).tolist()
    for side,sign in [('near',1),('far',-1)]:
        hip=centre_hip+[-sign*shear*hip_half,sign*hip_half,0]
        shoulder=centre(shoulder_z)+[-sign*shear*W/2,sign*W/2,0]
        ankle=np.array([sign*step,sign*ankle_half,ankle_z])
        segment=np.linalg.norm(ankle-hip)/(2*math.cos(math.radians(p['knee_bend_degrees']/2)))
        knee=bend_joint(hip,ankle,segment,segment,[1,0,0])
        j.update({name+'_'+side:point.tolist() for name,point in [('hip',hip),('shoulder',shoulder),('knee',knee),('ankle',ankle)]})
        j['foot_tip_'+side]=(ankle+[c['foot_length_px']*u/2,0,-ankle_z/2]).tolist()
    shoulder=np.array(j['shoulder_near']);hip=np.array(j['hip_near'])
    fist=hip+[p['fist_forward_of_hip_over_L']*L,p['fist_outward_of_hip_over_L']*L,0]
    fist[2]=p['fist_height_over_H']*H
    # The exact fist, elbow angle and source upper/fore ratio determine lengths.
    ratio=c['upper_length_px']/c['fore_length_px'];flex=math.radians(p['near_elbow_bend_degrees'])
    lower=np.linalg.norm(fist-shoulder)/math.sqrt(ratio*ratio+1+2*ratio*math.cos(flex))
    pole=[0,math.sin(math.radians(p['near_pole_outward_degrees'])),-math.cos(math.radians(p['near_pole_outward_degrees']))]
    j['elbow_near']=bend_joint(shoulder,fist,ratio*lower,lower,pole).tolist();j['hand_near']=fist.tolist()
    # Free arm: source lengths, exact lateral and elbow angles. Solve the sole
    # remaining pendulum angle against the actual rounded far thigh's front.
    from .body import segmented
    thigh=segmented('constraint','thigh_far','hip_far',j['hip_far'],j['knee_far'],d['thigh_diameter_over_H']*H)
    target=max(v[0] for v in thigh['vertices'])+p['far_wrist_ahead_of_thigh_over_L']*L
    out=math.radians(p['far_upper_out_degrees']);flex=math.radians(p['far_elbow_bend_degrees'])
    def axes(pitch):
        a=np.array([math.cos(out)*math.sin(pitch),-math.sin(out),-math.cos(out)*math.cos(pitch)])
        b=np.array([1.,0,0])-a*a[0];b/=np.linalg.norm(b)
        return a,a*math.cos(flex)+b*math.sin(flex)
    shoulder=np.array(j['shoulder_far']);upper=c['upper_length_px']*u;lower=c['fore_length_px']*u
    lo,hi=map(math.radians,NUMERICAL_DEFAULTS['forward_search_degrees'])
    for _ in range(NUMERICAL_DEFAULTS['constraint_iterations']):
        mid=(lo+hi)/2;a,b=axes(mid)
        if shoulder[0]+upper*a[0]+lower*b[0]<target:lo=mid
        else:hi=mid
    a,b=axes((lo+hi)/2);elbow=shoulder+upper*a;hand=elbow+lower*b
    j['elbow_far']=elbow.tolist();j['hand_far']=hand.tolist()
    for side in ('near','far'):j['hand_tip_'+side]=(np.asarray(j['hand_'+side])+[0,0,-c['hand_length_px']*u]).tolist()
    return j,shear


def solve(c,p,H,L,u,d):
    width=c['shoulder_width_px']*u
    j,shear=_solve(c,p,H,L,u,width,d)
    if j['elbow_near'][0]>j['shoulder_near'][0]:
        # Feedback 1 changes the near bend from forward to outward. Preserve
        # its inherited down/out pole and no-forward-elbow rule: the closest
        # admissible shoulder bar puts the near shoulder in the fist's X plane.
        lo,hi=c['hip_width_px']*u,width
        for _ in range(NUMERICAL_DEFAULTS['constraint_iterations']):
            mid=(lo+hi)/2;candidate,_=_solve(c,p,H,L,u,mid,d)
            if candidate['shoulder_near'][0]>candidate['hand_near'][0]:lo=mid
            else:hi=mid
        j,shear=_solve(c,p,H,L,u,(lo+hi)/2,d)
    return j,shear
