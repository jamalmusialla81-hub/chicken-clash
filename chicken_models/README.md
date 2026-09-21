# Chicken Clash - professional chicken model pipeline

Everything here is original: procedurally authored in Blender 5.2 (Python) from lofted sections, sculpted
ellipsoids, curved feather blades and armour shells wrapped over the body/head surface. No Toolbox assets,
no downloaded textures.

## Layout
| Path | Contents |
|---|---|
| `scripts/clib.py` | modelling library (loft, sculpted ellipsoid, feather blade with UVs, surface-wrapped armour patch) |
| `scripts/pbr.py` | procedural PBR material graphs (skin, leather, gold, gems, cloth, horn), atlas baker, authored feather tile |
| `scripts/golden.py` | Golden Chicken geometry |
| `scripts/golden_bake.py` | unwrap, bake albedo / roughness / metalness / normal, build final materials, save `blend/golden_chicken.blend` |
| `scripts/golden_export.py` | decimate to budgets, build the shared skeleton, skin, Idle + HeroReveal actions, export GLB/FBX, dump Studio data |
| `blend/golden_chicken.blend` | modelled + textured (full detail) |
| `blend/golden_chicken_rigged.blend` | decimated, rigged, animated |
| `textures/golden_{albedo,normal,roughness,metalness,orm,eyes}.png` | 1024 atlas maps (eyes 256) |
| `exports/GoldenChicken_combat.{glb,fbx}` | rigged combat model: 18 skinned mesh parts + 24-bone armature + animations |
| `exports/GoldenChicken_preview.{glb,fbx}` | static lightweight preview (main mesh + eyes + runes) |
| `exports/GoldenChicken_stats.json` | triangle counts per part |
| `renders/golden_*.png` | Blender reference renders |

Re-run everything: `blender -b -P scripts/golden_bake.py` then `blender -b -P scripts/golden_export.py`.

## Skeleton (24 bones, shared by every chicken)
Root > Body > Chest > Neck > Head > (Beak, Comb); Chest > WingUpperL > WingLowerL (and R); Body > LegL > FootL (and R);
Body > Tail; Chest > Cape; Root > Halo, Aura, Ultimate, FinisherTarget; Chest > ArmourAnchor_Chest / ArmourAnchor_Back;
WingUpperL > Weapon.

## Importing into Roblox (needs the account owner)
Roblox only keeps custom meshes that are uploaded assets. EditableMesh data does NOT survive saving a place
(verified: after a save/load round trip its content is empty), so it cannot be used as the shipping path.

1. Studio > View > Asset Manager > Import (or Home > Import 3D).
2. Choose `exports/GoldenChicken_combat.fbx` (or `.glb`). Enable "Import as rig" / keep the armature. Textures embedded.
3. Repeat with `exports/GoldenChicken_preview.fbx` (static, no rig).
4. Name the results exactly `Golden Chicken` and place the preview in `ReplicatedStorage/ChickenVisuals`, the combat rig in
   `ServerStorage/CombatChickens`. The model faces -Y in Blender; after import set it to face +X (existing viewers assume +X).
5. If the importer does not build a SurfaceAppearance, add one to the main MeshPart using the four maps in `textures/`.
