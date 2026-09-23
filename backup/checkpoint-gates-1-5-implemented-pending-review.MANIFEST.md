# checkpoint-gates-1-5-implemented-pending-review

## STATUS: IMPLEMENTED AND RUNTIME-VERIFIED / NOT YET HUMAN-VISUALLY-APPROVED

Per the user's own instruction ("Create checkpoints only after each gate genuinely passes... Do not name
a checkpoint 'complete' from runtime inspection alone"), this checkpoint deliberately does NOT use the six
gate-specific names from the work order (`checkpoint-golden-visible-camera-framed`,
`checkpoint-first-person-control-accepted`, `checkpoint-practice-ui-visually-rebuilt`,
`checkpoint-champion-roost-range-built`, `checkpoint-m1-vfx-rebuilt`,
`checkpoint-presentation-ready-for-human-review`). Those names are reserved for after the user has
actually looked at each gate and confirmed it. This is a recovery snapshot of real, implemented,
runtime-verified work - not a claim that any gate has passed human review. Only Gate 1's core item
("Golden Chicken actually visible") has a real human confirmation behind it (the user's own screenshot +
"ye its the golden chicken" reply); everything else below is implemented and passed every automated check
available on this host, but genuinely awaits the user's own eyes.

## Gate 1 - Golden Chicken visibility and camera framing

- Fixed `CombatCameraAttachment`'s local position (was 2.6 studs above Chest centre, 1.37 studs above the
  actual Head - i.e. up near the halo, not eye level). Lowered to 1.23. Applied to both the ServerStorage
  template and every currently-live fighter/dummy.
- Fixed every `BillboardGui` in the Practice Range (4 lane signs, gate beam, 2 chicken pedestals, dash
  lane sign): all used a fixed 200x50/240x60-**pixel** `Size` with `MaxDistance = inf`, so they rendered
  at a constant huge screen size regardless of distance - this was the "huge clipped Attacking L... label"
  bug. Switched all to Scale-based sizing with a real MaxDistance, and raised them above head height so
  they no longer sit in the direct fighter-dummy sightline.
- Confirmed server-side that `ChickenDefinitions.Get("Red").CombatCompatible == false` with a real,
  detailed rejection reason (no HumanoidRootPart-named PrimaryPart, no Humanoid, zero Motor6Ds, missing
  CombatCameraAttachment, bad bounding-box proportions) - Red Chicken was never actually selectable as a
  fighter. The bug was only the floating pedestal label reading the raw chicken name; it now reads
  "Red Chicken / RIG NOT READY".
- Corrected severe lighting overexposure (`Brightness` was 4, `Bloom.Intensity` 0.55) to the user's own
  Gate 4 target values (`Brightness=2.0`, `ClockTime=16`, `ExposureCompensation=0`, `Bloom.Intensity=0.15`)
  since a blown-out scene made visibility verification unreliable.
- **User-confirmed live**: after these fixes, the user looked at their own screen and confirmed the dummy
  (highlighted magenta for the check) was visible and reasonably framed, then confirmed again after the
  debug highlight was removed: "ye its the golden chicken."

## Gate 2 - First-person control and embodiment

- **Root-caused and fixed the reported "sliding/input-delayed/not smooth" movement**: the camera's render
  binding was at `RenderPriority.Camera.Value + 1` (300+1=301), which runs BEFORE the engine's own
  Character movement step (`RenderPriority.Character.Value`=300... corrected: Character=300 > Camera=200
  in this build - the binding at old Camera+1 ran before Character resolved movement for the frame, so the
  script's direct `hrp.CFrame` rotation write got partially fought by movement resolution immediately
  after it, every frame). Rebound to `RenderPriority.Character.Value + 1`, confirmed via
  `Enum.RenderPriority` values live (Character=300, Camera=200) that this now runs strictly after
  Character. Not yet re-confirmed by the user's own feel (requires a fresh Play session, which the user
  had not yet done as of this checkpoint).
- Added `Cape` to `HIDDEN_IN_FIRST_PERSON` (it drapes from behind the neck/camera attachment and would
  clip the view there).
- Added one real `SetCursorMode(mode)` function (`"Combat"`/`"Menu"`/`"Lobby"`) replacing three separate
  inline `MouseBehavior`/`MouseIconEnabled` assignment sites - the exact API the spec asked for.
