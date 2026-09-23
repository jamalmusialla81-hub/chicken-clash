# checkpoint-reference-informed-camera-ui

Phases 1 and 2 of the "reference-informed implementation and visual polish pass" (RIVALS/Grow a Chicken
Fighter architectural references - patterns only, no assets/scripts copied). Genuinely complete and
verified live for these two phases specifically; Phases 3-9 are NOT covered by this checkpoint (see
`checkpoint-reference-informed-quick-match` for Phase 6, and the accompanying status report for what
remains).

## Phase 1: camera/input consolidation

`ChickenCombatCameraController` rewritten with the exact explicit state machine requested: `Lobby`,
`Cutscene`, `PracticeCombat`, `MatchCombat`, `MenuOpen`, `Results`, `Disabled` (plus `DeathSpectator`,
kept as a real addition - death-spectating is genuinely distinct behavior that doesn't fold into any of
the 7).

- `PracticeCombat` vs `MatchCombat` is inferred from whether the chicken carries a `MatchId` attribute
  (MatchService sets one, PracticeService never does) - the same signal MatchHUD already reads for the
  same purpose - rather than threading a new parameter through 3 files' existing remote contract.
- Added idempotent `Controller.Start()`/`Controller.Stop()` wrapping the CollectionService tag-watching
  and MatchState-attribute auto-wiring. Verified live: calling `Start()` twice and `Stop()` twice in a row
  produced no errors and left state consistent (`Stop()` correctly returned to `Lobby`).
- Added a real `Results` state. **Fixed a genuine bug**: nothing previously released the mouse when a
  match reached its Results screen, so `MatchHUD`'s Rematch/Return-to-Lobby buttons were unclickable (the
  camera was still holding `MouseBehavior.LockCenter` from combat). Verified live: setting the player's
  `MatchState` attribute to `"Results"` correctly and automatically flipped `MouseBehavior` to `Default`
  and made the cursor visible, with zero changes needed in `MatchHUD` itself.
- `MenuOpen` is now a real state (was previously just a hidden boolean) that remembers and restores the
  exact prior combat state. Verified live: opening then closing returned to the same `PracticeCombat`/
  `MatchCombat` value it started from.
- **Deliberate, documented deviation**: the render-step binding stays at `RenderPriority.Character.Value +
  1` rather than a generic `Camera.Value + 1` a reference architecture might use. In this engine build,
  `Character` (300) runs after `Camera` (200); since this controller writes `hrp.CFrame` directly, binding
  before Character's own movement step caused the exact "sliding/input-delayed movement" the user reported
  and asked to be fixed earlier this session. Reverting to `Camera.Value + 1` would reintroduce that bug,
  so the fix was kept and the reasoning documented in the code itself.
- Verified live: 5 full Lobby -> Practice -> Lobby cycles (each firing a real attack) ended cleanly every
  time, zero non-noise runtime errors, `ReplicatedStorage` descendant count unchanged before/after,
  `workspace` descendant count +1 (noise, not a leak).

## Phase 2: UI mode controller + component kit

- `UIStateController` extended: it now reads `ChickenCombatCameraController.state ==
  Controller.States.Cutscene` (via a lightweight 10Hz poll, chosen over adding a state-changed event to
  the camera controller across its ~10 internal assignment sites for a state that only lasts 1-2 seconds)
  and reports a real `"Cutscene"` mode - previously documented in its own code as "no signal exists yet,
  not fabricated."
- Added a real, original reusable component kit to `Theme.luau`: `Theme.Panel`, `Theme.Card`,
  `Theme.HealthBar`, `Theme.CooldownIndicator`, `Theme.ViewportChickenPreview` - alongside the existing
  `Theme.Button` (already served the Primary/Secondary/Tab-button roles via color/selected-state params).
  These wrap the same corner/stroke/gradient visual language already used throughout the game rather than
  inventing a second design system, and are what the new Quick Match presentation (see the companion
  checkpoint) is built from.
- Verified live: all 5 new component functions load and are callable (`typeof(...) == "function"`) with
  zero errors.

## Not covered by this checkpoint

Phases 3 (practice range finish), 4 (chicken selection transformation sequence), 5 (full pooled VFX
suite beyond the existing slash rig/impact flash/damage numbers), 7 (modular duel presentation
components), 8 (sound architecture/SoundGroups), and the full Phase 9 verification matrix (screenshots,
Quick Match end-to-end with a human watching, multiplayer). These remain open.

## Restore

| File | import_rbxm parent_path |
|---|---|
| `checkpoint-reference-informed-camera-ui.replicatedstorage.rbxm` (whole ChickenClash folder) | `game.ReplicatedStorage` |
| `checkpoint-reference-informed-camera-ui.starterplayerscripts.rbxm` (4 individual scripts, never the StarterPlayerScripts container) | `game.StarterPlayer.StarterPlayerScripts` |
