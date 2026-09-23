# checkpoint-dash-completion-dust

Part of Phase 5 (VFX) from the "reference-informed implementation and visual polish pass": dash
"completion dust" / "ground debris", the one piece of that spec's dash effects list that wasn't already
built (the streak `Trail` already existed and works). Genuinely complete and verified live.

## What was built

`ChickenAura.luau` ([ChickenAura.luau:405](chicken_models/stylised/luau/ChickenAura.luau:405)): `Aura:DashEffect("End")` now also calls a new
`spawnDashDust(model)` alongside the existing Trail-disable logic. It raycasts straight down from the
chicken's `HumanoidRootPart` and, if it hits something, spawns a short-lived (1s, `Debris`-managed)
particle burst tinted from the **actual hit surface's real `Color` property** - so the dust genuinely
reacts to whatever the chicken lands on (Practice Range floor, arena ground, portal disc, etc.) rather
than using one fixed color. Reuses the same `SPARKLE` texture already used everywhere else in this file
(a built-in engine asset, not a new upload) rather than referencing an unverified new texture ID.

## Verification performed live (and a real test-methodology mistake caught and fixed)

- Triggered a dash server-side (`ChickenCombatService.RequestDash`) and confirmed via a client-side
  `GetPropertyChangedSignal("Enabled")` hook on `DashStreakLeft` that the pre-existing `DashStart`/
  `DashEnd` animation-marker pipeline (in `ChickenAnimator.client.luau`) does fire correctly - this is the
  same trigger point `Aura:DashEffect` was already wired to, now carrying the new dust call too.
- **First three verification attempts wrongly reported failure**: I checked for the new `DashDustAnchor`
  part via `workspace:GetChildren()` on the **server**, and it was never there. The actual cause: `Aura`
  instances (and everything they create, including this new dust part) are built by `ChickenAnimator`, a
  **LocalScript** - so the dust part is created in each client's own local Workspace replica and never
  replicates to the server or other clients, the same way the Practice lane ring-highlight in the earlier
  landmarks checkpoint is client-local. Switching the check to `eval_client_runtime` (the correct
  DataModel) on the dash-owning client confirmed the part really is created at exactly the moment the
  `DashEnd` marker fires (`workspace.ChildAdded` hook, timestamp matched to the trail-disable event).
- Independently verified the raycast itself: from the fighter's actual in-game position, it correctly hit
  `Workspace.Map.PracticeRange.Floor` at the expected ground height.
- Zero non-noise runtime errors across the whole test sequence, including the module reload after the
  `set_script_source` push (no syntax/load errors from the new code).

## Not covered by this checkpoint

The rest of Phase 5 (additional particle layers, first-person "speed lines" if that's meant as a distinct
screen-space effect rather than the existing world-space dash Trail), Phase 7, the rest of Phase 8, Phase 9.

## Restore

| File | import_rbxm parent_path |
|---|---|
| `checkpoint-dash-completion-dust.scripts.rbxm` (ChickenAura) | `game.ReplicatedStorage.ChickenClash` (replace existing) |
