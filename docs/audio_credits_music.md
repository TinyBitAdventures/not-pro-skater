# Not Pro Skater: music credits

Composition, arrangement, mix and master: Claude (Anthropic, Claude Opus 5.5), for Austin Ginder, with Wavelength 0.5.0-dev (a headless music engine). Every file was rendered offline from a generated job: the generators are `~/Documents/wavelength-songs/not-pro-skaters-<slug>/make-job.py` (one folder per piece), the shared palette, delivery and measuring scripts are in `~/Documents/wavelength-songs/not-pro-skaters/tools/`. Nothing was recorded and no audio loop or sample pack was imported; the only samples are the MuseScore General SoundFont drum hits. **Nobody has listened to these files yet**: every statement about them below is a measurement.

The compositions and recordings were made for the game and are released with it under the repository's MIT licence (`license`). Every sound source is OPEN (no commercial or freeware-only plugin, preset or sample library); the MuseScore General SoundFont's acknowledgements are below.

Shared theme: every piece uses the same motif, scale degrees 1-2-3-5-3-2 on a 3+3+2 sixteenth rhythm (A B C E C B in the title, D E F A F E in cruise, E F# G B G F# in hype, C D E G E D in results, F G A C A G in Launch Day, G A Bb D Bb A in Record Release, A B C# E C# B in Rush Hour, Eb F G Bb G F in Between Takes).

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
| Bass | Surge XT (VST3) | "Bass 2" by Bluelight (patches_3rdparty/Bluelight/Basses), transpose +12 | plucked offbeat / rolling bass | OPEN: Surge XT 1.0.1 patch (GPL-3.0-or-later distribution) | +0.05 dB (pan +0.00) |
| Stab | Surge XT (VST3) | "Gentle" by Cybersoda (patches_3rdparty/Cybersoda/Keys), width 0.55 | dub chord stabs through the echo | OPEN: Surge XT 1.0.1 patch (GPL-3.0-or-later distribution) | -0.54 dB (pan +0.00) |
| Pad | Surge XT (VST3) | "Juno-60 Strings" (patches_factory/Polysynths) | warm string pad | OPEN: Surge XT 1.0.1 patch (GPL-3.0-or-later distribution) | +0.05 dB (pan +0.00) |
| Hook | Surge XT (VST3) | "Friendly" (patches_factory/Plucks), transpose +12 | the hook / theme pluck | OPEN: Surge XT 1.0.1 patch (GPL-3.0-or-later distribution) | +0.02 dB (pan +0.00) |
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
| Bass | Surge XT (VST3) | "Bass 2" by Bluelight (patches_3rdparty/Bluelight/Basses), transpose +12 | plucked offbeat / rolling bass | OPEN: Surge XT 1.0.1 patch (GPL-3.0-or-later distribution) | -0.03 dB (pan +0.00) |
| Stab | Surge XT (VST3) | "Gentle" by Cybersoda (patches_3rdparty/Cybersoda/Keys), width 0.55 | dub chord stabs through the echo | OPEN: Surge XT 1.0.1 patch (GPL-3.0-or-later distribution) | -0.72 dB (pan +0.00) |
| Pad | Surge XT (VST3) | "Juno-60 Strings" (patches_factory/Polysynths) | warm string pad | OPEN: Surge XT 1.0.1 patch (GPL-3.0-or-later distribution) | +0.05 dB (pan +0.00) |
| Hook | Surge XT (VST3) | "Friendly" (patches_factory/Plucks), transpose +12 | the hook and the climbing theme | OPEN: Surge XT 1.0.1 patch (GPL-3.0-or-later distribution) | +0.17 dB (pan +0.00) |
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
| Bass | Surge XT (VST3) | "Bass 2" by Bluelight (patches_3rdparty/Bluelight/Basses), transpose +12 | plucked offbeat / rolling bass | OPEN: Surge XT 1.0.1 patch (GPL-3.0-or-later distribution) | -0.04 dB (pan +0.00) |
| Stab | Surge XT (VST3) | "Gentle" by Cybersoda (patches_3rdparty/Cybersoda/Keys), width 0.55 | dub chord stabs through the echo | OPEN: Surge XT 1.0.1 patch (GPL-3.0-or-later distribution) | -0.72 dB (pan +0.00) |
| Pad | Surge XT (VST3) | "Juno-60 Strings" (patches_factory/Polysynths) | warm string pad | OPEN: Surge XT 1.0.1 patch (GPL-3.0-or-later distribution) | +0.05 dB (pan +0.00) |
| Hook | Surge XT (VST3) | "Friendly" (patches_factory/Plucks), transpose +12 | pluck doubling the lead an octave down, break echoes | OPEN: Surge XT 1.0.1 patch (GPL-3.0-or-later distribution) | +0.11 dB (pan +0.00) |
| Lead | Surge XT (VST3) | "Happy Saws" by Inigo Kennedy (patches_3rdparty/Inigo Kennedy/Leads) | saw lead carrying the theme | OPEN: Surge XT 1.0.1 patch (GPL-3.0-or-later distribution) | +0.34 dB (pan +0.00) |
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
| Bass | Surge XT (VST3) | "Bass 2" by Bluelight (patches_3rdparty/Bluelight/Basses), transpose +12 | plucked offbeat / rolling bass | OPEN: Surge XT 1.0.1 patch (GPL-3.0-or-later distribution) | +0.53 dB (pan +0.00) |
| Pad | Surge XT (VST3) | "Juno-60 Strings" (patches_factory/Polysynths) | warm string pad | OPEN: Surge XT 1.0.1 patch (GPL-3.0-or-later distribution) | -0.08 dB (pan +0.00) |
| Stab | Surge XT (VST3) | "Gentle" by Cybersoda (patches_3rdparty/Cybersoda/Keys), width 0.55 | dub chord stabs through the echo | OPEN: Surge XT 1.0.1 patch (GPL-3.0-or-later distribution) | -1.02 dB (pan +0.00) |
| Hook | Surge XT (VST3) | "Friendly" (patches_factory/Plucks), transpose +12 | the hook / theme pluck | OPEN: Surge XT 1.0.1 patch (GPL-3.0-or-later distribution) | +0.49 dB (pan +0.00) |
| Arp | builtin:synth | preset "PL Pluck" (shorter amp decay 0.22 s) | 16th arpeggio behind a filter | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | -0.06 dB (pan +0.00) |
| Bell | builtin:synth | preset "PL Bell" | bell line / octave double | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | +0.20 dB (pan +0.00) |
| FX | builtin:fx | keys 48 impact, 50 riser, 52 reverse swell, 53 sub drop | transitions | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | +0.00 dB (pan +0.00) |

## new_best.ogg: New Best

Starts 1.4 s into results (during its G chord): a G major run G4 B4 D5 G5 B5 (0.1 s apart) on the pluck and the arp with a reverse swell, landing 0.60 s in on C major (bell C6 E6 G6 C7, pluck, stab) exactly on results' C downbeat at 2.00 s. No kick or crash of its own (results has both on that beat). Fades by 3.0 s.

- 120 BPM, C major, one-shot, 2.50 s (110250 samples), starts on its first sample (first sample above -50 dBFS: #0), ends in a fade to silence. Ogg Vorbis q3, 36391 bytes.
- Integrated **-12.1 LUFS**, true peak **-1.8 dBTP**, LRA 0.0 LU; L -16.96 / R -17.06 dBFS RMS (L minus R +0.09 dB).

| Track | Engine | Preset / patch | Role | Licence class | Alone: L minus R |
|---|---|---|---|---|---|
| Stab | Surge XT (VST3) | "Gentle" by Cybersoda (patches_3rdparty/Cybersoda/Keys), width 0.55 | dub chord stabs through the echo | OPEN: Surge XT 1.0.1 patch (GPL-3.0-or-later distribution) | -0.60 dB (pan +0.00) |
| Hook | Surge XT (VST3) | "Friendly" (patches_factory/Plucks), transpose +12 | the hook / theme pluck | OPEN: Surge XT 1.0.1 patch (GPL-3.0-or-later distribution) | +0.17 dB (pan +0.00) |
| Arp | builtin:synth | preset "PL Pluck" (shorter amp decay 0.22 s) | 16th arpeggio behind a filter | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | +0.03 dB (pan +0.00) |
| Bell | builtin:synth | preset "PL Bell" | bell line / octave double | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | +0.07 dB (pan +0.00) |
| FX | builtin:fx | keys 48 impact, 50 riser, 52 reverse swell, 53 sub drop | transitions | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | -0.08 dB (pan +0.00) |

## launchday.ogg: Launch Day

- **112 BPM, F major, 4/4, 56 bars**, a seamless loop: 120 s = **5292000 samples** at 44.1 kHz (bars x 4 x 60 / BPM x 44100 = 5292000; decoded Ogg 5292000, exact: yes). No lead-in: the first sample is the loop start.
- Ogg Vorbis q3, 1559284 bytes. Integrated **-14.1 LUFS**, true peak **-1.6 dBTP**, LRA **2.8 LU** (decoded file). L -16.11 / R -16.10 dBFS RMS (L minus R -0.01 dB), side -12.8 dB under mid, correlation 0.90.
- Loop seam (decoded Ogg played twice back to back): the step across the join is 0.0152 (L) / 0.0002 (R) against a typical local step of 0.0263 / 0.0249 (x0.58 / x0.01); the click energy of the 5 ms window on the join is 0.13x / 0.12x the loudest ordinary window within 1 s. Lossless 44.1 kHz source before encoding: x0.27 / x0.73.

| Section | Bars | Time | Chords | What plays | LUFS | TP | L minus R |
|---|---|---|---|---|---|---|---|
| Boot | 1-8 | 0:00.00-0:17.14 | Fmaj7 Am7 Bbmaj7 C (1 bar each) | half-time groove (kick on 1 and the "and" of 2, gated snare on 3), sustained bass, Rhodes comping, 16th arp behind a closed filter, swung shaker, two chip blips, a bell ping | -15.1 | -2.5 | -0.04 |
| Commit | 9-16 | 0:17.14-0:34.29 | Fmaj7 Am7 Bbmaj7 C | four on the floor, gated snare + clap on 2/4, 8th octave bass, low pad, the hook on the PWM lead (theme F G A C A G, call + answer), soft crash; gated tom fill in bar 16 | -13.6 | -1.7 | +0.06 |
| Lift | 17-24 | 0:34.29-0:51.43 | Bbmaj7 C Dm7 F | pad up, the theme climbs the chords (from Bb, C, D, then F: itself) in the low octave, 16th hats; the second half of bar 24 drops kick and snare for a tom fill and a high-pass sweep | -14.1 | -1.9 | +0.03 |
| Ship It | 25-32 | 0:51.43-1:08.57 | Bbmaj7 C Dm7 F | crash + impact + sub drop, the climb an octave up, octave bass with 16th pickups, open hats, Rhodes on the offbeat 8ths, arp open | -13.1 | -2.0 | -0.02 |
| Fountain | 33-36 | 1:08.57-1:17.14 | Bbmaj7 Am7 Gm7 C | kick, bass and snare out: Rhodes, pad, the bell plays the theme in augmentation, chip blips, music bus low-passed to 2.4 kHz | -16.8 | -6.0 | +0.03 |
| Countdown | 37-40 | 1:17.14-1:25.71 | Bbmaj7 / C | half-time kick (37-38), theme fragments rising, then 39-40 empty: snare roll, Rhodes 8ths, riser, high-pass sweep, chip 3-2-1 | -15.8 | -3.3 | -0.09 |
| Launch | 41-48 | 1:25.71-1:42.86 | Fmaj7 Am7 Bbmaj7 C | crash + impact + sub drop, full groove, the hook doubled an octave up by the bell | -13.0 | -1.5 | +0.00 |
| Picnic | 49-56 | 1:42.86-2:00.00 | Fmaj7 Am7 Bbmaj7 C | hook out, pad low, arp closing; 53-56 back to the half-time groove, tom fill and a small swell back into bar 1 | -14.4 | -1.9 | -0.09 |

| Track | Engine | Preset / patch | Role | Licence class | Alone: L minus R |
|---|---|---|---|---|---|
| Kick | builtin:synth | designed sine kick: sine + triangle (+1 oct, 30 ms) + noise click (4 ms), pitch envelope +30 st / 42 ms, then eq, saturate, soft clip | kick tuned F1: four on the floor; half-time in the Boot, bars 37-38 and 53-56 | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | +0.00 dB (pan +0.00) |
| Snare | builtin:sampler | MuseScore General bank 128 program 24 "Electronic", key 38 (snare), into a 2.6 s room gated 230 ms after each hit | gated synthwave snare on 2 and 4 (on 3 in the half-time bars), roll in the Countdown | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | +0.10 dB (pan +0.00) |
| Clap | builtin:sampler | MuseScore General bank 128 program 25 "TR-808", key 39 (hand clap) | under the snare on the backbeats | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | -0.25 dB (pan +0.00) |
| Toms | builtin:sampler | MuseScore General bank 128 program 24 "Electronic", keys 50/47/43 (toms), own gated room | descending tom fills at phrase ends | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | +0.14 dB (pan +0.00) |
| Hats | builtin:drums | keys 42 closed hat / 46 open hat | 8th and 16th hats, open hats in Ship It and Launch (air-heavy, little 2-5 kHz) | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | -0.01 dB (pan -0.18) |
| Cymbals | builtin:drums | key 49 crash | crash on bars 9 (soft), 25 and 41 | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | +0.00 dB (pan +0.00) |
| Shaker | builtin:sampler | MuseScore General bank 128 program 0 "Standard", key 70 (maracas) | swung 16th shaker | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | +0.00 dB (pan +0.00) |
| Bass | Surge XT (VST3) | "Saw Lo-Fi" (patches_factory/Basses), transpose +12, low-pass 1 kHz | 8th octave bass, sustained roots in the half-time bars | OPEN: Surge XT 1.0.1 patch (GPL-3.0-or-later distribution) | +0.00 dB (pan +0.00) |
| Keys | Surge XT (VST3) | "Treated Rhodes" by Bluelight (patches_3rdparty/Bluelight/Keys), tape wow, light chorus | lo-fi Rhodes comping in every section | OPEN: Surge XT 1.0.1 patch (GPL-3.0-or-later distribution) | -0.13 dB (pan +0.03) |
| Pad | Surge XT (VST3) | "Another Warm" by Bluelight (patches_3rdparty/Bluelight/Pads), transpose +12, tape wow | warm pad ducked 7 dB by the kick (side-chain pump) | OPEN: Surge XT 1.0.1 patch (GPL-3.0-or-later distribution) | +0.03 dB (pan +0.00) |
| Lead | Surge XT (VST3) | "Crisp PWM" (patches_factory/Leads), transpose +12, low-passed at 4.2-4.5 kHz | the hook and the climbing theme, dotted-8th echo | OPEN: Surge XT 1.0.1 patch (GPL-3.0-or-later distribution) | +0.10 dB (pan +0.00) |
| Arp | builtin:synth | preset "PL Pluck" (shorter amp decay 0.22 s) | 16th arpeggio behind a filter, in every section | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | +0.01 dB (pan +0.00) |
| Bell | builtin:synth | preset "PL Bell" | the theme in augmentation (Fountain), octave double (Launch), a ping in the Boot | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | -0.22 dB (pan +0.04) |
| Chip | builtin:synth | preset "PL Chip Arp" (12.5% pulse), low-passed at 4 kHz | quiet terminal blips and the 3-2-1 countdown | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | -0.11 dB (pan +0.00) |
| FX | builtin:fx | keys 48 impact, 50 riser, 52 reverse swell, 53 sub drop | transitions | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | -0.00 dB (pan +0.00) |

Theme: F G A C A G (scale degrees 1-2-3-5-3-2 on the 3+3+2 sixteenth rhythm). Sound-effects band: the decoded file's 2-5 kHz RMS sits 25.0 dB under its full-band RMS (same ffmpeg measurement: cruise 24.7, hype 23.8, title 24.4). Master chain as on the other loops (high-pass 28 Hz, -1.5 dB at 3.3 kHz, +1 dB shelf at 9 kHz, glue compressor 1.8:1, soft clip, true-peak limiter -2.3 dB, -14 LUFS target), 16th swing 0.54 on the whole job.

Effects: all Wavelength built-ins (OPEN, MIT): eq, filter, saturate, clip, vibrato (tape wow), chorus, duck (kick-keyed), width, compressor, reverb ("Room" 1.1 s, "Hall" 3.2 s, two 2.6 s rooms behind a gate keyed by the snare and by the toms), delay ("Echo", dotted 8th, not ping-pong) with chorus, limiter.

Notices: **MuseScore General SoundFont** (MuseScore_General.sf3 v0.2), MIT licence, used for the snare, clap, toms and shaker: its acknowledgements (FluidR3 by Frank Wen, FluidR3Mono by Michael Cowgill, MuseScore_General adaptation by S. Christian Collins, Temple Blocks by Ethan Winer, Drumline Cymbals by Michael Schorsch) must travel with the game, as in the Notices section already there. **Surge XT** (Surge Synth Team, GPL-3.0-or-later): patches "Saw Lo-Fi" and "Crisp PWM" (factory) and "Treated Rhodes" and "Another Warm" by Bluelight (third-party patches that ship with Surge XT); credit the patch designers. The installed Surge XT is 1.0.1 (package receipts com.surge-synth-team.surge-xt.vst3.pkg and .resources.pkg, both 1.0.1). **Wavelength** built-in synth, drum and FX engines: MIT, (c) 2026 Austin Ginder.

## recordrelease.ogg: Record Release

- **94.5 BPM, G minor, 4/4, 48 bars**, a seamless loop: 121.904762 s = **5376000 samples** at 44.1 kHz (bars x 4 x 60 / BPM x 44100 = 5376000; decoded Ogg 5376000, exact: yes). No lead-in: the first sample is the loop start.
- Ogg Vorbis q3, 1738454 bytes. Integrated **-14.1 LUFS**, true peak **-1.3 dBTP**, LRA **3.5 LU** (decoded file). L -15.74 / R -15.81 dBFS RMS (L minus R +0.07 dB), side -15.4 dB under mid, correlation 0.94.
- Loop seam (decoded Ogg played twice back to back): the step across the join is 0.0088 (L) / 0.0029 (R) against a typical local step of 0.0399 / 0.0399 (x0.22 / x0.07); the click energy of the 5 ms window on the join is 0.34x / 0.34x the loudest ordinary window within 1 s. Lossless 44.1 kHz source before encoding: x1.45 / x1.44.

| Section | Bars | Time | Chords | What plays | LUFS | TP | L minus R |
|---|---|---|---|---|---|---|---|
| Load-In | 1-8 | 0:00.00-0:20.32 | Gm9 Ebmaj9 Cm9 F13 (a bar each) | boom-bap kick + sine boom, laid-back snare with ghost notes, swung 16th hats, fingered bass + sine sub, Rhodes comping, vinyl crackle; scratch fill in bar 8 | -14.8 | -1.6 | -0.10 |
| Van | 9-16 | 0:20.32-0:40.63 | Gm9 Ebmaj9 Cm9 F13 | + clav riff on the theme (G A Bb D Bb A, then C D Eb G Eb D), clap under the snare, open hats, horn stab answers in bars 12 and 16 | -13.8 | -1.3 | +0.16 |
| Lift | 17-24 | 0:40.63-1:00.95 | Cm9 F13 Bbmaj9 Ebmaj9 Cm9 F13 Ebmaj9 F13 | the Rhodes plays the theme climbing the chords, sax + trombone swell in long notes, tambourine on 2/4; bar 24: two kicks, a horn hit, scratches and a record stop on beat 4 | -14.3 | -1.8 | -0.10 |
| Stage | 25-32 | 1:00.95-1:21.27 | Gm9 Ebmaj9 Cm9 F13 | crash + impact + sub drop, the horn section plays the hook (theme on Gm9 and Cm9, stabs on Ebmaj9 and F13), clav comping, tambourine 16ths, scratch chirps | -13.0 | -1.5 | +0.17 |
| Alley | 33-36 | 1:21.27-1:31.43 | Gm9 / Ebmaj9 | break: kick, bass and horns out; Rhodes low-passed to 1.3 kHz, rim clicks, soft hats, louder crackle, scratch calls | -17.2 | -5.3 | +0.00 |
| Build | 37-40 | 1:31.43-1:41.59 | Cm9 / F13 | half-time kick and rim (37-38), then 39-40: snare roll, transformer scratches, horn swell, riser, music and drum high-pass sweeps | -15.8 | -2.1 | +0.17 |
| Merch | 41-44 | 1:41.59-1:51.75 | Gm9 Ebmaj9 Cm9 F13 | crash + impact + sub drop, the hook again, the trumpet falls off the bar 44 stab | -13.0 | -1.5 | +0.14 |
| Pack-Up | 45-48 | 1:51.75-2:01.91 | Gm9 Ebmaj9 Cm9 F13 | horns out: the clav theme on Gm9/Cm9 answered by the Rhodes on Ebmaj9/F13; scratch fill back into bar 1 | -14.0 | -1.9 | +0.10 |

| Track | Engine | Preset / patch | Role | Licence class | Alone: L minus R |
|---|---|---|---|---|---|
| Kick | builtin:sampler | MuseScore General bank 128 program 8 "Room", key 36 (bass drum); eq (+2 dB at 70 Hz), saturate, soft clip | boom-bap kick | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | +0.00 dB (pan +0.00) |
| Boom | builtin:synth | designed sine kick: sine, pitch envelope +22 st / 45 ms, 0.36 s decay, low-passed at 400 Hz, soft clip | sub layer under the kick, tuned G1 | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | +0.00 dB (pan +0.00) |
| Snare | builtin:sampler | MuseScore General bank 128 program 8 "Room", key 38 (snare) and key 37 (side stick) | snare on 2 and 4 laid back 12 ms, ghost notes, rolls; rim clicks in the alley and the build | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | -0.02 dB (pan +0.00) |
| Clap | builtin:sampler | MuseScore General bank 128 program 25 "TR-808", key 39 (hand clap) | clap layered under the snare | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | -0.01 dB (pan +0.00) |
| Hats | builtin:drums | keys 42 closed hat / 46 open hat | swung 16th hats (air-heavy, little 2-5 kHz) | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | -0.01 dB (pan -0.18) |
| Cymbals | builtin:drums | key 49 crash | crashes on bars 9, 25, 29 and 41 | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | +0.01 dB (pan +0.00) |
| Tamb | builtin:sampler | MuseScore General bank 128 program 0 "Standard", key 54 (tambourine), high-passed at 2.5 kHz | tambourine on 2 and 4 in the lift, 16ths on the stage and the merch run | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | -2.77 dB (pan +0.20) |
| Scratch | builtin:sampler | MuseScore General bank 128 program 0 "Standard", keys 29 "Scratch Push" / 30 "Scratch Pull" (GM2) | scratch fills (bars 8, 16, 24, 48), calls in the alley, transformer cuts in the build | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | -0.02 dB (pan +0.00) |
| Vinyl | builtin:synth | designed crackle: 4 ms noise ticks high-passed at 5.5 kHz, seeded random timing and level | vinyl crackle, louder at the loading dock and in the alley | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | +0.00 dB (pan +0.00) |
| Bass | builtin:sampler | MuseScore General program 33 "Fingered Bass"; saturate, compressor, light kick duck | the fat fingered bass line | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | +0.00 dB (pan +0.00) |
| Sub | builtin:synth | preset "BA Sub", low-passed at 110 Hz, ducked by the kick | sine sub under the bass roots | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | +0.00 dB (pan +0.00) |
| Keys | builtin:sampler | MuseScore General program 4 "Tine Electric Piano"; saturate, vibrato (tape wow), chorus, low-pass | Rhodes comping, the theme climbing the lift | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | +0.03 dB (pan +0.00) |
| Clav | builtin:sampler | MuseScore General program 7 "Clavinet" through the autowah | clav riff on the theme, funk comping | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | +1.63 dB (pan -0.12) |
| Trumpet | builtin:sampler | MuseScore General program 56 "Trumpet" | horn section top: the hook, stabs, the bar 44 fall-off | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | +3.30 dB (pan -0.25) |
| Sax | builtin:sampler | MuseScore General program 66 "Tenor Sax" | horn section middle (chord tones under the hook), lift swells | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | -3.14 dB (pan +0.25) |
| Trombone | builtin:sampler | MuseScore General program 57 "Trombone" | horn section bottom (an octave under the trumpet), lift swells | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | +0.19 dB (pan +0.00) |
| FX | builtin:fx | keys 48 impact, 50 riser, 52 reverse swell, 53 sub drop | transitions | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | +0.00 dB (pan +0.00) |

Theme: G A Bb D Bb A (the soundtrack motif, scale degrees 1-2-3-5-3-2 on a 3+3+2 sixteenth rhythm), sequenced on each chord of the loop inside G minor (Eb F G Bb G F, C D Eb G Eb D, F G A C A G, Bb C D F D C). 16th swing 0.58 on every part. Master chain as the other loops (eq: high-pass 28 Hz, -1.5 dB at 3.3 kHz, +1 dB shelf at 9 kHz; glue compressor 1.8:1, soft clip, true-peak limiter -2.3 dB, -14 LUFS), with a tapestop in front of it for the record stop at the end of bar 24. LFO rates (Rhodes vibrato and chorus, the echo's chorus) are set to a whole number of cycles per loop so the passes line up; the vinyl crackle is the only part that differs from pass to pass (free-running noise), which the 10 ms crossfade at the loop point covers.

Effects: Wavelength built-ins only (OPEN, MIT): eq, filter, saturate, clip, compressor, duck (kick-keyed), width, vibrato, chorus, autowah, reverb ("Room" 1.1 s, "Hall" 3.2 s), delay ("Echo", dotted 8th, not ping-pong) with chorus, tapestop, limiter.

### Notices

**MuseScore General SoundFont** (MuseScore_General.sf3 v0.2, 13 May 2020), MIT licence: every sampled sound in this piece (drums, scratches, fingered bass, tine electric piano, clavinet, trumpet, tenor sax, trombone). Its acknowledgements must be included in any derivative work: FluidR3 (original version) by Frank Wen, Copyright (c) 2000-02; mono conversion (FluidR3Mono) by Michael Cowgill, Copyright (c) 2014-17; adaptation for MuseScore_General.sf2 by S. Christian Collins, Copyright (c) 2018-19; Temple Blocks instrument by Ethan Winer, Copyright (c) 2002; Drumline Cymbals by Michael Schorsch, Copyright (c) 2016. Full text: `~/Library/Application Support/Wavelength/soundfonts/MuseScore_General_License.md`. (Already in the Notices of audio_credits_music.md.)

**Wavelength** built-in synth, drum and FX engines: MIT, (c) 2026 Austin Ginder. No Surge XT patch, commercial plugin or sample pack is used in this piece.

## rushhour.ogg: Rush Hour

- **126 BPM, A major, 4/4, 64 bars**, a seamless loop: 121.904762 s = **5376000 samples** at 44.1 kHz (bars x 4 x 60 / BPM x 44100 = 5376000; decoded Ogg 5376000, exact: yes). No lead-in: the first sample is the loop start.
- Ogg Vorbis q3, 1632808 bytes. Integrated **-14.1 LUFS**, true peak **-1.7 dBTP**, LRA **3.3 LU** (decoded file). L -16.07 / R -16.01 dBFS RMS (L minus R -0.06 dB), side -15.8 dB under mid, correlation 0.95.
- Loop seam (decoded Ogg played twice back to back): the step across the join is 0.0102 (L) / 0.0250 (R) against a typical local step of 0.0317 / 0.0322 (x0.32 / x0.78); the click energy of the 5 ms window on the join is 0.02x / 0.03x the loudest ordinary window within 1 s. Lossless 44.1 kHz source before encoding: x0.10 / x0.26.

| Section | Bars | Time | Chords | What plays | LUFS | TP | L minus R |
|---|---|---|---|---|---|---|---|
| Doors | 1-8 | 0:00.00-0:15.24 | A E F#m7 D (1 bar each) | kick, offbeat organ bass, clap 2/4, offbeat closed hats, shaker, the wood-block tick-tock; piano stabs from bar 5 | -15.6 | -2.3 | -0.04 |
| Market | 9-16 | 0:15.24-0:30.48 | A E F#m7 D | + house piano on the 3+3+2 accents, congas, open hats on the offbeat, syncopated bass with octave pops, soft crash | -14.5 | -2.3 | -0.01 |
| Hook | 17-24 | 0:30.48-0:45.71 | A E F#m7 D | + the hook on the square pluck (theme A B C# E C# B, call + answer), 16th arp with its filter opening | -13.6 | -1.7 | -0.09 |
| Rail | 25-32 | 0:45.71-1:00.95 | Bm7 D E A | pad in, clap out, the theme climbs the chords (from B, D, E, then A: itself) in the low octave; bars 31-32 empty out (no bass, no kick in 32, clap roll, high-pass sweep) | -14.7 | -2.0 | -0.05 |
| One Take | 33-40 | 1:00.95-1:16.19 | Bm7 D E A | crash + impact + sub drop, the climb an octave up doubled by the sync lead, rolling 16th bass, ride, arp open | -12.6 | -2.0 | -0.06 |
| Subway | 41-44 | 1:16.19-1:23.81 | F#m7 Dmaj7 Bm7 E | kick and bass out: pad, piano, the bell plays the theme in augmentation, hook echoes, the tick, music bus low-passed to 2.6 kHz | -17.1 | -3.8 | -0.12 |
| Clock | 45-48 | 1:23.81-1:31.43 | Dmaj7 / E | half-time kick (45-46), theme fragments rising, then 47-48 empty: clap roll, tick 8ths -> 16ths, piano 8ths, riser, drum and music high-pass sweeps | -15.3 | -2.6 | +0.08 |
| Return | 49-56 | 1:31.43-1:46.67 | A E F#m7 D | crash + impact + sub drop, full groove, hook doubled an octave up by the bell, the sync lead holding its long tones | -12.7 | -1.8 | -0.10 |
| Last Lap | 57-64 | 1:46.67-2:01.91 | A E F#m7 D | hook and lead out, piano + arp closing, busier congas, the tick back from bar 61; bar 64 fill and a small swell back into bar 1 | -14.4 | -2.0 | -0.08 |

| Track | Engine | Preset / patch | Role | Licence class | Alone: L minus R |
|---|---|---|---|---|---|
| Kick | builtin:synth | designed sine kick: sine + triangle (+1 oct, 30 ms) + noise click (4 ms), pitch envelope +34 st / 38 ms, then eq, saturate, soft clip | four-on-the-floor kick tuned A1, harder envelope and more saturation (as in hype) | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | +0.00 dB (pan +0.00) |
| Clap | builtin:sampler | MuseScore General bank 128 program 25 "TR-808", key 39 (hand clap) | clap on 2 and 4, rolls in builds | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | -0.02 dB (pan +0.00) |
| Hats | builtin:drums | keys 42 closed hat / 46 open hat | offbeat hats (open in Market, Hook, One Take, Return, Last Lap) and 16ths (air-heavy, little 2-5 kHz) | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | -0.01 dB (pan -0.18) |
| Cymbals | builtin:drums | key 49 crash, key 51 ride | crashes on bars 9, 17 (soft), 33 and 49, ride in the One Take | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | -0.02 dB (pan +0.00) |
| Shaker | builtin:sampler | MuseScore General bank 128 program 0 "Standard", key 70 (maracas) | 16th shaker | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | +0.00 dB (pan +0.00) |
| Perc | builtin:sampler | MuseScore General bank 128 program 0 "Standard", keys 62/63/64 congas | conga groove (the market) | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | +0.00 dB (pan +0.00) |
| Tick | builtin:sampler | MuseScore General bank 128 program 0 "Standard", keys 76/77 (high / low wood block) | the clock: tick-tock 8ths, 16ths in the build | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | +0.00 dB (pan +0.00) |
| Bass | Surge XT (VST3) | "House Organ" (patches_factory/Keys), transpose +24, compressor + soft clip | 90s house organ bass: offbeats, octave pops, rolling 16ths in the peaks | OPEN: Surge XT 1.0.1 patch (GPL-3.0-or-later distribution) | -0.25 dB (pan +0.00) |
| Piano | Surge XT (VST3) | "Like Piano" by Damon Armani (patches_3rdparty/Damon Armani/Plucks) | house piano stabs on the 3+3+2 accents | OPEN: Surge XT 1.0.1 patch (GPL-3.0-or-later distribution) | +0.12 dB (pan -0.05) |
| Pad | Surge XT (VST3) | "Juno-60 Strings" (patches_factory/Polysynths) | warm string pad (Rail, One Take, Subway, Clock) | OPEN: Surge XT 1.0.1 patch (GPL-3.0-or-later distribution) | +0.01 dB (pan +0.00) |
| Hook | Surge XT (VST3) | "Square Pop" (patches_factory/Plucks), transpose +12 | the hook and the climbing theme | OPEN: Surge XT 1.0.1 patch (GPL-3.0-or-later distribution) | -0.05 dB (pan -0.01) |
| Lead | Surge XT (VST3) | "Sync Lead" (patches_factory/Leads), transpose +12, low-passed at 3.4-3.6 kHz | doubles the climb in the One Take, long tones over the Return | OPEN: Surge XT 1.0.1 patch (GPL-3.0-or-later distribution) | -0.01 dB (pan +0.00) |
| Arp | builtin:synth | preset "PL Pluck" (shorter amp decay 0.22 s) | 16th arpeggio behind a filter | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | -0.02 dB (pan +0.00) |
| Bell | builtin:synth | preset "PL Bell" | the theme in augmentation (Subway), octave double (Return) | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | -0.03 dB (pan -0.03) |
| FX | builtin:fx | keys 48 impact, 50 riser, 52 reverse swell, 53 sub drop | transitions | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | +0.00 dB (pan +0.00) |

Theme: A B C# E C# B (scale degrees 1-2-3-5-3-2 on the 3+3+2 sixteenth rhythm); the piano comps on the same 3+3+2 accents. Sound-effects band: the decoded file's 2-5 kHz RMS sits 24.7 dB under its full-band RMS (same ffmpeg measurement: cruise 24.7, hype 23.8, title 24.4, launchday 25.0). Master chain as on the other loops (high-pass 28 Hz, -1.5 dB at 3.3 kHz, +1 dB shelf at 9 kHz, glue compressor 1.8:1, soft clip, true-peak limiter -2.3 dB, -14 LUFS target), 16th swing 0.53 on the whole job.

Effects: all Wavelength built-ins (OPEN, MIT): eq, filter, compressor, saturate, clip, duck (kick-keyed), width, reverb ("Room" 1.1 s, "Hall" 3.2 s), delay ("Echo", dotted 8th, not ping-pong) with chorus, limiter.

Notices: **MuseScore General SoundFont** (MuseScore_General.sf3 v0.2), MIT licence, used for the clap, shaker, congas and wood blocks: its acknowledgements (FluidR3 by Frank Wen, FluidR3Mono by Michael Cowgill, MuseScore_General adaptation by S. Christian Collins, Temple Blocks by Ethan Winer, Drumline Cymbals by Michael Schorsch) must travel with the game, as in the Notices section already there. **Surge XT** (Surge Synth Team, GPL-3.0-or-later): patches "House Organ", "Juno-60 Strings", "Square Pop" and "Sync Lead" (factory) and "Like Piano" by Damon Armani (a third-party patch that ships with Surge XT); credit the patch designers. The installed Surge XT is 1.0.1 (package receipts com.surge-synth-team.surge-xt.vst3.pkg and .resources.pkg, both 1.0.1). **Wavelength** built-in synth, drum and FX engines: MIT, (c) 2026 Austin Ginder.

## betweentakes.ogg: Between Takes

- **108 BPM, Eb major, 4/4, 56 bars**, a seamless loop: 124.444444 s = **5488000 samples** at 44.1 kHz (bars x 4 x 60 / BPM x 44100 = 5488000; decoded Ogg 5488000, exact: yes). No lead-in: the first sample is the loop start.
- Ogg Vorbis q3, 1622017 bytes. Integrated **-14.1 LUFS**, true peak **-1.6 dBTP**, LRA **3.7 LU** (decoded file). L -16.01 / R -16.02 dBFS RMS (L minus R +0.01 dB), side -12.2 dB under mid, correlation 0.89.
- Loop seam (decoded Ogg played twice back to back): the step across the join is 0.0080 (L) / 0.0142 (R) against a typical local step of 0.0700 / 0.0702 (x0.12 / x0.20); the click energy of the 5 ms window on the join is 0.67x / 0.67x the loudest ordinary window within 1 s. Lossless 44.1 kHz source before encoding: x0.01 / x0.11.

| Section | Bars | Time | Chords | What plays | LUFS | TP | L minus R |
|---|---|---|---|---|---|---|---|
| Call Sheet | 1-8 | 0:00.00-0:17.78 | Eb Ab Eb Bb Eb Ab Fm7 Bb7 | pizzicato oom-pah (basses + violins), staccato bassoon, kick on 1 and 3, clap 2/4, offbeat hats; the motif hinted on pizzicato violins in bars 5 and 7, tuba from bar 5 | -15.6 | -2.2 | +0.04 |
| Western | 9-16 | 0:17.78-0:35.56 | Eb Bb Ab Eb Eb Bb Ab Bb | [western street] galloping celli, four-on-the-floor, timpani, the theme whistled (Eb F G Bb G F ...), horn fifths, a bugle call in bar 16 | -13.8 | -1.8 | -0.16 |
| New York | 17-24 | 0:35.56-0:53.33 | Fm7 Bb7 Ebmaj7 Cm7 x2 | [New York street] walking pizzicato bass, muted trumpet calls the motif, clarinet answers, Charleston pizzicato comping; clarinet run, trombone glissando and harp into the stunt | -14.6 | -2.2 | +0.36 |
| Stunt | 25-32 | 0:53.33-1:11.11 | Eb Bb/D Cm Ab Eb Bb Ab Bb | [the big quarter pipe] cymbals + bass drum + impact + sub drop; tutti: horns play the theme, driving 16th celli, pizzicato basses, tuba, brass stabs, timpani, taiko, string pad, full beat | -12.7 | -1.7 | -0.18 |
| Green Screen | 33-36 | 1:11.11-1:20.00 | Abmaj7 Gm7 Fm7 Bbsus4 | break: beat out, string pad, harp arpeggios, celesta motif, triangle; soft timpani roll in bar 36 | -17.4 | -5.0 | -0.11 |
| Chalk Marks | 37-40 | 1:20.00-1:28.89 | Ab Ab Bb Bb | tutti hits on six marks with wood-block ticks between them (37-38), then snare and timpani rolls, celli climbing two octaves, horn and string swell, riser, harp glissando and the slate clap | -15.4 | -1.9 | -0.17 |
| Action! | 41-48 | 1:28.89-1:46.67 | Eb Bb/D Cm Ab Eb Bb Ab Bb | cymbals + bass drum + impact + sub drop; the theme on horns with violins an octave up, everything | -12.3 | -1.6 | +0.03 |
| Wrap | 49-56 | 1:46.67-2:04.44 | Eb Ab Eb Bb Eb Ab Fm7 Bb7 | back to the pizzicato groove and bassoon; the clarinet hums the motif, the horns once; pizzicato run back into bar 1 | -15.2 | -2.0 | +0.24 |

| Track | Engine | Preset / patch | Role | Licence class | Alone: L minus R |
|---|---|---|---|---|---|
| Kick | builtin:synth | designed sine kick: sine + triangle (+1 oct, 30 ms) + noise click (4 ms), pitch envelope +30 st / 42 ms, then eq, saturate, soft clip | the modern beat: kick tuned Bb1 (1 and 3, four-on-the-floor in the western and the tutti) | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | +0.00 dB (pan +0.00) |
| Clap | builtin:sampler | MuseScore General bank 128 program 25 "TR-808", key 39 (hand clap) | clap on 2 and 4 | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | -0.01 dB (pan +0.00) |
| Hats | builtin:drums | keys 42 closed hat / 46 open hat | offbeat and 16th hats (air-heavy, little 2-5 kHz) | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | -0.01 dB (pan -0.18) |
| Timpani | builtin:sampler | MuseScore General program 47 "Timpani" | downbeats, fills, rolls into the chalk marks and the action | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | -0.67 dB (pan +0.05) |
| Taiko | builtin:sampler | MuseScore General program 116 "Taiko Drum", high-passed at 50 Hz | hybrid hits in the tutti and on the chalk marks | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | -0.05 dB (pan +0.00) |
| Perc | builtin:sampler | MuseScore General bank 128 program 48 "Orchestra Kit": key 36 concert bass drum, 38 concert snare, 57 cymbals | concert cymbals and bass drum on the downbeats, the snare roll in the build | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | +0.15 dB (pan +0.00) |
| Tick | builtin:sampler | MuseScore General bank 128 program 0 "Standard": keys 76/77 wood blocks, 81 open triangle | the director's count between the marks, the slate clap before "Action!", triangle pings | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | -0.00 dB (pan +0.00) |
| BassPizz | builtin:sampler | MuseScore General bank 50 program 45 "Basses Pizzicato", light kick duck | oom-pah, walking and driving pizzicato bass | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | -0.58 dB (pan +0.00) |
| VlnPizz | builtin:sampler | MuseScore General bank 20 program 45 "Violins Pizzicato" | offbeat and Charleston chords, the motif hints, the run into bar 1 | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | +2.59 dB (pan -0.20) |
| LowStr | builtin:sampler | MuseScore General bank 40 program 48 "Celli Fast" | the western gallop, driving 16ths in the tutti, the climb in the build | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | -2.06 dB (pan +0.12) |
| StrPad | builtin:sampler | MuseScore General program 49 "Strings Slow" | sustained strings under the tutti, the green-screen pad, the build swell | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | +0.63 dB (pan -0.05) |
| VlnLegato | builtin:sampler | MuseScore General bank 20 program 49 "Violins Slow" | the theme an octave over the horns in "Action!" | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | +3.13 dB (pan -0.20) |
| Horns | builtin:sampler | MuseScore General program 60 "French Horns" | the theme (stunt and action), western fifths, marks and swell | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | +1.37 dB (pan -0.12) |
| Trumpet | builtin:sampler | MuseScore General program 56 "Trumpet" | brass stabs between the theme phrases, the bugle call in bar 16 | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | -2.27 dB (pan +0.18) |
| Trombone | builtin:sampler | MuseScore General program 57 "Trombone" | brass stabs, the glissando into the stunt | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | -2.75 dB (pan +0.20) |
| Tuba | builtin:sampler | MuseScore General program 58 "Tuba" | roots in the tutti, oom in the call sheet | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | -1.37 dB (pan +0.10) |
| MuteTpt | builtin:sampler | MuseScore General program 59 "Harmon Mute Trumpet", dipped 8 dB at 3 kHz | calls the motif on the New York street | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | +2.24 dB (pan -0.15) |
| Bassoon | builtin:sampler | MuseScore General program 70 "Bassoon" | staccato oom-pah line in the call sheet and the wrap | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | -1.72 dB (pan +0.12) |
| Clarinet | builtin:sampler | MuseScore General program 71 "Clarinet", dipped 7 dB at 3 kHz | answers on the New York street, hums the theme in the wrap | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | +1.98 dB (pan -0.12) |
| Whistle | builtin:sampler | MuseScore General program 78 "Whistle" | whistles the theme on the western street | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | +0.05 dB (pan +0.00) |
| Celesta | builtin:sampler | MuseScore General program 8 "Celesta" | the motif over the green screen | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | -1.79 dB (pan +0.15) |
| Harp | builtin:sampler | MuseScore General program 46 "Harp" | green-screen arpeggios, glissandos into the stunt and the action | OPEN: MuseScore General SoundFont 0.2 (MIT; notice below must travel with it) | +2.34 dB (pan -0.20) |
| FX | builtin:fx | keys 48 impact, 50 riser, 52 reverse swell, 53 sub drop | transitions | OPEN: Wavelength built-in (MIT, (c) 2026 Austin Ginder); synthesized, no samples | +0.00 dB (pan +0.00) |

Theme: Eb F G Bb G F (the soundtrack motif, scale degrees 1-2-3-5-3-2 on a 3+3+2 sixteenth rhythm), carried by the French horns (A: Eb | Bb/D | Cm | Ab, the motif on Eb and on C minor with a falling answer; B: Eb | Bb | Ab | Bb, rising to D5 and falling back); whistled in the western street, called by the muted trumpet in New York, on celesta over the green screen. Every note is inside Eb major (checked with a scan of the job as well as `lint --harmony`). Straight 16ths. Master chain as the other loops (eq: high-pass 28 Hz, -1.5 dB at 3.3 kHz, +1 dB shelf at 9 kHz; glue compressor 1.8:1, soft clip, true-peak limiter -2.3 dB, -14 LUFS). The orchestra is played clean (an "Orch" bus with a 1.5:1 compressor only); the beat is a separate layer.

Effects: Wavelength built-ins only (OPEN, MIT): eq, filter, saturate, clip, compressor, duck (kick-keyed, 2-3 dB on the pizzicato bass and tuba), width, reverb ("Room" 1.1 s, "Hall" 3.2 s), delay ("Echo", dotted 8th, not ping-pong) with chorus (its rate set to a whole number of cycles per loop), limiter.

### Notices

**MuseScore General SoundFont** (MuseScore_General.sf3 v0.2, 13 May 2020), MIT licence: the whole orchestra, the percussion and the clap in this piece. Its acknowledgements must be included in any derivative work: FluidR3 (original version) by Frank Wen, Copyright (c) 2000-02; mono conversion (FluidR3Mono) by Michael Cowgill, Copyright (c) 2014-17; adaptation for MuseScore_General.sf2 by S. Christian Collins, Copyright (c) 2018-19; Temple Blocks instrument by Ethan Winer, Copyright (c) 2002; Drumline Cymbals by Michael Schorsch, Copyright (c) 2016. Full text: `~/Library/Application Support/Wavelength/soundfonts/MuseScore_General_License.md`. (Already in the Notices of audio_credits_music.md.)

**Wavelength** built-in synth, drum and FX engines: MIT, (c) 2026 Austin Ginder. No Surge XT patch, commercial plugin or sample pack is used in this piece.

## Overlay check (results at -2 dB + new_best at 0 dB starting 1.4 s later, as event_world.gd plays them)

Measured on the two decoded files summed: integrated -11.2 LUFS, sample/true peak +2.7 dBFS at file level (the two landings stack on the C downbeat at 2.00 s); with new_best at -3 dB: -12.4 LUFS, +1.2 dBFS; at -6 dB: -13.1 LUFS, -0.1 dBFS. In the game the Music bus sits at -9 dB, so the sum reaches about -6.3 dBFS there and does not clip; play new_best at about -3 dB if it should not outshout results.

## Effects

All effects are Wavelength built-ins (OPEN, MIT): eq, filter, saturate, clip, duck (kick-keyed), width, compressor, reverb ("Room" 1.1 s, "Hall" 3.2 s), delay ("Echo", dotted 8th, not ping-pong) with chorus, limiter.

## Notices

**MuseScore General SoundFont** (MuseScore_General.sf3 v0.2, 13 May 2020), MIT licence. Its acknowledgements must be included in any derivative work: FluidR3 (original version) by Frank Wen, Copyright (c) 2000-02; mono conversion (FluidR3Mono) by Michael Cowgill, Copyright (c) 2014-17; adaptation for MuseScore_General.sf2 by S. Christian Collins, Copyright (c) 2018-19; Temple Blocks instrument by Ethan Winer, Copyright (c) 2002; Drumline Cymbals by Michael Schorsch, Copyright (c) 2016. Full text: `~/Library/Application Support/Wavelength/soundfonts/MuseScore_General_License.md`.

**Surge XT** (Surge Synth Team, GPL-3.0-or-later). Patches used: "Juno-60 Strings", "Friendly", "Saw Lo-Fi", "Crisp PWM", "House Organ", "Square Pop" and "Sync Lead" (factory patches), "Bass 2", "Treated Rhodes" and "Another Warm" by Bluelight, "Gentle" by Cybersoda, "Happy Saws" by Inigo Kennedy and "Like Piano" by Damon Armani (third-party patches that ship with Surge XT 1.0.1, the version installed when every piece was rendered). Credit the patch designers; whether rendered audio carries any obligation from the patch licence is the repository owner's call (crediting them is the safe answer).

**Wavelength** built-in synth, drum and FX engines: MIT, (c) 2026 Austin Ginder.
