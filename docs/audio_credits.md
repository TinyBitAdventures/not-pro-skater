# Not Pro Skater SFX: credits and licence classes

Rendered with Wavelength 0.5.0-dev (headless host) at 44.1 kHz, then sliced, folded to mono, faded, peak-normalised and dithered to 16 bit (see `recipes/scripts/`). The job for every sound is in `recipes/jobs/<recipe>.job.json`. Plugin renders are not bit-reproducible, so the WAVs are the assets; do not rebuild them in CI.

The pushing, wind and per-surface grind sounds (push, wind_loop, grind_metal_loop, grind_concrete_loop, grind_wood_loop) and the ambiences are synthesised with numpy/scipy instead, by `audio/build_skate_sfx.py`, `audio/build_ambience.py` and `audio/build_level_ambience.py` (class OPEN (synth): code in this repo, no samples, no plugins; seeded, so a rebuild gives the same sound). Their loops are periodic by construction (filters applied as their steady-state response over the loop, whole-cycle envelopes, events and reverb tails wrapping), so they need no crossfade.

Licence classes follow the research report (`research/sfx-palette.md`, section 4): OPEN = plugin code is open source; builtin:* = Wavelength's own DSP. No FREE-proprietary or COMMERCIAL source is used anywhere (Vital, RP2A03 and every sample library were left out).

**Licence status (v0.1.0):** every sound the game ships is made from Wavelength's builtin:* instruments or synthesised by this repo's numpy/scipy scripts, and needs no third-party terms. Six sounds (ollie, land, land_hard, grab, grind_start, manual) were first made with community Surge XT patches and a Dexed cartridge voice whose terms were unknown; their builtin-only stand-ins replaced them on 2026-09-30, loudness-matched to the originals. The earlier versions and the `alt/` files that still use community patches are not shipped.

