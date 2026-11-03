# mq-23 opened segment lengths

All lengths are metres in the mq-16 L=1m gauge. Every ratio must be 1.000 ±0.002.

| Segment | mq-16 source | Opened delivery | Ratio | Opened mesh length |
|---|---:|---:|---:|---:|
| near_upper_arm | 0.318667661 | 0.318667759 | 1.000000308 | 0.318667773 |
| near_forearm | 0.348747114 | 0.348746846 | 0.999999231 | 0.348747190 |
| near_thigh | 0.353217000 | 0.353217079 | 1.000000224 | 0.353216995 |
| near_shin | 0.547888069 | 0.547888102 | 1.000000060 | 0.547888067 |
| far_upper_arm | 0.371706317 | 0.371706188 | 0.999999652 | 0.371706444 |
| far_forearm | 0.406792158 | 0.406792111 | 0.999999884 | 0.406792233 |
| far_thigh | 0.353217000 | 0.353217158 | 1.000000446 | 0.353216999 |
| far_shin | 0.547888069 | 0.547888037 | 0.999999942 | 0.547888070 |

Exact bends: near elbow 35°, near/far knees 24°/20°. Hip lean 12°.

Near fist misses its soft target by 0.042442253H.
Stance span: 1.259433508 shoulder spans; requested 1.400000000; signed miss -0.040789385H.
Step: 0.100300409L; requested 0.180000000L; signed miss -0.079699591L.

The targets are overconstrained by fixed source lengths, exact bends and planted soles. The independent optimality gates pass; no segment is scaled.

Accepted far blade clearance: 0.058604694H (maximum 0.12H).