- Verified live: 5 fresh Lobby -> Practice -> Lobby cycles (each including a real `RequestAttack` call)
  all ended in `MatchState="Lobby"`; final state showed `controllerState="Lobby"`, real avatar name,
  `mouseIcon=true`/`mouseBehavior=Default`, and the `"ChickenCombatCamera"` render-step name free to
  rebind (no leaked duplicate binding).

## Gate 3 - UI rebuild

- **Fixed a real, confirmed bug in `Theme.Button`**: `textLabel.TextColor3` was hardcoded to dark
  `Outline900` on every face regardless of the face's own color - unreadable on every dark Navy/Panel
  button (this is the "dark text on dark navy buttons" complaint). Text color is now computed from the
  actual face color's perceived luminance. Verified live: the Stationary lane button (selected, Gold face)
  shows dark text; the Strafing lane button (unselected, dark Navy face) shows exact Cream100 `(255, 241,
  210)` text.
- **Fixed `SetSelected` never actually changing the face color** - it only changed the outline before, so
  "the active mode" never visually looked different beyond a thin outline. Selected mode now shows the
  spec's Gold face with dark text; added a separate `SetTopColor` method for genuine ON/OFF toggles
  (Infinite HP, Damage Numbers) so they show Cyan when on / dark Navy when off, distinct from the
  "selected lane" Gold semantic.
- Rebuilt the reticle from a single translucent dot (read as "a muddy brown pixel") into a proper 4-tick
  cross with a dark outline on each tick and a tiny gold centre dot, matching the spec exactly.
- Rebuilt the bare 10px health line and plain dash circle into proper framed cards (icon, name/label,
  numeric value, bordered bar) bottom-left/bottom-right - these were the "unexplained red line at
  bottom-left" and "unexplained yellow circle at bottom-right."
- Fixed the broken glyph after "STATS" (`\u{25BE}`/`\u{25B8}` triangle characters that didn't render in
  this font) - replaced with plain `v`/`>`.
- Fixed the training-controls panel overflowing its own bounds (action row's buttons summed to 584px
  against a 536px-wide panel interior) by resizing the panel to the spec's 720x148 (within the 680-760 /
  130-160 range) and re-laying out both rows to fit comfortably.
