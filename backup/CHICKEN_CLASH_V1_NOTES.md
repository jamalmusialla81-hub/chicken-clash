# Chicken Clash hub v1 - checkpoint notes

Source session: local file `hickenClash_Base.rbxl` (PlaceId 0, GameId 0). Nothing was published.

Files
- checkpoint-before-chicken-clash-rebuild.{workspace,services}.rbxm : full state BEFORE the rebuild (old map included)
- hickenClash_Base.on-disk-before-rebuild.rbxl                       : copy of the file on disk before the rebuild
- checkpoint-chicken-clash-hub-v1.{workspace,services}.rbxm          : state AFTER the rebuild (this checkpoint)

Note: the .rbxm snapshots hold one folder per service, children renamed "NNN_Name" to keep duplicate names apart.
Restore by copying children back to the matching service and stripping the numeric prefix.

The rebuild lives in the open Studio session. Save the .rbxl from Studio to keep it on disk.
