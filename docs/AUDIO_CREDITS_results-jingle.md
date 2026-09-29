# Credits: "Session Complete" results jingle and "New Best" sting (Skate Park, one-shots)

Composition, arrangement and mix: Claude (Anthropic), working for Austin Ginder with Wavelength 0.5.0-dev (a headless music
engine, ~/Documents/wavelength). Both audio files were rendered offline from jobs (`make-job.py` -> `jingle.json` + `best.json`, in
`~/Documents/wavelength-songs/skate-park-results-jingle/`); nothing was recorded and no audio sample was imported. The melodic hook
in bar 2 of the jingle is the chorus hook cell of the sibling track "Grip Tape Summer" (same project, same author). No licence has
been chosen for the compositions themselves: that is the game repo's decision (every source below is OPEN, so any open licence
works, subject to the SoundFont notice at the end).

**Licence class of every sound: OPEN. No COMMERCIAL and no FREE-proprietary source (no third-party plugin, no Bitwig, Apple or
Native Instruments content) is used anywhere in these two files.**

## results-jingle.ogg / results-jingle.wav (14.5 s)

| Track | Engine | Sound | Class |
|---|---|---|---|
| Drums | `builtin:sampler` + MuseScore General SoundFont | bank 128, program 16, "Power" kit (keys 36 kick, 38 snare, 45/48 toms, 49 crash) | OPEN (MIT) |
| Bass | `builtin:sampler` + MuseScore General | bank 0, program 34, "Picked Bass" | OPEN (MIT) |
| Brass | `builtin:sampler` + MuseScore General | bank 0, program 61, "Brass Section" (transpose -0.075 semitone) | OPEN (MIT) |
| Lead | `builtin:sampler` + MuseScore General | bank 0, program 80, "Square Lead" | OPEN (MIT) |
| Marimba | `builtin:sampler` + MuseScore General | bank 0, program 12, "Marimba" | OPEN (MIT) |
| Glock | `builtin:sampler` + MuseScore General | bank 0, program 9, "Glockenspiel" (transpose -0.08 semitone) | OPEN (MIT) |
| FX | `builtin:fx` (Wavelength built-in) | key 52 reverse swell, key 48 impact | OPEN (Wavelength engine) |
| Bus and master | Wavelength built-in effects | `reverb` (Room), `eq` (with a +1.5 dB high shelf at 4.5 kHz), `compressor`, `clip`, `limiter` | OPEN (Wavelength engine) |

## new-best.ogg / new-best.wav (3.0 s)

| Track | Engine | Sound | Class |
|---|---|---|---|
| Chip | `builtin:synth` (Wavelength built-in synthesizer) | preset "LD Chip" | OPEN (Wavelength engine) |
| Glock, Brass, Bass, Lead | `builtin:sampler` + MuseScore General | programs 9 / 61 / 34 / 80 as above | OPEN (MIT) |
| Drums | `builtin:sampler` + MuseScore General | bank 128, program 16: kick 36 and crash 49 | OPEN (MIT) |
| Bus and master | Wavelength built-in effects | same chain as the jingle | OPEN (Wavelength engine) |

The brief's COMMERCIAL upgrade options (Bitwig "Acoustic Drums" and the Bitwig trumpet/horn ensemble) were not used. The `.ogg`
files were encoded with `oggenc` (Xiph vorbis-tools, `-q 5`), the `.wav` files with ffmpeg (16-bit, triangular dither) and the
preview `.mp3` with LAME; these are encoders and add no third-party content.

## SoundFont notice (must travel with the audio)

MuseScore_General.sf3 v0.2 (13 May 2020), from the MuseScore project, is shared under the MIT license. Its acknowledgements, as
shipped with it:

- FluidR3 (original version) by Frank Wen, Copyright (c) 2000-02
- Mono conversion (FluidR3Mono) by Michael Cowgill, Copyright (c) 2014-17
- Adaptation for MuseScore_General.sf2 by S. Christian Collins, Copyright (c) 2018-19
- Temple Blocks instrument provided by Ethan Winer, Copyright (c) 2002
- Drumline Cymbals provided by Michael Schorsch, Copyright (c) 2016

"The acknowledgements and copyright notices above must be included in any derivative work." The full licence text is in
`~/Library/Application Support/Wavelength/soundfonts/MuseScore_General_License.md`; copy it into the game repo's licences folder
(the same one as for "Grip Tape Summer" and "Boardwalk Morning"). Not verified: the upstream file
`MuseScore_General_Sample_Sources.csv` (per-instrument sample sources; it is not installed here) was not read, so I rely on the
SoundFont's own statement that the whole font is MIT. Whether rendered audio counts as a "derivative work" needing the notice is a
question for the repo's licence owner; including the notice is the safe answer.
