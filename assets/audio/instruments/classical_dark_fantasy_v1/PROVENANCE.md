# Procedural Dark Fantasy Ensemble v1

All eight WAV files in this directory are original project-generated assets created deterministically by `tools/classical_soundtrack_pipeline/bank.py`.

The five bowed-string loops use mathematical sinusoidal partials, fixed integer phase seeds, deterministic attack envelopes, and fixed low-bit signal quantization. The three percussion one-shots use mathematical oscillators, fixed integer-noise seeds, deterministic pitch sweeps/envelopes, and fixed quantization. No recording, performance, sample pack, SoundFont, ROM or ripped console/game audio, commercial audio, or generative-model audio was used.

The assets are intended for unrestricted commercial use in Escape the Umbra and its distributed builds. `bank_manifest.json` records the synthesis parameters and SHA-256 hash for each file. Regenerate with:

```bash
.venv-classical-soundtrack/bin/python tools/classical_soundtrack.py generate-bank
```

Do not modify this bank version in place. If synthesis changes a WAV hash, create a new versioned bank directory so approved soundtrack renders remain reproducible.
