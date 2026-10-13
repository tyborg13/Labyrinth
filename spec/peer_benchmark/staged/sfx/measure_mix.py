import json, sys, numpy as np, soundfile as sf, pyloudnorm as pyln
root = sys.argv[1]
def mmax(path):
    x, sr = sf.read(path, always_2d=True)
    m = pyln.Meter(sr, block_size=0.4)
    win = int(0.4 * sr); hop = int(0.1 * sr)
    if len(x) < win: x = np.vstack([x, np.zeros((win - len(x), x.shape[1]))])
    best = -99.0
    for s in range(0, len(x) - win + 1, hop):
        seg = x[s:s+win]
        if np.max(np.abs(seg)) < 1e-6: continue
        v = m.integrated_loudness(seg)
        if np.isfinite(v): best = max(best, v)
    return best
d = json.load(open(f"{root}/data/sfx_cues.json"))
rows = {}
for cue, c in d["cues"].items():
    paths = c.get("variants") or c.get("fallback") or []
    if c.get("variants_from"):
        src = d["cues"][c["variants_from"]]; paths = src.get("variants") or src.get("fallback") or []
    if not paths: continue
    vals = [mmax(root + "/" + p.replace("res://", "")) for p in paths]
    rows[cue] = {"file": round(float(np.mean(vals)), 1), "volume_db": c.get("volume_db", 0), "eff": round(float(np.mean(vals)) + c.get("volume_db", 0), 1), "n": len(paths), "has_variants": bool(c.get("variants"))}
refs = {"ref.melee_sword(-5.5)": ("assets/audio/sfx/attack_melee_sword_first.wav", -5.5)}
for k,(p,g) in refs.items():
    try: rows[k] = {"file": round(mmax(root + "/" + p),1), "volume_db": g, "eff": round(mmax(root + "/" + p)+g,1)}
    except Exception as e: rows[k] = {"err": str(e)}
json.dump(rows, open(sys.argv[2], "w"), indent=1)
for k, v in sorted(rows.items(), key=lambda kv: kv[1].get("eff", 0)):
    print(f"{v.get('eff'):>6} {k:22} file={v.get('file')} vol={v.get('volume_db')}")
