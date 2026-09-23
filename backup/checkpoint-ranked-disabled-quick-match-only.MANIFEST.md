# checkpoint-ranked-disabled-quick-match-only

## Finding before implementing

Grepped every script in the project for "Ranked": there is no matchmaking, rating, or remote logic
behind Ranked at all - `Workspace.Map.Hub.Ranked` is a pure "coming soon" visual (Podium/TrophyCup/steps),
with no ProximityPrompt or RemoteEvent wired to it anywhere. This simplified the task: there was no live
remote/UI path to lock down, only a dead-end signpost+bridge+island to hide.

## What changed

- **New:** `ReplicatedStorage.ChickenClash.FeatureFlags` - `FeatureFlags.RankedEnabled = false`, the
  single central place any not-ready-for-players feature gets gated through going forward.
- **New:** `ServerScriptService.Combat.RankedFeatureGate` (Script) - reads the flag once at server start;
  if disabled, reparents `Hub.Ranked`, `Hub.Bridges.Bridge_Ranked`, and
  `Hub.Center.Signposts.Sign_RANKED` from Workspace into `ServerStorage.DisabledFeatures.Ranked`, fully
  intact (nothing destroyed). Re-enabling later is flipping `RankedEnabled` back to `true` and restarting
  the server.
- **Modified:** `ServerScriptService.Combat.ArenaQueuePrompt` - the live queue prompt's `ObjectText` now
  reads "Quick Match" instead of "Arena" (was already functional, just mislabeled).
- **Modified (static signage, not scripts):** every "ARENA PORTAL" text label (the portal's own two
  carved-stone surface labels, its floating title billboard, and the Center signpost) now reads
  "QUICK MATCH", and the stale "1v1 battles - coming soon" subtitle now reads "1v1 battles - live now" -
  this mode has been fully playable since Phase 1/2, the label was just never updated.
- **Bonus fix, same category, noticed in passing:** `Workspace.Map.Training.TrainingDojo`'s title billboard
  said "Combat coming soon" even though Practice mode has been fully functional since Phase 3 - updated to
  "Practice mode - live now".

## Preserving the underlying work

Nothing about Ranked was deleted. `ServerStorage.DisabledFeatures.Ranked` holds the exact same
`Ranked`/`Bridge_Ranked`/`Sign_RANKED` instances, ready to reparent back to `Workspace.Map.Hub` (or just
flip the flag and restart) whenever real ranked matchmaking is actually built.

## "Ensure no player can invoke ranked through hidden UI or remotes"

Not applicable in the literal sense - there was never a remote or UI action to invoke in the first place
(confirmed by the grep above). Moving the island out of Workspace removes it from replication entirely, so
this is strictly safer than before, not just cosmetically hidden.

## Restore order

| File | import_rbxm parent_path |
|---|---|
| `checkpoint-ranked-disabled-quick-match-only.replicatedstorage.rbxm` (FeatureFlags) | `game.ReplicatedStorage.ChickenClash` |
| `checkpoint-ranked-disabled-quick-match-only.serverscriptservice.rbxm` (whole Combat folder, incl. RankedFeatureGate + modified ArenaQueuePrompt) | `game.ServerScriptService` |
| `checkpoint-ranked-disabled-quick-match-only.workspace.rbxm` (Hub + Training, static signage updated) | `game.Workspace.Map` |

## Verified live (solo playtest)

`RankedFeatureGate` correctly moved all 3 Ranked instances into `ServerStorage.DisabledFeatures.Ranked`
at server start (confirmed: none remain in `Workspace.Map.Hub`, all 3 preserved intact in
`ServerStorage`). No runtime errors. `MatchService.Queue`/`Dequeue` still work identically; the live
prompt's `ObjectText` reads "Quick Match".
