# Peer-benchmark decisions log (binding for this program)

- 2026-10-12 OWNER: program scope = everything (visual, audio, mechanics, content, map, events, cards, enemies, level gen);
  bold changes allowed; prior Codex-era approvals not binding; experiment lives on `codex/peer-benchmark`.
- 2026-10-12 OWNER: blanket permission to download CC0 or otherwise free-for-commercial-use assets that fit and meet
  the bar. Rule: record source URL, licence text/terms and sha256 per asset in a provenance file; never NC/ND/unclear;
  no account creation or logins.
- 2026-10-12 OWNER: use orchestrate-codex (Claude decides taste, Codex implements); keep the owner in the loop with
  screenshots/clips; inspection fixtures only for feel-critical work.
- 2026-10-12 CLAUDE: Events are data-driven (data/events.json), 27 authored events (15 shared, 2 per dragon element, 2
  shadow-only in section VI), illustrated full-screen view per mockup output/peer-benchmark-2026-10-12/mockups/
  event_choices.png. Exact effect lines, costs red / gains gold / banes violet / odds neutral; locked choices stay
  visible with a reason (StS grammar). Omens = timed blessings/banes (11), our analogue of StS curses-for-power.
- 2026-10-12 CLAUDE: Event art style = pixel-painted dark fantasy matching key art + card art; 1536x1024 3:2, edges dark.
  Approved pilots: hanged_knight, frozen_champion, bloodletters_basin (spec/peer_benchmark/staged/event_art/approved/).
- 2026-10-12 CLAUDE: Map revision 4 = StS rules adapted: 4 lanes, 5 non-crossing walks, fixed rows (step 1 fights,
  mid treasure row, Hearth row before boss), mystery "?" rooms (event 70/combat 20/treasure 5/scavenger 5), several
  optional Guardians (≤1 per route), full visibility in sections I–V, section VI keeps fog (heart of the Umbra), Scout
  reveals mystery contents.
- 2026-10-12 CLAUDE: Feel: modest hit-stop (StS has none; ITB-style crunch) + damage-scaled shake + enemy-phase pacing
  budget (4-enemy round ≤ 6 s) + Combat speed setting. Next feel round candidates from StS research: HP-bar damage
  ghost (1.2 s hold), damage numbers that pop large and settle, round-robin SFX variants.
- Backlog from StS research: score tally + run history + compendium/stats (meta screen); Ascension-style 20-step
  difficulty ladder; daily seeded run with modifiers; event v2 (opt-in fights, push-your-luck, cross-event callbacks,
  harsher variants at high difficulty); tiered intent art by damage.

## 2026-10-12 — Wave-1 peer review outcomes
- Hero Expose works as displayed (director): master put Expose on the hero (Bile Bloomer Shard Mark 2, Noctyrax Void
  Claw 1) and showed it, but never consumed it. ev-01 made it consume on the next hit; we keep that (keyword text says
  so), add it to previews, score both enemies, and tell the owner it is a rules change versus master.
- Pause/menu must reach through an open event (Esc/Start).
- Debt (not now): combat_pacing reaches ~12 run_scene privates by string; EventRules/OmenRules call engine privates.
  Schedule a refactor unit once the parallel waves settle.
- Sound: round-2 designs are layered recipes (sfx-02 renderer), director-authored.

## 2026-10-12 — visual identity gate, art-02 fronts batch 1
- Independent judge (fresh subagent, rubric spec/art_identity/judge_rubric.md): 5/10 PASS (hoarfrost_seer, gale_herald,
  arc_thrall, storm_capacitor, gloam_stalker); FAIL briar_weaver (veined leaves, olive edge fringe), slag_mortar (head
  hidden under kiln), glacial_mirror (warm terracotta, reads as earth golem), gust_shrike (clone of roc_fledgling —
  both kit peers were that bird), hollow_mimic (bronze camo, not black glass).
- Fixes: process unmixes key blends in the edge ring (olive fringe); preamble gains "References are for camera, scale
  and hand only — never copy a silhouette"; shrike re-generated from a new silhouette subject (front_v2); the other
  four iterated as colour/detail/head edits of the same job.
- Lesson: duplicate peers bias copying; when an anatomy has one canon member, the subject must spell out a distinct
  silhouette.

## 2026-10-15 — sfx-04 loudness exceptions (director)
- Under the restored peak caps (impacts ≤ −3 dBFS, all ≤ −1 dBTP), two re-trimmed cues fall below the −1.0 LU window:
  `hit.blade.light_01` −2.131 LU and `hurt.hero_01` −1.255 LU. Accepted: both are light/secondary impacts where a slightly
  softer hit reads correctly; revisit only if a listening pass flags them.

## 2026-10-15 — ux-04 text decisions (director)
- Keyword/term tokens render in `UiPalette.GOLD_BRIGHT`, same font/weight, no underline, everywhere (one named constant).
- Graftwright donor result: "<Item> destroyed" ("consumed" stays reserved for the item Consume keyword).

## 2026-10-16 — owner decisions
- Self-hits from Meteorfall / Detonate stay amplified by the hero's Expose / Chilled / Frozen (owner: "Yes, I think so").
  Only Fatigue is excluded (fix-03). No change needed.
- Starting diversity: a run-start boon choice (pick 1 of 3), offered by the emaciated man at the beginning of a run;
  the heirloom (one equipment piece kept from the previous run) is one possible option, never automatic.
- Spell/magic slot limit: dropped entirely. Spells go straight into the deck (no equipping after fights); deck
  dilution is the cost, so card removal must be available.
