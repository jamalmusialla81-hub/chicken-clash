# checkpoint-practice-chicken-select

Phase 4 (chicken selection UI + transformation sequence) from the "reference-informed implementation and
visual polish pass". Genuinely complete and verified live for what currently exists to select from - see
the honest scope note below on why that's only 2 chickens today. Depends on
`checkpoint-reference-informed-camera-ui` (`Theme`, `UIStateController`).

## What was actually missing

`ChickenDefinitions.luau`'s own header comment stated plainly: *"no chicken-selection UI exists yet; that
is a later pass."* `PracticeService.PracticeSelectChickenRequest` and `PracticeChickenLocked` remotes
already existed and `PracticeHUD` already had a toast wired to `PracticeChickenLocked` - but nothing
client-side ever fired `PracticeSelectChickenRequest`. This checkpoint is that later pass.

## What was built

- **`ChickenTemplateService.server.luau`** ([ChickenTemplateService.server.luau:34](chicken_models/stylised/luau/ChickenTemplateService.server.luau:34)): after its existing rig-validation bootstrap
  runs, it now also publishes a client-safe snapshot - `ReplicatedStorage.Combat.GetChickenRoster`
  (RemoteFunction) - of `{Id, DisplayName, CombatCompatible, CombatUnavailableReason}` per definition.
  This exists because `ChickenDefinitions`' own header explicitly warns the client must never read
  `CombatCompatible` directly off the shared module (validation only ever runs server-side against
  `ServerStorage` rigs, which don't replicate) - that warning was previously just documentation of a gap,
  now it's closed.
- **New `PracticeChickenSelect.client.luau`** (`StarterPlayer.StarterPlayerScripts`): a toggleable panel
  (top-right "CHICKEN" button, visible only during Practice) showing a scrolling grid of cards built from
  `Theme.Panel`/`Theme.ViewportChickenPreview`/`Theme.Button` - the `ViewportChickenPreview` component
  built in the camera/UI checkpoint but never used until now. Each card cross-references the roster against
  the player's own `player.Chickens` ownership folder (the same data source `InventoryController` already
  uses - not re-derived) and shows exactly one of: "Ready" + enabled Select button, "Not owned" + disabled
  Locked button, or the chicken's real validator rejection reason (e.g. Red Chicken's actual
  `RigCompatibilityValidator` text) + disabled Locked button.
- **No new transformation effect was built.** `PracticeService.SetChicken` already fires the existing
  Entrance camera cutscene for the newly-selected fighter (the same one used for match start) - reusing
  that real cinematic instead of building a second, redundant "switch" effect.

### Honest scope limit

`ChickenDefinitions.List` currently has exactly two entries: `Golden` (the one hand-verified,
combat-compatible rig) and `Red` (always locked, real rejection reason). **A chicken-selection UI has very
little to actually select between right now** - this was built because the remote/architecture gap was
real and worth closing, and the grid needs no changes whenever more combat-compatible chickens are added,
but it is not a rich feature yet by itself.

## Verification performed live

- Granted the test player ownership of both Golden and Red (`IntValue` children under `player.Chickens`,
  matching `InventoryController`'s exact data shape) to exercise all three card states.
- Opening the panel during an active Practice session correctly showed "Golden Chicken / Ready / SELECT"
  (enabled) and "Red Chicken / <full validator rejection text> / LOCKED" (disabled) - confirmed the real,
  specific rejection reason renders, not a placeholder.
- Calling `PracticeService.SetChicken(player, "Red")` directly (bypassing the client's own disabled button,
  to test server-side defense-in-depth) correctly left the fighter's `ChickenDefId` unchanged at `"Golden"`
  - the server rejects the switch regardless of what the client UI allows.
- Zero non-noise runtime errors across the whole sequence.
- **Test-methodology artifact, not a bug**: toggling the panel's `Visible` property twice within the same
  Luau execution (no yield in between) left duplicate stale cards behind - traced to Roblox's deferred
  property-changed-signal behavior double-firing the rebuild callback in that specific rapid-fire pattern.
  A real click only ever produces one genuine open/close transition per interaction; two separate,
  naturally-paced toggles (isolated into separate calls, matching real usage) rebuilt the grid correctly
  every time with no duplicates.

## Not covered by this checkpoint

Phase 5 (VFX beyond the existing slash rig/impact flash), Phase 7 (modular duel presentation), the rest of
Phase 8 (real audio content), Phase 9 (full verification matrix, screenshots, multiplayer).

## Restore

| File | import_rbxm parent_path |
|---|---|
| `checkpoint-practice-chicken-select.scripts.rbxm` (PracticeChickenSelect, ChickenTemplateService) | `PracticeChickenSelect` → `game.StarterPlayer.StarterPlayerScripts`; `ChickenTemplateService` → `game.ServerScriptService.Combat` (replace existing) |

Also requires `checkpoint-reference-informed-camera-ui` restored first (for `Theme`/`UIStateController`).
