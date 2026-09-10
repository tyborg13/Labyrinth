"""Explicit Cinder Droplet v01 ownership, anatomy and shared mesh recipes.

Run after register_sources.py. The maintained cutout workflow owns actual
segmentation and mesh construction. This task-specific recipe copies paint.
"""
from pathlib import Path
import hashlib
import json
import math
import shutil
import subprocess
import sys
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
CASE = Path(__file__).resolve().parent / "v01"


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n")


def smooth(value):
    t = min(1.0,max(0.0,value))
    return t*t*(3.0-2.0*t)


def distance_to_chain(point, points):
    result = 1000.0
    for a,b in zip(points,points[1:]):
        dx,dy=b[0]-a[0],b[1]-a[1]
        t=min(1.0,max(0.0,((point[0]-a[0])*dx+(point[1]-a[1])*dy)/(dx*dx+dy*dy)))
        result=min(result,math.hypot(point[0]-a[0]-dx*t,point[1]-a[1]-dy*t))
    return result


def shared_weights(point, chains, view):
    # A single material field across all adjoining pieces keeps the molten web
    # continuous. The cap and face are exactly rigid above the flesh transition.
    x,y=point
    body = 1.0-smooth((y-(166 if view=='front' else 150))/18.0)
    result={"core":body}
    strengths={n:1.0/(distance_to_chain(point,p)+5.0)**6 for n,p in chains.items()}
    total=sum(strengths.values())
    for name,(base,bend,tip) in chains.items():
        values=[1.0]
        for center,axis,width in [(bend,[tip[0]-base[0],tip[1]-base[1]],14),([tip[0]-(tip[0]-bend[0])*.15,tip[1]-(tip[1]-bend[1])*.15],[tip[0]-bend[0],tip[1]-bend[1]],8)]:
            factor=smooth(((x-center[0])*axis[0]+(y-center[1])*axis[1])/math.hypot(*axis)/width+.5)
            values=[v*(1-factor) for v in values]+[factor]
        for suffix,value in zip(['base','bend','tip'],values):
            result[name+'_'+suffix]=value*strengths[name]/total*(1-body)
    # The actual painted toe, not merely its bone origin, is rigid. A shared
    # six-pixel contact patch blends back into the same material field over
    # four pixels, so every adjoining mesh still uses identical weights.
    nearest=min(chains,key=lambda n:math.dist(point,chains[n][-1]))
    distance=math.dist(point,chains[nearest][-1])
    terminal=1.0-smooth((distance-6.0)/4.0)
    if terminal:
        result={name:value*(1.0-terminal) for name,value in result.items()}
        result[nearest+'_tip']=result.get(nearest+'_tip',0.0)+terminal
    return result