- Fixed `IgnoreGuiInset = true` on ChickenCombatHUD/MatchHUD/PracticeHUD (was placing the settings
  gear/RETURN TO HUB button under Roblox's own top-bar chrome) - all three now respect the safe inset.
- Added the real damage-number renderer: `Controller.damageNumbersEnabled`/`SetDamageNumbersEnabled`
  existed as a toggle before this but nothing ever rendered a number - floating gold/red text now spawns
  on confirmed hits dealt/taken, drifts up and fades over ~0.9s.
- Verified live: zero runtime errors through all of the above, all new elements exist with correct sizes.

## Gate 4 - Practice map rebuild ("Champion Roost Training Grounds")

Real geometry/material/lighting work landed, but this is the gate furthest from the full 6-pass spec -
treat it as a first substantial pass, not the complete rebuild:
- Floor expanded to 180x130 (from 100x100), recolored to the spec's warm stone grey with a lighter-stone
  centre circulation path.
- All 4 boundary walls rebuilt with height variation (18-24 studs), Slate material, dark-slate color
  (never pure black), and a gold trim band.
- Lane floor patches changed from full-brightness Neon slabs (the "blue box" complaint) to SmoothPlastic
  with a slim Neon accent ring only - matches "Neon only for small guidance elements."
- All poles (light poles, ring posts, gate posts) restyled from default gray to Metal/Wood with real
  colors - was "random poles."
- Added: backstops behind every lane's dummy position, a raised observation deck with a scoreboard reading
  "CHAMPION ROOST," partial fabric/timber canopies over two lanes, a gold pavilion roof over the
  chicken-selection station, a glowing portal disc at the return gate, and scattered prop clusters (crates,
  feed sacks, barrels, banners, lamps with real point lights) along the walls/corners, never in the open
  lanes.
- Lighting corrected per Gate 4's own specified values (see Gate 1 section above); ColorCorrection
  saturation/contrast tuned to the spec's 0.05-0.12 range.
- **Not done**: the full height/silhouette pass (pass 3), most of the landmark-specific detail per lane
  (pass 6 - e.g. cyan floor arrows for Strafe, warning stripes for Attack, hit-counter for Combo), and
  edge/corner detail (pass 5) beyond the prop clusters already placed. This is a real first pass, not the
  finished 6-pass range.

## Gate 5 - VFX rebuild

Also a real first pass, not the full spec:
- **Found and fixed a genuine gap**: `Controller.damageNumbersEnabled` was a toggle with nothing behind
  it (see Gate 3). Also found `ChickenSoundKit` is wired but has no real `SoundId`s filled in - already
  honestly documented in its own code as pending; not something fabricated here with fake asset IDs.
- **Added the beam slash rig** the spec named explicitly: a pooled rig with 3 curved `Beam` pairs
  (cream-white core fading to gold/orange edge, `FaceCamera=true`, tapered width 0->peak->0, a brief
  rotation sweep), alternating direction per attack in the combo (Attack1 left-to-right, Attack2
  right-to-left, Attack3 wider/brighter). Debug-traced live and confirmed it correctly builds all 9 child
  instances (3 attachment pairs + 3 beams) and parents/unparents correctly through the pool.
- **Found and fixed a real syntax bug during this work**: `self.model:PrimaryPart` (colon call syntax on a
  property) crashed the entire `ChickenAura` module on load the first time this was tested live - caught
  via `get_runtime_logs`, not assumed away. Fixed to `.PrimaryPart` and re-verified clean.
- Added a `PointLight` flash on server-confirmed hits (the "tiny PointLight flash" impact-feel item),
  wired from the camera controller's existing hit-confirmed handler.
- **Not done**: the full 7-stage M1 sequence (anticipation/on-swing/primary/confirmed-impact/secondary
  debris/dissipation/follow-through - only primary-slash + confirmed-impact-flash exist), the 6 separate
  particle layers, ground debris (raycast-based, needs a real hit-position from the server that isn't
  currently passed over the network), and dash speed-lines/feather-trail/completion-dust. The pre-existing
  `ChickenAura` idle/attack-arc/dash-trail particle system (built in an earlier phase) was left intact and
  is still the primary particle layer.

## Verified this session (automated, not human-visual)

- Zero non-noise runtime errors across every test in this checkpoint, including 5 full
  Lobby -> Practice -> Lobby cycles each firing a real attack.
- `RenderPriority.Character` (300) > `RenderPriority.Camera` (200) confirmed live; camera binds at
  Character+1.
- `Theme.Button` text-color fix confirmed live on both a selected (Gold, dark text) and unselected (Navy,
  cream text) button.
- Beam slash rig confirmed live via debug trace to build and parent 9 child instances correctly.
- `Red.CombatCompatible == false` confirmed server-side with a real validator-produced reason string.

## Not verified (explicitly)

- No pixel-level screenshot verification anywhere in this checkpoint except the one screenshot the user
  personally sent for Gate 1. `capture_screenshot` on this host still returns a blank frame every time it
  has been tried.
- The movement-smoothness fix (Gate 2, render-priority reorder) has not been felt/confirmed by the user in
  a fresh Play session yet.
- Gates 3/4/5 have zero human visual confirmation - only automated/runtime checks.

## Restore

| File | import_rbxm parent_path |
|---|---|
| `checkpoint-gates-1-5-implemented-pending-review.serverscriptservice.rbxm` (whole Combat folder) | `game.ServerScriptService` |
| `checkpoint-gates-1-5-implemented-pending-review.starterplayerscripts.rbxm` (6 individual scripts, never the StarterPlayerScripts container itself) | `game.StarterPlayer.StarterPlayerScripts` |
| `checkpoint-gates-1-5-implemented-pending-review.replicatedstorage.rbxm` (Theme, UIStateController, ChickenCombatCameraController, ChickenAura) | `game.ReplicatedStorage.ChickenClash` |
| `checkpoint-gates-1-5-implemented-pending-review.practicerange.rbxm` (whole PracticeRange, Gate 4 map work) | `game.Workspace.Map` |
