#!/usr/bin/env bash
# Rebuild Blender assets, then re-import them into Godot.
#   ./build.sh                  everything (levels, board, items; the neighborhood light bake takes a while)
#   ./build.sh neighborhood     just Neighborhood Park (NOBAKE=1 keeps the old lightmaps)
#   ./build.sh greybox          just the greybox test level
# Characters: blender --background --python blender/character.py -- <key>   (needs MPFB; see README)
cd "$(dirname "$0")" || exit 1
blender --background --factory-startup --python blender/build.py -- "$@" 2>&1 | grep -E "Error|Traceback|File \"|exported|WARNING: Mesh"
rm -f game/assets/levels/*.glb.import.tmp
(cd game && timeout 300 godot --headless --import --path . 2>&1 | grep -E "ERROR|Parse Error")
echo "build done"