| sound | source (plugin / preset or builtin patch) | class | notes |
|---|---|---|---|
| ollie | builtin:synth "Init": pitch-enveloped sine pop + noise click + noise rattle (`ollie_C`, was `alt/ollie__alt.wav`) | OPEN (builtin) | swapped in for v0.1.0 (the Surge XT community-patch version's terms were unknown) |
| land | builtin-only stand-in (was `alt/builtin-only/land.wav`) | OPEN (builtin) | swapped in for v0.1.0 |
| land_hard | builtin-only stand-in (was `alt/builtin-only/land_hard.wav`) | OPEN (builtin) | swapped in for v0.1.0 |
| crack | builtin:synth "Init": noise tick (high-pass 2.8 kHz, low-pass 6.5 kHz, decay 8 ms, +20 dB) + sine thunk G2 with 14 st pitch envelope (-3 dB) | OPEN (builtin) | recipe `crack__crack_G5` = report pick `crack_G` with the tick raised (the original tick was inaudible next to the thunk; original kept in `alt/builtin-only/crack__report_original.wav`) |
| flip | builtin:synth "Init": white noise, 24 dB band-pass (500 Hz, res 0.45, filter env +3 oct, attack 120 ms) | OPEN (builtin) | report pick `flip_E` |
| grab | builtin:synth "Init": noise burst through a band-pass (`grab_H`, was `alt/grab__alt.wav`) | OPEN (builtin) | swapped in for v0.1.0 |
| manual | builtin sine blip (was `alt/builtin-only/manual.wav`) | OPEN (builtin) | swapped in for v0.1.0 (the Dexed cartridge voice's provenance was unknown) |
| bail | builtin:fx "impact" C3 + builtin:drums toms 41/45/41/48 bounces + builtin:drums crash (band-passed 500 Hz-5 kHz) + builtin:synth "Init" noise skid | OPEN (builtin) | report pick `bail_Ar2`, cut at 1.05 s with a 300 ms fade |
| grind_start | builtin inharmonic clank (was `alt/builtin-only/grind_start.wav`) | OPEN (builtin) | swapped in for v0.1.0 |
| trick | builtin:synth "LD Chip" C6 then G6 | OPEN (builtin) | |
| bank | builtin:synth "LD Chip" C5 E5 G5 C6 at 75 ms steps, last note lengthened to 0.3 s | OPEN (builtin) | |
| bank_big | builtin:synth "LD Chip" arpeggio C5..G6 + C major chord C6 E6 G6 C7 at 0.44 s + builtin:synth "BR Stab" chord C4 E4 G4 C5 (-6 dB) | OPEN (builtin) | |
| combo_lost | builtin:synth "LD Soft" G4 then D4 (2 st downward bend) | OPEN (builtin) | |
| pickup | builtin:synth "LD Chip" B5 then E6 | OPEN (builtin) | for the five letters play with pitch_scale 2^(n/12), n = 0, 2, 4, 7, 9 |
| skate_done | builtin:synth "BR Brass" C5 x3 + C major chord, with "PL Bell" chord C6 E6 G6 C7 (+0.8 dB) | OPEN (builtin) | |
| go | builtin:synth "LD Chip" G5 | OPEN (builtin) | |
| time_up | builtin:synth "Init": three saws G3 + D4 + G4, 2-voice unison, low-pass 2.2 kHz | OPEN (builtin) | |
| ui_ok | builtin:synth "LD Chip" C6 | OPEN (builtin) | |
| roll_loop | builtin:synth "Init" noise: band-pass 260 Hz body + 3 kHz band-pass hiss (-26.3 dB fader), whole-Hz amp LFOs (4 Hz, 7 Hz) | OPEN (builtin) | recipe `roll_Br`; loop = report ffmpeg crossfade recipe |
| roll_grass_loop | builtin:synth "Init" noise: low-pass 800 Hz swish (LFO 3 Hz) + band-pass 1.8 kHz blades (LFO 2 Hz) | OPEN (builtin) | recipe `grass_Ar` |
| roll_wood_loop | builtin:synth "Init" noise: resonant band-pass 300 Hz (res 0.6, LFO 6 Hz) + 1.5 kHz knock layer | OPEN (builtin) | recipe `wood_Ar` |
| grind_loop | builtin:synth "Init" noise: 24 dB band-pass 2.4 kHz (res 0.55, cutoff LFO 2 Hz) + tanh saturate, amp LFO 11 Hz | OPEN (builtin) | recipe `grind_B` (chosen over the saw stack for lower fatigue); the saw stack `grind_A` is `alt/grind_loop__alt.wav` |
| push | numpy/scipy (`audio/build_skate_sfx.py`): grit clicks (capped Pareto amplitudes) band-passed 0.6-2.6 kHz and 2.2-6 kHz, denser and brighter as the foot speeds up, over band-passed rubber friction noise; a 110 Hz sole thump and a 1.2-5 kHz scuff tick at contact | OPEN (synth) | 0.33 s one push stride, peak -1 dBFS; loudest 400 ms -20.3 LUFS, about 1 dB under land (-19.3), since it repeats every ~0.7 s |
| wind_loop | numpy/scipy (`audio/build_skate_sfx.py`): six independent pink-noise bands 35 Hz-12 kHz on a whole-cycle gust envelope (0.55-1), the higher bands brightening more in each gust, buffeting flutter on the low bands | OPEN (synth) | 6 s loop, peak -3 dBFS like the other loops; for the game to fade in with speed |
| grind_metal_loop | numpy/scipy (`audio/build_skate_sfx.py`): stick-slip friction (noise + capped Pareto clicks, 11 Hz chatter) driving ten steel modes (free-beam ratios on 470 Hz, plus 1.71, 3.32/3.36 and 5.53 kHz; 0.2-0.6 s rings), a 2-7 kHz scrape and a 0.7-2.2 kHz body | OPEN (synth) | 3 s loop, RMS-matched to grind_loop (-15.35 dBFS); strongly tonal (the ringing), so it reads ~1 dB louder (loudest 400 ms -11.2 LUFS vs -12.1) |
| grind_concrete_loop | numpy/scipy (`audio/build_skate_sfx.py`): dense capped-Pareto grit band-passed 380 Hz-3 kHz + sparse 2.5-6 kHz grit + pink 140 Hz-1.9 kHz roar + rumble under 220 Hz, slow surface patches, 7 Hz chatter; two faint truck modes (1.18, 2.65 kHz) about 20 dB down | OPEN (synth) | 3 s loop, RMS-matched to grind_loop (-15.35 dBFS) |
| grind_wood_loop | numpy/scipy (`audio/build_skate_sfx.py`): low-passed friction noise + a jittered 26 Hz train of grain bumps through six hollow plank/box modes (150, 232, 395, 610, 940, 1450 Hz, Q 14-24), two soft board-joint knocks per loop | OPEN (synth) | 3 s loop, RMS-matched to grind_loop (-15.35 dBFS); centroid ~1.1 kHz, so it reads softer (loudest 400 ms -14.4 LUFS) |

## Ambience (`game/assets/audio/ambience/`)

32 s seamless stereo loops, Vorbis q1 (`oggenc -q 1`, ~80 kb/s), all at the park's integrated loudness (-17.2 LUFS, ffmpeg ebur128; the level ambiences are measured and corrected after encoding).

| file | source | class | notes |
|---|---|---|---|
| park_ambience.ogg | numpy/scipy (`audio/build_ambience.py`): gusting wind, leaves in the gusts, traffic hum with one car passing, five birds | OPEN (synth) | |
| city_ambience.ogg | numpy/scipy (`audio/build_level_ambience.py city`): brown/pink traffic hum, six vehicles passing (Doppler engine harmonics, tyre roar, pan following the bearing, a bus among them), two distant dual-tone horns (415 + 523 Hz), an 18-talker crowd murmur, four walkers' footsteps (shoes, heels, sneakers), three pigeons cooing and a flock taking off at ~18 s, street-canyon slap echoes | OPEN (synth) | the murmur is vowel formants on a buzz with random pitch contours: no consonants, no words. L/R within 0.1 dB, true peak -2.3 dBFS |
| industrial_ambience.ogg | numpy/scipy (`audio/build_level_ambience.py industrial`): 60 Hz mains hum and harmonics, dust-extractor roar, two compressors chugging (4 Hz, 2.7 Hz), a faint motor whine, two reversing beepers (1.05 kHz forklift, 1.23 kHz truck further off), a steel plate dropped, a chain, a container door and a pipe (modal hits) ringing round the yard, a truck passing far off, gusty wind with a whistle and a loose sheet rattling | OPEN (synth) | yard reverb with 120-470 ms wall echoes. L/R within 0.5 dB, true peak -2.3 dBFS |
| studio_ambience.ogg | numpy/scipy (`audio/build_level_ambience.py studio`): diesel generator (4 cylinders at 1800 rpm, 60 Hz firing, uneven cylinders, enclosure modes), seven distant crew talkers with two calls (vowels only, no words), three runs of hammering (nail ping + wood thunk, duller as the nail goes home), a far-off radio playing a small band tune (120 bpm, I-vi-IV-V, 16 bars = the loop) through a tinny band-pass, three birds, breeze and far traffic | OPEN (synth) | slapback off the stage walls (150-330 ms). L/R within 0.4 dB, true peak -4.0 dBFS |

## Alternates (`alt/`)

| file | source | class |
|---|---|---|
| ollie__alt.wav | builtin:synth "Init": pitch-enveloped sine pop + noise click + noise rattle (`ollie_C`) | OPEN (builtin) |
| grab__alt.wav | builtin:synth "Init": noise burst through a band-pass (`grab_H`) | OPEN (builtin) |
| bail__alt.wav | builtin:synth slide whistle down 24 st + builtin:fx impact + builtin:drums rim/tom bounces (`bail_Br`) | OPEN (builtin) |
| land__alt.wav | Surge XT "Kick Body Model" (3rdparty/Psiome Send Sound/Percussion) + "Simple Click" (`land_Cr`) | OPEN (plugin); patch terms unknown |
| grind_loop__alt.wav | builtin:synth saw stack (C4, +7 st, +1 oct) + noise, band-pass 2.6 kHz, LFOs 9 Hz and 3 Hz (`grind_A`) | OPEN (builtin) |
| builtin-only/land.wav | builtin:synth thud + knock + slap + rattle (new recipe `land_B`, not from the report) | OPEN (builtin) |
| builtin-only/land_hard.wav | builtin:drums kick + tom + snare + crash debris (`landhard_A`) | OPEN (builtin) |
| builtin-only/manual.wav | builtin:synth sine blip E5 (`manual_E`) | OPEN (builtin) |
| builtin-only/grind_start.wav | builtin:synth inharmonic square clank, band-pass 2.2 kHz (`gstart_G`) | OPEN (builtin) |
| builtin-only/crack__report_original.wav | builtin:synth tick + thunk exactly as the report (`crack_G`) | OPEN (builtin) |

Surge XT: https://surge-synthesizer.github.io (GPL-3.0-or-later). Dexed: https://github.com/asb2m10/dexed (GPL-3.0-or-later). Wavelength: https://wavelength.run.
