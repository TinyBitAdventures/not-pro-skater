# Not Pro Skater: music credits

Composition, arrangement, mix and master: Claude (Anthropic, Claude Opus 5.5), for Austin Ginder, with Wavelength 0.5.0-dev (a headless music engine). Every file was rendered offline from a generated job: the generators are `~/Documents/wavelength-songs/not-pro-skaters-<slug>/make-job.py` (one folder per piece), the shared palette, delivery and measuring scripts are in `~/Documents/wavelength-songs/not-pro-skaters/tools/`. Nothing was recorded and no audio loop or sample pack was imported; the only samples are the MuseScore General SoundFont drum hits. **Nobody has listened to these files yet**: every statement about them below is a measurement.

The compositions and recordings were made for the game and are released with it under the repository's MIT licence (`license`). Every sound source is OPEN (no commercial or freeware-only plugin, preset or sample library); the MuseScore General SoundFont's acknowledgements are below.

Shared theme: every piece uses the same motif, scale degrees 1-2-3-5-3-2 on a 3+3+2 sixteenth rhythm (A B C E C B in the title, D E F A F E in cruise, E F# G B G F# in hype, C D E G E D in results).

Loops were rendered three times back to back and the middle pass kept (sample-exact cut), so reverb and delay tails, held pads and the master compressor run into the loop point exactly as on the next pass; the first 10 ms are crossfaded from the start of the third pass (Surge XT voices start at free-running phases, so the second and third passes differ by a phase there). Master chain on every file: eq (high-pass 28 Hz, a 1.0-1.5 dB dip at 3.3 kHz to leave room for sound effects, +1 dB shelf at 9 kHz), glue compressor 1.8:1, soft clip, true-peak limiter (-2.3 dB loops, -2.6 dB stings) and a loudness target (-14 LUFS loops, -12 LUFS stings). Encoded with `oggenc -q 3` (vorbis-tools 1.4.3).

## title.ogg: Title

- **120 BPM, A minor, 4/4, 32 bars**, a seamless loop: 64 s = **2822400 samples** at 44.1 kHz (bars x 4 x 60 / BPM x 44100 = 2822400; decoded Ogg 2822400, exact: yes). No lead-in: the first sample is the loop start.
- Ogg Vorbis q3, 871635 bytes. Integrated **-14.1 LUFS**, true peak **-1.7 dBTP**, LRA **5.0 LU** (decoded file). L -16.26 / R -16.28 dBFS RMS (L minus R +0.02 dB), side -12.0 dB under mid, correlation 0.88.
- Loop seam (decoded Ogg played twice back to back): the step across the join is 0.0582 (L) / 0.0512 (R) against a typical local step of 0.0670 / 0.0700 (x0.87 / x0.73); the click energy of the 5 ms window on the join is 0.18x / 0.14x the loudest ordinary window within 1 s. Lossless 44.1 kHz source before encoding: x0.23 / x0.62.

| Section | Bars | Time | Chords | What plays | LUFS | TP | L minus R |
|---|---|---|---|---|---|---|---|
| Glow | 1-8 | 0:00.00-0:16.00 | Am9 Fmaj9 Cadd9 G6 (2 bars each) | kick, soft offbeat bass, Juno pad, Friendly-pluck theme, shaker, two bell pings | -14.7 | -2.1 | +0.16 |
| Drift | 9-16 | 0:16.00-0:32.00 | Am9 Fmaj9 Cadd9 G6 | + clap on 2/4, offbeat hats, dub stabs through the echo, the theme's answer phrase, crash | -13.2 | -2.0 | -0.16 |
| Float | 17-24 | 0:32.00-0:48.00 | Fmaj9 G6 Em7 F G | breakdown: kick/bass/clap out, pad + bell line, pluck echoes, music bus low-passed to 2.2 kHz; kick back half-time in bar 23, 4/4 in 24, reverse swell | -16.8 | -2.4 | +0.27 |
| Return | 25-32 | 0:48.00-1:04.00 | Am9 Fmaj9 Cadd9 G6 | full: open hats, 16th arp opening up, stabs, theme; bar 32 leads back into bar 1 | -12.8 | -1.7 | +0.01 |

| Track | Engine | Preset / patch | Role | Licence class | Alone: L minus R |
|---|---|---|---|---|---|
| Kick | builtin:synth | designed sine kick: sine + triangle (+1 oct, 30 ms) + noise click (4 ms), pitch envelope +30 st / 42 ms, then eq, saturate, soft clip | four-on-the-floor kick tuned A1 | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | +0.00 dB (pan +0.00) |
| Clap | builtin:sampler | MuseScore General bank 128 program 25 "TR-808", key 39 (hand clap) | clap on 2 and 4, rolls in builds | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | -0.01 dB (pan +0.00) |
| Hats | builtin:drums | keys 42 closed hat / 46 open hat | offbeat and 16th hats (air-heavy, little 2-5 kHz) | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | -0.01 dB (pan -0.18) |
| Cymbals | builtin:drums | key 49 crash, key 51 ride | crash on bars 9 and 25 | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | +0.01 dB (pan +0.00) |
| Shaker | builtin:sampler | MuseScore General bank 128 program 0 "Standard", key 70 (maracas) | swung 16th shaker | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | -2.07 dB (pan +0.15) |
| Bass | Surge XT (VST3) | "Bass 2" by Bluelight (patches_3rdparty/Bluelight/Basses), transpose +12 | plucked offbeat / rolling bass | OPEN: Surge XT 1.3.4 patch (GPL-3.0-or-later distribution) | +0.05 dB (pan +0.00) |
| Stab | Surge XT (VST3) | "Gentle" by Cybersoda (patches_3rdparty/Cybersoda/Keys), width 0.55 | dub chord stabs through the echo | OPEN: Surge XT 1.3.4 patch (GPL-3.0-or-later distribution) | -0.54 dB (pan +0.00) |
| Pad | Surge XT (VST3) | "Juno-60 Strings" (patches_factory/Polysynths) | warm string pad | OPEN: Surge XT 1.3.4 patch (GPL-3.0-or-later distribution) | +0.05 dB (pan +0.00) |
| Hook | Surge XT (VST3) | "Friendly" (patches_factory/Plucks), transpose +12 | the hook / theme pluck | OPEN: Surge XT 1.3.4 patch (GPL-3.0-or-later distribution) | +0.02 dB (pan +0.00) |
| Arp | builtin:synth | preset "PL Pluck" (shorter amp decay 0.22 s) | 16th arpeggio behind a filter | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | +0.02 dB (pan +0.00) |
| Bell | builtin:synth | preset "PL Bell" | bell line / octave double | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | +0.49 dB (pan +0.00) |
| FX | builtin:fx | keys 48 impact, 50 riser, 52 reverse swell, 53 sub drop | transitions | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | +0.01 dB (pan +0.00) |

## cruise.ogg: Cruise

- **125 BPM, D dorian, 4/4, 64 bars**, a seamless loop: 122.88 s = **5419008 samples** at 44.1 kHz (bars x 4 x 60 / BPM x 44100 = 5419008; decoded Ogg 5419008, exact: yes). No lead-in: the first sample is the loop start.
- Ogg Vorbis q3, 1672941 bytes. Integrated **-14.1 LUFS**, true peak **-1.7 dBTP**, LRA **3.6 LU** (decoded file). L -16.31 / R -16.32 dBFS RMS (L minus R +0.01 dB), side -12.2 dB under mid, correlation 0.89.
- Loop seam (decoded Ogg played twice back to back): the step across the join is 0.0189 (L) / 0.0109 (R) against a typical local step of 0.0244 / 0.0303 (x0.78 / x0.36); the click energy of the 5 ms window on the join is 0.02x / 0.01x the loudest ordinary window within 1 s. Lossless 44.1 kHz source before encoding: x0.08 / x0.16.

| Section | Bars | Time | Chords | What plays | LUFS | TP | L minus R |
|---|---|---|---|---|---|---|---|
| Groove | 1-8 | 0:00.00-0:15.36 | Dm9 / G9 vamp | kick, offbeat bass, clap 2/4, offbeat hats, swung shaker, congas, dub stabs | -15.1 | -1.9 | +0.11 |
| Hook | 9-16 | 0:15.36-0:30.72 | Dm9 / G9 | + the hook (theme D E F A F E, call + answer) | -13.9 | -2.2 | -0.24 |
| Hook 2 | 17-24 | 0:30.72-0:46.08 | Dm9 / G9 | + open hats, 16th arp with its filter opening, fill in bar 24 | -13.7 | -1.8 | +0.15 |
| Lift | 25-32 | 0:46.08-1:01.44 | Fmaj7 G Am7 Dm9 | pad in, stabs and clap out, the theme climbs the chords in the low octave; bars 31-32 empty out (no bass, no kick in 32, clap roll, high-pass sweep) | -14.3 | -1.7 | -0.19 |
| Peak | 33-40 | 1:01.44-1:16.80 | Fmaj7 G Am7 Dm9 | crash + impact + sub drop, climbing theme an octave up, rolling 16th bass, ride, stabs, arp open | -12.8 | -2.0 | +0.02 |
| Break | 41-44 | 1:16.80-1:24.48 | Fmaj7 / G | kick and bass out: pad, bell theme, pluck echoes, claps | -17.8 | -5.8 | -0.06 |
| Build | 45-48 | 1:24.48-1:32.16 | Am7 / G | half-time kick (45-46), then 47-48 empty: clap roll, riser, drum and music high-pass sweeps | -16.9 | -4.3 | -0.08 |
| Return | 49-56 | 1:32.16-1:47.52 | Dm9 / G9 | crash + impact + sub drop, full groove, hook doubled an octave up by the bell | -12.8 | -1.7 | +0.05 |
| Cooldown | 57-64 | 1:47.52-2:02.88 | Dm9 / G9 | hook out, stabs + arp closing down, busier congas; small swell back into bar 1 | -14.7 | -2.0 | +0.26 |

| Track | Engine | Preset / patch | Role | Licence class | Alone: L minus R |
|---|---|---|---|---|---|
| Kick | builtin:synth | designed sine kick: sine + triangle (+1 oct, 30 ms) + noise click (4 ms), pitch envelope +30 st / 42 ms, then eq, saturate, soft clip | four-on-the-floor kick tuned A1 | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | +0.00 dB (pan +0.00) |
| Clap | builtin:sampler | MuseScore General bank 128 program 25 "TR-808", key 39 (hand clap) | clap on 2 and 4, rolls in builds | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | -0.01 dB (pan +0.00) |
| Hats | builtin:drums | keys 42 closed hat / 46 open hat | offbeat and 16th hats (air-heavy, little 2-5 kHz) | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | -0.01 dB (pan -0.18) |
| Cymbals | builtin:drums | key 49 crash, key 51 ride | crashes on section downbeats, ride in the peaks | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | -0.00 dB (pan +0.00) |
| Shaker | builtin:sampler | MuseScore General bank 128 program 0 "Standard", key 70 (maracas) | swung 16th shaker | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | -3.50 dB (pan +0.25) |
| Perc | builtin:sampler | MuseScore General bank 128 program 0 "Standard", keys 62/63/64 congas (+37 rim in hype) | conga / rim groove | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | +4.23 dB (pan -0.30) |
| Bass | Surge XT (VST3) | "Bass 2" by Bluelight (patches_3rdparty/Bluelight/Basses), transpose +12 | plucked offbeat / rolling bass | OPEN: Surge XT 1.3.4 patch (GPL-3.0-or-later distribution) | -0.03 dB (pan +0.00) |
| Stab | Surge XT (VST3) | "Gentle" by Cybersoda (patches_3rdparty/Cybersoda/Keys), width 0.55 | dub chord stabs through the echo | OPEN: Surge XT 1.3.4 patch (GPL-3.0-or-later distribution) | -0.72 dB (pan +0.00) |
| Pad | Surge XT (VST3) | "Juno-60 Strings" (patches_factory/Polysynths) | warm string pad | OPEN: Surge XT 1.3.4 patch (GPL-3.0-or-later distribution) | +0.05 dB (pan +0.00) |
| Hook | Surge XT (VST3) | "Friendly" (patches_factory/Plucks), transpose +12 | the hook and the climbing theme | OPEN: Surge XT 1.3.4 patch (GPL-3.0-or-later distribution) | +0.17 dB (pan +0.00) |
| Arp | builtin:synth | preset "PL Pluck" (shorter amp decay 0.22 s) | 16th arpeggio behind a filter | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | -0.00 dB (pan +0.00) |
| Bell | builtin:synth | preset "PL Bell" | bell line / octave double | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | +0.03 dB (pan +0.00) |
| FX | builtin:fx | keys 48 impact, 50 riser, 52 reverse swell, 53 sub drop | transitions | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | +0.00 dB (pan +0.00) |

## hype.ogg: Hype

- **131.25 BPM, E minor, 4/4, 64 bars**, a seamless loop: 117.028571 s = **5160960 samples** at 44.1 kHz (bars x 4 x 60 / BPM x 44100 = 5160960; decoded Ogg 5160960, exact: yes). No lead-in: the first sample is the loop start.
- Ogg Vorbis q3, 1577734 bytes. Integrated **-14.1 LUFS**, true peak **-1.8 dBTP**, LRA **3.3 LU** (decoded file). L -16.38 / R -16.37 dBFS RMS (L minus R -0.00 dB), side -11.6 dB under mid, correlation 0.87.
- Loop seam (decoded Ogg played twice back to back): the step across the join is 0.0001 (L) / 0.0284 (R) against a typical local step of 0.0220 / 0.0230 (x0.01 / x1.24); the click energy of the 5 ms window on the join is 0.17x / 0.18x the loudest ordinary window within 1 s. Lossless 44.1 kHz source before encoding: x0.35 / x0.37.

| Section | Bars | Time | Chords | What plays | LUFS | TP | L minus R |
|---|---|---|---|---|---|---|---|
| Drive | 1-8 | 0:00.00-0:14.63 | Em pedal | hard kick, rolling 16th bass with an E-D-B turn, clap, 16th hats, rim + conga, minor stabs | -14.8 | -2.8 | -0.08 |
| Arp | 9-16 | 0:14.63-0:29.26 | Em C G D | + 16th pluck arp with its filter opening, bass follows the chords | -14.6 | -2.0 | -0.09 |
| Theme | 17-24 | 0:29.26-0:43.89 | Em C G D | + saw lead with the theme (E F# G B G F#, call + answer), open hats | -13.9 | -2.1 | +0.07 |
| Theme 2 | 25-32 | 0:43.89-0:58.51 | Em C G D | + Juno pad, ride, the pluck doubles the lead an octave down, crash | -13.5 | -1.8 | +0.08 |
| Break | 33-36 | 0:58.51-1:05.83 | Cmaj7 D Bm7 Em | kick and bass out: pad, lead in long notes, pluck echoes | -17.2 | -6.1 | -0.26 |
| Build | 37-40 | 1:05.83-1:13.14 | C D C D | half-time kick (37-38), then 39-40 empty: clap roll, riser, high-pass sweeps | -16.6 | -3.8 | -0.38 |
| Peak | 41-56 | 1:13.14-1:42.40 | Em C G D | crash + impact + sub drop, everything, lead A/B/A/B, bell an octave up in the second half | -13.0 | -1.8 | +0.13 |
| Drive Out | 57-64 | 1:42.40-1:57.03 | Em pedal | lead and pad out, arp closing, stabs; bar 64 fill back into bar 1 | -14.5 | -2.2 | -0.24 |

| Track | Engine | Preset / patch | Role | Licence class | Alone: L minus R |
|---|---|---|---|---|---|
| Kick | builtin:synth | designed sine kick: sine + triangle (+1 oct, 30 ms) + noise click (4 ms), pitch envelope +30 st / 42 ms (+34 st / 38 ms here), then eq, saturate, soft clip | four-on-the-floor kick tuned B1, harder envelope and more saturation | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | +0.00 dB (pan +0.00) |
| Clap | builtin:sampler | MuseScore General bank 128 program 25 "TR-808", key 39 (hand clap) | clap on 2 and 4, rolls in builds | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | -0.01 dB (pan +0.00) |
| Hats | builtin:drums | keys 42 closed hat / 46 open hat | offbeat and 16th hats (air-heavy, little 2-5 kHz) | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | -0.01 dB (pan -0.18) |
| Cymbals | builtin:drums | key 49 crash, key 51 ride | crashes on section downbeats, ride in the peaks | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | -0.02 dB (pan +0.00) |
| Perc | builtin:sampler | MuseScore General bank 128 program 0 "Standard", keys 62/63/64 congas (+37 rim in hype) | conga / rim groove | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | +2.05 dB (pan -0.15) |
| Bass | Surge XT (VST3) | "Bass 2" by Bluelight (patches_3rdparty/Bluelight/Basses), transpose +12 | plucked offbeat / rolling bass | OPEN: Surge XT 1.3.4 patch (GPL-3.0-or-later distribution) | -0.04 dB (pan +0.00) |
| Stab | Surge XT (VST3) | "Gentle" by Cybersoda (patches_3rdparty/Cybersoda/Keys), width 0.55 | dub chord stabs through the echo | OPEN: Surge XT 1.3.4 patch (GPL-3.0-or-later distribution) | -0.72 dB (pan +0.00) |
| Pad | Surge XT (VST3) | "Juno-60 Strings" (patches_factory/Polysynths) | warm string pad | OPEN: Surge XT 1.3.4 patch (GPL-3.0-or-later distribution) | +0.05 dB (pan +0.00) |
| Hook | Surge XT (VST3) | "Friendly" (patches_factory/Plucks), transpose +12 | pluck doubling the lead an octave down, break echoes | OPEN: Surge XT 1.3.4 patch (GPL-3.0-or-later distribution) | +0.11 dB (pan +0.00) |
| Lead | Surge XT (VST3) | "Happy Saws" by Inigo Kennedy (patches_3rdparty/Inigo Kennedy/Leads) | saw lead carrying the theme | OPEN: Surge XT 1.3.4 patch (GPL-3.0-or-later distribution) | +0.34 dB (pan +0.00) |
| Arp | builtin:synth | preset "PL Pluck" (shorter amp decay 0.22 s) | 16th arpeggio behind a filter | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | -0.08 dB (pan +0.00) |
| Bell | builtin:synth | preset "PL Bell" | bell line / octave double | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | +0.12 dB (pan +0.00) |
| FX | builtin:fx | keys 48 impact, 50 riser, 52 reverse swell, 53 sub drop | transitions | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | +0.00 dB (pan +0.00) |

## results.ogg: Results

The theme (C D E G E D) over Fmaj7 -> G, landing on C major at 2.00 s (beat 4 at 120 BPM) with kick, crash and a soft impact; the chord rings and fades out by about 5 s.

- 120 BPM, C major, one-shot, 5.09 s (224469 samples), starts on its first sample (first sample above -50 dBFS: #1), ends in a fade to silence. Ogg Vorbis q3, 68257 bytes.
- Integrated **-12.1 LUFS**, true peak **-1.9 dBTP**, LRA 2.8 LU; L -14.91 / R -15.27 dBFS RMS (L minus R +0.37 dB).

| Track | Engine | Preset / patch | Role | Licence class | Alone: L minus R |
|---|---|---|---|---|---|
| Kick | builtin:synth | designed sine kick: sine + triangle (+1 oct, 30 ms) + noise click (4 ms), pitch envelope +30 st / 42 ms, then eq, saturate, soft clip | kick on each beat and the C downbeat | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | +0.00 dB (pan +0.00) |
| Clap | builtin:sampler | MuseScore General bank 128 program 25 "TR-808", key 39 (hand clap) | clap on 2 and 4, rolls in builds | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | -0.03 dB (pan +0.00) |
| Cymbals | builtin:drums | key 49 crash, key 51 ride | crash on the C downbeat | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | +0.01 dB (pan +0.00) |
| Bass | Surge XT (VST3) | "Bass 2" by Bluelight (patches_3rdparty/Bluelight/Basses), transpose +12 | plucked offbeat / rolling bass | OPEN: Surge XT 1.3.4 patch (GPL-3.0-or-later distribution) | +0.53 dB (pan +0.00) |
| Pad | Surge XT (VST3) | "Juno-60 Strings" (patches_factory/Polysynths) | warm string pad | OPEN: Surge XT 1.3.4 patch (GPL-3.0-or-later distribution) | -0.08 dB (pan +0.00) |
| Stab | Surge XT (VST3) | "Gentle" by Cybersoda (patches_3rdparty/Cybersoda/Keys), width 0.55 | dub chord stabs through the echo | OPEN: Surge XT 1.3.4 patch (GPL-3.0-or-later distribution) | -1.02 dB (pan +0.00) |
| Hook | Surge XT (VST3) | "Friendly" (patches_factory/Plucks), transpose +12 | the hook / theme pluck | OPEN: Surge XT 1.3.4 patch (GPL-3.0-or-later distribution) | +0.49 dB (pan +0.00) |
| Arp | builtin:synth | preset "PL Pluck" (shorter amp decay 0.22 s) | 16th arpeggio behind a filter | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | -0.06 dB (pan +0.00) |
| Bell | builtin:synth | preset "PL Bell" | bell line / octave double | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | +0.20 dB (pan +0.00) |
| FX | builtin:fx | keys 48 impact, 50 riser, 52 reverse swell, 53 sub drop | transitions | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | +0.00 dB (pan +0.00) |

## new_best.ogg: New Best

Starts 1.4 s into results (during its G chord): a G major run G4 B4 D5 G5 B5 (0.1 s apart) on the pluck and the arp with a reverse swell, landing 0.60 s in on C major (bell C6 E6 G6 C7, pluck, stab) exactly on results' C downbeat at 2.00 s. No kick or crash of its own (results has both on that beat). Fades by 3.0 s.

- 120 BPM, C major, one-shot, 2.50 s (110250 samples), starts on its first sample (first sample above -50 dBFS: #0), ends in a fade to silence. Ogg Vorbis q3, 36391 bytes.
- Integrated **-12.1 LUFS**, true peak **-1.8 dBTP**, LRA 0.0 LU; L -16.96 / R -17.06 dBFS RMS (L minus R +0.09 dB).

| Track | Engine | Preset / patch | Role | Licence class | Alone: L minus R |
|---|---|---|---|---|---|
| Stab | Surge XT (VST3) | "Gentle" by Cybersoda (patches_3rdparty/Cybersoda/Keys), width 0.55 | dub chord stabs through the echo | OPEN: Surge XT 1.3.4 patch (GPL-3.0-or-later distribution) | -0.60 dB (pan +0.00) |
| Hook | Surge XT (VST3) | "Friendly" (patches_factory/Plucks), transpose +12 | the hook / theme pluck | OPEN: Surge XT 1.3.4 patch (GPL-3.0-or-later distribution) | +0.17 dB (pan +0.00) |
| Arp | builtin:synth | preset "PL Pluck" (shorter amp decay 0.22 s) | 16th arpeggio behind a filter | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | +0.03 dB (pan +0.00) |
| Bell | builtin:synth | preset "PL Bell" | bell line / octave double | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | +0.07 dB (pan +0.00) |
| FX | builtin:fx | keys 48 impact, 50 riser, 52 reverse swell, 53 sub drop | transitions | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | -0.08 dB (pan +0.00) |

## Overlay check (results at -2 dB + new_best at 0 dB starting 1.4 s later, as event_world.gd plays them)

Measured on the two decoded files summed: integrated -11.2 LUFS, sample/true peak +2.7 dBFS at file level (the two landings stack on the C downbeat at 2.00 s); with new_best at -3 dB: -12.4 LUFS, +1.2 dBFS; at -6 dB: -13.1 LUFS, -0.1 dBFS. In the game the Music bus sits at -9 dB, so the sum reaches about -6.3 dBFS there and does not clip; play new_best at about -3 dB if it should not outshout results.

## Effects

All effects are Wavelength built-ins (OPEN, MIT): eq, filter, saturate, clip, duck (kick-keyed), width, compressor, reverb ("Room" 1.1 s, "Hall" 3.2 s), delay ("Echo", dotted 8th, not ping-pong) with chorus, limiter.

## Notices

**MuseScore General SoundFont** (MuseScore_General.sf3 v0.2, 13 May 2020), MIT licence. Its acknowledgements must be included in any derivative work: FluidR3 (original version) by Frank Wen, Copyright (c) 2000-02; mono conversion (FluidR3Mono) by Michael Cowgill, Copyright (c) 2014-17; adaptation for MuseScore_General.sf2 by S. Christian Collins, Copyright (c) 2018-19; Temple Blocks instrument by Ethan Winer, Copyright (c) 2002; Drumline Cymbals by Michael Schorsch, Copyright (c) 2016. Full text: `~/Library/Application Support/Wavelength/soundfonts/MuseScore_General_License.md`.

**Surge XT** (Surge Synth Team, GPL-3.0-or-later). Patches used: "Juno-60 Strings" and "Friendly" (factory patches), "Bass 2" by Bluelight, "Gentle" by Cybersoda and "Happy Saws" by Inigo Kennedy (third-party patches that ship with Surge XT). Credit the patch designers; whether rendered audio carries any obligation from the patch licence is the repository owner's call (crediting them is the safe answer).

**Wavelength** built-in synth, drum and FX engines: MIT, (c) 2026 Austin Ginder.
