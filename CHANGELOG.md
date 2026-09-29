# Changelog

## Unreleased

### Rebuild: skating feel (Not Pro Skaters)
- Every skating value lives in one `SkateTuning` resource (`game/tuning/default.tres`); **F3** opens live sliders with Save / Reset.
- **Greybox test level** (`scenes/greybox.tscn`): tile seams, curb, step, three quarter pipes up to a vert wall, a mini ramp, flat / kinked / curved rails, a ledge, stairs, funbox, hip and kicker, with a world grid; number keys warp between lanes.
- **Feel tests** (`scenes/dev_feel.tscn`, 16 pass / fail checks) on the greybox.
- **Momentum:** coasting drag is a sixth of what it was, so speed carries (10 m/s keeps 7.8 m/s after 5 s instead of 2.3).
- **Curbs roll:** the floor normal comes from a ray straight under the board instead of the capsule's contact, which read a 12 cm curb edge as a 50-degree ramp and threw the skater 0.9 m up. A four-wheel plane fit (smoothed) tilts the board and rider.
- **Vert lock:** leaving a steep face going up keeps the air in the wall's plane and turns the skater 180 on the way, so straight airs come back down the same ramp; vert air floats (gravity x0.55) and lip pops are scaled to match (a 3 m quarter gives about 1.1 s of air). Riding across a face at an angle skips the lock; holding **M** at the lip **transfers** onto the deck.
- **Landing assist:** within 35 degrees the board lines up with the way it is going; up to 58 degrees is a *sketchy* landing (25% speed lost); beyond that bails; landing backwards rolls away **fakie** (`stance`). **Revert**: M just after landing on a ramp spins 180 and keeps the combo.
- **Apex hang:** gravity is halved near the top of every jump.
- **Chase camera** (greybox): a perspective camera behind the direction of travel (spins never swing it), half-following jump height, looking ahead along the velocity, field of view opening with speed and kicking on a pop, a little shake on big landings, and a ray that pulls it in front of walls. On vert it moves out in front of the wall at coping height so the lip sits low in the shot with the skater rising above it, then swings back behind after the landing.
- Greybox look: darker grid materials, real sun shadows (no fake blob shadow).
- **Realistic look, first proof** (`scenes/looktest.tscn`, `blender/looktest.py`, `blender/realism.py`): the kit's flat colours become CC0 PBR texture sets (ambientCG) with real-scale UVs (ramp surfaces unwrap along the profile, so the transition is one seamless sheet); static surfaces are merged and get a lightmap UV set; Blender Cycles bakes sky light (the HDRI with its sun disc clipped out) plus the sun's bounce into a PNG lightmap. In Godot a small shader (`baked_pbr.gdshader`, Compatibility renderer) adds the baked light, the live sun adds direct light and shadows, and the same Poly Haven HDRI is the sky, matched to the bake (sun direction, energies, a fixed quarter-turn between Blender's and Godot's panorama mappings). AgX tonemapping, light glow and fog. Credits in `ART_CREDITS.md`.
- **Rails** are Blender curves exported to `<level>.rails.json` and loaded as `Curve3D`s: curved rails grind smoothly, rails whose ends meet are linked. **Rail magnetism**: grind pressed in the air looks 0.35 s along the air path and bends it onto a rail up to 1.2 m to the side.

First playable prototype: one level, a full skating model and the isometric toon look.

### Look
- Orthographic true-isometric camera that follows the skater with look-ahead; Q / E turn it in 90 degree steps.
- Cel shading with three light bands, inverted-hull outlines, world-space grid and patch noise on big flat surfaces.
- Anything standing between the camera and the skater dithers out around them, so tall ramps never hide the rider.
- Everything is built in Blender from scripts (level kit, park, skater) and shipped as glTF.

### Controls and camera
- Default steering is skater-relative (A / D turn, W push, S brake); the camera follows the skater's heading so the rider always goes "up" the screen. Screen steering and a fixed camera stay available (T / C, or the title menu).
- Jump is hold-and-release: Space crouches (POP meter), releasing pops; hold up to 0.45 s for a full-height jump. Release at a ramp lip for a big air (about 5 m off the small quarter pipe versus 2 m for a plain roll-off). Y (or the title menu) switches to an instant jump on press.
- Jumps: no squat before the pop, heavier fall, stronger pop, and the camera follows ground height so the whole arc is visible.

### Look and effects
- Atmosphere: distance haze into the sky colour, drifting cloud shadows, contact shading on walls, grass tufts and flowers, a light colour grade with a vignette.
- Rider effects: air trail, landing dust and shockwave ring, grind sparks, floating trick names; heavier rider outline; board graphics, star shirt, wrist guards, chin strap, mouth and eyebrows.
- Life: birds circle the park (their shadows cross the plaza), leaves drift by, ducks paddle on the pond, cars drive round the block, swings swing, and a crowd of 79 spectators (bleachers, benches, ramp decks, the plaza fence) hops and cheers. The crowd is baked into the level's merged meshes and hops in the vertex shader, so it costs a couple of dozen draws.
- Dressing: painted plaza (starburst, block-letter SKATE, checker strips, chevrons, dashed ramp outlines), mural wall, bunting and balloons at the gates, two bleacher stands, a pond with lily pads and a jetty, a playground (swings, slide, sandbox, see-saw, climber), parked cars, street lamps, hydrants, mailboxes, bus stops, a food cart, more tree varieties (birch, autumn, poplar), flower patches and picnic blankets.
- Depth cue: the far side of the screen fades slightly toward the sky. (A true isometric camera never sees a horizon, so distant hills are not shown.)
- Fixed z-fighting flicker where the spoke paths meet the plaza.

### Audio
- Wavelength-rendered sound effects (22) with a per-sound level table; two themes: Boardwalk Morning (title) and Grip Tape Summer (park). Credits in `docs/`.

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
