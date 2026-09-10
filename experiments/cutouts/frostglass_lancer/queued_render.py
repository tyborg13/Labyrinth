"""Use the maintained cutout proof pipeline with a longer GUI queue wait.

Twelve concurrent enemy tasks can exceed cutout_workflow render's fixed 30s
lease wait. This task-local entrypoint changes ONLY that wait. Startup watchdog,
native probe, structural checks, hash guards, packing and verifier are retained.
No shared runner or production runtime is modified.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

PROJECT = Path(__file__).resolve().parents[3]
sys.path.insert(0,str(PROJECT / "tools"))
from cutout_pipeline.cases import digest, fresh_directory, load_case, read_json, write_json
from cutout_pipeline.validation import validate
from cutout_pipeline.proof import input_hashes, pack, verify_render

parser = argparse.ArgumentParser()
parser.add_argument("case",type=Path)
parser.add_argument("--output",type=Path,required=True)
parser.add_argument("--task-id",required=True)
parser.add_argument("--gui-lease-timeout",type=float,default=900)
args = parser.parse_args()
path, config = load_case(args.case)
validation = validate(path)
if not validation["ok"] or args.output.exists():
    raise SystemExit("Require valid case and fresh output")
before = input_hashes(path)
frames = sum(c["frames"]*c.get("preview_cycles",1) for c in config["clips"].values())*len(config["layouts"])
with tempfile.TemporaryDirectory(prefix="frostglass-queued-native-") as scratch:
    result_path = Path(scratch)/"result.json"
    command = [sys.executable,str(PROJECT/"tools/visual_probe_runner.py"),"tools/cutout_pipeline/preview.gd",
               "--project",str(PROJECT),"--godot","godot","--no-headless","--expect-size","1920x1080","--expect-size","512x512",
               "--timeout",str(max(60,round(frames*0.20+30))),"--result-manifest",str(result_path),
               "--task-id",args.task_id,"--rendering-method","mobile","--rendering-driver","metal",
               "--gui-lease-timeout",str(args.gui_lease_timeout),"--","--case",str(path)]
    process = subprocess.run(command,cwd=PROJECT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    if process.returncode:
        print(process.stdout[-20000:])
        raise SystemExit(process.returncode)
    result = read_json(result_path)
    if not result.get("ok") or input_hashes(path)!=before:
        raise SystemExit("Native proof rejected or capture input changed")
    raw = next(Path(i["path"]).parent for i in result["images"] if Path(i["path"]).name=="keyboard_focus.png")
    root = fresh_directory(args.output)
    shutil.copytree(raw,root,dirs_exist_ok=True)
    (root/"native_probe.log").write_text(process.stdout)
    for collection in [result["images"]]+[a.get("images",[]) for a in result["attempts"]]:
        for item in collection:
            item["path"] = str(Path(item["path"]).relative_to(raw))
    write_json(root/"visual_probe_result.json",result)
    write_json(root/"capture_input_sha256.json",before)
    write_json(root/"case_validation.json",validation)
encoding = pack(root)
write_json(root/"proof_sha256.json",{str(p.relative_to(root)):digest(p) for p in sorted(root.rglob("*")) if p.is_file() and p.name!="proof_sha256.json"})
verification = verify_render(path,root)
print(json.dumps({"ok":verification["ok"],"output":str(root),"preview":str(root/encoding["reel"]),"authored_frames":frames,"verification":verification},indent=2))
raise SystemExit(0 if verification["ok"] else 1)
