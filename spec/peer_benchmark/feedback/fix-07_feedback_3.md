# fix-07 feedback 3 (final, tiny)

The windowed probe ran on the director's Retina display and captured at the window size (3024x1898), so its 1920x1080
and on-screen checks failed. Render the probe's scene inside a fixed 1920x1080 SubViewport at 100% UI scale, as
`tests/suites/empower_seal_tooltip_suite.gd` does with `tests/helpers/ui03_capture_viewport.gd` (fix-06's proof), and
save that viewport's image. Keep its checks. Re-run only the probe's headless contract check; the director runs the
windowed command.
