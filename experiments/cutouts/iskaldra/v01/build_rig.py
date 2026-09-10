"""Assemble the explicitly segmented dragon and small generated joint fills.

Visible paint is copied without retouching. Concealed material is a uniformly
sampled crop of generated scaled body paint, selected by recorded source-space
polygons and clipped beneath fully opaque accepted rest pixels.
"""
from pathlib import Path
import json
import hashlib
import shutil
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n")


JOINTS = {
    "front": {
        "root": ([128,180], None), "pelvis": ([142,154], "root"),
        "torso": ([126,128], "pelvis"), "head": ([101,100], "torso"),
        "wing_near": ([138,128], "torso"), "wing_far": ([96,89], "torso"),
        "arm_near": ([148,137], "torso"), "talon_near": ([129,178], "arm_near"),
        "arm_far": ([93,131], "torso"), "talon_far": ([63,166], "arm_far"),
        "hip_near": ([173,147], "pelvis"), "knee_near": ([167,168], "hip_near"),
        "foot_near": ([170,181], "knee_near"),
        "hip_far": ([119,155], "pelvis"), "knee_far": ([111,170], "hip_far"),
        "foot_far": ([105,179], "knee_far"), "tail": ([188,143], "pelvis"),
    },
    "rear": {
        "root": ([128,180], None), "pelvis": ([137,149], "root"),
        "torso": ([138,123], "pelvis"), "head": ([155,66], "torso"),
        "wing_near": ([115,105], "torso"), "wing_far": ([172,105], "torso"),
        "arm_near": ([95,135], "torso"), "talon_near": ([70,177], "arm_near"),
        "arm_far": ([181,128], "torso"), "talon_far": ([202,149], "arm_far"),
        "hip_near": ([165,149], "pelvis"), "knee_near": ([153,168], "hip_near"),
        "foot_near": ([166,182], "knee_near"),
        "hip_far": ([127,151], "pelvis"), "knee_far": ([124,168], "hip_far"),
        "foot_far": ([124,176], "knee_far"), "tail": ([126,149], "pelvis"),
    },
}

FILLS = {
    "front": [
        ("neck_socket", "torso", [(91,92),(105,90),(112,101),(105,122),(90,127),(83,114)]),
        ("wing_socket_near", "torso", [(130,117),(147,115),(160,131),(150,147),(131,141),(123,130)]),
        ("wing_socket_far", "torso", [(86,79),(105,80),(112,95),(100,107),(86,99)]),
        ("arm_socket_near", "arm_near", [(140,125),(154,125),(162,139),(152,152),(137,145)]),
        ("arm_socket_far", "arm_far", [(85,122),(100,122),(104,135),(95,146),(81,140)]),
        ("hip_fill_near", "hip_near", [(166,140),(181,137),(190,150),(177,169),(160,166),(157,151)]),
        ("hip_fill_far", "hip_far", [(107,147),(122,145),(133,157),(127,174),(111,178),(100,165)]),
        ("tail_socket", "pelvis", [(180,134),(196,137),(199,153),(187,164),(176,151)]),
    ],
    "rear": [
        ("pelvic_bridge", "pelvis", [(136,128),(164,128),(175,138),(174,154),(143,156),(136,145)]),
        ("neck_socket", "torso", [(142,55),(162,53),(173,67),(162,83),(141,81),(136,67)]),
        ("wing_socket_near", "torso", [(102,96),(116,90),(132,104),(125,120),(108,124),(97,111)]),
        ("wing_socket_far", "torso", [(159,95),(176,94),(187,110),(178,124),(161,119),(153,108)]),
        ("arm_socket_near", "arm_near", [(86,127),(101,124),(108,140),(98,151),(82,143)]),
        ("arm_socket_far", "arm_far", [(171,120),(184,118),(195,133),(188,146),(173,139)]),
        ("hip_fill_near", "hip_near", [(149,142),(169,138),(178,151),(166,170),(149,175),(139,160)]),
        ("hip_fill_far", "hip_far", [(116,144),(132,144),(139,156),(133,173),(118,176),(109,161)]),
        ("tail_socket", "pelvis", [(115,140),(131,135),(145,147),(138,162),(119,168),(110,155)]),
    ],
}


