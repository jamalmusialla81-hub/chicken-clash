# checkpoint-partABC-camera-avatar-fixes

Parts A/B/C of the presentation rebuild (chicken spawning diagnostic, first-person camera/cursor,
authoritative lobby-avatar restoration), verified live. Parts D (UI rebuild) and E (map rebuild) are
separate, much larger checkpoints still in progress.

## Part A: chicken spawning diagnostic

Ran the full diagnostic (definition, source/runtime model path, descendant/BasePart/MeshPart counts,
PrimaryPart, pivot, health, parent, transparency/LocalTransparencyModifier counts, Animator) against both
the fighter and dummy live in the Practice Range. Result: **no spawn bug exists**. Both are correctly
parented, PrimaryPart=HumanoidRootPart, real Humanoid+Animator, 19/19 Motor6Ds, all 19 MeshParts valid,
zero parts hidden by LocalTransparencyModifier, correct pivots/health/ChickenDefId. Also confirmed
`setLocalTransparency` already only ever touches `Controller.chicken`'s own named descendants by direct
reference - it cannot hide the dummy or any other player's chicken, since it never scans Workspace by
name. No rebuild was needed here; the earlier "chickens don't appear" report was the Lighting darkness.

## Part B: first-person camera and cursor

Confirmed the exact bug reported: `MouseIconEnabled` stayed `true` while `MouseBehavior=LockCenter` -
internally inconsistent, cursor visibly stuck at screen centre. Fixed in
`ChickenCombatCameraController`:
- `MouseIconEnabled = false` on entering first person, `= true` on exit (was missing entirely before).
- Switched mouse-look from an `InputChanged` connection to `UserInputService:GetMouseDelta()` read once
  per frame inside the single `onRenderStep` bind, matching the exact order specified (delta -> yaw ->
  pitch -> clamp -> base CFrame -> yaw/pitch -> sway/bob -> recoil -> shake -> set `camera.CFrame` once ->
  FOV separately).
- Added `Controller.SetMenuOpen(bool)`/`IsMenuOpen()`: releases the mouse without tearing down the render
  binding, preserves yaw/pitch (no snap on close). `ChickenCombatInput` now checks `IsMenuOpen()` before
  firing attack/dash so a menu can't leak combat input.
- Verified live: 5 Practice enter/exit cycles left `RunService:BindToRenderStep("ChickenCombatCamera", ...)`
  free to bind again afterward (no leaked duplicate), final state correctly `Lobby` with
  `MouseIconEnabled=true`/`MouseBehavior=Default`. Verified `mouseIcon=false`/`autoRotate=false` while
  actually in `CombatFirstPerson`.

## Part C: authoritative lobby-avatar restoration

New `ServerScriptService.Combat.LobbyReturn` module - the one shared `RestoreAvatar(player)` function now
used by `MatchService.PlayerAdded`, `MatchService.teardownMatch`, and `PracticeService.Exit` (previously
three independent `player:LoadCharacter()` calls). Waits for a real Humanoid/HumanoidRootPart after
`LoadCharacter()` (5s timeout, warns instead of silently continuing if it never appears), with a defensive
fallback pivot to a known-safe hub position only if the avatar somehow lands more than 300 studs from it.

## Restore

| File | import_rbxm parent_path |
|---|---|
| `checkpoint-partABC-camera-avatar-fixes.serverscriptservice.rbxm` (whole Combat folder incl. new LobbyReturn) | `game.ServerScriptService` |
| `checkpoint-partABC-camera-avatar-fixes.clientscripts.rbxm` (ChickenCombatCameraController, ChickenCombatInput) | `game.ReplicatedStorage.ChickenClash` / `game.StarterPlayer.StarterPlayerScripts` respectively |

## Still open

Part D (complete UI rebuild - Theme module, Lobby/Practice/Match layouts, responsive testing) and Part E
(map rebuild in passes) are next, per the user's explicit instruction not to resume any other roadmap
phase until those are done and verified too.
