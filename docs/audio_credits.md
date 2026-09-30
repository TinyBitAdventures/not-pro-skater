# Not Pro Skater SFX: credits and licence classes

Rendered with Wavelength 0.5.0-dev (headless host) at 44.1 kHz, then sliced, folded to mono, faded, peak-normalised and dithered to 16 bit (see `recipes/scripts/`). The job for every sound is in `recipes/jobs/<recipe>.job.json`. Plugin renders are not bit-reproducible, so the WAVs are the assets; do not rebuild them in CI.

Licence classes follow the research report (`research/sfx-palette.md`, section 4): OPEN = plugin code is open source; builtin:* = Wavelength's own DSP. No FREE-proprietary or COMMERCIAL source is used anywhere (Vital, RP2A03 and every sample library were left out).

**Licence status (v0.1.0):** every sound the game ships is made from Wavelength's builtin:* instruments and needs no third-party terms. Six sounds (ollie, land, land_hard, grab, grind_start, manual) were first made with community Surge XT patches and a Dexed cartridge voice whose terms were unknown; their builtin-only stand-ins replaced them on 2026-09-30, loudness-matched to the originals. The earlier versions and the `alt/` files that still use community patches are not shipped.

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
