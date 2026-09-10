"""Current Frostglass Lancer v01 source ownership and rig authoring recipe.

Run semantic with a NEW revision name; outputs are never silently replaced.
All geometry uses the inspected registered 255px paint. Hidden paint is copied
from imagegen underpaintings; this recipe does not draw anatomy.
"""
from pathlib import Path
import json
import subprocess
import sys
from PIL import Image, ImageDraw

CASE = Path(__file__).resolve().parent
PROJECT = CASE.parents[3]

JOINTS = {
    "front": {
        "root": ([128, 128], None), "pelvis": ([116, 117], "root"),
        "torso": ([117, 95], "pelvis"), "head": ([116, 60], "torso"),
        "upper_r": ([96, 89], "torso"), "fore_r": ([87, 112], "upper_r"),
        "hand_r": ([65, 125], "fore_r"), "lance": ([61, 126], "hand_r"),
        "upper_l": ([149, 79], "torso"), "fore_l": ([158, 108], "upper_l"),
        "hand_l": ([153, 142], "fore_l"),
        "thigh_r": ([104, 140], "pelvis"), "shin_r": ([97, 176], "thigh_r"),
        "foot_r": ([100, 220], "shin_r"),
        "thigh_l": ([133, 143], "pelvis"), "shin_l": ([142, 181], "thigh_l"),
        "foot_l": ([150, 226], "shin_l"),
        "cloak": ([125, 70], "torso"), "tabard": ([115, 126], "pelvis"),
    },
    "rear": {
        "root": ([128, 128], None), "pelvis": ([131, 119], "root"),
        "torso": ([132, 93], "pelvis"), "head": ([135, 60], "torso"),
        "upper_r": ([160, 88], "torso"), "fore_r": ([174, 118], "upper_r"),
        "hand_r": ([191, 128], "fore_r"), "lance": ([194, 129], "hand_r"),
        "upper_l": ([103, 83], "torso"), "fore_l": ([94, 111], "upper_l"),
        "hand_l": ([102, 142], "fore_l"),
        "thigh_r": ([148, 143], "pelvis"), "shin_r": ([152, 182], "thigh_r"),
        "foot_r": ([155, 228], "shin_r"),
        "thigh_l": ([116, 143], "pelvis"), "shin_l": ([112, 183], "thigh_l"),
        "foot_l": ([108, 225], "shin_l"),
        "cloak": ([133, 72], "torso"), "tabard": ([134, 123], "pelvis"),
    },
}

