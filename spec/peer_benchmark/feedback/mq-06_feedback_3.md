# mq-06 feedback 3 — bridge deadline, robe contact, rear frame and fit (decided)

Good work holding the gates. Four decisions:

1. **Bridge deadline (my brief's error).** The 120 s limit was meant to detect a bridge that isn't answering, not to
   cap a job. Builds take about 300 s.
   - Stop only if a job isn't picked up within 120 s of queueing (the bridge log shows no `RUN` for it).
   - Once a job is running, allow up to 900 s.
   - Resume native work.
2. **`TODO_IMPLEMENTATION_BODY_ROBE_CONTACT`.** Resolve the 59 intersecting face pairs and 113 samples the same way
   as the floor correction.
   - Move each offending robe-skirt vertex along the front camera's view ray, toward or away from the camera,
     whichever clears with the smaller move, until the existing 0.003 m margin holds. The front projection stays
     unchanged.
   - Only if a vertex can't clear that way, push it along its normal by the minimum amount. The whole-figure front
     alpha must still change by 0 px; otherwise stop and report.
   - Keep the existing collision assertions; don't weaken them.
3. **`TODO_DESIGN_REAR_FRAME`.**
   - Keep the rear camera's direction and scale exactly.
   - Reframe by panning only, so that every rear pixel is at least 8 px (1024 space) from every canvas edge.
   - The root's canvas position in the rear may then differ from the front. That is already supported: each view
     has its own `root` in `joints_px.json`. Record it as usual.
   - No scaling and no rotation.
4. **`TODO_DESIGN_REAR_FIT_REGISTRATION`.**
   - Use the standard mq-04 dynamic ground-centroid registration on the corrected body and gate rear IoU against the
     old approved rear painting at ≥ 0.60. The corrected stance legitimately differs from the old painting's, and
     the director repaints the rear anyway.
   - Report the fixed-original-registration value too, for the record.

Then finish feedback 1:
- the certified corrected build;
- front and rear captures, staging, the 1024 sheet and coverage;
- the turn regression passing for the Seer;
- the full Python suite.
