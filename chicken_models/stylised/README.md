# Stylised Golden Chicken - benchmark

Direction: clean, chunky, cartoon low-poly Roblox combat chicken. Colour blocking from a painted palette atlas, no PBR noise,
aura as effects (never baked into the mesh). The previous realistic/PBR iteration is preserved in
`../../chicken_model_iterations/realistic_pbr_v1/` and (Studio side) `ServerStorage/Preserved/ChickenModelIterations`.

## Files
| Path | What |
|---|---|
| `scripts/golden_toon.py` | builds the model in Blender (clean shapes, palette UVs, painted atlas) |
| `scripts/golden_toon_export.py` | 29-bone skeleton, rigid skinning, FBX/GLB export, derived preview, triangle + rig report |
| `scripts/render_refs.py` | front / side / three-quarter renders + black silhouettes |
| `blend/golden_toon_master.blend`, `blend/golden_toon_rigged.blend` | source files |
| `textures/golden_toon_atlas.png` | 512x512 albedo atlas (gradient rows, painted eye, engraved feather emblem). No normal / roughness / metalness maps are used. |
| `exports/GoldenChicken_Stylised_combat.{fbx,glb}` | rigged combat master: 19 mesh parts, 29 bones |
| `exports/GoldenChicken_Stylised_preview.{fbx,glb}` | derived preview: one merged, decimated mesh, no rig |
| `exports/GoldenChicken_Stylised_report.json` | triangles per part, full rig list, part-to-bone map |
| `renders/GoldenStylised_{combat,silhouette}_{front,side,three}.png` | reference renders |
| `luau/` | ChickenRig, ChickenLocomotion (IK), ChickenIdle, ChickenPoses, ChickenAura, ChickenAnimator, ChickenStateService, tests/ |

## Numbers
- Combat master: 15,728 triangles, 19 MeshParts (target was 8-15k; 728 over - the crown petals and breastplate carry the identity).
- Preview: 6,604 triangles, 1 MeshPart (target 3-7k).
- One material atlas: 512x512.

## Rig hierarchy (Roblox names)
HumanoidRootPart > Body > Chest > Neck > Head > (Beak, Comb, Halo); Chest > LeftWingUpper > LeftWingLower, RightWingUpper > RightWingLower,
Cape; Body > Tail, LeftUpperLeg > LeftLowerLeg > LeftFoot, RightUpperLeg > RightLowerLeg > RightFoot.
Attachments: AuraRoot, FootSigil, LeftWingTrail, RightWingTrail, Weapon, Ultimate, CrownEffect, BackEffect, FinisherTarget.

## Importing into Roblox (needs you - assets must be uploaded)
Runtime EditableMesh / EditableImage data was tested and does NOT survive save/load or reach the playtest client, so it cannot be
the shipping path.
1. Studio > Home > Import 3D (or Asset Manager > Import), pick `exports/GoldenChicken_Stylised_combat.fbx`.
   Keep "Import as Model", meshes named as in the FBX (Body, Chest, Head, ... they already use the rig names). Textures embed.
2. Import `GoldenChicken_Stylised_preview.fbx` the same way.
3. Combat: put the imported parts in a Model named `Golden Chicken`, then run
   `require(ReplicatedStorage.ChickenClash.ChickenRig).Assemble(model, CFrame.new(...))`. It builds the HumanoidRootPart, all Motor6Ds
   with correct pivots, the 9 attachments, Humanoid and Animator. (The parts must be at their imported rest positions; the FBX keeps them.)
4. Preview: place the single MeshPart model in `ReplicatedStorage/ChickenVisuals` as `Golden Chicken` (Anchored, CanCollide false).
5. The model faces -Y in Blender. The importer converts axes; if the chicken does not face +X in Studio, rotate the whole model, since
   the rig module and all existing viewers assume +X.
