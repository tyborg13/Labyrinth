| View / clip | Unfillable sampled frames | Largest certified gap (px) |
| --- | --- | ---: |
| front/idle | 0012, 0013, 0014, 0015, 0016, 0017, 0018, 0019, 0020, 0021, 0022, 0023, 0150, 0151, 0152, 0153, 0154, 0155 | 8 |
| front/move | 0020, 0021, 0022, 0031 | 28 |
| front/shot | 0006, 0012, 0040 | 36 |
| front/death | 0005 | 6 |
| rear/idle | 0000, 0001, 0002, 0003, 0004, 0005, 0012, 0013, 0014, 0015, 0016, 0017, 0018, 0019, 0020, 0021, 0022, 0023 | 13 |
| rear/move | 0026, 0027, 0028, 0030, 0031 | 13 |
| rear/hit | 0018, 0025, 0026, 0027 | 5 |

Every certificate in TODO_DESIGN.json includes source-canvas coordinates, contributing nodes/bones, exact authored channel/key arrays, applied view tracks, phase and presented phase. The bound gives every painted bone the entire opaque rest silhouette, including feature texels: a more generous domain than authorized bleed. A connected gap of at least 2 pixels surviving this CPU bound cannot be filled by legal static support at these painted-bone transforms.

The 53 certificates are a subset of the 451 failing poses. Other seams are not claimed to have this impossibility proof; all per-pose failures remain in output/rr-05/feedback6/shale-pixel-gates.json. No other motion key was changed.
