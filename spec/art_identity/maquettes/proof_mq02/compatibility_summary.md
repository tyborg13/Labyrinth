# mq-02 committed-render comparisons

All values are minimum per-part IoU in each view. Solo alpha is the
silhouette proof wherever committed solos exist. Visible categorical label
IoU is retained separately; it is sensitive to antialiasing/colour blending
and occlusion. Missing solo baselines are not presented as passing.

| Spec | Front solo min | Rear solo min | Front visible min | Rear visible min | Front whole silhouette | Rear whole silhouette | Joint error |
|---|---:|---:|---:|---:|---:|---:|---:|
| chainbound_gaoler | 0.990113 | 0.990150 | 0.922417 | 0.000000 | 0.999254 | 0.999201 | 0.010000 |
| frostglass_lancer | unavailable | unavailable | 0.520278 | 0.015237 | 0.995771 | 0.995425 | unavailable |
| lightning_wisp | unavailable | unavailable | 0.859936 | 0.902028 | 0.997045 | 0.995679 | unavailable |
| shale_bloomer | unavailable | unavailable | 0.000000 | 0.000000 | 0.997123 | 0.997365 | unavailable |
| gust_shrike | 0.997827 | 0.998428 | 0.410494 | 0.274688 | 0.994706 | 0.996346 | 0.010000 |

Gaoler and shrike solo silhouette checks pass the 0.98 threshold in both views.
Lancer r1, wisp and bloomer visible-label checks fail; full per-part silhouette
verification remains pending director legacy/shared Blender solo captures.
The current evidence does not establish the whole-roster back-compat gate.

Joint projection is within 0.01 px of the available committed gaoler/shrike
joints. The other three baselines have no committed joints_px.json here.

Full per-part values and baseline paths: [compatibility_report.json](compatibility_report.json).
Director commands: [FITTING.md](../FITTING.md#proof-for-the-design-owner).
