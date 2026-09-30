# Not Pro Skater SFX: credits and licence classes

Rendered with Wavelength 0.5.0-dev (headless host) at 44.1 kHz, then sliced, folded to mono, faded, peak-normalised and dithered to 16 bit
(see `recipes/scripts/`). The job for every sound is in `recipes/jobs/<recipe>.job.json`. Plugin renders are not bit-reproducible, so the WAVs
are the assets; do not rebuild them in CI.

Licence classes follow the research report (`research/sfx-palette.md`, section 4): OPEN = plugin code is open source; builtin:* = Wavelength's own DSP.
No FREE-proprietary or COMMERCIAL source is used anywhere (Vital, RP2A03 and every sample library were left out).

**Licence caveat, read before shipping (unknown, not checked):** the report only established that Surge XT, OB-Xf and Dexed are GPL-3.0-or-later
(`wavelength kit`). It did not establish the terms of the presets themselves or of the rendered audio. On this machine every Surge XT preset used
below lives in `Surge XT/patches_3rdparty/<author>/` (community-contributed, no licence file next to them) and the Dexed voice comes from the
`SynprezFM_26` cartridge. Audio terms for those: **unknown**. Six sounds depend on them (ollie, land, land_hard, grab, grind_start, manual). Licence-safe
stand-ins made only from builtin:* are in `alt/builtin-only/` (land, land_hard, manual, grind_start) and `alt/` (ollie__alt = builtin-only, grab__alt = builtin-only);
swap them in if the patch terms turn out not to allow redistribution. Everything else is builtin:* and needs no third-party terms.

| sound | source (plugin / preset or builtin patch) | class | notes |
|---|---|---|---|
| ollie | Surge XT "Tuned Wood" (3rdparty/Altenberg/Percussion) + Surge XT "Simple Click" (3rdparty/Rare Earth/Percussion, -11.8 dB) + builtin:drums closed hat x3 at 50/100/155 ms (high-pass 2.5 kHz, low-pass 6 kHz, +3 dB) | OPEN (plugin GPL-3.0-or-later); patch audio terms unknown | recipe `ollie__ollie_Br3` = report pick `ollie_Br` with the rattle low-passed (the original had 25% of A-weighted energy above 8 kHz) |
| land | Surge XT "Kick Room 1" + "Snare Room 1" (low-passed 2.5 kHz, -1.9 dB), both 3rdparty/Emu/Drums | OPEN (plugin); patch terms unknown | report pick `land_Br` unchanged |
| land_hard | Surge XT "Boomy Kick" (3rdparty/Cybersoda/Drums) + "Snare Room 2" (-3.8 dB) + "Mort Noisey Drum" (-4.1 dB) (both 3rdparty/Emu/Drums) | OPEN (plugin); patch terms unknown | report pick `landhard_Br` unchanged |
| crack | builtin:synth "Init": noise tick (high-pass 2.8 kHz, low-pass 6.5 kHz, decay 8 ms, +20 dB) + sine thunk G2 with 14 st pitch envelope (-3 dB) | OPEN (builtin) | recipe `crack__crack_G5` = report pick `crack_G` with the tick raised (the original tick was inaudible next to the thunk; original kept in `alt/builtin-only/crack__report_original.wav`) |
| flip | builtin:synth "Init": white noise, 24 dB band-pass (500 Hz, res 0.45, filter env +3 oct, attack 120 ms) | OPEN (builtin) | report pick `flip_E` |
| grab | Surge XT "Clap - Noise Layer" (3rdparty/TNMG/Drums, velocity 0.5, low-passed 3 kHz) | OPEN (plugin); patch terms unknown | report pick `grab_B`; builtin cloth-noise alternative is `alt/grab__alt.wav` |
| manual | Dexed "WOOD BLOCK" (DX7 cartridge SynprezFM_26), C5 | OPEN (plugin GPL-3.0-or-later); cartridge voice provenance unknown | report pick `manual_D`; builtin sine blip is `alt/builtin-only/manual.wav` |
| bail | builtin:fx "impact" C3 + builtin:drums toms 41/45/41/48 bounces + builtin:drums crash (band-passed 500 Hz-5 kHz) + builtin:synth "Init" noise skid | OPEN (builtin) | report pick `bail_Ar2`, cut at 1.05 s with a 300 ms fade |
| grind_start | Surge XT "Household Metallic" (3rdparty/Rare Earth/Percussion) | OPEN (plugin); patch terms unknown | report pick `gstart_A`; builtin inharmonic clank is `alt/builtin-only/grind_start.wav` |
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