def main():
    raw = ROOT / "source/hidden_body_generated.png"
    if not raw.exists():
        raise SystemExit("Missing retained ImageGen source: " + str(raw))
    # Opaque interior torso scales only. The RGB checker background is rejected
    # and never selected; no alpha reconstruction from the checker is attempted.
    crop_box = [622,568,782,728]
    patch = Image.open(raw).convert("RGBA").crop(crop_box).resize((40,40), Image.Resampling.LANCZOS)
    patch.save(ROOT / "source/hidden_scale_patch.png")
    hidden_recipe = {"source":"source/hidden_body_generated.png", "source_crop":crop_box,
                     "scale":0.25,"patch_size":[40,40],"resample":"Lanczos",
                     "selected_material":"opaque interior cobalt torso scales; no background pixels",
                     "registration":"one-to-one patch pixels into explicit native overlap polygons; no stretching",
                     "rest_constraint":"front only alpha 255; rear alpha >=250 (generator interiors are alpha 253); all fills below visible paint", "facings":{}}
    for facing, graph in JOINTS.items():
        registered = Image.open(ROOT / f"source/{facing}_registered.png").convert("RGBA")
        segmentation = json.loads((ROOT / f"segmented/{facing}/segmentation.json").read_text())
        assert segmentation["ok"]
        joints = {n:{"position":p,"parent":parent} for n,(p,parent) in graph.items()}
        z = {"wing_far":0,"arm_far":2,"talon_far":3,"leg_far":4,"foot_far":5,
             "torso":8,"head":10,"leg_near":9,"foot_near":10,"wing_near":12,
             "arm_near":14,"talon_near":15,"tail":16}
        if facing == "rear":
            z.update({"head":0,"wing_far":4,"arm_far":6,"talon_far":7,"wing_near":12})
        parts = []
        for p in segmentation["parts"]:
            n = p["name"]
            parts.append({"name":n,"file":f"segmented/{facing}/{p['file']}","offset":p["offset"],
                          "bone":n.replace("leg_","hip_"),"z_index":z[n]})
        hidden_recipe["facings"][facing] = []
        for n,bone,polygon in FILLS[facing]:
            mask = Image.new("1",(255,255));ImageDraw.Draw(mask).polygon(polygon,fill=1)
            # A patch may be shared between sockets, but every destination and
            # selected source pixel is determined by this retained recipe.
            x0=min(p[0] for p in polygon);y0=min(p[1] for p in polygon)
            x1=max(p[0] for p in polygon)+1;y1=max(p[1] for p in polygon)+1
            assert x1-x0 <= 40 and y1-y0 <= 40
            image=Image.new("RGBA",(x1-x0,y1-y0))
            for y in range(y0,y1):
                for x in range(x0,x1):
                    if mask.getpixel((x,y)) and registered.getpixel((x,y))[3] >= (255 if facing == "front" else 250):
                        image.putpixel((x-x0,y-y0),patch.getpixel((x-x0,y-y0)))
            path=ROOT/f"assets/{facing}/{n}.png";path.parent.mkdir(parents=True,exist_ok=True);image.save(path)
            parts.append({"name":n,"file":str(path.relative_to(ROOT)),"offset":[x0,y0],"bone":bone,"z_index":-5})
            hidden_recipe["facings"][facing].append({"name":n,"bone":bone,"polygon":polygon,
                                                     "offset":[x0,y0],"selected_pixels":sum(a>0 for a in image.getchannel('A').getdata())})
        landmarks = {"sole_near":[170,195],"sole_far":[105,187],"maw":[65,144]} if facing == "front" else {"sole_near":[172,194],"sole_far":[127,185],"maw":[170,59]}
        layout={"canvas_size":[255,255],"facing":facing,"joints":joints,"parts":parts,"landmarks":landmarks}
        write(ROOT/f"layouts/{facing}.json",layout)
        fields=[]
        for side in ["near","far"]:
            knee=graph[f"knee_{side}"][0];foot=graph[f"foot_{side}"][0]
            fields.append({"name":f"{facing}_hind_{side}","parts":[f"leg_{side}",f"hip_fill_{side}"],
                           "bones":[f"hip_{side}",f"knee_{side}",f"foot_{side}"],"grid":[2,1],
                           "bands":[{"center":knee,"axis":[0,1],"width":10},
                                    {"center":[foot[0],foot[1]-3],"axis":[0,1],"width":6}]})
        write(ROOT/f"recipes/{facing}_skin.json",{"facing":facing,"input_layout":f"layouts/{facing}.json",
                                                "output_layout":f"layouts/{facing}_skinned_v3.json","fields":fields})
    write(ROOT/"recipes/hidden_material.json",hidden_recipe)
    config=json.loads((ROOT/'cutout.json').read_text())
    config.update({"rigid_bones":["head","torso","wing_near","wing_far","arm_near","arm_far","talon_near","talon_far","foot_near","foot_far","tail"],
                   "contact_feet":["foot_near","foot_far"],
                   "source_baseline":{"kind":"new_character","art_status":"registered own dragon anatomy; accepted front bytes preserved"}})
    config['sources']=sorted(str(p.relative_to(ROOT)) for p in (ROOT/'source').glob('*') if p.is_file())
    config['sources'] += ['author.py','build_rig.py','capture.py','promote.py','recipes/hidden_material.json','recipes/front_skin.json','recipes/rear_skin.json']
    write(ROOT/'cutout.json',config)


if __name__ == '__main__':
    main()
