# checkpoint-ui-complete-rebuild

## STATUS: RUNTIME-ONLY / VISUALLY REJECTED

Everything below was verified only via `ScreenGui`/attribute/instance-count inspection, never an actual
look at the rendered screen. The user has since visually inspected the live game and rejected it: a broken
glyph after "STATS", a giant floating "Red Chicken"/lane label, unexplained yellow circle and red line
artifacts, dark text on dark buttons, an oversized bottom-centre training panel, a tiny low-contrast brown
reticle, and CoreGui overlap. Runtime existence checks do not override that visible evidence. Do not treat
this checkpoint as an accepted milestone - it is a recovery snapshot only. The real fixes are tracked under
Gate 3 of the follow-up work order (`checkpoint-practice-ui-visually-rebuilt` supersedes this once Gate 3
actually passes a human visual check).

Part D (complete UI rebuild) of the "STOP - complete presentation rebuild" directive. Structurally and
functionally complete and verified live; pixel-level visual verification is NOT done (see "Not verified"
below) - this checkpoint should not be read as "looks correct," only "built to spec and functions without
errors."

## Design system

`Theme.luau` carries the exact spec palette (Navy900/Navy700/Cream100/Gold500/Gold700/Orange500/Coral500/
Cyan400/Green500/Red500/Muted500/Outline900/White - never pure black for a panel), `Theme.FormatFullNumber`
(comma-grouped, e.g. `"1,000"`, never compact/`$`), and `Theme.Button` - the full 13-step depth-button
construction (rounded rect, vertical gradient, darker offset depth layer, dark outline, cream inner
highlight, soft shadow, icon+label, hover tween to ~1.04, press to ~0.96, Back-eased return, persistent
selected accent, desaturated disabled state).

## UIStateController (new)

`ReplicatedStorage.ChickenClash.UIStateController` - single source of truth for the active top-level mode
(Lobby/Practice/Match/Results), computed from the player's `MatchState` attribute. Closes a real bug found
this session: `ChickenClashUI`'s ScreenGui had **no gate at all** and stayed visible during Practice and
Match - exactly the "too many unrelated interfaces visible simultaneously" complaint. `ChickenClashUI` now
subscribes via `UIStateController.OnModeChanged` and disables itself (closing any open panel/drawer first)
whenever the mode isn't `"Lobby"`. `ChickenCombatHUD`/`MatchHUD`/`PracticeHUD` already gated themselves
correctly off the same underlying `MatchState`/camera-controller state (verified repeatedly this session)
and were left as-is rather than risk regressing already-working logic; there is no scenario where they and
`UIStateController` can disagree, since both read the same authoritative `MatchState` attribute.

## ChickenCombatHUD

Six always-visible settings controls (Reduced Motion + 5 cycle buttons) collapsed into one gear icon
opening one panel, wired through `Controller.SetMenuOpen` so opening it releases the mouse and closing it
relocks first-person without a snap. Auto-closes if combat ends while open.

## MatchHUD

Rematch/Return-to-Lobby buttons rebuilt with `Theme.Button`; all hardcoded colors replaced with
`Theme.Colors.*`.

## PracticeHUD

- Top-left **RETURN TO HUB** button (new - previously this only existed as a physical ProximityPrompt at
  the range's return gate, not as a UI button per spec). Wired through a new `PracticeExitRequest`
  RemoteEvent -> `PracticeService.Exit`, the same call the physical gate already uses.
- Collapsible stats panel (moved down to y=64 so it sits below the new Return button) with the exact spec
  row order: Last Hit, Total Damage, DPS, Combo, Hits per sec, Best Combo, Session. DPS is computed
  client-side (`totalDamage / sessionTime`) since the server payload didn't carry it.
- One grouped training-controls panel, bottom-centre: lane row (Stationary/Strafing/Attacking/Combo) +
  action row (Infinite HP, Damage Numbers, Reset Dummy, Clear Stats), all built with `Theme.Button`.
  Damage Numbers toggle shares `Controller.damageNumbersEnabled` with ChickenCombatHUD's own toggle (one
  underlying flag, not two competing ones).
- New `PracticeService.ClearStats` + `PracticeClearStatsRequest` remote: zeroes counters only, without
  repositioning/re-healing the dummy (deliberately distinct from Reset Dummy).

