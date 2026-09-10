"""Grave Surgeon v01: explicit source ownership and concealed material recipe.

This recipe is case-owned. It uses the maintained segment/skin commands, never a
historical character builder. Run with a fresh --pass-name after recipe edits.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

CASE = Path(__file__).resolve().parents[1]
ROOT = CASE.parents[3]


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n")


FRONT = [
    ["hand_saw", [[113,120],[131,120],[135,126],[129,135],[124,140],[118,144],[111,141],[106,138],[106,130],[110,123]]],
    ["saw", [[55,157],[95,134],[96,125],[108,126],[111,138],[124,144],[121,157],[115,161],[83,203],[55,199]]],
    ["vial", [[197,131],[204,130],[213,131],[216,141],[210,148],[199,150],[193,139]]],
    ["vial", [[211,111],[216,110],[219,113],[219,116],[216,119],[211,118]]],
    ["vial", [[208,119],[211,119],[214,121],[214,122],[211,122],[207,121]]],
    ["vial", [[201,129],[206,129],[207,133],[201,135]]],
    ["hand_vial", [[200,110],[220,109],[224,120],[224,132],[217,140],[211,135],[199,134],[197,123]]],
    ["sleeve_saw", [[123,100],[136,99],[141,104],[138,112],[132,120],[130,125],[112,124],[109,118]]],
    ["sleeve_vial", [[191,90],[199,86],[210,90],[218,101],[219,112],[211,117],[201,121],[194,109],[187,98]]],
    ["foot_r", [[104,193],[121,191],[143,190],[146,204],[125,210],[103,208]]],
    ["foot_l", [[186,198],[209,197],[214,212],[203,220],[185,217]]],
    ["leg_r", [[124,179],[137,180],[141,185],[144,193],[137,197],[121,196],[120,186]]],
    ["leg_l", [[191,183],[200,181],[204,187],[208,196],[205,201],[188,202],[187,191]]],
    ["hood", [[116,20],[169,20],[180,51],[189,58],[178,65],[173,75],[165,84],[154,89],[142,91],[130,88],[116,93],[120,77],[120,65]]],
    ["belt_kit", [[176,106],[190,107],[193,116],[199,121],[198,140],[189,148],[177,146],[172,137],[173,123]]],
    ["torso", [[122,86],[144,90],[166,82],[176,55],[194,58],[212,87],[201,91],[190,98],[194,105],[192,119],[181,130],[158,130],[136,130],[137,112],[133,103],[121,101]]],
    ["robe", [[136,120],[171,122],[181,130],[201,137],[211,157],[222,186],[218,198],[187,199],[164,199],[145,198],[132,190],[110,188],[112,164],[120,142],[128,132]]],
]

REAR = [
    ["hand_saw", [[195,128],[208,128],[212,137],[209,143],[204,145],[197,141],[192,134]]],
    ["saw", [[210,127],[224,132],[226,141],[235,149],[247,162],[260,173],[260,198],[237,198],[210,162],[199,156],[202,146],[209,139]]],
    ["vial", [[125,106],[130,105],[133,109],[130,112],[130,115],[134,119],[135,124],[129,129],[120,127],[117,120],[120,116],[124,114]]],
    ["hand_vial", [[116,102],[130,103],[134,108],[134,115],[125,119],[116,116],[114,108]]],
    ["sleeve_saw", [[185,99],[195,97],[203,103],[209,117],[214,132],[204,139],[190,133],[187,119],[180,110]]],
    ["sleeve_vial", [[125,79],[136,77],[143,85],[138,92],[134,100],[134,106],[128,108],[119,113],[113,104],[117,93],[118,87]]],
    ["foot_l", [[124,178],[143,175],[153,178],[153,190],[138,196],[124,197]]],
    ["foot_r", [[184,198],[203,193],[218,196],[223,205],[204,214],[184,217]]],
    ["leg_l", [[132,169],[141,166],[144,175],[140,182],[128,184]]],
    ["leg_r", [[188,181],[200,180],[204,188],[205,198],[197,205],[184,201],[185,189]]],
    ["hood", [[148,46],[158,35],[175,22],[197,36],[201,48],[199,67],[196,73],[188,69],[176,64],[166,66],[154,61],[149,57]]],
    ["belt_kit", [[139,96],[148,96],[151,104],[157,106],[153,120],[150,131],[145,137],[136,134],[131,126],[134,112]]],
    ["torso", [[144,57],[155,56],[176,64],[188,66],[200,75],[200,82],[205,92],[205,99],[195,97],[184,104],[185,114],[161,122],[143,116],[137,97],[128,85],[126,75],[135,64]]],
    ["robe", [[145,112],[183,111],[192,125],[201,141],[207,160],[217,190],[209,197],[185,193],[175,196],[168,186],[157,193],[146,186],[139,180],[119,174],[118,162],[128,138]]],
]


def joints(facing):
    if facing == "front":
        positions = {
            "pelvis": [162,124], "torso": [162,103], "hood": [152,78], "robe": [160,126],
            "upper_saw": [137,100], "fore_saw": [128,111], "wrist_saw": [123,125], "saw": [112,137],
            "upper_vial": [187,88], "fore_vial": [201,108], "wrist_vial": [209,122], "vial": [206,136],
            "thigh_r": [146,144], "shin_r": [135,171], "foot_r": [133,194],
            "thigh_l": [178,145], "shin_l": [191,178], "foot_l": [198,201],
        }
    else:
        positions = {
            "pelvis": [162,115], "torso": [164,94], "hood": [180,61], "robe": [162,116],
            "upper_saw": [184,94], "fore_saw": [195,116], "wrist_saw": [203,134], "saw": [209,140],
            "upper_vial": [136,86], "fore_vial": [126,99], "wrist_vial": [124,111], "vial": [125,118],
            "thigh_r": [179,136], "shin_r": [190,168], "foot_r": [194,200],
            "thigh_l": [149,130], "shin_l": [138,157], "foot_l": [135,179],
        }
    parents = {"pelvis":"root", "torso":"pelvis", "hood":"torso", "robe":"pelvis"}
    for arm in ["saw","vial"]:
        parents.update({"upper_"+arm:"torso", "fore_"+arm:"upper_"+arm, "wrist_"+arm:"fore_"+arm, arm:"wrist_"+arm})
    for side in ["r","l"]:
        parents.update({"thigh_"+side:"pelvis", "shin_"+side:"thigh_"+side, "foot_"+side:"shin_"+side})
    return {"root":{"position":[0,0],"parent":None}, **{n:{"position":p,"parent":parents[n]} for n,p in positions.items()}}


def hidden_pieces(facing, source, output):
    # Only interior material is sampled; none of the RGB rear reference's
    # checkerboard is selected. Target masks stay underneath opaque original
    # paint at rest. Distinct hand/tool drawings are never supplied by these fills.
    original = Image.open(CASE / "source" / (facing+"_registered.png")).convert("RGBA")
    opaque = original.getchannel("A").point(lambda a: 255 if a == 255 else 0)
    if facing == "rear":
        # The selected generated rear has alpha 251-253 in its interior.
        # Use an inward-only silhouette mask; equality with 255 erased anatomy.
        opaque = original.getchannel("A").point(lambda a: 255 if a >= 245 else 0).filter(ImageFilter.MinFilter(3))
    if facing == "front":
        specs = [
            ("hip_fill", [682,610,816,711], [[142,121],[177,121],[186,142],[176,153],[156,153],[135,143]], "pelvis", 3),
            ("thigh_fill_r", [607,735,673,816], [[137,137],[157,142],[148,166],[141,185],[126,183],[128,161]], "thigh_r", 0),
            ("thigh_fill_l", [824,736,885,820], [[171,138],[187,140],[197,166],[201,188],[185,192],[177,166]], "thigh_l", 0),
            ("sleeve_cap_saw", [613,438,651,485], [[132,93],[143,97],[142,104],[137,111],[128,105]], "upper_saw", 7),
            ("sleeve_cap_vial", [850,393,905,451], [[178,77],[191,81],[198,91],[191,101],[180,91]], "upper_vial", 7),
        ]
    else:
        specs = [
            ("hip_fill", [564,581,695,694], [[143,109],[179,108],[186,133],[173,145],[154,143],[137,132]], "pelvis", 3),
            ("thigh_fill_r", [711,759,759,816], [[171,128],[187,129],[197,157],[202,189],[185,193],[179,161]], "thigh_r", 0),
            ("thigh_fill_l", [545,724,590,777], [[142,123],[158,128],[150,149],[143,174],[127,174],[131,148]], "thigh_l", 0),
            ("sleeve_cap_saw", [691,390,736,441], [[177,86],[190,88],[198,98],[194,108],[181,101]], "upper_saw", 7),
            ("sleeve_cap_vial", [474,410,518,451], [[130,76],[141,81],[144,88],[133,96],[125,88]], "upper_vial", 7),
        ]
    parts, records = [], []
    paint = Image.open(source).convert("RGBA")
    for name, crop, polygon, bone, layer in specs:
        mask = Image.new("L", (255,255));ImageDraw.Draw(mask).polygon([tuple(p) for p in polygon],fill=255)
        mask = ImageChops.multiply(mask,opaque)
        bbox=mask.getbbox(); assert bbox
        patch=paint.crop(crop).resize((bbox[2]-bbox[0],bbox[3]-bbox[1]),Image.Resampling.LANCZOS)
        # The selected sources are deliberately internal brown cloth, including
        # the rear source where outer-background extraction was unsuccessful.
        pixels=[p for p,m in zip(patch.getdata(),mask.crop(bbox).getdata()) if m]
        neutral=sum(1 for r,g,b,a in pixels if min(r,g,b)>90 and max(r,g,b)-min(r,g,b)<8)
        assert neutral == 0, (name,"background-like pixel in selected cloth",neutral)
        assert len(pixels) > 40, (name,"concealed surface unexpectedly discarded",len(pixels))
        patch.putalpha(ImageChops.multiply(patch.getchannel("A"),mask.crop(bbox)))
        path=output/(name+".png");patch.save(path)
        parts.append({"name":name,"file":str(path.relative_to(CASE)),"offset":list(bbox[:2]),"bone":bone,"z_index":layer,"equipment_slot":"legs" if name.startswith("thigh") or name == "hip_fill" else "arms"})
        records.append({"part":name,"source":str(source.relative_to(CASE)),"source_crop":crop,"target_polygon":polygon,"target_bbox":list(bbox),"registration":"Explicit local width/length fit of generated interior cloth; front clipped under alpha-255 paint, rear under eroded alpha-at-least-245 interior at rest.","selected_pixels":len(pixels),"checkerboard_pixels":neutral})
    return parts, records


def main():
    parser=argparse.ArgumentParser();parser.add_argument("--pass-name",required=True);args=parser.parse_args()
    provenance=[]
    for facing, polygons in [("front",FRONT),("rear",REAR)]:
        overrides=[]
        if facing == "front":
            # Inspected antialiased edges in the source's narrow sleeve gaps.
            for name, points in {
                "sleeve_vial":[[194,110],[194,111],[194,112],[194,114],[195,115],[194,116],[195,116],[196,117],[197,118]],
                "sleeve_saw":[[136,116],[135,117],[136,117],[134,118],[136,118],[135,119],[133,120],[134,120]],
                "hand_saw":[[109,121],[108,122],[109,122],[110,122],[108,123],[109,123],[107,124],[108,125]],
            }.items():
                overrides.extend({"point":point,"name":name} for point in points)
        else:
            overrides=[{"point":[197,98],"name":"torso"}]
        ownership=CASE/"source"/(facing+"_ownership.json");write(ownership,{"priority_polygons":polygons,"pixel_overrides":overrides})
        out=CASE/"segmented"/(facing+"_"+args.pass_name)
        result=subprocess.run([sys.executable,str(ROOT/"tools/cutout_workflow.py"),"segment","--source",str(CASE/"source"/(facing+"_registered.png")),"--ownership",str(ownership),"--output",str(out)],capture_output=True,text=True)
        report=json.loads((out/"segmentation.json").read_text())
        print(facing,"unassigned:",report["unassigned_pixels"],"report:",out/"segmentation.json")
        if result.returncode:
            raise SystemExit(result.returncode)
        binding={"hand_saw":("wrist_saw",16,"hands"),"saw":("saw",15,"weapon"),"vial":("vial",17,"offhand"),"hand_vial":("wrist_vial",18,"hands"),"sleeve_saw":("upper_saw",10,"arms"),"sleeve_vial":("upper_vial",10,"arms"),"hood":("hood",22,"head"),"belt_kit":("torso",21,"belt"),"torso":("torso",20,"chest"),"robe":("robe",12,"cloak"),"leg_r":("thigh_r",2,"legs"),"leg_l":("thigh_l",2,"legs"),"foot_r":("foot_r",3,"boots"),"foot_l":("foot_l",3,"boots")}
        parts=[]
        for p in report["parts"]:
            bone,z,slot=binding[p["name"]]
            parts.append({**p,"file":str((out/p["file"]).relative_to(CASE)),"bone":bone,"z_index":z,"equipment_slot":slot})
        hidden=CASE/"assets"/(facing+"_"+args.pass_name);hidden.mkdir(parents=True)
        source=CASE/"source"/("front_underbody_alpha.png" if facing=="front" else "rear_underbody_v3_generated.png")
        extra,records=hidden_pieces(facing,source,hidden);parts+=extra;provenance+=records
        joint_map=joints(facing)
        layout={"canvas_size":[255,255],"facing":facing,"joints":joint_map,"parts":parts,"landmarks":{"sole_r":[129,202] if facing=="front" else [197,211],"sole_l":[198,212] if facing=="front" else [136,189],"weapon_grip":joint_map["saw"]["position"],"vial_grip":joint_map["vial"]["position"]}}
        layout_name="layouts/"+facing+"_"+args.pass_name+".json";write(CASE/layout_name,layout)
        fields=[]
        for side in ["r","l"]:
            fields.append({"name":facing+"_leg_"+side,"parts":["leg_"+side,"thigh_fill_"+side],"bones":["thigh_"+side,"shin_"+side,"foot_"+side],"grid":[2,1],"bands":[{"center":joint_map["shin_"+side]["position"],"axis":[0,1],"width":16},{"center":[joint_map["foot_"+side]["position"][0],joint_map["foot_"+side]["position"][1]-4],"axis":[0,1],"width":10}]})
        for arm in ["saw","vial"]:
            start=joint_map["upper_"+arm]["position"];end=joint_map["wrist_"+arm]["position"];axis=[end[0]-start[0],end[1]-start[1]]
            fields.append({"name":facing+"_sleeve_"+arm,"parts":["sleeve_"+arm,"sleeve_cap_"+arm],"bones":["upper_"+arm,"fore_"+arm,"wrist_"+arm],"grid":[1,1],"bands":[{"center":joint_map["fore_"+arm]["position"],"axis":axis,"width":10},{"center":end,"axis":axis,"width":6}]})
        recipe=CASE/"recipes"/(facing+"_"+args.pass_name+"_skin.json")
        write(recipe,{"facing":facing,"input_layout":layout_name,"output_layout":"layouts/"+facing+"_"+args.pass_name+"_skinned.json","fields":fields})
        subprocess.run([sys.executable,str(ROOT/"tools/cutout_workflow.py"),"skin",str(CASE),"--recipe",str(recipe)],check=True)
    write(CASE/"recipes"/"hidden_material.json",provenance)
    for image in CASE.rglob("*.png"):
        Path(str(image)+".import").write_text('[remap]\n\nimporter="keep"\n')
    config=json.loads((CASE/"cutout.json").read_text())
    config.update({"rigid_bones":["hood","wrist_saw","saw","wrist_vial","vial","foot_r","foot_l"],"contact_feet":["foot_r","foot_l"],"source_baseline":{"kind":"new_character","art_status":"original front preserved; generated rear and selected concealed cloth"},"clips":{"idle":{"frames":24,"duration":1.8,"loop":True,"preview_cycles":2},"walk":{"frames":32,"duration":0.68,"loop":True,"preview_cycles":2,"travel":"motion"},"attack":{"frames":40,"duration":0.70,"loop":False},"treat":{"frames":24,"duration":0.48,"loop":False},"ward":{"frames":24,"duration":0.48,"loop":False}},"draw_order_parts":{f:["Skin_leg_r","Skin_thigh_fill_r","foot_r","Skin_leg_l","Skin_thigh_fill_l","foot_l"] for f in ["front","rear"]}})
    config["sources"]=sorted(set(config.get("sources",[])+[str(p.relative_to(CASE)) for folder in ["source","recipes"] for p in (CASE/folder).rglob("*") if p.is_file() and p.suffix in [".png",".json",".py"]]))
    write(CASE/"cutout.json",config)


if __name__ == "__main__":
    main()
