"""Retain Dust Acolyte native proof with wall-clock video timing.

The Godot probes must run through visual_probe_runner.py first. This only
packages their real frames; it does not synthesize poses or speed up clips.
"""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import subprocess
import statistics


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")


def raw_directory(result, filename):
    return next(Path(i["path"]).parent for i in result["images"] if Path(i["path"]).name == filename)


def q(path):
    return "'" + str(path).replace("'", "'\\''") + "'"


def encode(raw, destination):
    manifest = json.loads((raw / "manifest.json").read_text())
    if not manifest["ok"]:
        raise RuntimeError(manifest["errors"])
    destination.mkdir(parents=True)
    shutil.copy2(raw / "manifest.json", destination / "manifest.json")
    for png in raw.glob("*.png"):
        shutil.copy2(png, destination / png.name)
    records = []
    for clip in manifest["clips"]:
        label = clip["label"]
        samples = clip["samples"]
        frames = sorted((raw / label).glob("frame_*.jpg"))
        assert len(frames) == len(samples) and len(frames) > 1
        durations = [samples[i+1]["seconds"] - samples[i]["seconds"] for i in range(len(samples)-1)]
        durations.append(statistics.median(durations))
        assert min(durations) > 0
        seconds = sum(durations)
        listing = destination / (label + ".ffconcat")
        listing.write_text("ffconcat version 1.0\n" + "".join("file " + q(f) + "\nduration %.9f\n" % d for f,d in zip(frames,durations)) + "file " + q(frames[-1]) + "\n")
        video = destination / (label + ".mp4")
        subprocess.run(["ffmpeg","-v","error","-y","-f","concat","-safe","0","-i",str(listing),"-t",str(seconds),"-vf","fps=60","-c:v","libx264","-threads","2","-preset","fast","-crf","18","-pix_fmt","yuv420p","-movflags","+faststart",str(video)],check=True)
        listing.unlink()
        metadata = json.loads(subprocess.check_output(["ffprobe","-v","error","-select_streams","v:0","-count_frames","-show_entries","stream=nb_read_frames,width,height","-of","json",str(video)],text=True))["streams"][0]
        encoded = int(metadata["nb_read_frames"])/60
        assert metadata["width"] == 1920 and metadata["height"] == 1080
        assert abs(encoded-seconds) <= 1/60+0.000001
        walking = [i for i,s in enumerate(samples) if s["animation"].get("clip") == "walk"]
        if walking:
            shutil.copy2(frames[walking[len(walking)//2]], destination / (label + "_mid_walk.jpg"))
        records.append({"label":label,"source_frame_sha256":[digest(f) for f in frames],"durations":durations,"source_seconds":seconds,"encoded_seconds":encoded,"encoded_frames":metadata["nb_read_frames"],"duration_error_seconds":encoded-seconds})
    concat = destination / "clips.ffconcat"
    concat.write_text("ffconcat version 1.0\n" + "".join("file " + q(r["label"]+".mp4")+"\n" for r in records))
    reel = destination / "acolyte_gameplay_full_speed.mp4"
    subprocess.run(["ffmpeg","-v","error","-y","-f","concat","-safe","0","-i",str(concat),"-c","copy","-movflags","+faststart",str(reel)],check=True)
    subprocess.run(["ffmpeg","-v","error","-i",str(reel),"-f","null","-"],check=True)
    # Keep a compact review preview of front idle, Dust Bolt and Siphon.
    selected = [r for r in records if r["label"] in ["00_idle_southwest","01_dust_bolt_southwest","05_siphon_southwest"]]
    concat.write_text("ffconcat version 1.0\n"+"".join("file "+q(r["label"]+".mp4")+"\n" for r in selected))
    subprocess.run(["ffmpeg","-v","error","-y","-f","concat","-safe","0","-i",str(concat),"-c","copy","-movflags","+faststart",str(destination / "acolyte_casting_preview.mp4")],check=True)
    concat.unlink()
    # Full reel plus the original PNGs and per-source-frame digests are durable;
    # redundant intermediate MP4s stay outside the committed proof.
    for r in records:
        (destination/(r["label"]+".mp4")).unlink()
    report = {"clips":records,"source_seconds":sum(r["source_seconds"] for r in records),"encoded_seconds":sum(r["encoded_seconds"] for r in records),"timing":"Actual RunScene wall-clock sample intervals; frames repeated at 60fps, no synthesized poses. Each clip rounds by at most one 60fps frame.","full_decode":"PASS"}
    write(destination / "video_timeline.json",report)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--gameplay-result",type=Path,required=True)
    parser.add_argument("--asset-result",type=Path,required=True)
    parser.add_argument("--inputs",type=Path,required=True)
    parser.add_argument("--output",type=Path,required=True)
    args = parser.parse_args()
    assert not args.output.exists(), "Choose a fresh proof directory"
    inputs = json.loads(args.inputs.read_text())
    changed = [p for p,sha in inputs.items() if not Path(p).is_file() or digest(Path(p)) != sha]
    assert not changed, f"Capture inputs changed: {changed}"
    game = json.loads(args.gameplay_result.read_text())
    assets = json.loads(args.asset_result.read_text())
    assert game["ok"] and assets["ok"]
    args.output.mkdir(parents=True)
    game_raw = raw_directory(game, "00_idle_southwest.png")
    asset_raw = raw_directory(assets, "front_rest.png")
    encode(game_raw,args.output/"gameplay")
    shutil.copytree(asset_raw,args.output/"assets")
    write(args.output/"capture_input_sha256.json",inputs)
    for kind,result,raw in [("gameplay",game,game_raw),("assets",assets,asset_raw)]:
        for item in result["images"]:
            item["path"] = str(Path(item["path"]).relative_to(raw))
        for attempt in result["attempts"]:
            for item in attempt.get("images",[]):
                item["path"] = str(Path(item["path"]).relative_to(raw))
        write(args.output/(kind+"_native_result.json"),result)
    for name,source in [("full_suite.log","/private/tmp/acolyte-full-suite.log"),("focused_suite.log","/private/tmp/acolyte-focused-suite.log"),("export_build.log","/private/tmp/acolyte-export-build.log"),("export_runtime.log","/private/tmp/acolyte-export-runtime.log"),("gameplay_probe.log","/private/tmp/acolyte-gameplay-final.log")]:
        shutil.copy2(source,args.output/name)
    shutil.copy2("/private/tmp/acolyte-workflow-suite.log",args.output/"workflow_suite.log")
    shutil.copy2("/private/tmp/acolyte-check-lease.py",args.output/"check_lease_forwarding.py")
    shutil.copy2("/private/tmp/acolyte-preservation-audit.json",args.output/"preservation_audit.json")
    shutil.copy2("/private/tmp/acolyte-check-preservation.py",args.output/"check_preservation.py")
    shutil.copy2("/private/tmp/acolyte-rejected-capture.json",args.output/"rejected_capture.json")
    write(args.output/"proof_sha256.json",{str(p.relative_to(args.output)):digest(p) for p in sorted(args.output.rglob('*')) if p.is_file() and p.name != "proof_sha256.json"})
    print(json.dumps({"ok":True,"output":str(args.output),"runtime_inputs":len(inputs)},indent=2))


if __name__ == "__main__":
    main()
