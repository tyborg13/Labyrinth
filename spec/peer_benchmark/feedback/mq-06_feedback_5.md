# mq-06 feedback 5 — rear accepted; register with the fixed original offset; stage

The director reviewed `feedback4/rear_sheet.png` and accepts the planted rear:
- the camera-near foot is lower-right under a hem resting on the floor;
- the staff is on the right;
- it is an exact 180° turn with pan-only framing;
- the front is unchanged.

**`TODO_DESIGN_REAR_DYNAMIC_REGISTRATION_CONFLICT` (decided).**
- Dynamic ground-centroid registration anchors the old painting and the corrected body on different features (its
  lower-left robe edge versus the planted lower-right foot), so its 0.2054 measures the anchor mismatch, not the
  silhouette.
- Gate the Seer rear on the fixed original mq-04 registration offset: 0.7609 ≥ 0.60, PASS. Record both values and
  this reason in the fit report.
- Don't change the method for other figures.

Then:
1. Stage the rear delivery: rear clay, part map, solos and rear `joints_px.json` entries, replacing the mirrored mq-04
   rear. The front files stay byte-unchanged.
2. The turn regression passes for the committed Seer delivery.
3. Floor guard, collision, coverage, exact native replay and curation (≤ 6 MB) pass.
4. The full Python suite PASSES.
5. Report the final file list and the hashes of the staged rear files.
