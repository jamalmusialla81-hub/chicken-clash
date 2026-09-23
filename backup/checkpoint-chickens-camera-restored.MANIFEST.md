# checkpoint-chickens-camera-restored

## STATUS: RUNTIME-ONLY / VISUALLY REJECTED

Everything below was verified only via attribute/instance-count/runtime-state inspection, never via an
actual look at the rendered screen (this host's screenshot tooling was broken all session). The user has
since visually inspected the live game and rejected the result: no player chicken or dummy is actually
visible on screen, the camera sits inside/beside structural beams instead of framing a target, and the
active fighter label showed the already-known-incompatible Red Chicken. Runtime existence checks do not
override that visible evidence. Do not treat this checkpoint as an accepted milestone - it is a recovery
snapshot only. The real fixes are being tracked under Gate 1 of the follow-up work order
(`checkpoint-golden-visible-camera-framed` is the checkpoint that will supersede this once Gate 1 actually
passes a human visual check).

Parts A (chicken spawning diagnostic), B (first-person camera/cursor), and C (authoritative lobby-avatar
restoration) of the "STOP - complete presentation rebuild" directive. This is a fresh checkpoint under the
name requested in the latest full spec re-paste; the same work was previously checkpointed as
`checkpoint-partABC-camera-avatar-fixes` earlier in this session - see that manifest for the original
diagnostic details. This checkpoint captures the current, re-verified state after Part D's UI work landed
on top (no camera/avatar/spawning code changed since the earlier checkpoint, only re-confirmed live).

## Part A: chicken spawning diagnostic

No spawn bug exists. Both fighter and dummy are correctly parented, PrimaryPart=HumanoidRootPart, have a
real Humanoid+Animator, all Motor6Ds/MeshParts intact, zero parts hidden by LocalTransparencyModifier,
correct pivots/health/ChickenDefId. `setLocalTransparency` only ever touches `Controller.chicken`'s own
named descendants by direct reference, never scans Workspace by name - it cannot hide the dummy or another
player's chicken. The earlier "chickens don't appear" report was the Lighting darkness, already fixed.

## Part B: first-person camera and cursor

`MouseIconEnabled` now correctly tracks `MouseBehavior` (both flip together entering/exiting first person -
the original bug was `MouseIconEnabled` staying `true` while `MouseBehavior=LockCenter`). Mouse-look reads
`UserInputService:GetMouseDelta()` once per frame inside the single `onRenderStep` bind in the exact
required order (delta -> yaw -> pitch -> clamp -> base CFrame -> yaw/pitch -> sway/bob -> recoil -> shake ->
set `camera.CFrame` once -> FOV separately). `Controller.SetMenuOpen`/`IsMenuOpen` release/relock the mouse
without tearing down the render binding or snapping yaw/pitch. Verified live this session: 5 fresh
Lobby -> Practice -> Lobby cycles left the `"ChickenCombatCamera"` render-step binding free to rebind every
time (no leaked duplicate), final state after cycle 5 was `controllerState="Lobby"`,
`mouseIcon=true`/`mouseBehavior=Default`, zero runtime errors.

## Part C: authoritative lobby-avatar restoration

`ServerScriptService.Combat.LobbyReturn.RestoreAvatar(player)` is the one shared function used by
`MatchService.PlayerAdded`, `MatchService.teardownMatch`, and `PracticeService.Exit` - no more independent
`player:LoadCharacter()` call sites racing each other. Verified live: after `PracticeService.Exit`,
`player.Character.Name` correctly becomes the real avatar name (`Jakob6566`, not `Jakob6566_Practice`)
within ~1.5s of `LoadCharacter()` completing.

## Restore

| File | import_rbxm parent_path |
|---|---|
| `checkpoint-chickens-camera-restored.serverscriptservice.rbxm` (whole Combat folder) | `game.ServerScriptService` |
| `checkpoint-chickens-camera-restored.starterplayerscripts.rbxm` (ChickenCombatInput only) | `game.StarterPlayer.StarterPlayerScripts` |
| `checkpoint-chickens-camera-restored.replicatedstorage.rbxm` (ChickenCombatCameraController) | `game.ReplicatedStorage.ChickenClash` |
