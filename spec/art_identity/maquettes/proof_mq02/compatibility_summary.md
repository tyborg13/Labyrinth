# mq-02 native legacy compatibility — PASS

Original and shared geometry were built in Blender 5.2.1 LTS through the approved
serial bridge. Every native invocation used `--factory-startup --disable-autoexec`.
The original builders come from `61b0c2f0ba8793db3499038de3d959b1a6f220d4`.
Only the rendering loop was replaced with matched Cycles CPU solo alpha proof.
Each of the 20 view jobs answered within 120 seconds; no native retry was used.

| Figure | Front minimum part IoU | Rear minimum part IoU | Maximum joint error (px) | Gate |
|---|---:|---:|---:|---|
| chainbound_gaoler | 0.990079 | 0.990081 | 0.00 | PASS |
| frostglass_lancer | 0.997701 | 0.997645 | 0.00 | PASS |
| lightning_wisp | 1.000000 | 1.000000 | 0.00 | PASS |
| shale_bloomer | 0.986605 | 0.982631 | 0.00 | PASS |
| gust_shrike | 0.998274 | 0.998746 | 0.00 | PASS |

Unchanged gates: **every part IoU >=0.98; every joint within 1 px**.
All five figures pass in both views. No builder geometry correction or gate relaxation was needed.

Exact observed result: `MAQUETTE_COMPAT: PASS` (exit 0).

Full per-part IoUs, input image/joint SHA-256 hashes, source receipts and exact
bridge command receipts are in [compatibility_report.json](compatibility_report.json).
Native captures are archived at `/private/tmp/labyrinth_codex/mq-03/round4/compatibility`.
The capture source uses the real shared adapter callback, not a numerical proxy.

```sh
python3 -B spec/art_identity/maquettes/blender/legacy_proof.py
python3 -B tools/maquette_fit.py compat --out spec/art_identity/maquettes/proof_mq02 --require-gate
```

This supersedes the earlier committed-render report with three pending figures.
The original visible-label comparisons are not used as substitutes for solo proof.
