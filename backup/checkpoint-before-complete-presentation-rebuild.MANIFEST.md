# checkpoint-before-complete-presentation-rebuild

Captured per explicit user instruction before starting a full presentation-layer rebuild (chicken
spawning diagnostics, first-person camera/cursor, lobby avatar restoration, complete UI rebuild, map
rebuild in passes). This is the **known-broken** state being fixed, not a known-good state — kept so the
rebuild has an exact "before" to diff against and so nothing here is lost if any step needs reverting.

## Contents

| File | Covers |
|---|---|
| `checkpoint-before-complete-presentation-rebuild.serverandmap.rbxm` | `Workspace.Map` (Hub, PracticeRange, Training, arenas), `ReplicatedStorage.ChickenClash`, `ServerScriptService.Combat`, `ServerScriptService.HubSafety` |
| `checkpoint-before-complete-presentation-rebuild.starterplayerscripts.rbxm` | The 8 combat-related client scripts only (ChickenClashUI, ChickenAnimator, ChickenCombatCamera, ChickenCombatHUD, ChickenCombatInput, MatchCameraBridge, PracticeHUD, MatchHUD) - never the `StarterPlayerScripts` container itself (singleton, cannot be reparented via `import_rbxm` - see the original recovery incident this same session) |

Restore: `import_rbxm` the first into `game.ServerScriptService`/`game.ReplicatedStorage`/`game.Workspace`
as appropriate per top-level name; the second into `game.StarterPlayer.StarterPlayerScripts`.

## Current (broken) Lighting state, for reference

```
ClockTime = 14, Brightness = 4
Ambient = (0.549, 0.510, 0.647), OutdoorAmbient = (0.627, 0.588, 0.745)
FogStart = 300, FogEnd = 3000
Atmosphere: Density = 0.15, Haze = 0.4, Glare = 0.1
```

This was already raised twice live (from the original `ClockTime=0`/`Brightness=1.6` baseline) in response
to "too dark" feedback and is still reported as too dark - meaning the darkness complaint is not fully a
Lighting-property problem. Investigating further as part of Part A/E below.

## Comparison against the last working camera/avatar state

There is no prior checkpoint where the first-person camera had real mouse-look - `ChickenCombatCameraController`
never implemented mouse input at all before today's live-bug-report fix attempt (confirmed by reading the
pre-fix source: `onRenderStep` copied `CombatCameraAttachment.WorldCFrame` directly with no yaw/pitch
tracking anywhere in the file). So "the last known-good camera" does not exist as a prior checkpoint to
restore from - this needs a real implementation, not a revert, which is what Part B below does.

The "avatar missing in lobby" and "dummy/chicken not appearing" reports are being treated as still-open
bugs, not assumed fixed by the lighting changes alone - Part A and Part C below build real diagnostics and
a single authoritative transition function rather than re-patching individual properties.
