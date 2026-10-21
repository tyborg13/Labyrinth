# rr-31 feedback 3 (Codex SIGNOFF e9aadfc32 with two Lows; clean up before merge)

The rig is accepted. Two Lows before it merges; this is the last round.

1. **Repo weight.** `rr30_joint_calibrate.py:57` writes a 27.6 MB JSON with repeated per-frame texels. Keep the
   operational cuts and bindings compact (only what the runtime and gates read), and move the detailed evidence into
   a gzipped sidecar. Regenerate, and show that every gate and test still passes on the compact form. Report the
   sizes before and after.
2. **Stale documentation.** `rr31/README.md:37` still says brace lacks its selector and that production differs from
   editable motion. The director restored `brace:block` in the staged data, so both compiled files are identical.
   Update the text.
3. Don't change the construction, motion, paintings or any visual output; the director's native acceptance stands.
   Prove the runtime assets are byte-identical before and after. Focused tests only.
