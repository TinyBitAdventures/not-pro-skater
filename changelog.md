# Changelog

## Unreleased

### Fixes
- The floating NEXT marker no longer repeats a gate's own banner: it hides over the start and finish gates of the Skate-a-thon laps and the Rush Hour one-take run (both said START twice).
- Rush Hour's MARKET MORNING banner hung right behind the START gate, hidden by it; it spans Market Street further up now.
- **Event goals count what you actually did:**
  - Sponsored laps and the one-take bonus are paid straight into the score. They used to join the combo in progress, where they sat unbanked while you rolled, were halved as repeats (three laps paid 1,400 points instead of 2,400) and were lost in a bail. They show as their own "+$80" note now.
  - A combo in a zone (the Launch Day demo, the front of the Record Release stage, the Rush Hour intro) counts if its tricks were done in the zone. It used to be judged 1.25 s after landing, wherever you had rolled to by then.
  - Showing the kids, the team, the fans or the crew needs the trick landed: one that ends in a bail no longer counts.
  - The "(in the zone!)" note follows you in and out of the zone.
  - Nothing completes or saves after the buzzer (a letter or a mark reached while coasting to a stop used to be saved without showing on the results).
  - The number keys and TAB no longer warp you around an event (you could carry the cake most of the way, or skip one-take checkpoints). P still swaps the rider.
