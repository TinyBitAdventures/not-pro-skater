# Changelog

## Unreleased

First playable prototype: one level, a full skating model and the isometric toon look.

### Look
- Orthographic true-isometric camera that follows the skater with look-ahead; Q / E turn it in 90 degree steps.
- Cel shading with three light bands, inverted-hull outlines, world-space grid and patch noise on big flat surfaces.
- Anything standing between the camera and the skater dithers out around them, so tall ramps never hide the rider.
- Everything is built in Blender from scripts (level kit, park, skater) and shipped as glTF.

### Skating
- Ground, air, grind and bail states on a CharacterBody3D. Rolls along any surface (gravity acts along the slope), pumps on transitions, coasts, brakes; grass is slow.
- Ollie, spins (tank left / right in the air), five flip tricks, five grabs (hold), manuals, grinds on rails, ledges, benches and ramp coping. Boardslides, noseslides, tailslides and lip slides by stick direction.
- Landing sideways or hitting a wall at speed bails; the rider tumbles and gets back up.
- Combo scoring: pending points, multiplier = number of different tricks, repeats worth less, banked after a short idle window; a bail loses the pile.
- Camera-relative steering by default, tank steering optional (T).

### Level 1: Community Park
- A fenced skate plaza (mini ramp, two quarter pipes, funbox with kickers and bank, pyramid, stair set with rails, flat rails, ledges, manual pads) inside a big ring path with kickers, rails, ledges and manual pads on it, four spoke paths, benches, lamps, trees, a skate shop, a hedge, a road and houses.
- S-K-A-T-E letter pickups around the ring.
- Two-minute sessions with a results screen and saved best score; free skate mode.
- AI skaters cruise the ring.

### Tech
- Godot 4.7 Compatibility renderer, so the same build exports to the web (single-threaded, no special headers).
- Headless regression tests (`dev_skate`), gameplay screenshot tours, a level view tour and a frame-time check.
- Numpy-synthesised placeholder sound effects and music.
