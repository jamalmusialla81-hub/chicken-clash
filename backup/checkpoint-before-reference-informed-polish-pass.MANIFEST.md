# checkpoint-before-reference-informed-polish-pass

Pre-work snapshot for the "reference-informed implementation and visual polish pass" work order (RIVALS /
Grow a Chicken Fighter architectural references - patterns only, no assets/scripts copied from either).
Taken immediately before Phase 1 (camera/input consolidation) begins.

## Place/file identity confirmed

`game.Workspace.Name` / dataModelName = `ChickenClash_recovered.rbxl` (the authorized recovery working
copy, distinct from the protected original PlaceId 127672215849650, which was never opened this session).

## Backup verified

`backup_local.sh` run successfully: `Backup written to /Users/jakoblal/Roblox-Backups/2026-09-23_195912`
(270M, non-empty, chicken_models.tar.gz and studio_checkpoints.tar.gz both verified by the script itself).

## Baseline instance counts (fresh Play session, immediately after start, before any test actions)

- `workspace:GetDescendants()`: 9744
- `ReplicatedStorage:GetDescendants()`: 1935
- `ServerScriptService:GetDescendants()`: 79
- `workspace.ActiveMatches` folders: 0 (no players had entered Practice/Match yet)

## Baseline errors

`get_runtime_logs` at this point: 484 total ERR-level entries, **0 non-noise** (all 484 are the
already-documented, pre-existing, unrelated asset-delivery/TLS/plugin-load noise this offline environment
always produces - confirmed present in every playtest this entire session, before any of this session's
own edits). Zero real script errors at the start of this pass.

## Prior checkpoints preserved

This checkpoint does not replace or modify any earlier checkpoint - `checkpoint-chickens-camera-restored`,
`checkpoint-ui-complete-rebuild`, and `checkpoint-gates-1-5-implemented-pending-review` (and their
MANIFEST.md status annotations) remain exactly as they were.

## Honest status of Gates 1-5 as of this checkpoint (per the user's own framing)

- Gate 1 (framing): visually confirmed by the user directly.
- Gate 2 (camera/input): automated evidence only (render-priority fix, 5-cycle test clean) - not yet felt
  in a fresh session by the user.
- Gate 3 (UI): implementation complete for the items found broken, no final visual approval.
- Gate 4 (map): one real but incomplete first environment pass, not the full spec.
- Gate 5 (VFX): slash rig + impact light + damage numbers only, not the full M1/pooled VFX suite.

## Restore

| File | import_rbxm parent_path |
|---|---|
| `checkpoint-before-reference-informed-polish-pass.serverscriptservice.rbxm` | `game.ServerScriptService` |
| `checkpoint-before-reference-informed-polish-pass.starterplayerscripts.rbxm` (individual scripts, never the StarterPlayerScripts container) | `game.StarterPlayer.StarterPlayerScripts` |
| `checkpoint-before-reference-informed-polish-pass.replicatedstorage.rbxm` (whole ChickenClash folder) | `game.ReplicatedStorage` |
| `checkpoint-before-reference-informed-polish-pass.practicerange.rbxm` | `game.Workspace.Map` |