OWNERSHIP = {
    "front": [
        ["hand_r", [[53,118],[62,115],[73,120],[75,129],[69,138],[59,139],[54,134],[52,126]]],
        ["hand_l", [[145,138],[159,137],[162,146],[159,155],[150,158],[143,152],[142,146]]],
        ["foot_r", [[90,216],[107,217],[110,227],[105,234],[87,239],[68,240],[70,230],[85,224]]],
        ["foot_l", [[142,219],[158,220],[161,230],[166,241],[159,249],[144,249],[138,239],[139,228]]],
        ["lance", [[31,6],[65,6],[70,102],[69,132],[78,168],[90,223],[80,228],[68,183],[60,146],[50,101],[31,87]]],
        ["head", [[101,60],[100,49],[108,30],[126,16],[130,27],[139,56],[129,65],[117,68],[106,66]]],
        ["torso", [[101,79],[123,73],[140,83],[140,106],[138,118],[117,122],[96,114],[96,99]]],
        ["pelvis", [[96,111],[137,109],[143,117],[151,137],[144,149],[129,141],[114,127],[96,148],[83,158],[89,136],[92,121]]],
        ["arm_r", [[87,96],[97,97],[100,107],[96,116],[75,131],[70,128],[71,117],[80,111],[85,106]]],
        ["arm_l", [[138,63],[155,62],[167,77],[174,100],[165,110],[164,132],[158,145],[145,141],[148,130],[149,110],[142,99],[141,91],[136,81]]],
        ["leg_r", [[87,170],[95,162],[105,165],[112,183],[110,207],[108,222],[94,226],[87,207],[84,185]]],
        ["leg_l", [[133,164],[144,164],[155,179],[161,197],[160,223],[144,227],[137,213],[131,196],[128,179]]],
        ["tabard", [[98,128],[116,122],[128,139],[138,161],[137,180],[126,193],[119,211],[118,199],[110,213],[104,188],[103,170],[87,174],[84,160]]],
        ["cape", [[79,75],[103,60],[137,49],[155,52],[178,92],[184,119],[206,135],[227,165],[232,198],[205,225],[181,224],[160,231],[157,198],[145,160],[130,142],[108,155],[89,182],[77,215],[62,215],[69,186],[79,153],[85,127],[79,109]]],
    ],
    "rear": [
        ["hand_r", [[188,119],[199,119],[201,126],[200,134],[195,138],[187,137],[184,132],[184,124]]],
        ["hand_l", [[99,137],[109,135],[113,144],[107,155],[99,156],[95,149]]],
        ["foot_r", [[145,224],[161,224],[166,229],[181,236],[184,244],[161,249],[143,249],[142,238]]],
        ["foot_l", [[100,221],[115,220],[119,228],[119,237],[110,244],[96,244],[95,232]]],
        ["lance", [[192,10],[226,10],[226,96],[208,118],[202,151],[192,197],[178,237],[166,236],[168,211],[179,164],[187,116],[187,87]]],
        ["head", [[119,59],[120,43],[129,22],[143,31],[151,52],[150,64],[136,66],[124,63]]],
        ["torso", [[126,87],[144,88],[151,102],[155,117],[139,124],[117,121],[116,110]]],
        ["pelvis", [[118,113],[149,113],[161,128],[165,147],[158,151],[143,141],[138,127],[124,131],[116,139],[115,124]]],
        ["arm_r", [[151,70],[166,75],[174,87],[172,102],[177,110],[191,119],[187,133],[181,133],[169,126],[159,119],[154,106],[148,96],[145,83]]],
        ["arm_l", [[93,72],[106,66],[115,77],[112,89],[107,99],[104,117],[109,134],[108,142],[97,145],[91,129],[87,115],[87,90]]],
        ["leg_r", [[144,168],[157,168],[164,182],[164,208],[166,227],[157,234],[145,231],[141,213],[139,197],[139,180]]],
        ["leg_l", [[104,174],[116,168],[123,178],[122,197],[117,218],[117,226],[101,230],[98,209],[100,193]]],
        ["tabard", [[124,124],[139,126],[144,142],[138,168],[136,195],[130,212],[124,202],[121,182],[119,161],[119,146]]],
        ["cape", [[109,58],[131,54],[157,59],[165,73],[151,101],[157,131],[167,159],[177,179],[190,220],[173,216],[163,205],[157,192],[148,173],[143,157],[136,146],[126,160],[123,186],[113,212],[100,233],[90,227],[89,207],[75,229],[66,226],[66,210],[52,204],[40,201],[32,182],[35,157],[46,137],[69,115],[86,92]]],
    ],
}

PARTS = {
    "head": ("head", 13, "head"), "torso": ("torso", 11, "chest"),
    "pelvis": ("pelvis", 10, "legs"), "cape": ("cloak", 9, "cloak"),
    "tabard": ("tabard", 8, "cloak"),
    "arm_r": ("upper_r", 12, "gloves"), "hand_r": ("hand_r", 15, "gloves"),
    "arm_l": ("upper_l", 12, "gloves"), "hand_l": ("hand_l", 15, "gloves"),
    "lance": ("lance", 7, "weapon"),
    "leg_r": ("thigh_r", 3, "legs"), "foot_r": ("foot_r", 4, "boots"),
    "leg_l": ("thigh_l", 5, "legs"), "foot_l": ("foot_l", 6, "boots"),
}

def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n")

