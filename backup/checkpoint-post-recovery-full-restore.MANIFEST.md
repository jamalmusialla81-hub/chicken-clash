# checkpoint-post-recovery-full-restore

Created after the 2026-09-23 data-loss incident (a stale, pre-Phase-1 Studio window was mistakenly
treated as current and the real session was closed). Everything below was rebuilt from local `.luau`
source files in `chicken_models/stylised/luau/` plus known-correct inline-script parameters, verified
live via a full solo playtest (queue -> bot-fallback -> arena -> entrance -> countdown -> best-of-3
rounds -> results -> lobby, plus practice mode enter/exit).

## Why per-file, not one bundled .rbxm

An earlier bundled checkpoint (children of 5 services in one file) could not be re-imported:
`StarterPlayerScripts`/`StarterCharacterScripts` are singleton instances and `import_rbxm` cannot
reparent them under ANY destination ("Cannot change Parent of type StarterPlayerScripts"), and the
whole call fails atomically. The fix used here: never export the singleton container itself, only
its ordinary child instances, and import those children directly back into the real (always-existing)
singleton.

## Restore order (each is an independent `import_rbxm` call)

| File | import_rbxm parent_path |
|---|---|
| `checkpoint-post-recovery-full-restore.replicatedstorage.rbxm` (ChickenClash folder, ChickenVisuals["Golden Chicken"], Combat folder) | `game.ReplicatedStorage` |
| `checkpoint-post-recovery-full-restore.serverscriptservice.rbxm` (Combat folder, HubSafety script) | `game.ServerScriptService` |
| `checkpoint-post-recovery-full-restore.starterplayerscripts.rbxm` (7 combat client LocalScripts, NOT the StarterPlayerScripts container) | `game.StarterPlayer.StarterPlayerScripts` |
| `checkpoint-post-recovery-full-restore.wheelspincontroller.rbxm` (patched WheelSpinController only) | `game.StarterPlayer.StarterPlayerScripts.Controllers` |
| `checkpoint-post-recovery-full-restore.arenas.rbxm` (ArenaSlot1/ArenaSlot2 models) | `game.Workspace.Map` |
| `checkpoint-post-recovery-full-restore.goldenchicken.rbxm` (production combat rig incl. CombatCameraAttachment) | `game.ServerStorage.CombatChickens` |

All other project state (CombatChickens for other chickens, ChickenVisuals for other chickens,
Preserved/, MoonAnimator saves, etc.) was untouched by the incident and is covered by the existing
per-phase `.services.rbxm`/`.workspace.rbxm` checkpoints already in this folder.

## Not capturable in any .rbxm

Runtime-created RemoteEvents/RemoteFunctions (`AttackRequest`, `DashRequest`, `MatchCameraDirective`,
`RematchRequest`, `ChickenHitConfirmed`) are created lazily by the Combat scripts' own top-level code
the first time they run (in Play mode or in a published server) - they will not exist in an edit-mode
snapshot and do not need to be, since the scripts recreate them idempotently
(`FindFirstChild(...) or Instance.new(...)`) every time.
