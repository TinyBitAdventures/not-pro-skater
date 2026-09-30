# Rebuild plan: Not Pro Skater

Title **Not Pro Skater** (working title Not Pro Skaters until 2026-09-30). A skate game about people who skate for the love of it: a developer, a musician, a vlogger, a dad, an actor. The characters are archetypes *inspired by* real non-pro skaters, with the intent to ask for permission to use the real people if the game takes off. The events are community events, not contests: birthday parties, fundraisers, park openings, cleanup days and block parties.

Decisions (2026-09-29):

| Question | Decision |
|---|---|
| Platform | Keep the web build. Stay on the **Compatibility** renderer and get realism from PBR materials, CC0 textures and **baked lighting** |
| Camera | **Third-person perspective chase camera** (replaces the orthographic iso camera) |
| Characters | **Grounded stylized**: realistic light and materials, slightly stylized proportions |
| Engine | Stay on Godot 4.7. Feel comes from the controller, not the engine |

The core rule for the controller: **the code decides where the skater goes; physics only answers "what is under me?"**

## Status (2026-09-30)

| Phase | State |
|---|---|
| 1. Foundation | **Done.** `SkateTuning` + F3 panel, greybox level (`scenes/greybox.tscn`), 16 feel tests (`scenes/dev_feel.tscn`), all passing |
| 2. Controller | **Done, awaiting Austin's feel sign-off.** Momentum, curb-safe floor probe + four-wheel board normal, vert lock + auto 180 + transfer, landing assist / sketchy / fakie / revert, apex hang + vert float, Curve3D rails from Blender curves + rail linking + rail magnet, chase camera. The tile-seam fix turned out not to be needed (seams were already smooth) |
| 3. Realistic look | **In use** on Neighborhood Park (two bake groups). The look-test scene is retired. Still to do: material variety and wear, sky/exposure per event, performance numbers on real hardware |
| 4. Characters | **All five archetypes built** (MPFB + MakeHuman CC0, skinned, `RiderRig` IK posing, real board, 1K textures). Next: eye/hair material polish, per-character clothing colours, facial variety |
| 5. First level + event | **Neighborhood Park + Birthday at the Park playable** (goals, kids, guests, cake, balloons, swaying trees, title screen, web build ~78 MB). The old cartoon park and its tests are retired |
| 6. Polish | **Second pass done:** late-afternoon light (long shadows, backlit leaves), rolling lawns with grass tufts, hills and a horizon with instanced trees, built-looking ramps (plywood sheets, screws, steel foot plates, painted sides, galvanized rails), scuffed concrete, real eye colours and softer skin, lip tricks, smooth rail/coping entries, new techno soundtrack. Playtest fixes (2026-09-30): grind balance meter, warp back before the level's edge, whole street benches, no balloon-shadow flicker; ragdoll muscles (crashes brace and catch), P-A-R-T-Y badges on the HUD, Quit on the title. **Next:** gamepad feel pass, perf on low-end hardware |
| 7. Second level + event | **Maple Grove Elementary + the Skate-a-thon playable** (title menu, `?scene=skateathon`): the school grounds as planned (plaza steps with three handrails and a ramp rail, the sign ledge, covered walkway, car park with wheel stops, curb island and speed bump, the loading dock, the court with the PTA's ramps, the fenced playground), mid-morning sky; money scoring, the fundraising thermometer, lap gates, the principal. Levels export as glTF with shared textures; web build 77 MB with both levels (no shadow meshes, 256 px eyes / brows / lashes). Verified by the event test, a physics lap ride of the gate route and a rail audit of every grind line |

Decisions made while building (they override the text below where it differs):

- **Transfer is a button, not a stick direction.** Players hold forward while pumping up a ramp anyway, so "stick into the wall + pop" would have broken the vert lock for everyone. Holding **manual (M)** as you leave the lip transfers; that is also Tony Hawk's spine-transfer / revert button. Riding across a face at more than 50 degrees skips the lock (hips).
- **Vert airs float:** gravity x0.55 while vert-locked, and lip pops are scaled x0.55 to match (a 3 m quarter gives ~1.1 s of air; a lip ollie on the big quarter peaks ~2.4 m above the coping).
- **Lighting is baked in Blender (option B).** Godot 4.7 has no scriptable or command-line LightmapGI bake (only the editor button), so option A would break the scripted pipeline. Cycles bakes sky (sun disc clipped out of the HDRI) + the sun's bounce; the live sun supplies direct light and shadows; `baked_pbr.gdshader` disables ambient on baked surfaces so the sky is not counted twice. Moving things (skater, metal) use the HDRI sky as ambient. Blender's and Godot's panorama mappings differ by a quarter turn (`RealEnv.SKY_YAW`).
- **Sky drawn brighter than it lights** (`background_energy_multiplier` 1.7, exposure 0.9): matches photos of sunny parks without changing the lighting.

---

## What stays, what gets replaced

| Keep (maybe with changes) | Replace | Retire |
|---|---|---|
| `skater.gd` state machine (GROUND / AIR / GRIND / BAIL), input buffers, coyote time, `LIP_WINDOW` | `iso_camera.gd` → `chase_camera.gd` | `toon.gdshader`, `outline`, `occlude.gdshaderinc` (see-through hole), `blob.gdshader`, haze |
| `score_keeper.gd`, `tricks.gd`, `skater_brain.gd` | `grind_line.gd` (polyline) → `Curve3D`-backed rails | `util/toon.gd` style-by-material-name |
| `level.gd` marker loading, `level_baker.gd` batching | `blender/lib.py` + `pieces.py` (no UVs, flat colours) → a UV'd PBR kit | Numpy placeholder audio (already replaced by Wavelength) |
| Sound autoload, Wavelength audio, HUD logic, `ui_kit.gd` | `skater_visual.gd` primitive rider → skinned character (keep the IK *approach*) | |
| `dev_skate` / `audit_skate` test harness | `park.py` community park (new level, real scale) | |

The toon pipeline stays working until the new look replaces it (phase 5), so the game stays playable the whole way.

---

## Phase 1: Foundation (greybox + tuning + tests)

**1a. Tuning resource.** Move the ~40 constants at the top of `skater.gd` (lines 18–55) into `scripts/skater/skate_tuning.gd` (`class_name SkateTuning extends Resource`, `@export_range` on every value) with `tuning/default.tres`. The skater reads `tune.x` everywhere. Add an **F3 tuning panel**: sliders that change values live, plus Save and Reset. Tuning feel will take hundreds of small changes, and it has to be possible without a restart.

**1b. Greybox level.** `blender/greybox.py` → `greybox.glb`. Plain grey with a 1 m grid texture, so speed and distance are easy to judge. It contains:
- a 2.0 m mini quarter, a 3.0 m quarter, a 3.5 m vert wall with coping, and a quarter-to-quarter mini ramp
- a funbox with a hubba ledge, a flat rail, a kinked rail, a **curved** rail, and 8 stairs with a handrail
- a small bowl with a hip
- a long strip with deliberate trimesh seams, a curb step (0.12 m) and a wall step (0.4 m)
- start markers in front of each feature

**1c. Test scenes** (added to `audit_skate.gd`, headless, pass/fail):
| Test | Pass when |
|---|---|
| `momentum` | Coasting 5 s on flat from 10 m/s keeps ≥ 7.5 m/s |
| `seam` | The board normal changes < 2° while rolling over the seam strip |
| `curb` | A 0.12 m step rolls over with no bail; a 0.4 m step blocks or bails above crash speed |
| `vert` | Launching up the 3.5 m wall at 12 m/s with no input lands on the **same** face, within 0.5 m of the take-off point along the coping |
| `transfer` | The same launch with the stick held away from the ramp plus pop clears the lip onto the deck |
| `curve_rail` | A grind on the curved rail stays within 3 cm of the curve end to end |
| `land_assist` | Landings at 0/20/34° offset ride away clean, 45° is "sketchy", 65° bails, 180° lands fakie |
| `rail_magnet` | Grind pressed 0.25 s before reaching a rail 1.2 m off the air path still locks on |

## Phase 2: Controller rebuild (on the greybox, grey materials)

**2a. Surface probe.** New `scripts/skater/surface_probe.gd`. Five ray casts every tick: four wheels (trucks ±0.40 m along `hdg`, ±0.12 m sideways) and the centre.
- The board normal = average of the wheel normals, then smoothed (`lerp` + normalize at ~20/s; not `slerp`, see Gotchas).
- A single ray that disagrees wildly (a trimesh seam or a triangle edge) is ignored for that tick.
- Front wheels hitting a rise < 0.15 m lift the nose instead of stopping the board, so the board rolls up curbs.

This replaces the one `get_floor_normal()` from `move_and_slide` in `_ground` (`skater.gd:425-447`). `move_and_slide` stays for walls only. Velocity is rebuilt on the plane of the probe's normal. The existing rebuild code (`v_want`, tangent at the same speed) is the right idea and moves into the probe.

**2b. Momentum.** Coast drag drops from 0.30/s to ~0.06/s, so rolling speed barely fades. Pumping on transitions (`PUMP_ACCEL`) stays. Grass stays slow. Only braking, turning hard, grass or a bail should really cost speed.

**2c. Vert lip lock.** Tag vert surfaces in Blender (`Vert_…-col`, stored as surface meta `vert`). When the skater leaves a `vert` surface going up and the normal's `y` < 0.35:
- Enter AIR with `vert_air = true` and store the wall plane (its horizontal normal and the lip line).
- Each tick, remove any velocity away from the wall (pull back onto the plane). Keep the speed along the coping (it becomes lateral drift) and the vertical speed.
- Rotate the heading 180° over the rise and fall, so the board comes down facing the right way. Player spin adds to it (a 360 on vert = 180 auto + 180 player).
- **Transfer.** Stick held away from the wall plus a pop within `LIP_WINDOW` releases the lock. That keeps hips, channels and deck landings possible.
- **Landing.** A vert landing always counts as lined up with the face, which makes vert air generous the way Tony Hawk's is.

**2d. Rails as Blender curves.** glTF does not export bare curves, so rails are authored as Blender Curve objects named `Rail_<id>` with custom properties `kind = rail | ledge | coping | curb` and `slides = true|false`. `build.py` samples each curve (every ~0.1 m, ~0.07 m above the rail top as today) into a sidecar **`<level>.rails.json`**. `level.gd` loads it into Godot `Curve3D`s.

`grind_line.gd` becomes a thin wrapper over `Curve3D`:
- `get_closest_offset()` finds the snap point.
- `sample_baked_with_rotation()` gives the position and tangent.
- Curved rails get smooth motion with no kinks at polyline joints.

On top of that:
- **Magnetism.** While the grind button is buffered (in the air or on the ground), look 0.35 s ahead along the ballistic path. If any rail passes within 1.2 m, pull the air velocity toward it over ~0.2 s and snap. The current snap window (`GRIND_SNAP_H` 0.9 m, `_try_grind` at `skater.gd:641`) only checks where the skater *is*, not where the skater is *going*.
- **Line linking.** At the end of a rail, if another rail's end is within 0.3 m and its tangent is within 35°, carry on into it with no pop, like around a kinked handrail or a ledge corner.
- **Balance (later).** A grind balance meter, as in Tony Hawk. The data (lean) is already there. Leave it off until the basic feel is signed off.

**2e. Landing assist.** Rewrite `_land()` (`skater.gd:598`). Measure the angle between heading and travel:
- < 35°: **clean**. Turn the heading onto the travel direction (with a little of the travel direction pulled toward the heading so it doesn't look like it snapped).
- 35°–58°: **sketchy**. Land, lose 25% of the speed, show a wobble animation and a "Sketchy" popup, no combo multiplier for that landing.
- \> 58°: **bail**, the same as today.
- Near 180°: **land fakie**. Add a `stance` field (regular or fakie). The rider animation and trick names respect it.
- **Revert.** A button press within 0.3 s of a vert landing spins 180° and keeps the combo alive (Tony Hawk 3's combo glue).
- **Manual buffer.** A manual pressed in the last 0.2 s of air starts a manual on touchdown, keeping the combo alive.

**2f. Air feel.** Today air gravity (26 going up / 34 coming down) is heavier than ground gravity (24), so the air feels short. Use lower gravity going up plus an **apex hang** (half gravity while `|vy| < 1.5`). Keep the faster fall so landings still feel weighty. Tune on the greybox until a 3 m quarter gives ~1.1 s of air at normal speed.

**2g. Chase camera.** New `scripts/camera/chase_camera.gd`, perspective:
- FOV 70, widening to 78 with speed.
- Sits 4.2 m behind and 1.8 m above the skater, springs toward the target (critically damped), and follows the *travel* direction, not the board's facing, so spins don't spin the camera.
- **Look-ahead** of ~0.4 s along the velocity.
- A `SpringArm3D`-style ray pulls the camera in when a wall is behind the skater.
- **Vert mode.** While `vert_air`, the camera stops following height, stays behind the lip and pitches up, so the skater rises into view against the sky.
- **Grind mode.** Swings slightly to the side of the rail so the rail is visible.
- Stays level over bumps. Only large-scale slope changes tilt it.

This replaces `iso_camera.gd` for play. The iso camera can stay around for a photo mode.

**2h. Feel polish.**
- Squash on crouch and landing, stretch on pop.
- 40 ms hitstop on landings over 1.5 s of air.
- Light screen shake on big landings.
- A little FOV kick when popping off a lip.
- Wind audio that rises with speed; wheel roar that changes with surface.
- Sparks for grinds (`skater_fx.gd` already has hooks).

**Gate: Austin plays the greybox and signs off on feel before any art work starts.**

## Phase 3: Realistic look (greybox corner → proof)

**3a. Lighting spike (1–2 sessions).** Build one greybox corner both ways and compare:
- **(A) Godot `LightmapGI`.** Rendering baked lightmaps works in Compatibility. Baking needs a RenderingDevice (fine on this Mac, in the editor, not headless). It also generates **light probes**, so the moving skater picks up bounce light. That is a big realism win.
- **(B) Blender Cycles bake.** Bake AO plus indirect light into UV2 textures from `build.py`, applied through `ao_on_uv2` or a small custom shader. Fully scriptable and headless, but no probes for moving objects.

Criteria: how it looks in a web build, PCK size, rebuild time, whether it can run headless. Expected winner: A for visuals, with B as the fallback if editor-only baking gets in the way of the scripted pipeline.

**3b. Materials.** `blender/materials.py` builds Principled BSDF materials from **CC0** texture sets (ambientCG, Poly Haven) kept in `art/textures/<set>/` at 1K (2K only for hero surfaces).
- The glTF export carries base colour, normal and ORM maps straight into Godot's `StandardMaterial3D`.
- Kit pieces get proper UVs (box projection for procedural meshes) and a second UV set for lightmaps. Godot can generate UV2 on import with the "Static Lightmaps" option.
- Skate-specific wear: waxed ledge edges (darker, glossier), coping scuffs, rubber marks at the base of ramps, cracked concrete, and grip tape on the board.
- Record every texture's source and licence in `art_credits.md`, as with the audio credits.

**3c. Environment.**
- A Poly Haven CC0 HDRI for the sky and reflections, and ReflectionProbes (Compatibility supports 2 per mesh) around wet or glossy spots.
- AgX tonemapping, soft sun shadows, light depth fog, subtle glow, and a colour grade per event (golden hour for the birthday party, overcast for the cleanup day, dusk with string lights for the block party).

**3d. Web budget** (checked with the existing Playwright load test):
- 60 fps at 1080p in Chrome on an M1
- Draw calls < 400
- PCK < 80 MB, with VRAM-compressed textures
- First load < 15 s on broadband

## Phase 4: Characters (one archetype end to end)

- **Base body.** MPFB2 (MakeHuman for Blender; its output is CC0) → a game skeleton → glTF. Grounded stylized: slightly bigger heads and hands, simple readable clothing, hand-painted details over PBR cloth.
- **Animation approach.** Keep what works in `skater_visual.gd`: poses are numbers, and two-bone IK puts the feet on the board and the hands on grabs. It now drives a real `Skeleton3D` through `SkeletonModifier3D` IK instead of stacked primitive pieces. Author a small set of key poses in Blender by script: push, crouch, ollie, flip catch, each grab, 50-50, boardslide, manual, bail tumble. Blend between them with the pose numbers.
- **Licensing.** Avoid Mixamo: its terms forbid redistributing the raw files, and this repo is open source. Use CC0 animation libraries (for example Quaternius) for walking and idle, and scripted poses for anything skate-specific.
- **The board.** A proper deck with a concave shape, trucks, wheels and grip tape, a real-sized PBR model.
- **First archetype: The Dev.** Hoodie, backpack with a laptop, headphones around the neck. Proves the whole pipeline before building the others: the Musician, the Vlogger, the Dad and the Actor.

## Phase 5: First real level + first event

- **Level 1: "Neighborhood Park".** Rebuild at real scale for a chase camera: sight lines to a horizon, a backdrop of houses and trees (LODs and impostors), and spots found in everyday places (picnic tables, planters, a library ramp), not just park pieces.
- **Event 1: "Birthday at the Park".** The goal list replaces pro objectives:
  - teach three kids an ollie (they copy your line)
  - deliver the cake across the plaza without bailing
  - boardslide past the party table when the candles come out
  - collect the balloons that got away
  - a combo goal ("Party Trick: 10,000")
  - a hidden S-K-A-T-E-style collectible spelling **P-A-R-T-Y**
- **Events system.** `scripts/events/event_def.gd` resources, each with goals, a time of day or grade, a music track, and props to spawn. The same level can host several events later (a fundraiser in the same park at a different time of day).
- **Then:** delete the toon pipeline and the old park, rename the project to Not Pro Skaters (Godot `config/name`, README, window title, title screen), and do a web performance pass.

## Phase 7: Second level + event: the school skate-a-thon

- **Level 2: "Maple Grove Elementary"** on a Saturday morning (a higher, fresher sun than the park's golden hour). Real-scale school grounds with everyday spots:
  - the front **entrance plaza**: steps down from the doors with two handrails and a centre rail, a long access ramp with its own rail, planter ledges, benches, a flagpole;
  - the **school sign**: a low brick wall by the street, its capstone a ledge;
  - a **covered walkway** to the car park (a row of columns to weave through);
  - the **car park**: painted bays, grindable wheel stops, curb islands with trees, a speed bump, parked cars, light poles;
  - the **loading dock** at the building's end (a 1.1 m dock ledge);
  - the **basketball court**, where the PTA set up portable ramps for the day (two quarter pipes, a funbox with a rail, a kicker, a flat bar);
  - the old fenced playground the money is for, lawns, trees, the street and houses opposite.
- **Event 2: "Skate-a-thon"**, raising money for a new playground. Sponsors pledge per trick, so the score reads as dollars, and a big fundraising thermometer on the plaza fills as you raise it. Goals:
  - ride laps of the school through the gates (the heart of a skate-a-thon)
  - grind the front-steps handrail
  - carry the bake-sale cake from a car to the table without bailing
  - collect **D-O-N-A-T-E**
  - impress the principal (land a trick near her)
  - raise $2,500
- **Pipeline first:** levels share their textures (one copy of each CC0 set and prop texture for every level) so a second level fits the web build.

## Later: the rest of the cast and events

| Archetype | Home event | Music |
|---|---|---|
| The Dev | Company picnic / conference hall | Lo-fi, synthwave |
| The Musician | Record release party, tour stop loading dock | Hip-hop, funk |
| The Vlogger | Rush-hour city run, "one-take intro" goals | Upbeat electronic |
| The Dad | Kid's birthday, backyard miniramp session | Classic rock / pop punk |
| The Actor | Film set between takes | Orchestral hybrid |

Each character's combos drive their own stems (the "city is the song" idea): grinds add bass, flips add drums, grabs add the lead. The music engine is Wavelength.

---

## Order of work and first commits

1. `📦 NEW: SkateTuning resource and live F3 tuning panel` (no behaviour change; all current tests still pass)
2. `📦 NEW: Greybox test level` + the new audit tests (expected to fail at first)
3. `👌 IMPROVE: Four-wheel surface probe` → `momentum` → `vert lip lock` → `curve rails` → `landing assist` → `air feel`, one commit each, each turning its test green
4. `📦 NEW: Chase camera`, then feel polish, then **the feel sign-off**
5. Lighting spike, material kit, environment
6. The Dev character
7. Neighborhood Park + Birthday event, retire the toon pipeline, rename

## Gotchas carried over

- Run `./build.sh` (or `godot --headless --import`) after any glb **or rails.json** change.
- `Vector3.slerp` errors on near-opposite vectors: use lerp + normalize for normal smoothing.
- GDScript lambdas capture primitives by value: mutate a Dictionary in test callbacks.
- Keep the single-threaded web preset and run the Playwright load check after shader or export changes.
