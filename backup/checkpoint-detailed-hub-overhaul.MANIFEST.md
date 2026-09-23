# checkpoint-detailed-hub-overhaul

Environment pass on `workspace.Map.Hub`, done in-place: every existing functional element (SpawnPads,
Signposts, PartyPads, FloorRings, Boundary walls, Island base geometry, bridge Decks) is untouched. All
new content lives in new `ZoneDecor`/`PlazaDecor` Folders added alongside the existing structure, so
nothing here can conflict with `MatchService`/`PracticeService`/the queue prompts, which were re-verified
live after this pass (spawn, queue, dequeue all still work).

## What changed

- **Center (spawn/welcome plaza):** `PlazaDecor` folder - 4 rock/bush/lamp prop clusters filling the 4
  previously-empty gap angles between the 8 signposts (67.5/157.5/247.5/337.5 degrees, radius 30, clear
  of every spawn pad/party pad/lantern/sign), a low decorative edge-step ring for height variation, and a
  **Practice Portal landmark arch** (a torii-style gate: two lacquer-red posts + crossbeam + glowing orb)
  straddling the Training Dojo bridge threshold - the strongest single landmark visible from the plaza,
  per the brief's own instruction that this zone read as the strongest landmark.
- **Roll Shrine** (gold theme): `ZoneDecor` - 6 prayer-banner posts ringing the shrine + 4 warm votive
  lantern clusters near the steps.
- **Chickendex** (pale-blue/white theme): `ZoneDecor` - 6 holographic data-pillar-and-orb pairs + 5 angled
  glass display-case panels, an archive/database storytelling beat.
- **Team Deck** (cyan theme): `ZoneDecor` - 4 tech-crate clusters (2 crates each, varied size/rotation)
  with a glowing status light per cluster, plus a glowing overhead cable arc between two clusters.
- **Arena Portal** (red theme, this is the Quick Match queue zone): `ZoneDecor` - 6 weapon-rack-and-banner
  posts (crossed practice blades + a battle banner each) plus 4 scattered supply crates - "about to fight"
  storytelling.
- **Gene Lab** (teal theme, serving as the "future content" zone): `ZoneDecor` - 6 glowing specimen-tank
  props + 6 floor conduit lines, reinforcing "something is brewing here, coming soon."
- **Training Dojo, Boss Portal, Ranked:** deliberately left untouched. Training Dojo was already the
  richest, most detailed zone in the whole hub (bamboo, cherry blossoms, stone lanterns, practice
  dummies/targets) and is about to be replaced by the separate portal-practice-range task, so its interior
  wasn't worth re-decorating twice. Boss Portal and Ranked are both still "coming soon" and Ranked is
  being hidden entirely in the very next task (`checkpoint-ranked-disabled-quick-match-only`), so neither
  received new decoration this pass.

## Known follow-up

`workspace.Map.Training.TrainingDojo`'s sign still reads "Combat coming soon" - stale leftover text from
before Phases 1-6 actually built real combat. Noticed in passing while placing the practice-portal arch;
not fixed in this pass since it's a text/label issue unrelated to the environment geometry, but worth a
quick fix (likely alongside the upcoming dojo-to-practice-range replacement, since that same sign will
need new copy anyway).

## Restore

Single file, `checkpoint-detailed-hub-overhaul.workspace.rbxm` (contains the whole `Hub` folder,
functional geometry included), `import_rbxm` `parent_path="game.Workspace.Map"`.

## Verified live (solo playtest)

No runtime errors. Player spawns correctly on a SpawnPad, `MatchService.Queue`/`Dequeue` both still work
identically to before this pass.
