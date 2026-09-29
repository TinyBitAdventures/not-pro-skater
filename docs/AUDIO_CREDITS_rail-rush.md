# Credits: "Rail Rush" (Skate Park, high-energy loop for a later level / hype mode)

Composition, arrangement and mix: Claude (Anthropic), working for Austin Ginder with Wavelength 0.5.0-dev (a headless music
engine, ~/Documents/wavelength). The audio file was rendered offline from a job (`make-job.py` + `job.json`, in
`~/Documents/wavelength-songs/skate-park-rail-rush/`); nothing was recorded and no audio sample was imported. No licence has
been chosen for the composition itself: that is the game repo's decision (every source below is OPEN, so any open licence works,
subject to the SoundFont notice at the end).

**Licence class of every sound: OPEN. No COMMERCIAL and no FREE-proprietary source (no third-party plugin, no Bitwig, Apple or
Native Instruments content) is used anywhere in this track.**

| Track | Engine | Sound | Class |
|---|---|---|---|
| Drums | `builtin:sampler` + MuseScore General SoundFont | bank 128, program 16, "Power" kit (keys 36 kick, 38 snare, 42/46 hats, 45/48 toms, 49 crash, 51 ride) | OPEN (MIT) |
| Bass | `builtin:sampler` + MuseScore General | bank 0, program 34, "Picked Bass" | OPEN (MIT) |
| GuitarL | `builtin:sampler` + MuseScore General | bank 0, program 30, "Distortion Guitar" | OPEN (MIT) |
| GuitarR | `builtin:sampler` + MuseScore General | bank 0, program 29, "Overdrive Guitar" | OPEN (MIT) |
| Lead | `builtin:sampler` + MuseScore General | bank 0, program 80, "Square Lead" | OPEN (MIT) |
| Brass | `builtin:sampler` + MuseScore General | bank 0, program 61, "Brass Section" | OPEN (MIT) |
| Arp | `builtin:synth` (Wavelength built-in synthesizer) | preset "PL Chip Arp" | OPEN (Wavelength engine, MIT) |
| Chip | `builtin:synth` | preset "LD Chip" | OPEN (Wavelength engine, MIT) |
| FX | `builtin:fx` (Wavelength built-in) | keys 50 riser, 52 reverse swell, 48 impact | OPEN (Wavelength engine, MIT) |
| Buses and master | Wavelength built-in effects | `reverb` (Room), `delay` (Echo), `eq`, `filter`, `bitcrush`, `clip`, `compressor`, `limiter` | OPEN (Wavelength engine, MIT) |

Only the "OPEN sources" the brief lists were used. The brief's COMMERCIAL upgrade options (Bitwig kits and guitars, OB-Xf
"Possible Funk" bass, Surge XT "Gameboy Alias" lead, RP2A03 / PAPU chips) were not used. I did not audition other OPEN presets against
the brief's choices (no time budget for it), so no preset was replaced and none is claimed to be better.

The delivered `.ogg` was encoded with `oggenc` (Xiph vorbis-tools, `-q 5`, libvorbis) and the preview `.mp3` with LAME; these are
encoders and add no third-party content.

## SoundFont notice (must travel with the audio)

MuseScore_General.sf3 v0.2 (13 May 2020), from the MuseScore project, is shared under the MIT license. Its acknowledgements, as
shipped with it:

- FluidR3 (original version) by Frank Wen, Copyright (c) 2000-02
- Mono conversion (FluidR3Mono) by Michael Cowgill, Copyright (c) 2014-17
- Adaptation for MuseScore_General.sf2 by S. Christian Collins, Copyright (c) 2018-19
- Temple Blocks instrument provided by Ethan Winer, Copyright (c) 2002
- Drumline Cymbals provided by Michael Schorsch, Copyright (c) 2016

"The acknowledgements and copyright notices above must be included in any derivative work." The full licence text is in
`~/Library/Application Support/Wavelength/soundfonts/MuseScore_General_License.md`; copy it into the game repo's licences folder.
Not verified: the upstream file `MuseScore_General_Sample_Sources.csv` (per-instrument sample sources; it is not installed here)
was not read, so I rely on the SoundFont's own statement that the whole font is MIT. Whether rendered audio counts as a
"derivative work" needing the notice is a question for the repo's licence owner; including the notice is the safe answer.
