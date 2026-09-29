# Changelog

## Unreleased

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
