# checkpoint-portal-practice-range

Replaces the small TrainingDojo-island practice sandbox with a large, dedicated Practice Range reached
via the hub's existing dojo prompt (now framed as a portal). Reuses `PracticeService` end to end - no
second/parallel practice system was created.

## What changed

- **New:** `workspace.Map.PracticeRange` at `(500, 10, 0)`, far from both the hub and every match arena
  (arenas sit at x=300): a 100x100 floor with boundary walls, 4 lane zones with colored floor patches and
  signage (Stationary/Strafing/Attacking/Combo - all real physical positions, not just an AI-behavior
  label), a 5-gate dash/movement obstacle lane (pure level geometry, no server logic - there is nothing to
  score about running through space), a torii-style return gate + `ReturnToHubPrompt`, and a
  chicken-selection station with one pedestal per `ChickenDefinitions` entry (Golden selectable, Red shown
  "Locked").
- **Rewritten:** `ServerScriptService.Combat.PracticeService` - dummy/fighter spawn at the new range
  instead of the old dojo island; `SetDummyMode` now physically teleports both the dummy and the fighter
  to the chosen lane's real position (previously just changed an AI-behavior flag in place); added a
  fourth "Combo" lane (close-range, dummy holds still); added `SetChicken(player, defId)` which rejects
  anything the rig-compatibility validator hasn't cleared (fires `PracticeChickenLocked` with the real
  reason) and otherwise fully tears down the previous fighter+dummy (camera/tracks/VFX/sounds/connections)
  before spawning the new pair, in the same "build the replacement, swap `player.Character`, then destroy
  the old one" order every other spawn path in this codebase already uses; stats now also track
  `highestCombo` and `sessionTime`.
- **New:** `ServerScriptService.Combat.PracticeRangePrompts` - wires the range's own return gate and
  selection-station prompts to `PracticeService`.
- **Modified:** `ServerScriptService.Combat.TrainingDojoPrompt` - same toggle behavior, relabeled
  "Practice Portal" / "Enter Practice Range" since it now teleports into the new range instead of spawning
  practice on the small island itself. The dojo's own bamboo/lantern/target decoration is untouched -
  it was always just backdrop, never wired to a live dummy, so there was no second system to remove.
- **Modified:** `StarterPlayer.StarterPlayerScripts.PracticeHUD` - added the "Combo" lane button and two
  new stat lines (Highest Combo, Session time), plus a brief on-screen message when a locked chicken is
  attempted. The stats panel is otherwise the same Phase-3 layout; a proper collapsible-panel redesign is
  explicitly the next task (`checkpoint-final-hud-and-practice-ui-polish`), not this one.

## Real bug found and fixed mid-task

`ServerScriptService.HubSafety`'s distance safety net (returns players over 240 studs from the hub center
back to a hub spawn pad every 0.5s) had an `IN_MATCH_STATES` exemption table for real matches, but
`"Practice"` was never in it - Practice never needed the exemption before, since the old dojo island was
only ~90 studs from the hub center. The instant the range moved to 500 studs out, this net started
yanking practicing players back to the hub twice a second. Added `Practice = true` to the exemption table.
Caught by literally reading the fighter's position after `Enter()` and finding it back at a hub spawn pad
instead of the range - not assumed working without checking.

## Restore order

| File | import_rbxm parent_path |
|---|---|
| `checkpoint-portal-practice-range.serverscriptservice.rbxm` (whole Combat folder + HubSafety) | `game.ServerScriptService` |
| `checkpoint-portal-practice-range.starterplayerscripts.rbxm` (PracticeHUD) | `game.StarterPlayer.StarterPlayerScripts` |
| `checkpoint-portal-practice-range.workspace.rbxm` (PracticeRange) | `game.Workspace.Map` |

## Verified live (solo playtest)

Enter -> fighter/dummy spawn at the correct range position (confirmed exact coordinates) -> switch to
Attacking lane -> both fighter and dummy physically relocate to that lane -> attempted Red chicken ->
correctly rejected, stayed Golden -> real attacks landed, `PracticeHUD` showed all 6 stats including the
two new ones (`Highest Combo: 2x`, `Session: 0:22`) -> Exit via the same path the return gate uses ->
`MatchState` back to `Lobby`. Repeated Enter/SetChicken(no-op)/SetDummyMode/Exit x3 in a row: zero leftover
folders under `workspace.ActiveMatches`, no runtime errors. `MatchService.Queue`/`Dequeue` re-verified
unaffected by the `HubSafety` change.
