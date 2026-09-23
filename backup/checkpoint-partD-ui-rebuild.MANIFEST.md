# checkpoint-partD-ui-rebuild

Part D of the presentation rebuild (complete UI rebuild) for the "STOP - complete presentation rebuild
before resuming onboarding" directive. Parts A/B/C (chicken spawning diagnostic, first-person
camera/cursor, authoritative lobby-avatar restoration) were already checkpointed separately as
`checkpoint-partABC-camera-avatar-fixes`. Part E (map rebuild in passes) has not started yet.

## What changed

**Theme.luau** (`ReplicatedStorage.ChickenClash.Theme`) - already re-themed with the exact spec palette in
an earlier session segment; unchanged in this checkpoint but exported again for completeness since
everything below depends on it.

**ChickenCombatHUD.client.luau** - the six always-visible settings controls (Reduced Motion + 5 cycle
buttons) collapsed into one gear icon opening one panel, wired through `Controller.SetMenuOpen` so opening
it releases the mouse and closing it relocks first-person without a snap. Verified live: gear/panel exist,
`Controller.SetMenuOpen(true/false)` correctly toggles `MouseBehavior`/`MouseIconEnabled`, and the panel
auto-closes if combat ends while open.

**MatchHUD.client.luau** - Rematch/Return-to-Lobby buttons rebuilt with `Theme.Button` (13-step depth-button
constructor) instead of a bare TextButton; all hardcoded colors replaced with `Theme.Colors.*` references.
Verified live: zero runtime errors, buttons render and respond.

**PracticeHUD.client.luau** - full rebuild. Stats panel now uses the exact spec row order (Last Hit, Total
Damage, DPS, Combo, Hits per sec, Best Combo, Session) with a new DPS row computed client-side
(`totalDamage / sessionTime`) since the server payload didn't carry it. Training controls consolidated into
one grouped bottom-centre card (lane row: Stationary/Strafing/Attacking/Combo; action row: Infinite HP,
Damage Numbers, Reset Dummy, Clear Stats), all built with `Theme.Button`. Damage Numbers toggle now shares
`Controller.damageNumbersEnabled`/`SetDamageNumbersEnabled` with ChickenCombatHUD's own toggle (same
underlying state, not a second competing flag).

**PracticeService.luau** (`ServerScriptService.Combat`) - added `PracticeService.ClearStats` + a
`PracticeClearStatsRequest` RemoteEvent, deliberately distinct from `ResetDummy`: it only zeroes the
counters without repositioning/re-healing the dummy, matching the new "Clear Stats" button.

**ArenaQueuePrompt.server.luau** (`ServerScriptService.Combat`) - refactored the portal's existing
queue/dequeue toggle into a shared `toggleQueue` function, now also reachable via a new
`QuickMatchRequest` RemoteEvent so the Lobby's new "Quick Match" dock button does the exact same
authoritative queue/dequeue MatchService already does for the physical portal - one toggle path, two entry
points, never two competing implementations.

**ChickenClashUI** (`StarterPlayer.StarterPlayerScripts`, no local file - pre-existing 1388-line LocalScript,
edited in place via targeted `edit_script_lines` calls, never a wholesale rewrite) - replaced the flanking
LeftRail/RightRail "navigation towers" and the mobile-only bottom bar with ONE unified layout on every
platform:
- Top-left **profile card** (270x68): avatar headshot (`Players:GetUserThumbnailAsync`, with a
  letter-avatar fallback if the thumbnail never loads) + display name + `@username`.
- Top-right **currency cards**: Cash (unlocked, full comma-grouped number via the existing
  `Theme.FormatFullNumber`) plus three narrow locked cards (Gene Essence/Rift Shards/Arena Crests) with
  hover tooltips explaining what each unlocks - replaces the old single "giant currency pill" + dropdown.
- **Drawer trigger** + **settings gear** beside the currency cards (one small icon cluster, top right).
- Bottom-centre **dock**: Quick Match (primary, 84px, wired to the new `QuickMatchRequest` remote and
  showing live queued/cancel state polled off the real `MatchState` attribute) + Roll/Chickens/Team/Dex
  (58px, equal size).
