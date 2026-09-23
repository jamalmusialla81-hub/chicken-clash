# checkpoint-practice-landmarks-and-sound-scaffolding

Finishes the remaining part of Phase 3 (per-lane landmark identity) and adds the structural half of
Phase 8 (sound architecture) from the "reference-informed implementation and visual polish pass". Both
pieces are small, additive, and independently verified live. Depends on
`checkpoint-reference-informed-camera-ui` (uses `UIStateController`).

## Phase 3 finish: per-lane landmark identity

The Practice Range's 4 lanes (Stationary/Strafing/Attacking/Combo) already had signage and colored floor
accents from the Gate 4 map pass, but nothing made a lane feel "active" or showed real per-lane stats.
Added:

- **`PracticeService.luau`** ([PracticeService.luau:134](chicken_models/stylised/luau/PracticeService.luau:134)): `pushStats()`'s payload now includes the session's
  current `mode` (e.g. `"Stationary"`) alongside the existing combo/damage/combo-record fields - a
  one-field addition, no breaking changes to the existing `PracticeStats` consumers (`PracticeHUD`).
- **New `PracticeLaneLandmarks.client.luau`** (`StarterPlayer.StarterPlayerScripts`): reads that `mode`
  field to (a) set the active lane's floor `AccentRing` to `Neon` and dim the other three to
  `SmoothPlastic`, and (b) show live "`{dmg} dmg · x{combo} combo (best x{highestCombo})`" text on a new
  `CounterLabel` added under each lane sign's existing `BillboardGui` (idle lanes show `"-- hits"`). Resets
  every lane to idle the moment the player's UI mode leaves `"Practice"` (via `UIStateController`).
- **New `FloorArrows` folder** under `workspace.Map.PracticeRange`: 4 two-part Neon wedge arrows (one per
  lane, colored to match that lane's accent), placed along the path from the practice spawn point toward
  each lane, computed via `CFrame.lookAt` so they genuinely point at the right lane regardless of layout
  changes. **Not pixel/screenshot verified** (this host's `CaptureService` still returns a blank frame,
  a pre-existing, previously-documented limitation) - geometry placement was verified only numerically
  (position/orientation math), not visually.

### Verification performed live

Entered practice via direct server calls (`PracticeService.Enter`/`SetDummyMode`/`Exit`), then read back
client state via `eval_client_runtime`:
- Switching to `"Combo"` then `"Strafing"` correctly lit only that lane's ring and showed a live,
  correctly-formatted stats string (confirmed non-crashing on the `0`/`0`/`0` case, which also proves the
  `math.floor()` guards around `string.format("%d", ...)` work - an unguarded float there would have
  errored).
- Exiting practice correctly reverted all 4 rings to `SmoothPlastic` and all 4 counters to `"-- hits"`.
- One test run immediately after a fresh playtest start showed all 4 rings still `Neon` (their original
  Gate-4-built material) and no counter update after the very first `SetDummyMode` call - a startup race
  in my own test methodology (I drove `Enter`/`SetDummyMode` from a server script within ~1-2s of playtest
  start, faster than a real player could ever reach the training dojo, racing ahead of the client script's
  own `require`/`WaitForChild` calls), not a real bug: a direct listener hook on the same remote confirmed
  it fires correctly, and every subsequent call in the same session worked every time.
- Zero non-noise runtime errors across the whole test sequence (`get_runtime_logs` checked after each
  major step).

## Phase 8 (partial, honest): Sfx/Music SoundGroups

- Two `SoundGroup` instances created under `SoundService`: `Sfx` and `Music`.
- **`ChickenSoundKit.luau`** (`ReplicatedStorage.ChickenClash.ChickenSoundKit`): every pooled `Sound` now
  gets `sound.SoundGroup` set to `Music` or `Sfx` based on its `category` field (currently all 12 defined
  sounds are `"World"`, which routes to `Sfx` - there is no music track anywhere in the project yet, so
  `Music` exists as scaffolding for whenever one is added, not because one exists).
- **This is scaffolding only, not a functioning sound layer.** Every one of the 12 sound definitions still
  has `id = ""` (no real audio assets exist) - `getOrCreate()` still no-ops before ever touching
  `SoundGroup`, so this code path is entirely unexercised until Jakob uploads real audio and fills in a
  `SoundId`. Verified live only that the module still `require()`s without error and that both groups
  exist and are reachable from the client (`SoundService:FindFirstChild("Sfx"/"Music")`).
- **Not done**: no volume-control UI (no settings panel slider wired to `SoundGroup.Volume` - there's
  nothing meaningful to control with silent placeholder sounds, so building one now would be UI for a
  feature with no audible effect), no actual background music, no `Kit.PlayLocal` non-spatial seam
  (mentioned in the module's own header comment as a future addition, still not built).

## Not covered by this checkpoint

Phase 4 (chicken selection/transformation sequence), the rest of Phase 5 (full VFX suite), Phase 7
(modular duel presentation), the rest of Phase 8 (actual audio content, once Jakob supplies it), and the
full Phase 9 verification matrix (screenshots, multiplayer).

## Restore

| File | import_rbxm parent_path |
|---|---|
| `checkpoint-practice-landmarks-and-sound-scaffolding.scripts.rbxm` (PracticeService, PracticeLaneLandmarks, ChickenSoundKit) | `PracticeService` → `game.ServerScriptService.Combat`; `PracticeLaneLandmarks` → `game.StarterPlayer.StarterPlayerScripts`; `ChickenSoundKit` → `game.ReplicatedStorage.ChickenClash` (replace existing in each case) |
| `checkpoint-practice-landmarks-and-sound-scaffolding.worldgeometry.rbxm` (Lanes with CounterLabels, FloorArrows) | `game.Workspace.Map.PracticeRange` (replace existing `Lanes`, add `FloorArrows`) |
| `checkpoint-practice-landmarks-and-sound-scaffolding.soundgroups.rbxm` (Sfx, Music SoundGroups) | `game.SoundService` |