def audited_ownership(facing):
    entries = json.loads(json.dumps(OWNERSHIP[facing]))
    # The shaft is behind the fist but owns its complete lower end at the boot.
    lance = next(p for p in entries if p[0] == "lance")
    entries.remove(lance)
    entries.insert(2, lance)
    if facing == "front":
        lance[1] = [[31,6],[65,6],[67,88],[64,97],[66,116],[70,138],
                    [72,147],[74,161],[76,170],[79,181],[80,190],[83,199],
                    [85,205],[86,212],[87,218],[85,225],[80,226],[80,220],
                    [77,213],[74,210],[74,201],[70,187],[67,176],[65,167],
                    [62,157],[60,141],[57,138],[54,116],[51,97],[48,87],[31,85]]
        # The upper thumb/cuff contour and complete staff outline must move
        # with the fist/weapon, never remain embedded in the cape.
        next(p for p in entries if p[0] == "hand_r")[1] = [[53,118],[62,114],[69,115],
                    [75,120],[75,130],[70,139],[59,140],[54,134],[52,126]]
        next(p for p in entries if p[0] == "arm_r")[1] = [[81,99],[97,92],[100,111],[96,118],[73,133],[67,121],[71,111],[77,108]]
    else:
        # Stop above the boot. The original broad polygon stole the toe and
        # carried it through the rear attack's lower staff arc.
        # Include the entire dark left outline: leaving this narrow edge on
        # the cape reads as a hanging string when the rigid shaft rotates.
        lance[1] = [[192,10],[226,10],[226,96],[208,118],[201,138],[197,152],
                    [192,169],[187,187],[181,202],[179,216],[177,228],[166,228],
                    [166,220],[168,213],[170,206],[172,199],[173,191],[175,186],
                    [176,178],[178,171],[179,164],[181,156],[181,150],[184,146],
                    [184,140],[187,134],
                    [187,116],[187,87]]
    source = Image.open(CASE / "source" / (facing + "_registered.png"))
    owners = {}
    for name, polygon in entries:
        mask = Image.new("1", (255,255))
        ImageDraw.Draw(mask).polygon([tuple(p) for p in polygon], fill=1)
        for y in range(255):
            for x in range(255):
                if mask.getpixel((x,y)) and source.getpixel((x,y))[3]:
                    owners.setdefault((x,y),name)
    overrides = []
    for y in range(255):
        for x in range(255):
            r,g,b,a = source.getpixel((x,y))
            if not a:
                continue
            old = owners.get((x,y), "")
            name = old
            if not name:
                # Explicit small contours outside the first polygon draft,
                # classified by their inspected source-space material/region.
                if facing == "front":
                    if y < 48: name = "head"
                    elif x >= 158 and y < 94: name = "arm_l"
                    elif x < 114 and y >= 215: name = "foot_r"
                    elif x >= 138 and x < 166 and y >= 219: name = "foot_l"
                    elif 82 <= x < 114 and 174 <= y < 215: name = "leg_r"
                    elif 111 <= x < 150 and y >= 140: name = "tabard"
                    else: name = "cape"
                else:
                    if y < 65 and x >= 116: name = "head"
                    elif y < 80 and x < 116: name = "arm_l"
                    elif x >= 150 and 100 <= y < 136: name = "arm_r"
                    elif y >= 228 and x >= 140: name = "foot_r"
                    elif y >= 228 and x < 125: name = "foot_l"
                    elif 118 <= x < 147 and y >= 145: name = "tabard"
                    else: name = "cape"
            teal = g > r * 1.35 + 6 and b > r * 1.4 + 8
            cloth_on_head = name == "head" and y >= 57
            cloth_on_torso = name == "torso" and not (facing == "front" and 106 <= x <= 120 and 78 <= y <= 106)
            if teal and (cloth_on_head or cloth_on_torso or name in ["pelvis", "leg_r", "leg_l"]):
                name = "tabard" if y >= 123 and (96 <= x < 146 if facing == "front" else 118 <= x < 147) else "cape"
            if facing == "rear" and name == "arm_l" and y >= 94:
                name = "cape"  # This stripe is the outer rear drape, not a sleeve.
            # This exposed rear shaft edge has cold reflected light, while
            # the actual cloth remains well to its left until y=187.
            rear_shaft_edge = facing == "rear" and 138 <= y <= 186 and x >= 174
            if teal and name == "lance" and y > 100 and not rear_shaft_edge:
                name = "cape"  # Cloth touching the shaft never travels with it.
            if name != old:
                overrides.append({"point":[x,y],"name":name})
    return {"priority_polygons": entries, "pixel_overrides": overrides,
            "audit": "Scarf off head, cloth off armor/legs/lance; right fist distinct from rigid shaft; explicit regional contour owners. See author.py audited_ownership."}

HIDDEN = {
    "front": {
        "torso_under": ("torso", [[99,65],[137,64],[144,81],[142,115],[97,116],[97,83]]),
        "pelvis_under": ("pelvis", [[100,114],[137,112],[148,140],[139,153],[109,153],[93,143]]),
        "sleeve_r": ("upper_r", [[89,80],[101,83],[104,99],[98,113],[89,119],[80,114],[83,103]]),
        "sleeve_l": ("upper_l", [[142,81],[159,83],[171,103],[164,129],[155,145],[145,141],[148,117],[143,101]]),
        "thigh_cover_r": ("thigh_r", [[103,129],[120,135],[117,149],[111,167],[107,184],[89,186],[90,166],[96,146]]),
        "thigh_cover_l": ("thigh_l", [[124,132],[140,134],[147,151],[153,174],[153,191],[136,189],[130,169],[122,148]]),
    },
    "rear": {
        "torso_under": ("torso", [[115,60],[143,61],[151,81],[150,116],[110,116],[106,84]]),
        "pelvis_under": ("pelvis", [[113,115],[149,115],[158,138],[150,153],[119,152],[107,137]]),
        "sleeve_r": ("upper_r", [[153,83],[168,91],[178,111],[185,120],[185,133],[172,131],[159,119],[151,100]]),
        "sleeve_l": ("upper_l", [[96,84],[109,89],[106,110],[109,141],[99,148],[89,135],[85,112],[88,97]]),
        "thigh_cover_r": ("thigh_r", [[137,134],[154,135],[162,157],[162,181],[151,189],[140,183],[136,163]]),
        "thigh_cover_l": ("thigh_l", [[110,133],[129,134],[132,146],[123,170],[119,188],[102,190],[102,163]]),
    },
}