def continuous_meshes(layout, chains, view):
    # Shared globally aligned two-pixel topology. Transparent crop expansion
    # preserves all source RGB/alpha and makes adjoining interpolation identical.
    sys.path.insert(0,str(ROOT/'tools'))
    from cutout_pipeline.assets import skin_mesh
    layout['parts']=[p for p in layout['parts'] if p['name']!='hidden_belly']
    layout['joint_meshes']=[]
    for part in layout['parts']:
        raw=Image.open(CASE/part['file'])
        x0,y0=part['offset']; x1,y1=x0+raw.width,y0+raw.height
        box=[2*(x0//2),2*(y0//2),2*math.ceil(x1/2),2*math.ceil(y1/2)]
        paint=Image.new('RGBA',(box[2]-box[0],box[3]-box[1]));paint.paste(raw,(x0-box[0],y0-box[1]))
        part['file']='assets/'+view+'/'+part['name']+'.png';part['offset']=box[:2]
        paint.save(CASE/part['file'])
        mesh=skin_mesh(part,paint.size,{'name':view+'_molten_body','bones':['core'],'bands':[],'grid':[2,2]})
        mesh['weights']={name:[] for name in layout['joints'] if name!='root'}
        for point in mesh['vertices']:
            weights=shared_weights(point,chains,view)
            for name in mesh['weights']:
                mesh['weights'][name].append(round(weights.get(name,0.0),9))
        layout['joint_meshes'].append(mesh)
    layout['shared_material_field']='recipes/'+view+'_continuous_field.json'
    write(CASE/'recipes'/(view+'_continuous_field.json'),{'anatomy':chains,'global_grid':[2,2],'field':'Same source-space weights for every painted part. Rigid core above 166 front / 150 rear, 18px smooth flesh transition. Below, inverse-sixth-power distance to the five registered tendril chains, radius 5px; each chain blends base/bend/terminal over 14px/8px. Registered toe contact patches are rigid within 6px and blend into the common field over 4px. No frame-dependent pixel edits.','hidden_paint_disposition':'Generated belly retained but not selected: the coherent shared mesh preserves the complete original molten surface without exposed cut seams.','recipe':'recipes/author_rig.py:shared_weights'})


def main():
    # Each polygon follows one visible tendril or coherent small tendril bundle.
    # The core owns all cap, facial crust and the central molten belly.
    polygons = {
        "front": [
            ["left_outer", [[69,163],[77,165],[78,177],[76,185],[70,193],[61,199],[51,203],[40,203],[39,197],[47,193],[59,191],[65,184],[67,174]]],
            ["left_inner", [[90,167],[98,169],[96,180],[95,191],[95,199],[101,206],[99,213],[83,214],[74,211],[74,205],[82,199],[87,191],[86,179]]],
            ["center", [[123,171],[130,171],[132,190],[138,199],[143,204],[141,211],[126,214],[118,210],[120,202],[124,194],[122,185]]],
            ["right_inner", [[141,155],[151,156],[155,172],[158,186],[166,199],[175,205],[179,210],[174,216],[162,217],[153,211],[149,201],[143,190],[140,177]]],
            ["right_outer", [[163,144],[177,152],[177,159],[184,170],[189,177],[202,181],[206,185],[201,193],[191,194],[186,192],[190,198],[185,203],[174,204],[167,195],[162,182],[160,168]]],
        ],
        "rear": [
            ["left_outer", [[85,139],[97,142],[88,158],[85,174],[79,184],[73,191],[66,201],[39,201],[39,166],[70,163]]],
            ["left_inner", [[112,148],[124,152],[113,173],[106,188],[91,202],[74,208],[68,209],[67,197],[84,184],[100,163]]],
            ["center", [[126,164],[138,166],[138,192],[145,214],[145,222],[94,222],[94,205],[112,192]]],
            ["right_inner", [[139,142],[152,143],[153,163],[161,184],[177,207],[176,219],[145,220],[136,203],[136,184]]],
            ["right_outer", [[159,143],[178,146],[183,164],[200,180],[220,181],[222,208],[177,213],[173,195],[166,175]]],
        ]
    }
    joints_by_view = {
        "front": {
            "left_outer": [[74,168],[68,185],[48,199]],
            "left_inner": [[94,172],[90,191],[85,209]],
            "center": [[124,173],[128,190],[132,208]],
            "right_inner": [[144,157],[151,184],[166,210]],
            "right_outer": [[168,151],[177,175],[196,190]],
        },
        "rear": {
            "left_outer": [[89,145],[79,172],[52,192]],
            "left_inner": [[116,154],[101,177],[81,201]],
            "center": [[131,168],[126,189],[108,211]],
            "right_inner": [[146,148],[145,177],[162,210]],
            "right_outer": [[170,151],[178,172],[199,195]],
        }
    }
    config = json.loads((CASE / "cutout.json").read_text())
    config["layouts"] = {v: "layouts/"+v+"_skinned.json" for v in polygons}
    config["clips"] = {
        "idle": {"frames": 24, "duration": 1.5, "loop": True, "preview_cycles": 2},
        "walk": {"frames": 40, "duration": .34, "loop": True, "preview_cycles": 3, "travel": "motion"},
        "attack": {"frames": 41, "duration": .60, "loop": False,"phase_curve":[[0,0],[.30,.30],[.37,.38],[.42,.52],[.62,.68],[1,1]]},
        "retreat": {"frames":40,"duration":.34,"loop":True,"preview_cycles":3},
    }
    config["rigid_bones"] = ["core"] + [n+"_tip" for n in joints_by_view["front"]]
    config["contact_feet"] = [n+"_tip" for n in joints_by_view["front"]]
    config["source_baseline"] = {"kind": "new_character", "art_status": "accepted front retained; new matching rear with explicit matte; generated concealed belly retained but unselected", "front_original_sha256": hashlib.sha256((CASE/"source/front_original.png").read_bytes()).hexdigest()}
    config["sources"] = []
    write(CASE / "cutout.json", config)
    for view, entries in polygons.items():
        source = Image.open(CASE / "source" / (view+"_registered.png"))
        ownership = {"priority_polygons": entries + [["core", [[0,0],[254,0],[254,254],[0,254]]]], "pixel_overrides": []}
        # Lower contour edges and little painted drops follow their tendril's
        # material field, never a leftover rigid torso strip. Keep the central
        # front belly as its own semantic core region.
        for y in range(184,255):
            for x in range(255):
                if not source.getpixel((x,y))[3]:
                    continue
                if view=='front' and 99<=x<=122 and y<=201:
                    continue
                closest=min(joints_by_view[view],key=lambda n:distance_to_chain((x,y),joints_by_view[view][n]))
                ownership['pixel_overrides'].append({'point':[x,y],'name':closest})
        write(CASE / "source" / (view+"_ownership.json"), ownership)
        segmented = CASE / "segmented" / view
        if segmented.exists():
            shutil.rmtree(segmented) # Only this recipe's explicitly generated outputs.
        subprocess.run([sys.executable, str(ROOT/"tools/cutout_workflow.py"), "segment", "--source", str(CASE/"source"/(view+"_registered.png")), "--ownership", str(CASE/"source"/(view+"_ownership.json")), "--output", str(segmented)], check=True, stdout=subprocess.DEVNULL)
        layout = {"canvas_size": [255,255], "facing": view, "joints": {"root": {"position": [128,200], "parent": None}, "core": {"position": [125,152], "parent": "root"}}, "parts": [], "landmarks": {}}
        for name, points in joints_by_view[view].items():
            parent = "core"
            for suffix, point in zip(["base","bend","tip"], points):
                joint = name+"_"+suffix
                layout["joints"][joint] = {"position": point, "parent": parent}
                parent = joint
            layout["landmarks"][name+"_support"] = points[-1]
        report = json.loads((segmented/"segmentation.json").read_text())
        for part in report["parts"]:
            name = part["name"]
            part["file"] = "segmented/"+view+"/"+part["file"]
            part["bone"] = "core" if name == "core" else name+"_base"
            part["z_index"] = 12 if name == "core" else 10
            part["equipment_slot"] = "core_and_cap" if name == "core" else "tendril"
            layout["parts"].append(part)
        # Concealed material is selected only below FULLY opaque source pixels.
        # It cannot change neutral RGB/alpha, including antialiased source edges.
        generated = Image.open(CASE/"source/hidden_belly_registered.png")
        belly_polygon = [[94,166],[112,161],[136,164],[149,171],[155,181],[151,192],[140,199],[111,198],[95,193],[87,185],[88,174]]
        mask = Image.new("1", (255,255))
        ImageDraw.Draw(mask).polygon(belly_polygon, fill=1)
        belly = Image.new("RGBA", (255,255))
        for y in range(255):
            for x in range(255):
                if mask.getpixel((x,y)) and source.getpixel((x,y))[3] == 255:
                    r,g,b,a = generated.getpixel((x,y))
                    # Only the generated interior; flat magenta is never owned.
                    if a and not (r > 200 and b > 200 and g < 80):
                        belly.putpixel((x,y),(r,g,b,255))
        destination = CASE/"assets"/view
        destination.mkdir(parents=True, exist_ok=True)
        bbox = belly.getbbox()
        belly.crop(bbox).save(destination/"hidden_belly.png")
        layout["parts"].append({"name":"hidden_belly", "file":"assets/"+view+"/hidden_belly.png", "offset":list(bbox[:2]), "bone":"core", "z_index":0, "equipment_slot":"concealed_core"})
        write(CASE/"recipes"/(view+"_hidden_ownership.json"), {"polygon":belly_polygon,"alpha_rule":"Selected only where accepted registered source alpha is 255; no source pixel repainting.","source":"source/hidden_belly_registered.png","part":"hidden_belly","bbox":bbox})
        write(CASE/"layouts"/(view+".json"),layout)
        fields = []
        for name, points in joints_by_view[view].items():
            base, bend, tip = points
            fields.append({"name": view+"_"+name, "parts":[name],"bones":["core",name+"_base",name+"_bend",name+"_tip"],"grid":[2,1],"bands":[{"center":[base[0]+(bend[0]-base[0])*.35,base[1]+(bend[1]-base[1])*.35],"axis":[bend[0]-base[0],bend[1]-base[1]],"width":18},{"center":bend,"axis":[tip[0]-base[0],tip[1]-base[1]],"width":14},{"center":[tip[0]-(tip[0]-bend[0])*.15,tip[1]-(tip[1]-bend[1])*.15],"axis":[tip[0]-bend[0],tip[1]-bend[1]],"width":8}]})
        recipe = {"facing":view,"input_layout":"layouts/"+view+".json","output_layout":"layouts/"+view+"_skinned.json","fields":fields}
        recipe_path = CASE/"recipes"/(view+"_skinned.skin.json")
        write(recipe_path,recipe)
        (CASE/"layouts"/(view+"_skinned.json")).unlink(missing_ok=True)
        subprocess.run([sys.executable,str(ROOT/"tools/cutout_workflow.py"),"skin",str(CASE),"--recipe",str(recipe_path)],check=True,stdout=subprocess.DEVNULL)
        skinned_path=CASE/'layouts'/(view+'_skinned.json')
        skinned=json.loads(skinned_path.read_text())
        continuous_meshes(skinned,joints_by_view[view],view)
        write(skinned_path,skinned)
    config = json.loads((CASE/"cutout.json").read_text())
    config["sources"] = sorted(set(config["sources"]+[str(p.relative_to(CASE)) for folder in ["source","recipes"] for p in (CASE/folder).rglob("*") if p.is_file() and not p.name.endswith(".import")]))
    write(CASE/"cutout.json",config)
    for p in CASE.rglob("*.png"):
        Path(str(p)+".import").write_text('[remap]\n\nimporter="keep"\n')


if __name__ == "__main__":
    main()
