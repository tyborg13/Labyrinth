"""Encode the native gameplay samples at their measured wall-clock cadence.

Run with the retained gameplay directory. Frames are repeated at 60fps; this
never invents intermediate poses or includes the probe's later disk-write time.
"""
import argparse
from bisect import bisect_right
import json
import subprocess
from fractions import Fraction
from pathlib import Path


def run(arguments):
    return subprocess.run(arguments, check=True, capture_output=True, text=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("gameplay", type=Path)
    args = parser.parse_args()
    folder = args.gameplay.resolve()
    manifest = json.loads((folder / "manifest.json").read_text())
    if not manifest["ok"] or not manifest["native_capture"]:
        raise ValueError("Only a passing native gameplay capture can be encoded")
    report = {"timing": "Actual recorded wall-clock intervals; 60fps frame repetition without synthesized poses", "clips": []}
    outputs = []
    for clip in manifest["clips"]:
        label = clip["label"]
        samples = clip["samples"]
        frames = sorted((folder / label).glob("frame_*.jpg"))
        if len(frames) != len(samples) or not frames:
            raise ValueError("Every recorded sample must have its native frame: " + label)
        times = [sample["seconds"] for sample in samples]
        end = clip["duration_seconds"]
        durations = [right-left for left, right in zip(times, times[1:]+[end])]
        if any(value <= 0 for value in durations):
            raise ValueError("Non-monotonic capture cadence: " + label)
        seconds = end-times[0]
        output_frames = round(seconds*60)
        repeated_indices = [max(0,bisect_right(times,times[0]+index/60)-1) for index in range(output_frames)]
        sequence = folder / label / "frames.ffconcat"
        sequence.write_text("ffconcat version 1.0\n"+"".join("file '%s'\n" % frames[index].name for index in repeated_indices))
        video = folder / (label+".mp4")
        # Constant input cadence avoids the concat demuxer's default 25fps
        # timestamp quantization for individual JPEG files.
        run(["ffmpeg", "-v", "error", "-y", "-r", "60", "-f", "concat", "-safe", "0", "-i", str(sequence),
             "-frames:v", str(output_frames), "-an", "-c:v", "libx264", "-preset", "fast",
             "-crf", "18", "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(video)])
        stream = json.loads(run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-count_frames",
                                "-show_entries", "stream=width,height,nb_read_frames,avg_frame_rate", "-of", "json", str(video)]).stdout)["streams"][0]
        encoded_seconds = int(stream["nb_read_frames"])/float(Fraction(stream["avg_frame_rate"]))
        if (stream["width"],stream["height"]) != (1920,1080) or abs(encoded_seconds-seconds) > 1/60+1e-6:
            raise ValueError("Native dimensions or cadence changed: " + label)
        report["clips"].append({"label":label,"samples":len(samples),"first_sample_seconds":times[0],
                                "capture_end_seconds":end,"source_seconds":seconds,"encoded_seconds":encoded_seconds,
                                "duration_error_seconds":encoded_seconds-seconds,"frame_durations":durations,"output_sample_indices":repeated_indices})
        outputs.append(video)
    concat = folder / "clips.ffconcat"
    concat.write_text("ffconcat version 1.0\n"+"".join("file '%s'\n" % path.name for path in outputs))
    reel = folder / "grave_surgeon_gameplay_full_speed.mp4"
    run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", str(concat), "-c", "copy", "-movflags", "+faststart", str(reel)])
    run(["ffmpeg", "-v", "error", "-i", str(reel), "-f", "null", "-"])
    report["full_decode"] = "PASS"
    report["source_seconds"] = sum(clip["source_seconds"] for clip in report["clips"])
    report["encoded_seconds"] = sum(clip["encoded_seconds"] for clip in report["clips"])
    (folder / "video_timeline.json").write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps({"reel":str(reel),"clips":len(outputs),"seconds":report["encoded_seconds"],"decode":"PASS"}))


if __name__ == "__main__":
    main()