- **Cards don't overwrite each other:** a card that comes while another is up waits its turn (up to three), so the one-take bonus, the third lap's money and every goal finished by the same combo all show; before, only the last one did. Cards sit a little lower (clear of a gate's banner as you ride under it), narrower (clear of the goal list) and outlined, so they read over banners, walls and sky. A drop reads as the shout with what to do under it ("CAKE DROPPED!" over "Back to the car park").
- The goal list wraps long lines instead of growing under the cards ("(carrying!)" goes onto its own line).
- Gate banners read from both sides: the Skate-a-thon's START / FINISH arch was blank from the side you reach it on, before every lap.
- The one-take run doesn't start again once it's done (a later bail showed "THAT TAKE'S RUINED" for a finished goal), its checkpoint count shows the checkpoints passed (it read 5/5 on the way to FINISH), and the results no longer show live notes ("(carrying!)", a frozen "0:44 LEFT").
- Wording: the bake-sale cake goes back to the car park, the coffee comes from the café and the script pages from the trailer, and a bail in the one-take run says it's back to the start.
- **Easier to find what an event asks for:** the one-take run's countdown shows big under the session clock (TAKE 0:43, red for the last ten seconds); the chalk marks are orange gaffer-tape X's twice the size with a floating MARK label over each one still to hit ("STOP!" when you're on it but still rolling); the zone signs (DEMO STAGE, FRONT OF STAGE, ROLLING) float big, unlit and outlined over their rings; balloon letters no longer show through walls.
- "Boardslide the party bench" says how: ride at it across. Grinding the bench another way shows what you did and what it needs ("THAT'S A 50-50", "It needs a Boardslide: ride at it across") instead of silently not counting.
- Web: a level download shows the level's name in the middle of the screen with a bar and how much has come in, instead of a small grey line in the corner.
- The results mark the goals finished this session NEW, apart from ones done in earlier sessions.
- The title camera swings slowly either side of its opening view instead of circling the rider: the full circle spent about half a minute of every two behind the quarter pipe, looking through its handrail.
- The title's footer follows the row you're on: Free Skate describes its level, Rider shows that rider's own event and its goals (it always described the event row). Rider blurbs no longer end on a one-word line, and the controls card gives the manual and nose manual a row each.
- B backs out of the pause menu and leaves the results for the title, as START does.
- **Menus and results with a gamepad:** one push of the stick moves one row (it used to race to the bottom of the title menu and cycle the rider four times); A accepts and B goes back in every menu, as the hints say. The results screen ignores presses for its first second, so a jump pressed as the buzzer goes no longer skips it.
- The title menu rounds a fundraiser's best the same way as the HUD ($1,867, not $1,866).
- **Crashes near the level's edge no longer trap you:** a board thrown over the edge used to fall for ever while the rider walked after it into thin air until a 12 s safety limit ran out. Now the board turns up on the ground beside the rider, and a body thrown over the edge is back on the board on the last safe spot with a blink (like riding off the edge). A board that comes to rest up on something (a ledge, a car) is taken from the ground instead of the rider popping up onto it, and any walk back ends after 10 s.
- P (swap rider) is ignored mid-crash (the new rider started the fall over at the middle of the level, 30 m away, and left the old board behind), and a new rider keeps holding a carried cake, pizza box or coffee (it used to hang in mid-air where P was pressed).
- Bystanders watch the rider through a crash (the fall, the get-up, the walk back), not the spot where it began.
- Dev: the bail physics test's clock counted twice as fast as real time (1/60 s per 1/120 s physics tick); it reads true now (a crash is back on the board in 4.5 to 6.5 s).
- A save with an unknown rider, music, steering, jump mode or level falls back to the defaults instead of breaking the title menu. A level download on the web gives up after 90 s without data and goes back to the title instead of waiting forever.

## v0.1.0 (2026-09-30)

The first release of Not Pro Skater, a skateboarding game about people who skate for the love of it. Five archetype riders (the Dev, the Musician, the Vlogger, the Dad and the Actor) skate six community events on six real-scale levels. Play it in the browser, or download it for macOS, Windows or Linux.

### Six events
- **Birthday at the Park** (the Dad, Neighborhood Park): grab P-A-R-T-Y, bring the cake to the party, show the kids a trick.
- **The Skate-a-thon** (everyone, Maple Grove Elementary): every point is money for a new playground. Ride sponsored laps of the school, grind the front-steps handrail, raise $2,500.
- **Launch Day** (the Dev, Hilltop Tech): the app ships today. Pizzas to the company picnic, a demo combo on the amphitheatre stage, show the team.
- **Record Release** (the Musician, the Warehouse District): the merch from the tour van to the table, grind the loading dock, hype the fans in front of the stage.
- **Rush Hour** (the Vlogger, Downtown): the one-take run through six checkpoints in 45 seconds with no bails, the coffee order to the office lobby, film the intro.
- **Between Takes** (the Actor, Big Moon Studios): hit your marks on a film backlot, bring the script pages to the director, grind the dolly track.

Every level is also open for Free Skate with no timer, and a grey Practice level has every kind of ramp and rail in lanes.

### Skating
- Ollies, flips, grabs, spins, manuals, grinds with a balance meter, lip tricks, wall plants, reverts and transfers, linked into combos with a multiplier.
- Vert ramps lock the air to the wall; small landing mistakes are lined up for you, big ones bail.
- Crashes are physical: the rider falls like a body, braces with their arms, gets up the way they landed and walks back to the board.
- Skater or screen steering, hold or tap to jump, keyboard or gamepad.

### Look and sound
- CC0 materials and props, light baked in Blender's Cycles, a different sky on each level, characters built with MakeHuman.
- A melodic techno soundtrack and sound effects made with Wavelength.

### Web and desktop
- The browser version downloads the game and the first two levels (77 MB), then fetches each later level (6 to 15 MB) the first time you play it.
- Downloads for macOS (universal), Windows and Linux carry every level.

## Development history (before v0.1.0)

### Four more levels: every rider has a home event
Six events now, one for each rider plus the Skate-a-thon everyone rides. Each new level is a real-scale place built like the first two (a Blender script, CC0 PBR materials, light baked in Cycles, grind lines as curves) with its own sky, bystanders and item to carry, and every one is free to skate without a timer (Free Skate on the title menu).

- **Launch Day at Hilltop Tech** (the Dev, `scenes/launchday.tscn`, level `blender/campus.py`): an office campus at midday on the day the team ships. Eight granite atrium steps with three handrails and a hubba, a plaza with two long planter ledges, a fountain with a grindable rim and a manual pad, a sunken amphitheatre with three curved tiers of ledges round a stage, a 1.6 m parking deck with a railed ramp, the campus sign's ledge, and the company picnic on the lawn with a food truck. Goals: D-E-P-L-O-Y, the pizzas from the food truck to the picnic, a long planter ledge, show the team, a 6,000 demo combo at the stage, 30,000 points. 19 grind lines.
- **Record Release in the Warehouse District** (the Musician, `scenes/recordrelease.tscn`, `blender/warehouse.py`): an old industrial block in the late afternoon, the band's record release show at the Foundry. The Foundry's 1.2 m loading dock (its edge a ledge, a ramp down) with the tour van below, a parking lot with bays, wheel stops and a long median curb, a scaffold stage with speaker stacks and the fans, an alley with a bank up the wall and a railed side door, corrugated sheds up a long railed ramp. Goals: V-I-N-Y-L, the merch box from the van to the table, grind the dock, hype the fans, a 7,000 combo in front of the stage, 35,000 points. 22 grind lines.
- **Rush Hour Downtown** (the Vlogger, `scenes/rushhour.tscn`, `blender/downtown.py`): a few city blocks on a market morning. Market Street is closed to cars with stalls on the road and grindable curbs both sides, a café with sidewalk tables, a civic plaza raised 1.5 m (a railed ramp up, wide stairs down with the big rail and a hubba, the office tower's lobby), a bank to wall, a corner mini plaza where the camera is set up, a subway kiosk. Goals: V-I-R-A-L, the one-take run (six checkpoints from the market to the plaza and back round in 45 s, no bails), the coffee order to the office lobby, film the intro (a 5,000 combo on camera), grind the big rail, 35,000 points. 13 grind lines.
- **Between Takes at Big Moon Studios** (the Actor, `scenes/betweentakes.tscn`, `blender/backlot.py`): a film studio backlot in the afternoon. A western street of false fronts with raised boardwalks (their edges ledges) and hitching rails, a New York street of brownstones with railed stoops, a big stunt quarter pipe, a green screen cyclorama wall to ride like a quarter pipe, two long dolly tracks to grind, trailers, craft services and the director's chair. Goals: A-C-T-I-O-N, hit your four chalk marks (stop on each one), the script pages to the director's chair, grind the dolly track, impress the director and crew, 40,000 points. 23 grind lines.
- New bystanders for each: three coworkers, three fans, the director and two crew (MPFB, CC0 assets only), and new carried items (pizza boxes, a merch box, a coffee tray, script pages).
- New goal kinds: `zone_combo` (a combo landed inside an area, drawn as a ring on the ground), `timed_run` (checkpoints in order against the clock; a bail or the clock ruins the take and sends you back to the start) and `marks` (chalk X marks to stop on, like an actor's). `deliver` takes any item.
- Tests: the event test drives every new goal kind (`EVENT=launchday|recordrelease|rushhour|betweentakes`), the rail audit grinds every line on each level (`LEVEL=campus|warehouse|downtown|backlot`), and the route ride test rides the one-take run's checkpoints with real physics (`EVENT=rushhour scenes/dev_lapride.tscn`).
- `./build.sh` runs one Blender process per target (a level's module caches don't survive the next level's scene reset), and `build.py` loads any level module by name.

### Desktop builds
- macOS (universal, ad-hoc signed), Windows and Linux builds, every level in one package, with the board icon. They open an event or level straight away with `-- --scene=<id>`, like the web build's `?scene=`.

### Title menu: every event, every level
- The title menu's Event row cycles through the six events (their home rider, goals done and best score or money raised), and Free Skate cycles through the six levels. Progress totals count goals across all events.

### Web: later levels download when you play them
- The web build's first download holds the first two levels; each later level is its own resource pack next to `index.html` (`levels/<level>.pck`, 10 to 20 MB), fetched the first time in a session you start its event or free skate there (the browser's cache usually keeps it for next time), with a download line in the corner. So the first download stays under the 80 MB budget however many levels the game has. `tools/web_packs.py` writes the pack presets into `export_presets.cfg` from each level's glTF (the textures only it uses, its characters, items and sky).

### Fixes
- House and school windows no longer flicker: their glass was a thin box whose back face fought the wall behind it; it is a single quad just in front of the wall now.
- The school's doors are wide enough to see as doors (1.15 m).
- The Warehouse District's sky was drawn so bright it washed the lot out (its sky image is three times brighter than the others'); drawn at the others' brightness now. No car parked in front of the spawn.

### Sounds with known licences only
- Six sound effects (ollie, land, hard landing, grab, grind start, manual) were made with community synth patches whose terms were never confirmed. They are replaced by stand-ins made only from Wavelength's own instruments, loudness-matched to the originals, so everything the game ships has known terms. The music and sound effects are released with the game under its MIT licence (readme, audio credits).

### Fix: riders don't go black in the shade
- **The Vlogger's shirt no longer turns from red to black.** Two causes. Its fabric bump map (a grey height image) was exported as a normal map, and grey reads as surfaces tilted about 45 degrees one way, so the shirt shaded from one side and went black from the other; the character build now turns bump maps into real normal maps. And moving things (riders, bystanders, props, the board) got almost no fill light out of the sun: in the Compatibility renderer the sky's ambient barely reaches them, while the baked world around them is brightened, so the shade side of a rider went nearly black. They get a flat sky-coloured fill now (`fill` / `fill_color` in a level's look.json, default 1.0 and a soft sky blue); the baked world ignores it, so only live-lit things lift.
- Normal maps with empty areas (the Actor's suit, the Musician's fedora) have those areas set flat, so mipmaps don't darken the seams. Eyebrows and eyelashes no longer carry a normal map at all.

### Our logo on the web loading screen
- The web build's loading screen shows the Not Pro Skater wordmark (the board, NOT PRO / SKATER, "Skating for everyone else") instead of Godot's splash, with the progress bar in the game's orange. The same image is the boot splash on desktop. `game/assets/brand/splash.png` is the image (swap it for new art any time); the progress bar colour lives in the Web preset's `html/head_include`.

### Crashes: getting up and walking back like a person
- **Getting up is a real get-up now.** The body used to blend straight from however it lay into standing, each bone turning on its own, so the legs coiled through each other like a snake and the whole body spun round as it rose (worst after hitting a wall). Now the rider gets up the way they landed: face down, they push up onto hands and knees, bring a knee forward, kneel with a hand on it and stand; on their back, they sit up with knees bent and hands propping behind, rock forward into a crouch over their feet and stand. Every pose goes through the leg and arm IK, so limbs stay whole and bend only at the joints. They stand facing the way they lay (a step back from a wall they slid down), take a breath, then turn to the board.
- **The walk back to the board is a real walk.** It used to be a crouched shuffle: knees bent the whole time, feet flat and skating along the ground at up to twice the speed the legs moved. Now the standing leg is nearly straight and the pelvis rides up over it, the heel lands with the toes up and the foot rolls through to push off from the ball (toes bending), the knee folds as the leg swings through, the pelvis turns with each stride and the arms swing against the legs. Planted feet stay exactly where they landed (they no longer slide while the body speeds up, slows down or turns), and turning round on the spot is done in steps. A board close by is walked to (1.5 m/s, `walk_speed`); one further off is jogged to, and the gait blends into a jog with a flight phase, the heel coming up behind, a forward lean and bent arms. The same gait runs out a small mistake, with short quick steps while braking.
- **Relaxed hands.** Fingers used to be flat and spread like a mannequin's (the rest pose); they curl a little toward the palm now, riding, walking and getting up.
- The bail physics test checks the walk back: planted feet may not move more than 3 cm (they slid up to 33 cm in the first version of the new walk) and the standing knee averages under 23 degrees walking. `dev_bailfilm.tscn` takes `FILM_FROM=getup|walk|run` to film just that part, side-on (`FILM_H` for the height, `FILM_LEFT=1` for the other side, `FILM=runout`).

### Characters: CC0 throughout
- The Actor's hair and Leo's mom's bun were the only assets in the cast whose files say AGPL3 rather than CC0. The Actor wears culturalibre_hair_05 (CC0, tinted near black as before) and the mom a braid (braid01, CC0). Everything the characters are made of is CC0 now, which fits the MIT licence of the code (`art_credits.md` has the details and the rule for new assets).
- The mom's flats were 57,600 triangles on their own (97k for the whole character, three times anyone else); her shoes are a 1,000-triangle pair by the same author now, and her file went from 2.3 MB to 1.0 MB.

### Level 2 finished: the Skate-a-thon rides clean
- **The lap route is rideable end to end:** a new test (`scenes/dev_lapride.tscn`) rides the gates with real physics and found three blockers, now fixed: the car park's south row of bays ran across its own driveway (wheel stops in the way out; those bays are gone), the street lamps and a fire hydrant stood in the middle of the sidewalk the laps run along (they are at the kerb now, the utility box on the verge), and a bin sat on the line from the plaza to the car park. An autopilot rides all three laps in about 62 s of the 2:30 session.
- **Every grind line checked:** `scenes/dev_railaudit.tscn` drops the skater onto each rail, ledge, coping and curb of a level with grind pressed and makes it slide (25 on the school, 11 in the park, all pass).
- The principal has dark hair (the MPFB bob is golden blond) and faces the plaza instead of the doors; she still turns her head to watch you.
- The basketball court is painted a proper green; the morning sky is drawn brighter to match the park's.
- The playground warp spot starts inside the fence, looking out through the gate at the E and the school (the camera used to sit in the gate behind the letter).
- Dev: fixed-camera screenshots (`SHOT_EYE`, `SHOT_LOOK`, `SHOT_FOV`), and `SCENE=skateathon` for the perf probe.
- **Both levels fit the web build:** the second level took the package to 91 MB, over the 80 MB budget; it is 77 MB now. Godot's shadow meshes are off for every model (they doubled the levels' mesh data: 13.2 MB to 8.3 MB, with no measurable frame cost; LODs stay, since without them the far trees and houses quadruple the triangles). Eyes, eyebrows and eyelashes are 256 px (they were 10 MB across the cast at 512, and still read on the title's close-up). The cake's textures are 512 like other props.
- The Skate-a-thon draws fewer calls than the Birthday (about 400 against 410).

### Level 2: Maple Grove Elementary and the Skate-a-thon (first pass)
- **Maple Grove Elementary** (`blender/school.py`, `scenes/school.tscn`): a real-scale primary school on a Saturday morning under a mid-morning sky. A two-storey brick school with its name over the doors; front steps with three handrails and an access ramp with its own rail; a covered walkway on columns; planter ledges and benches on the entrance plaza; the school sign by the street (its cap is a ledge); a car park with painted bays, grindable wheel stops, a curb island with trees and lamps, a speed bump and parked cars; a 1.1 m loading dock with a ramp up and a ledge edge; a basketball court with the PTA's portable ramps (two quarter pipes, a funbox, a flat bar, a kicker); the old fenced playground behind the school. Same street and houses as Neighborhood Park.
- **Skate-a-thon** (`scenes/skateathon.tscn`, title menu): the score is money raised for a new playground ($0.10 a point: HUD, trick string, best and results read in dollars), and a fundraising thermometer on the plaza fills as it comes in. Goals: ride 3 sponsored laps through the gates (START / FINISH arch, cone gates, a NEXT marker; each lap is a trick), grind a front-steps handrail, bring the bake-sale cake from the car park, collect D-O-N-A-T-E, impress the principal, raise $2,500. 2:30 sessions.
- New goal kind `laps`; `trick_on` takes a list of rails and any grind; the deliver goal's drop message is per event; the event test drives any event's goals by kind (`EVENT=skateathon`).
- A principal (MPFB bystander) and PTA parents and kids around the plaza, car park and court.
- `terrain.configure()` and `realism.set_sky()` make the lawn layout and the sky per level; the Neighborhood street and house builders take parameters.

### Fix: half pipe airs are the shot
- Off a quarter or half pipe the camera used to park where the air began and watch the lip, so the air read as a pause. The vert shot now sits closer and a little higher (2.9 m out, 1.8 m to the side), rises with the rider, slides along the coping with any drift, looks at the rider instead of the lip, and pushes in (12 degrees of zoom) as the rider leaves the lip; big airs off kickers get the same push-in by height. It still holds out front until the rider is back down the wall, then swings behind.

### Fix: crashes bend like a body, not a doll
- Knees are hinges now: they bend the natural way only, about the leg's left-right axis. They hung off cone joints that let them fold 60 degrees sideways and hyperextend backwards by up to 48 (the frog-legged half pipe slams). The legs also ease out of the riding crouch as soon as the fall starts, so a rider face down on the ground no longer lies there with the feet in the air.
- The bail physics test measures every knee through each crash and fails on hyperextension or sideways bending (before: sideways up to 62 degrees, backwards up to 48; now: at most 3 and none).

### Fix: holding Space never jumps by itself
- In hold-to-jump mode, pressing Space on a grind or during a lip stall popped you off at once, on the press, which read as the jump letting go by itself while Space was still held (and the rail magnet can put you on a rail without you noticing). Those pops now wait for the release like every other jump; a release left over from just before a grind or stall no longer bounces you straight off. Tap mode is unchanged, and the wall plant still fires on the press.
- `scenes/dev_jumphold.tscn` holds Space through real key events (with key repeat) while riding, pushing, tapping other keys, over seams and a curb, up a quarter pipe, onto a kicker, in a manual and on a grind: no jump until the release, and the POP charge never resets under a held key.

### Renamed: Not Pro Skater
- The game is **Not Pro Skater** (was the working title Not Pro Skaters): title screen logo, window and browser tab title (`config/name`), docs. The repo folder is `~/Code/not-pro-skater`. Saves move to `user://not_pro_skater.cfg`; the old `not_pro_skaters.cfg` is still read when there is no new one.

### Playtest fixes: crashes, letters, quit
- **Crashes look like a person falling, not a rag doll:** the ragdoll has muscles now. Each part pulls toward the pose it had when it went down (neck and back firmest), the arms reach down toward where the body is falling to catch it, and the legs let go of the riding crouch; once the body lies still the muscles relax and the back and legs ease straight. Before, it went completely limp: face-plants with the arms tucked under the chest, the head thrown back against a wall. `LIMP=1` turns the muscles off for comparison.
- Fixed: a one-frame pop at every get-up after a crash (the rider flashed upright on the board), from the skeleton showing its stale riding pose the frame the ragdoll stopped.
- **P-A-R-T-Y on the HUD:** the event's letters are balloon badges at the top of the screen, dim until grabbed. A grabbed letter flies from its balloon to its badge, which fills with the balloon's colour and pops; with the whole word in, the row waves. The goal list counts them (2/5).
- **Quit on the title menu** (desktop; the web build has nothing to quit to). Esc on the title jumps to it.
- Dev: `dev_bailfilm.tscn` films physical bails side-on up close (slam, tumble, half pipe, wall, grind fall); `tools/film_sheet.sh` makes contact sheets.

### Playtest fixes: grind balance, the level's edge
- **Grinds have a balance meter:** the lean tips away from the middle faster and faster (quicker the longer the grind; nose and tail slides tip faster than a 50-50), and left / right shift the weight back. Coming in across the rail starts you leaning the way you were going. Past either end the rider falls off to that side (a slam, never a run-out). The rider sways with the lean. A clean 50-50 left alone lasts about 1.7 s, a sloppy entry about 1.1 s. Tuning in F3 under Grinding (`grind_wobble`, `grind_control`, ...). Feel tests `grind_hold`, `grind_drop`, `grind_lean`.
- **Lip stalls balance the same way:** the stick is the rider's weight, so push against the lean (it was the other way round, unlike grinds).
- **No more falling off the world:** about 2 m before the edge of the level's ground the screen blinks and you are back on the last flat spot at least 6 m inside, stopped and facing away from that edge (a combo in progress is lost). The level's edge comes from its ground colliders (`Level.bounds`). Feel test `edge_warp`.
- Fixed: a flickering dark patch in the mini ramp's top corner. It was the shadow of the bobbing P balloon: under the low sun it slid about a metre up and down the ramp. The letter balloons cast no shadow now (the party's balloon bunches already did not).
- Fixed: the street benches were half built. Poly Haven's street seating is a kit laid out piece by piece (one bench with a back, a spare backless seat without its far leg, four curved connector seats floating beside them), and all of it was merged into one prop. Only the bench is kept now (`park_props.EXCLUDE`); rebaked, so the floating pieces' shadows are gone too.
- Dev: `dev_flicker.tscn` parks the camera at given views and nudges it a millimetre a frame; `tools/flicker_map.py` turns the frames into a heat map of whatever flips between them (z-fighting, shadow shimmer, moving shadows).

### Graphics: late afternoon light
- Fallen leaves on the ground under the park's trees.
- Flocks of birds wheel over the park, flapping and gliding (one MultiMesh, no shadows), and a filmic split-tone grade warms the mid-tones and cools the shade.
- House windows reflect the sky (a gradient along the reflected view ray, a warm glint toward the sun, stronger at grazing angles) over a dark room with a hint of curtain, instead of flat navy panels (`window_glass.gdshader`).
- A soft contact shadow under the board (ambient occlusion the renderer does not have): keeps the rider grounded in the shade, widens and fades as the board leaves the ground.
- 16x anisotropic filtering (ground and roofs at grazing angles shimmered less); MSAA stays at 4x (`msaa_3d=2` is the 4x setting).
- **Life in the streets and park:** a fire hydrant and utility boxes on the sidewalks, cars under covers parked along the far curb, garden gnomes in the front yards, trash bags by the bins, street benches on the plaza's edges, a drinks crate and a chalkboard at the party, balls left on the lawn (CC0 Poly Haven; heavy scans decimated, prop colour maps at 512 for the web).
- **Ramps look built:** a worn steel plate at the foot of every quarter pipe, slate-painted side sheets with a timber edge following the curve, and a timber fascia under the coping.
- **Faces:** MPFB's eye material quietly failed to apply, so everyone had the same red-brown irises with pinkish whites (the eyes read red); `character.py` now recolours the iris to each recipe's eye colour (brown, blue, hazel, green, grey) and cleans the whites. Skin gets a soft warm rim and a little backlight at load, standing in for subsurface scattering.
- **The park is lit by a late afternoon sun** (Poly Haven's CC0 Qwantani Late Afternoon sky, sun 19 degrees up): long shadows across the plaza and street, warm backlight on the trees, rim light on the riders. The midday sun (48 degrees) made everything flat. `SKY=<polyhaven id>` in `blender/realism.py` switches the sky for a bake; the level's `look.json` carries the matching exposure and baked-light strength.
- **Grass and ground never shine like a wet road:** a roughness floor per material (grass 0.92), which a low sun had turned into glare.
- **Clean shadow edges:** a low sun stretches each shadow texel along the ground and the edges stair-stepped; the sun's shadows now cover 40 m with a wider near split, more blur and the higher soft-shadow filter.
- **Title screen:** the rider stands by the mini ramp in the sun, facing it, and the camera starts on the sunny side.

### New soundtrack: melodic techno
- Five new Wavelength pieces replace the cartoon-era music, all built on one motif: **title** (atmospheric melodic techno, 120 BPM, A minor, 32 bars), **cruise** (friendly, groovy, swung, 125 BPM, D dorian, 64 bars, with a lift, a peak, a break and a return), **hype** (harder, straight 16ths, 131.25 BPM, E minor, 64 bars), and **results** / **new best** stings (the new-best run lands on the results chord). Seamless loops (exact sample counts, seams checked), -14 LUFS, balanced left/right, the 2-5 kHz band kept clear for the sound effects. All open-licensed sounds (Wavelength built-ins, MuseScore General, Surge XT patches); credits in `docs/audio_credits_music.md`.
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

### Polish: grabs look like grabs
- Maya and The Vlogger wear light denim shorts and Leo khaki cargos: the dark originals rendered as flat black on bystanders (no normal maps) and on a small rider.
- Grabs tuck the knees hard and pull the board up to the hand (the hand used to hang in the air by the shin), and each has its own shape: Indy between the feet, Melon reaching down the heel side with the board tilted, Nosegrab with the nose pulled up, Method with the board kicked back and the chest turned, Mute reaching across. Hands aim at the posed deck's edges, not a rest-pose offset. Pose tour `POSES=grab_`.

### Polish: no snaps onto rails and copings
- Locking onto a rail or a coping moved the body there in one physics tick (up to a third of a metre in a frame for a lip stall) and the board jumped to its stall angle. The drawn rider now glides the last bit over about a tenth of a second (`Skater._snap_to`, a decaying offset carried inside the interpolated positions) and the board eases into a stall. The `lip_stall` feel test checks the largest per-tick move (0.31 m before, 0.09 m now).

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
- **Realistic look, first proof** (`scenes/looktest.tscn`, `blender/looktest.py`, `blender/realism.py`): the kit's flat colours become CC0 PBR texture sets (ambientCG) with real-scale UVs (ramp surfaces unwrap along the profile, so the transition is one seamless sheet); static surfaces are merged and get a lightmap UV set; Blender Cycles bakes sky light (the HDRI with its sun disc clipped out) plus the sun's bounce into a PNG lightmap. In Godot a small shader (`baked_pbr.gdshader`, Compatibility renderer) adds the baked light, the live sun adds direct light and shadows, and the same Poly Haven HDRI is the sky, matched to the bake (sun direction, energies, a fixed quarter-turn between Blender's and Godot's panorama mappings). AgX tonemapping, light glow and fog. Credits in `art_credits.md`.
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
