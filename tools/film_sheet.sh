#!/usr/bin/env bash
# Contact sheet of dev_bailfilm.tscn frames: tools/film_sheet.sh <name> [out.png] [frames=12] -> rows of 6 frames.
cd "$(dirname "$0")/../shots" || exit 1
n=$1; out=${2:-film_${n}_sheet.png}; count=${3:-12}
rows=()
for ((s = 0; s < count; s += 6)); do
	files=()
	for ((i = s; i < s + 6 && i < count; i++)); do files+=("$(printf 'film_%s_%02d.png' "$n" "$i")"); done
	magick "${files[@]}" +append "/tmp/_fs_row$s.png" && rows+=("/tmp/_fs_row$s.png")
done
magick "${rows[@]}" -append "$out"
