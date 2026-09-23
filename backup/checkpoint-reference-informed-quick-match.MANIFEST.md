# checkpoint-reference-informed-quick-match

Phase 6 (Quick Match queue presentation) of the "reference-informed implementation and visual polish
pass". Genuinely complete and verified live. Builds on `checkpoint-reference-informed-camera-ui`
(Phases 1-2), which this depends on (`Theme.Panel`/`Theme.Button` from that checkpoint).

## What this adds

Queue *presentation* only - queue *logic* (`MatchService`, `ArenaQueuePrompt`) is unchanged and remains
fully authoritative. A new LocalScript, `QuickMatchPresentation.client.luau`, drives two sinks off the
single real signal already available (the player's own `MatchState` attribute):

1. **World terminal** at the Hub's Arena Portal: a new `QuickMatchTerminal` Part (3x2x0.3, Metal, navy)
   with a `Frame` trim Part (gold) and a `SurfaceGui` (`Background` Frame with `StateLabel`/`SubLabel`
   TextLabels), positioned near the existing `PromptHolder`. What a player physically standing at the
   portal sees.
2. **Persistent overlay** (`QuickMatchOverlay` ScreenGui, built from `Theme.Panel`/`Theme.Button`):
   visible from anywhere in the Lobby, since Quick Match can also be started from the Lobby dock button
   without walking to the portal. Shows a live search timer and a Cancel button.

Both are driven by the same `render()` function reading `player:GetAttribute("MatchState")` - no
duplicated state logic between the world terminal and the overlay.

### Honest scope limit (deliberate, not an oversight)

There is no "OpponentFound"/"Preparing"/"EnteringMatch" pad state. `MatchService.Queue()` sets
`MatchState="Queued"` and on pairing goes directly to `match.state="Preparing"` - there is no
intermediate "opponent found, about to start" server signal to read, so one was not fabricated here.
Once `MatchState` leaves `Queued`/`Lobby`/`Practice` for any real match state, this presentation hides
completely and hands off to the pre-existing `MatchHUD` pre-fight card and Entrance cutscene, rather than
building a second, overlapping "match found" screen.

### Cancel-flash

Clicking Cancel while queued fires the same `QuickMatchRequest` remote used to queue (toggle semantics,
unchanged from `ArenaQueuePrompt`'s existing `toggleQueue`), and locally flashes "QUEUE CANCELLED" /
"CANCELLED" for 1.2s so the click has visible feedback before `MatchState` clears.

## Verification performed live

- Queuing via the Lobby dock button correctly showed "SEARCHING..." with a running timer on both the
  world terminal and the overlay simultaneously.
- An accidental bot-fallback match trigger during testing progressed cleanly through
  Preparing -> Entrance -> Countdown -> Active with the overlay correctly disappearing the instant
  `MatchState` left `"Queued"`, and zero runtime errors - confirming the hand-off to `MatchHUD` works
  without a gap or an overlap.
- Cancel-while-queued correctly showed the flash text, then reverted to the idle "QUICK MATCH / Step up
  to queue" state.

## Not covered by this checkpoint

Everything outside Phase 6: Phases 3 (practice range finish), 4 (chicken selection/transformation), 5
(VFX beyond the existing slash rig/impact flash), 7 (modular duel presentation), 8 (sound architecture),
9 (final verification matrix, screenshots).

## Restore

| File | import_rbxm parent_path |
|---|---|
| `checkpoint-reference-informed-quick-match.starterplayerscripts.rbxm` (QuickMatchPresentation LocalScript) | `game.StarterPlayer.StarterPlayerScripts` |
| `checkpoint-reference-informed-quick-match.worldgeometry.rbxm` (QuickMatchTerminal + Frame parts) | `game.Workspace.Map.Hub.ArenaPortal.Portal` |

Also requires `checkpoint-reference-informed-camera-ui` restored first (for `Theme.Panel`/`Theme.Button`
and the `QuickMatchRequest`/`Combat` remotes this script depends on).