## ChickenClashUI (Lobby)

Replaced the flanking LeftRail/RightRail towers and the mobile-only bottom bar with one layout on every
platform:
- Top-left **profile card**: avatar headshot (`GetUserThumbnailAsync`, letter-avatar fallback) + display
  name + `@username`.
- Top-right **currency cards**: Cash (unlocked, full comma-grouped number) + 3 narrow locked cards (Gene
  Essence/Rift Shards/Arena Crests) with hover tooltips - replaces the old single currency pill + dropdown.
- **Drawer trigger** + **settings gear** beside the currency cards.
- Bottom-centre **dock**: Quick Match (primary, 84px, wired to a new `QuickMatchRequest` remote sharing
  `ArenaQueuePrompt`'s exact queue/dequeue toggle - one authoritative path, two entry points) +
  Roll/Chickens/Team/Dex (58px, equal size).
- **Secondary drawer**: Daily/Playtime/Quests/Pass/Codes/Wheel/Shop (kept Playtime alongside the spec's
  named list rather than dropping a working reward system's only entry point).
- Battle's coming-soon panel builder is left defined but unreachable from any nav element, matching the
  spec's exact dock+drawer lists (neither mentions Battle).

## Verified live this session

- ChickenCombatHUD gear/panel: exists, `Controller.SetMenuOpen` round-trips correctly, auto-closes on
  combat end.
- PracticeHUD RETURN TO HUB: button exists at (16,16) without overlapping the stats panel at (16,64);
  firing `PracticeExitRequest` correctly returns `MatchState` to `"Lobby"` and swaps `player.Character`
  back to the real avatar name.
- ChickenClashUI dock has exactly 5 buttons (QuickMatch/Roll/Chickens/Team/Dex), drawer has exactly 7
  (Daily/Playtime/Quests/Pass/Codes/Wheel/Shop). Firing `QuickMatchRequest` flips `MatchState` to
  `"Queued"`, the dock button turns red with text "CANCEL QUEUE" within the 1s poll window, and the Cash
  card shows the full-precision `"1,000"`.
- **UIStateController gate**: confirmed `ChickenClashUI.Enabled` is `true` in Lobby, flips to `false` the
  instant `MatchState` becomes `"Practice"` (while `PracticeHUD.Enabled` is `true` at the same moment), and
  flips back to `true` on return to Lobby.
- 5 fresh Lobby -> Practice -> Lobby cycles via `PracticeService.Enter`/`Exit`: all 5 ended with
  `MatchState="Lobby"`; final state after cycle 5 showed `controllerState="Lobby"`, `mode="Lobby"`,
  `guiEnabled=true`, `mouseIcon=true`/`mouseBehavior=Default`, real avatar name, and the camera's
  `"ChickenCombatCamera"` render-step name was free to rebind (no leaked duplicate).
- `get_runtime_logs` after every test above: zero non-noise errors (only pre-existing, unrelated
  asset-delivery/TLS/plugin-load noise, confirmed present in this environment before any of this session's
  edits).

## Not verified (explicitly, per the user's own instruction not to claim visual completion without it)

- No pixel-level screenshot verification at any of the 5 specified breakpoints (1920x1080/2560x1440/
  3440x1440/phone/tablet). This macOS host's `capture_screenshot` returns a blank single-colour frame every
  time it has been tried this session (confirmed again just now) - `CaptureService` is documented as not
  working on this host, and host window capture is Windows-only per the tool's own message. This is a
  genuine environment limitation, not something retried carelessly.
- The currency cards' "brief count tween" animation on value change (spec item) was not implemented - text
  updates instantly. Minor, flagged rather than fabricated as done.

## Restore

| File | import_rbxm parent_path |
|---|---|
| `checkpoint-ui-complete-rebuild.starterplayerscripts.rbxm` (4 individual scripts, never the StarterPlayerScripts container itself) | `game.StarterPlayer.StarterPlayerScripts` |
| `checkpoint-ui-complete-rebuild.replicatedstorage.rbxm` (Theme + UIStateController) | `game.ReplicatedStorage.ChickenClash` |
| `checkpoint-ui-complete-rebuild.serverscriptservice.rbxm` (whole Combat folder) | `game.ServerScriptService` |
