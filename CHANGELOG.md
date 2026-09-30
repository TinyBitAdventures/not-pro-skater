# Changelog

## Unreleased

### Graphics: late afternoon light
- **The park is lit by a late afternoon sun** (Poly Haven's CC0 Qwantani Late Afternoon sky, sun 19 degrees up): long shadows across the plaza and street, warm backlight on the trees, rim light on the riders. The midday sun (48 degrees) made everything flat. `SKY=<polyhaven id>` in `blender/realism.py` switches the sky for a bake; the level's `look.json` carries the matching exposure and baked-light strength.
- **Grass and ground never shine like a wet road:** a roughness floor per material (grass 0.92), which a low sun had turned into glare.
- **Clean shadow edges:** a low sun stretches each shadow texel along the ground and the edges stair-stepped; the sun's shadows now cover 40 m with a wider near split, more blur and the higher soft-shadow filter.
- **Title screen:** the rider stands by the mini ramp in the sun, facing it, and the camera starts on the sunny side.

### New soundtrack: melodic techno
- Five new Wavelength pieces replace the cartoon-era music, all built on one motif: **title** (atmospheric melodic techno, 120 BPM, A minor, 32 bars), **cruise** (friendly, groovy, swung, 125 BPM, D dorian, 64 bars, with a lift, a peak, a break and a return), **hype** (harder, straight 16ths, 131.25 BPM, E minor, 64 bars), and **results** / **new best** stings (the new-best run lands on the results chord). Seamless loops (exact sample counts, seams checked), -14 LUFS, balanced left/right, the 2-5 kHz band kept clear for the sound effects. All open-licensed sounds (Wavelength built-ins, MuseScore General, Surge XT patches); credits in `docs/AUDIO_CREDITS_music.md`.
- Free Skate and Practice play the gameplay music too (only the event did).

### Graphics: an environment with depth
- **Trees look alive:** the leaf texture's transparent texels were black, and mipmapping bled that into every leaf as a dark jagged outline; they now carry the leaves' own colour. Leaves let light through (backlight), each tree has its own shade of green, and the cut-out edges are smoothed by alpha to coverage.
- **Real deck railings:** the mini ramp and quarter pipes had 17 cm red and green bars from the cartoon days; they are galvanized pipe now (48 mm top rail, 42 mm mid rail and posts, base flanges).
- **Skated concrete:** the plaza is a shade darker and warmer, with patches of wheel marks and rubber scuffs streaking in a few directions.
- A gentle grade (contrast 1.08, saturation 1.1) and a soft vignette under the HUD: a camera's picture profile rather than the flat physical render (`GRADE=off`, `VIGNETTE=off` for comparison shots).
- **A world past the fence:** the park used to end at a flat lawn edge under the sky. Now the ground rolls out to low hills with a few hundred trees in clumps, real trees just past the edge, and the street carrying on to the horizon both ways; the haze does the rest (`blender/terrain.py`, one object, a few draw calls).
- **The ground has shape:** the lawn gently rolls with a few low mounds (flattening to meet the plaza, paths, picnic paving and street), with trees, props and markers following it.
- **Grass you can see:** tens of thousands of grass tufts on the lawns (`GrassField`, `grass_tuft.gdshader`), dropped onto grass collision at load (about 150 ms), in 20 m chunks culled past 46 m, swaying in the wind, fading into the ground at the edge of their range, no shadow cost. Shrub clumps soften the edges of the plaza and paths.
- Fixed: every joined mesh (the baked plaza, the baked world) kept the first object's mesh name, and a "-col" in it made Godot build a second collider from the whole baked mesh; the lawn's copy sat on top of everything and reported "wall".
- The curb faces were black (a 12 cm face is smaller than a lightmap texel and sampled the black around its island); vertical baked faces never fall below a little sky light now, and the sidewalks' curb face drops exactly to the road.

### Feel fixes (Austin's playtest)
- **Grass is rideable:** grass drag 0.9 per second (was 2.8, which stopped you in a couple of seconds) and pushing tops out at 6.5 m/s there (was 4.2; 9 on concrete).
- **Ramps look built:** the plywood riding surfaces show their 4 x 8 ft sheets, a screw every foot along each edge, faint wheel wear down the ride line, and a less pink tone (in `baked_pbr.gdshader`, from the ramps' metre UVs).
- **Lip tricks:** grind at the top of a quarter or half pipe while crossing the coping stalls on it: Rock to Fakie, Nose Stall (up), Blunt to Fakie (down), Axle Stall (left), Disaster (right), each with its own board angle. Pressed on the way up the wall it waits for the coping. A balance meter (left / right) like a manual, jump drops back in (fakie for the "to Fakie" ones), losing the balance bails, five seconds drops in by itself. Riding along the coping is still a coping grind. Feel tests `lip_stall`, `lip_arm`; pose tour `POSES=lip_`.
- **Half pipes keep you in the ramp:** Level tags quarter and half pipe transitions (a sloped face steeper than 57 degrees; kickers top out around 35), and leaving one going up locks the air to the ramp at any angle of approach and from a pop partway up the face; only riding almost along the coping skips it. Before, a diagonal line or releasing the jump before the lip launched you off the ramp (out over the flat or onto the deck). The float and the lip's pop damping scale with how steep the take-off was, so a hop from low on the face stays a hop. Hips and kickers still launch you across. Feel tests `mini_angle`, `mini_pop`.
- **Spins are calmer:** 460 degrees a second at most, wound up over a quarter second (was 630 in under a fifth): a 360 takes about 0.9 s. Feel test `spin_rate`.
- **No more moonwalking after a small bail:** the walking gait lifted each foot while it moved backwards, and the arms swung across the body; feet now lift on the forward swing and arms swing fore and aft. The rider also turns to face the board before walking to it when it is behind.

### Polish: gamepad hints
- Hints follow the last device used: pick up a gamepad and the HUD, title and results show STICK, A, BACK, START (keyboard-only extras like the warp keys drop out); press a key and they switch back. The controls card lists keys and gamepad buttons side by side.

### Polish: small things
- Standing still, riders breathe, shift their weight and glance about instead of freezing like a mannequin (the title screen rider most of all).
- The title camera starts on the rider's front three-quarter, so you see the character you picked.
- Scene changes show a quiet LOADING note while the level loads (the web build loads without threads, so this can take a few seconds).

### Polish: carrying the cake
- The rider carries the birthday cake in both hands, held out in front of the belly (`RiderRig.carry_item`), instead of the cake floating by the chest while the arms balance; a crash lets go of it and it goes back to the table at the street, as before. The pose tour has a `carry` pose.

### Polish: grind sparks
- Grinding metal (rails, coping) throws real sparks: thin streaks stretched along their flight, hot yellow to orange, thrown back off the trucks and falling fast. They used to be little yellow cubes. Concrete ledges and curbs kick up grit instead.

### Polish: the camera on ramps
- Rolling back down a ramp after an air, "behind the rider" is inside the ramp: the camera used to pull in against the ramp's face, right at the coping. It now rises (up to 3 m) until it sees the rider clearly, floating over the deck and looking down the transition, like a skate game camera should.
- A big swing (after a vert landing) no longer slides straight through the rider: the camera keeps a minimum radius as it comes round.
- After a vert air the shot stays out in front while the rider comes back down the wall, then swings behind once the rider is off the steep part (it used to swing at touchdown and end up over the deck with the rider hidden below the lip). Rises over a deck only count if the rider's chest stays in view.

### Polish: boards and details
- **Every rider has their own deck graphic** (base colour, a slanted band toward the tail, a ring toward the nose, pinstripes; drawn at load, `RiderRig.deck_art`); the board that rolls away in a crash keeps it.
- The Dad wears khaki chinos with his green polo: the cargo pants asset has ripped knees, which read as a rendering fault. Garment textures with see-through parts are filled with the garment's own colour (they showed white where the alpha was).
- New app icon and boot colour in the UI palette (the old ones were from the cartoon look).

### Polish: the end of a session
- The clock ticks softly through the last five seconds; when it runs out the music fades, the results jingle plays, and a NEW BEST sting follows when you beat your score.
- Fixed: skating again straight after a session could leave the music silent (the results fade was still running and stopped the new track).
- The flow test now plays a session out, checks the results card and restarts from it.

### Polish: the party looks like a party
- Birthday at the Park dresses the park for the day (`dressing` in the event, built by `EventRunner`): a HAPPY BIRTHDAY LEO! banner on two poles across the path in, bunches of balloons tied to the picnic tables, the cake table, the lamps and the banner poles (they lean and turn in the breeze), a pile of wrapped presents by the cake table, and party hats on the kids.
- Title cards stay between the goal list and the clock, and long lines wrap onto two.

### Polish: feel and sound
- **Landings have weight:** the camera dips on a spring when you land (bigger air, deeper dip) and settles with a small rebound; a bail presses it too. The random camera shake is gone.
- **The park sounds alive:** a seamless ambience loop synthesised in `audio/build_ambience.py` (gusting wind, leaves rustling in the gusts, distant traffic with a car passing, five birds with their own calls placed around the stereo field). It plays under the park, the birthday and the title (quieter), and goes quiet with the effects when paused. 330 KB.

### Polish: the neighbourhood
- **Concrete looks poured, not tiled:** saw-cut expansion joints on a 2 m grid across the plaza and cross cuts along the sidewalks (world-space, in `baked_pbr.gdshader`, laid out by `<level>.look.json` which `neighborhood.py` writes), and large-scale variation on every baked surface so textures never repeat exactly (grass drifts to dry yellow in patches, concrete and asphalt stain).
- **Houses with character** (`blender/houses.py`): three roof colours and five sidings, chimneys, porches over the doors, window sills and shutters, attached garages with driveways, front walks, picket fences or rows of shrubs, mailboxes. Seven houses across the street at 17 m spacing so every garage fits.
- **A real street:** dashed centre line, a crosswalk where the park path meets the road, power poles with sagging wires.
- **Shaded walls are no longer black:** the bake only contains the park, so a wall facing away from the sun missed the bounce light a real street gives it; baked light is lifted on vertical faces (`wall_fill`) and a touch overall. The dark line along every curb is gone too (raised slabs are only as thick as their step, so no buried face bakes black and bleeds).
- The world lightmap is 1024 (lawn, street and houses carry soft light; the plaza keeps 2048), which brings the web build back to 77 MB.

### Polish: characters
- **Everyone dresses differently now:** five of ten characters wore the same blue tee and jeans. `character.py` can recolour a plain garment (`tint`: the texture's own shading, the new colour); The Vlogger has a red tee and denim shorts, The Dad a green polo, Grandpa a tan one, Maya a yellow tee, Leo (the birthday boy) an orange tee and cargo pants, his mom a red knit sweater with her hair in a bun (her grey bob read as white).
- **Hair renders properly:** it came in alpha-blended (Blender 5 no longer exports the cutout setting), which left dark patches on the scalp; it is now a hard cutout smoothed by alpha to coverage, and casts real shadows. Brows and lashes stay soft.
- Bystanders ship without normal maps (not visible at their distance), and the music is re-encoded at Vorbis q3 from q5 (loop lengths and seams checked); the unused placeholder track is gone.

### Polish: a grounded UI
- **New look for every screen** (`UiKit`): Barlow Condensed (SIL OFL), warm white text with a soft shadow, one orange accent, translucent dark panels. The cartoon navy-and-yellow panels are gone.
- **HUD**: score top left with the event's goal checklist (ticks fill green), clock and best top right (the best score was never shown before), the **trick string** bottom centre like a skate game should have it (tricks joined with +, points x multiplier, a little pop per trick, green +total on a bank, red BAIL on a bail), slim pop and balance meters, title cards with an accent rule instead of the banner that overlapped the goals, key hints on a panel that fades once you roll.
- **Pause menu** (ESC): Resume, Restart, Controls, Quit to title; the game freezes, effects go quiet and the music sounds muffled behind a low-pass filter. ESC used to drop you straight to the title.
- **Results card**: score, best combo, NEW BEST, goals ticked, Enter to skate again or ESC for the title.
- **Title screen** restyled: the logo, the menu with settings changed by left / right, and a card for the chosen rider with a one-line blurb for each archetype.
- Scene changes fade through black (`Game.go`).
- Tests: `scenes/dev_flow.tscn` drives the menus with real input events (title, event, pause, restart, resume, quit); `scenes/dev_ui.tscn` screenshots every UI state.

### Polish: smoother and lighter
- **Even motion at any frame rate:** physics runs at 120 Hz, and the rider and camera used to read the raw physics position, so on a 144 Hz screen (or a wobbly browser frame rate) some frames moved two ticks and some none. They now draw between the last two physics positions (`Skater.render_position()`): judder measured 0.33 before, 0.006 after.
- **Draw calls 591 -> 260** on Birthday at the Park: Blender merges the live-lit scenery (house trim and glass, guard rails, bunting, trees, one-off props) into one object per 30 m map cell (`realism.join_live`); props placed more than once stay shared and Godot draws each kind as one MultiMesh; the board is one mesh instead of fifteen parts; eyes, brows and lashes no longer cast shadows; the sun uses two blended shadow splits over 55 m instead of four over 70 m.
- `scenes/dev_perf.tscn`: frame times, draw calls, judder, and our own script costs (`COST=1`), scene breakdown (`DUMP=1`).

### Cleanup: the old cartoon park is gone
- Removed the isometric cartoon prototype: the community park level and its scene, the cartoon rider, spectators, cars, ducks and backdrop (models, Blender scripts and glbs), the iso camera, the toon / outline / occlusion / blob / water / fence / post shaders, the level baker, the AI skater brain and eleven old test and screenshot scenes. The web export no longer needs an exclude list for them.
- `RiderRig` stands on its own (it used to extend the cartoon `SkaterVisual`): the pose logic moved in, and its old kinematic bail poses are gone now that every crash is physical.
- The air trail and the landing shockwave ring are gone (they belonged to the cartoon look); dust and grind sparks stay.
- `Level` loads the realistic look by default; `Skater` always uses a skinned rider; `blender/pieces.py` keeps only the skate kit.

### Not Pro Skaters: first level and event
- **Neighborhood Park** (`blender/neighborhood.py`, `scenes/neighborhood.tscn`): a real-scale suburban park. A concrete skate plaza (mini ramp with guard rails, two ledges, a manual pad, a flat rail, a four-stair set with handrails and a bank feed, a quarter pipe, a bank), a paved picnic area with bunting, lawn and paths, a street with sidewalks and curbs, fourteen houses (siding, brick, tiled roofs, glossy windows) and 23 trees. Two lightmaps: a sharp one for the plaza and picnic area, one for everything else.
- **CC0 props** from Poly Haven (`blender/park_props.py`): picnic tables, a bench, bins, street lamps, planters, shrubs, a boombox, a cake. Imported once, shared by every copy, with box colliders. `tools/fetch_assets.py` fetches all CC0 sources (ambientCG textures and Poly Haven models) into `art/`.
- **Trees** (`blender/trees.py`): a tapered, bent trunk and branches in oak bark, a crown of alpha-cut leaf cards from a leaf-cluster texture composited out of CC0 Leaf001, with normals pointing out of the crown for soft foliage shading. About 1-2k triangles each.
- **Houses** (`blender/houses.py`).
- **Events** (`scripts/events/`): an event is a level plus goals (`Events.get_event`), run by `EventRunner`, shown in a HUD goal list, saved when done. Goal kinds: balloon letters, deliver an item without bailing, a named grind on one rail, show the kids a trick, a big combo, a session score.
- **Birthday at the Park** (`scenes/birthday.tscn`): grab the P-A-R-T-Y balloons (some only in the air), bring the cake from the street table to the party (bail and it goes back), boardslide the party bench, land a trick near each of the three kids, a 10,000 combo, 25,000 points. Two-minute session with results.
- **Kids** (Maya, Leo, Sam) from the character pipeline, as `Npc` bystanders: relaxed stance, heads following the skater, cheering with arms up when shown a trick.
- **Party guests**: Leo's mom and Grandpa stand by the picnic tables and cheer tricks done near them.
- **Trees sway** in the wind (`leaf_sway.gdshader`: sway grows with height, varies by position; shadows sway too).
- **Web build stays under budget** (~78 MB): textures import GPU-compressed by default, detail maps (normal, roughness, packed AO/rough/metal) export at 512 and colour maps at 1K, characters keep 1K skin and 512 for the rest (bystanders 512 throughout), and the old cartoon park is left out of the web export.
- **Title screen** for Not Pro Skaters: the park behind a slowly circling camera with the chosen rider on the board; Birthday at the Park, Free Skate, Practice, rider select (left / right), settings. The project is renamed; ESC in a level goes back to the title.

### Rebuild: skating feel (Not Pro Skaters)
- Every skating value lives in one `SkateTuning` resource (`game/tuning/default.tres`); **F3** opens live sliders with Save / Reset.
- **Greybox test level** (`scenes/greybox.tscn`): tile seams, curb, step, three quarter pipes up to a vert wall, a mini ramp, flat / kinked / curved rails, a ledge, stairs, funbox, hip and kicker, with a world grid; number keys warp between lanes.
- **Feel tests** (`scenes/dev_feel.tscn`, 16 pass / fail checks) on the greybox.
- **Momentum:** coasting drag is a sixth of what it was, so speed carries (10 m/s keeps 7.8 m/s after 5 s instead of 2.3).
- **Curbs roll:** the floor normal comes from a ray straight under the board instead of the capsule's contact, which read a 12 cm curb edge as a 50-degree ramp and threw the skater 0.9 m up. A four-wheel plane fit (smoothed) tilts the board and rider.
- **Vert lock:** leaving a steep face going up keeps the air in the wall's plane and turns the skater 180 on the way, so straight airs come back down the same ramp; vert air floats (gravity x0.55) and lip pops are scaled to match (a 3 m quarter gives about 1.1 s of air). Riding across a face at an angle skips the lock; holding **M** at the lip **transfers** onto the deck.
- **Landing assist:** within 35 degrees the board lines up with the way it is going; up to 58 degrees is a *sketchy* landing (25% speed lost); beyond that bails; landing backwards rolls away **fakie** (`stance`). **Revert**: M just after landing on a ramp spins 180 and keeps the combo.
- **Apex hang:** gravity is halved near the top of every jump.
- **First real character: The Dev** (`blender/character.py`, MPFB + MakeHuman CC0 assets): a grounded-stylized human (slightly bigger head and hands) in a long-sleeve tee, jeans and sneakers, MPFB's 53-bone game-engine skeleton, exported as a skinned glb (27k triangles). Skin and cloth textures are forced opaque (their alpha showed the inside of the head and holes in the jeans); the body shape is baked before eyes, hair and clothes are fitted.
- **Physical crashes:** slams and big crashes are real physics now. The rider becomes a **ragdoll** (capsules for pelvis, chest, head, arms, legs and feet from the skeleton, cone joints) thrown with the speed and spin he had, so he slides down a transition, crumples against a wall or tumbles into the flat depending on where it happens. The board becomes a **loose rigid body** that rolls on its wheels (grips sideways, rolls lengthways), runs down ramps and back up, bounces off walls, and scrapes to a stop if it flips. For the first third of a second the two ignore each other so the board shoots out from under the feet. Once the body is still, the rider **gets up** (blending from the fallen pose), walks (or jogs) to wherever the board ended up and steps on. Small mistakes are physical too: the board comes loose the same way, and the rider runs it out on foot as a real body (the feet brake it, walls stop it); too fast to stay up, a wall hit or a slope trips him into the ragdoll; once stopped he walks to the board. `scenes/dev_bailphys.tscn` runs a half pipe, flat and wall crash headless.
- **Jolt physics** replaces Godot Physics (stable ragdolls); the board is now held to curving transitions explicitly (Jolt drops floor contact there), so every riding number is unchanged.
- Camera: the look-ahead point and the smoothed position are wall-checked too (no frames inside walls or ramps).
- **Manuals, Tony Hawk style:** tap up then down (W then S, or the stick) for a manual, down then up for a **nose manual**; M still starts one. The first press has to be a tap, so pushing then braking never triggers it. Once in, a **balance meter** (HUD) drifts toward one end faster and faster; up / down bring it back; past the end you fall off into a run-out. A combo pressed in the air lands straight into a manual.
- **Wall plants:** jump into a wall and pop (Space) as you hit it: a short stick, then you spring back out, turned around (+250).
- **Pushing** is a real stride now: lift off the deck, step down beside the board, push back along the ground and swing back onto the tail, with the front foot and hips turning toward the nose; about one stride a second instead of two and a half, and a stride always finishes instead of the foot snapping back.
- **Fakie** riders look over the other shoulder, toward where they are going.
- **Bails are physical:** the board (the physics body) rolls on and stops by itself; the rider goes down where the fall happened, gets up and walks to it (a run-out runs just behind it). Nothing snaps back at the end. The camera follows the rider, not the loose board.
- **Camera against walls:** with a wall close behind, the camera rises up and over instead of ending inside the rider.
- Greybox: a 3.5 m wall lane (`wall`). Feel tests: 31.
- **The cast:** The Musician (jacket, fedora), The Vlogger (tee and jeans, ponytail), The Dad (polo, cargo pants) and The Actor (striped shirt, boots) join The Dev; all original archetypes, 27-32k triangles each, textures capped at 1K for the web (The Dev went from 19 MB to 6.6 MB). **P** in the greybox swaps riders live.
- **Real-sized board** (`blender/board.py`): 8.0" x 31.5" deck with kicktails, grip, printed bottom, trucks and 54 mm wheels.
- **RiderRig** (`scripts/skater/rider_rig.gd`): drives the skeleton from the same pose logic as the cartoon rider: hips and a three-bone spine (lean, twist, sway), two-bone IK legs with the feet flat on the deck (front foot angled to the nose; the feet follow the board's tilt in manuals and boardslides but not its flips), arm IK for balance and grabs, the head turned toward the nose, the run-out and slam bails, and the board staying on the ground while the body goes down. The greybox uses it. Pose tour: `scenes/dev_rig.tscn`.
- **Jumps no longer get lost:** a Space tap made while still falling (up to 0.35 s before touchdown) pops again on landing; before, anything earlier than 0.14 s was dropped, so chained ollies felt hit-and-miss. A quick tap is also a real ollie now (minimum pop 7.8, was 6.8). Checked with real key events frame by frame (`scenes/dev_jumptap.tscn`).
- **Vert airs look like vert airs:** the rider stays side-on to the wall (feet toward the ramp, body out) and the 180 turns in the wall's plane; the vert camera sits off to one side so the whole body is in view as it turns. Fakie riding is drawn facing backwards, and fakie grinds stay fakie.
- **Bails match the mistake:** severity (speed, air time, how crooked) picks a **run-out** (step off, run a few steps, the board rolls ahead and you hop back on, keeping half your speed), a **slam** (down onto a hip and slide, then up) or, only for fast, high crashes, a **roll**. The old end-over-end tumble was used for every bail.
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
