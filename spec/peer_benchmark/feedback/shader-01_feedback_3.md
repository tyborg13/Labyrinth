# shader-01 feedback 3 (final; from the Codex review of bf7de529c)

Finding 4 of the review (deleted records) is an artifact of the integration branch moving on. Ignore it and don't
touch spec/ files.

1. **Medium: a dangling matching link must not count as success.** At `scripts/engine_cache_directories.gd` ~36, a
   matching link whose source folder is missing returns `linked` with no error, but writes fail. Before accepting a
   link, make sure the source folder exists (create it); report a creation failure as an error. Add a
   dangling-matching-link test for each of the three folders.
2. **Medium: the regressions must prove the switch happened.** Removing both `ProjectSettings.set_setting()` calls
   still passes every test today. Assert:
   - after the Steam switch, `user://` resolves to the expected Steam-account path;
   - a real save, settings and analytics write lands there;
   - the original profile's bytes are untouched;
   - the cache folders resolve to the pre-switch ones.
   Removing the switch must fail these tests.
3. **Low: cover the nested-link guards (~56, ~71):** a nested source link, a nested destination link, a foreign
   destination that stays untouched, and a cycle. Removing either guard must fail.

Re-run the cache tests, the Steam/settings regressions and the save pipeline, and report each mutation. No full suites.
