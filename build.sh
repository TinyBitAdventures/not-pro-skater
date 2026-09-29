#!/usr/bin/env bash
# Rebuild Blender assets, then re-import them into Godot.
#   ./build.sh            everything
#   ./build.sh park       just the level
#   ./build.sh greybox    just the greybox test level
#   ./build.sh skater     just the character
cd "$(dirname "$0")" || exit 1
blender --background --factory-startup --python blender/build.py -- "$@" 2>&1 | grep -E "Error|Traceback|File \"|exported|WARNING: Mesh" 
rm -f game/assets/levels/*.glb.import.tmp
(cd game && timeout 200 godot --headless --import --path . 2>&1 | grep -E "ERROR|Parse Error" | grep -v "park.tscn" )
echo "build done"
