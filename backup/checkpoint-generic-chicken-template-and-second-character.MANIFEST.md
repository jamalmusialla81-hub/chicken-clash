# checkpoint-generic-chicken-template-and-second-character

Phase 6 of the playable-alpha expansion: generalized combat away from a hardcoded "Golden Chicken"
string, without fabricating support for any chicken that isn't actually ready.

## What changed

- **New:** `ReplicatedStorage.ChickenClash.ChickenDefinitions` - the registry (display name, combat
  model, preview model, animation catalog, stats, hitbox/playback-speed adjustments, VFX theme,
  rig version, CombatCompatible/CombatUnavailableReason) that everything else now resolves chickens
  through, keyed by a "ChickenDefId" attribute set on every spawned fighter/dummy model.
- **New:** `ServerScriptService.Combat.RigCompatibilityValidator` - inspects real Motor6D hierarchy,
  joint names, required attachments, forward-axis convention, proportions, PrimaryPart, and
  CanCollide-part convention between a candidate rig and the Golden Chicken master template.
- **New:** `ServerScriptService.Combat.ChickenTemplateService` - a Script that runs the validator once
  per non-master definition at server start and writes the real result back into the registry.
- **Modified:** `ChickenCombatService`, `MatchService`, `PracticeService`, `ChickenAnimator` (client) -
  all resolve catalog/stats/hitbox-scale/playback-speed through `ChickenDefinitions` via the model's
  `ChickenDefId` attribute instead of a hardcoded Golden Chicken reference.

## Result: Red Chicken (the second character tested, per the brief's own preference)

**Not combat-compatible.** The validator's real findings, exactly as logged at server start:

> PrimaryPart mismatch: candidate=Body reference=HumanoidRootPart; No Humanoid instance - candidate is
> not a skeletal/animatable rig; Candidate has zero Motor6D joints - it is a static/decorative model
> with no skeleton, not a rig; Missing required attachment(s): Chest/CombatCameraAttachment; Could not
> sample forward axis - missing HumanoidRootPart and/or Head; Proportions differ too much between axes
> to share animation without clipping (bounding-box ratios X=0.69 Y=0.87 Z=0.51); CanCollide part set
> differs from reference convention

In plain terms: **Red Chicken (and, spot-checked, all other 6 non-Golden combat-tier chickens:
Spotted/Lapis/Storm/Toxic/Light/Phantom) have zero Motor6Ds and no Humanoid at all.** They are static
decorative armor/cosmetic clumps (Helm, Pauldrons, Plumes, Talons, Cape, etc.), not skeletal rigs. This
is a bigger gap than "missing animations" - before any animation work can even begin on a second
chicken, someone needs to build a full Motor6D skeleton (matching Golden's exact joint names/topology:
Beak/Cape/Chest/Comb/Halo/Head/Left+RightFoot/Left+RightLowerLeg/Left+RightUpperLeg/Left+RightWingLower/
Left+RightWingUpper/Neck/Tail, all parented under HumanoidRootPart->Body via RootJoint) plus a Humanoid,
the CombatCameraAttachment on Chest, and PrimaryPart=HumanoidRootPart, matching Golden's proportions and
CanCollide convention. This was documented, not fabricated - Red Chicken remains CombatCompatible=false
and untouched as a playable fighter; Golden Chicken is still the only chicken anyone actually fights as.

## Restore order

| File | import_rbxm parent_path |
|---|---|
| `checkpoint-generic-chicken-template-and-second-character.replicatedstorage.rbxm` (ChickenDefinitions) | `game.ReplicatedStorage.ChickenClash` |
| `checkpoint-generic-chicken-template-and-second-character.serverscriptservice.rbxm` (whole Combat folder, incl. the 2 new files + 3 modified ones) | `game.ServerScriptService` |
| `checkpoint-generic-chicken-template-and-second-character.starterplayerscripts.rbxm` (ChickenAnimator only) | `game.StarterPlayer.StarterPlayerScripts` |

## Verified live (solo playtest)

Full match loop through the new generic path: queue -> bot-fallback -> arena reserve -> spawn (fighter
tagged `ChickenDefId="Golden"`) -> Entrance -> Countdown -> Active combat (attack request, combo
attribute replication, hit/damage via `def.Stats.AttackDamage`) -> round win -> best-of-3 -> Results ->
teardown -> `MatchState` back to `Lobby`. Practice mode: Enter (fighter + dummy both tagged
`ChickenDefId="Golden"`) -> attack -> Exit -> `Lobby`. No script errors in runtime logs (only the
expected offline-sandbox asset/sound-CDN fetch failures, unrelated to this change).