- **Secondary drawer** (unchanged popup mechanism, `toggleDrawer`) now holds Daily/Playtime/Quests/Pass/
  Codes/Wheel/Shop - the user's spec list was Daily/Quests/Pass/Codes/Wheel/Shop; Playtime Rewards was kept
  in the drawer too since dropping it would have silently removed access to a working, pre-existing reward
  system with no replacement entry point.
- `Battle`'s coming-soon panel builder is left defined but is no longer reachable from any nav element
  (matches the user's exact dock + drawer lists, neither of which mention Battle).

All `makeButton`/`makeIcon`/tooltip/panel/MORE-drawer/old-frame-controller machinery is untouched - only
the LAYOUT (which frames exist, what they contain, where they sit) changed, not the underlying
Roll/Chickens/Team/Daily/Codes/Wheel wiring, which was explicitly called out as must-not-break.

## Verified live (this session, via solo_playtest + eval_client_runtime/eval_server_runtime)

- ChickenCombatHUD gear/panel: exists, `Controller.SetMenuOpen` round-trips correctly, panel auto-closes on
  combat end.
- MatchHUD/PracticeHUD: push to Studio clean, zero runtime errors in `get_runtime_logs` (checked against the
  full non-noise error list, filtering out known pre-existing asset-delivery/TLS/plugin noise).
- ChickenClashUI: `Dock` has exactly 5 buttons (QuickMatch/Roll/Chickens/Team/Dex), `MoreDrawer` has exactly
  7 (Daily/Playtime/Quests/Pass/Codes/Wheel/Shop), `ProfileCard`/`TopRightCluster`/`CurrencyRow`/
  `DrawerTrigger`/`SettingsButton` all exist. Firing `QuickMatchRequest` from the client flips
  `MatchState` to `"Queued"` and the dock button turns red with text "CANCEL QUEUE" within the 1s poll
  window; the Cash currency card correctly shows the full-precision `"1,000"` (not the old compact `"1K"`).
  A second fire cancels queueing UNLESS the bot-fallback matchmaker already started a real match in the
  interim (observed once live - `MatchState` became `"Countdown"` - which is the pre-existing matchmaking
  system working as designed, not a bug in this UI).
- Two pre-existing, unrelated runtime errors were observed during testing (`FreeSpin is not a valid member
  of Frame "Wheel"` and `Can only tween objects in the workspace`), both from `WheelSpinController`'s
  free-spin countdown loop - confirmed unrelated to any file in this checkpoint (grep shows zero references
  to "FreeSpin" or "Wheel" tweening in any edited file) and flagged separately as a background task rather
  than fixed here (out of scope for the presentation rebuild).

## Not done yet

- No pixel-level screenshot verification - this macOS host's `capture_screenshot`/`CaptureService` returns
  a blank frame (same documented limitation as earlier in this session), so responsive-breakpoint
  verification (1920x1080/2560x1440/3440x1440/phone/tablet) has only been done structurally
  (`camera.ViewportSize` + `applyLayout`'s `computeMode`/`uiScale` math reviewed, not visually screenshotted).
- A `UIStateController` ensuring only one mode layout (Lobby/Practice/Match/Cutscene/Results) is active at a
  time was not built as a separate module - each HUD script already independently gates its own visibility
  off `MatchState`/`Controller.state`, which has worked correctly in every live check this session, but
  there is no single central arbiter.
- Part E (map rebuild in the specified 4-pass sequence) has not started.

## Restore

| File | import_rbxm parent_path |
|---|---|
| `checkpoint-partD-ui-rebuild.serverscriptservice.rbxm` (whole Combat folder) | `game.ServerScriptService` |
| `checkpoint-partD-ui-rebuild.starterplayerscripts.rbxm` (5 individual scripts, never the StarterPlayerScripts container itself) | `game.StarterPlayer.StarterPlayerScripts` |
| `checkpoint-partD-ui-rebuild.replicatedstorage.rbxm` (Theme + ChickenCombatCameraController) | `game.ReplicatedStorage.ChickenClash` |