def hidden_parts(facing):
    under = Image.open(CASE / "source" / (facing + "_underbody_registered.png"))
    front = Image.open(CASE / "source" / (facing + "_registered.png"))
    parts = []
    records = []
    for name, (bone, polygon) in HIDDEN[facing].items():
        mask = Image.new("1", (255,255))
        ImageDraw.Draw(mask).polygon([tuple(p) for p in polygon], fill=1)
        image = Image.new("RGBA", (255,255))
        for y in range(255):
            for x in range(255):
                if mask.getpixel((x,y)) and front.getpixel((x,y))[3] and under.getpixel((x,y))[3]:
                    image.putpixel((x,y), under.getpixel((x,y)))
        bbox = image.getbbox()
        path = CASE / "assets" / facing / (name + ".png")
        path.parent.mkdir(parents=True,exist_ok=True)
        image.crop(bbox).save(path)
        Path(str(path)+".import").write_text('[remap]\n\nimporter="keep"\n')
        slot = "chest" if name == "torso_under" else "legs" if "thigh" in name or "pelvis" in name else "gloves"
        parts.append({"name":name,"bone":bone,"file":str(path.relative_to(CASE)),"offset":list(bbox[:2]),"bbox":list(bbox),"z_index":-5,"equipment_slot":slot})
        records.append({"name":name,"source":str((CASE/"source"/(facing+"_underbody_registered.png")).relative_to(CASE)),"polygon":polygon,"clip_to_registered_silhouette":True,"no_new_rgb_pixels":True})
    write_json(CASE / "recipes" / (facing+"_hidden.json"), records)
    return parts

def semantic(revision):
    for facing in ["front", "rear"]:
        recipe = CASE / "recipes" / (facing + "_ownership_" + revision + ".json")
        write_json(recipe, audited_ownership(facing))
        output = CASE / "segmented" / revision / facing
        result = subprocess.run([sys.executable, str(PROJECT / "tools/cutout_workflow.py"), "segment", "--source", str(CASE / "source" / (facing + "_registered.png")), "--ownership", str(recipe), "--output", str(output)], capture_output=True, text=True)
        print(facing, result.returncode, str(output))
        if result.stderr: print(result.stderr)
        if result.returncode:
            continue
        report = json.loads((output / "segmentation.json").read_text())
        parts = []
        for part in report["parts"]:
            bone, layer, slot = PARTS[part["name"]]
            if facing == "rear" and part["name"] in ["leg_l", "foot_l"]:
                layer -= 4
            if facing == "rear" and part["name"] in ["leg_r", "foot_r"]:
                layer += 2
            parts.append({**part, "file": str((output / part["file"]).relative_to(CASE)), "bone": bone, "z_index": layer, "equipment_slot": slot})
            (output / (part["file"] + ".import")).write_text('[remap]\n\nimporter="keep"\n')
        joints = {name: {"position": point, "parent": parent} for name, (point, parent) in JOINTS[facing].items()}
        parts += hidden_parts(facing)
        layout = {"canvas_size": [255, 255], "facing": facing, "joints": joints, "parts": parts,
                  "landmarks": {"sole_r": [92, 237] if facing == "front" else [162, 247],
                                "sole_l": [153, 247] if facing == "front" else [106, 242],
                                "weapon_grip": joints["lance"]["position"],
                                "weapon_tip": [39, 10] if facing == "front" else [218, 16]},
                  "projection": "2:1; front lower-left, rear upper-right; separate projected near/far soles"}
        write_json(CASE / "layouts" / (facing + "_" + revision + ".json"), layout)

if __name__ == "__main__":
    semantic(sys.argv[1] if len(sys.argv) > 1 else "v01")
