#!/bin/bash
# Local backup of the Chicken Clash project: Studio checkpoints, Blender pipeline/assets, and the full git history.
# Usage: ~/Roblox/backup_local.sh    (writes to ~/Roblox-Backups/<timestamp>/)
set -e
STAMP=$(date +%Y-%m-%d_%H%M%S)
DEST="$HOME/Roblox-Backups/$STAMP"
mkdir -p "$DEST"
cd "$HOME/Roblox"
tar -czf "$DEST/studio_checkpoints.tar.gz" backup
tar -czf "$DEST/chicken_models.tar.gz" chicken_models
git bundle create "$DEST/roblox_repo.bundle" --all >/dev/null 2>&1
(cd "$DEST" && shasum -a 256 * > SHA256SUMS.txt)
for f in "$DEST"/*.tar.gz; do tar -tzf "$f" >/dev/null && echo "verified $(basename "$f")"; done
git bundle verify "$DEST/roblox_repo.bundle" 2>&1 | tail -1
echo "Backup written to $DEST"; du -sh "$DEST"
