# Credits: Boardwalk Morning (Skate Park title / menu theme)

**Every sound source in this track is OPEN (permissively licensed). No COMMERCIAL or FREE-proprietary instrument, sample or plugin was used.**

Composition, arrangement, programming, mix and master: Claude (Anthropic, Sonnet 5.5) for Austin Ginder, rendered offline with Wavelength 0.5.0-dev
(MIT, Copyright (c) 2026 Austin Ginder). The composition's own licence is the game owner's to set; the sound sources below impose only the notice at the end of this file.

| Part | Source | Preset / program | Licence class |
|---|---|---|---|
| Drums (kick, rim-click, hats, crash, one soft snare) | `builtin:sampler` + MuseScore General SoundFont v0.2 | bank 128, program 8 ("Room" kit) | OPEN, MIT |
| Bass | `builtin:sampler` + MuseScore General | bank 0, program 33 "Fingered Bass" | OPEN, MIT |
| Ukulele | `builtin:sampler` + MuseScore General | bank 8, program 24 "Ukulele" | OPEN, MIT |
| Electric piano | `builtin:sampler` + MuseScore General | bank 0, program 4 "Tine Electric Piano" | OPEN, MIT |
| Pad | `builtin:sampler` + MuseScore General | bank 0, program 89 "Warm Pad" | OPEN, MIT |
| Marimba | `builtin:sampler` + MuseScore General | bank 0, program 12 "Marimba" | OPEN, MIT |
| Whistle (the hook) | `builtin:sampler` + MuseScore General | bank 0, program 78 "Whistle" (tuned -0.14 semitone) | OPEN, MIT |
| Glockenspiel sparkles | `builtin:sampler` + MuseScore General | bank 0, program 9 "Glockenspiel" | OPEN, MIT |
| Transitions (reverse swell, soft impact) | Wavelength `builtin:fx` (synthesised in the engine, no samples) | keys 52 and 48 | OPEN, MIT (Wavelength) |
| Reverb ("Room" bus), delay ("Echo" bus), EQ, filter, tremolo, compressor, soft clip, limiter | Wavelength built-in DSP | no plugins | OPEN, MIT (Wavelength) |

Delivery tools (not part of the audio): ffmpeg (resampling, measurement), oggenc / libvorbis 1.3.7 (Xiph.Org, BSD-3-Clause) for the Ogg Vorbis file.

## MuseScore General SoundFont notice (must accompany the samples)

MuseScore_General.sf2 (v0.2, 13 May 2020) is shared under the MIT licence. All instruments without further attribution use samples from FluidR3Mono.

- FluidR3 (original version) by Frank Wen, Copyright (c) 2000-02, and Copyright (c) 2000-2002, 2008 Frank Wen
- Mono conversion (FluidR3Mono) by Michael Cowgill, Copyright (c) 2014-17
- Adaptation for MuseScore_General.sf2 by S. Christian Collins, Copyright (c) 2018-19
- Temple Blocks by Ethan Winer, Copyright (c) 2002; Drumline Cymbals by Michael Schorsch, Copyright (c) 2016

MIT licence text (from the SoundFont's COPYING): Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files
(the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice
shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
(Full text: MuseScore_General_License.md in Wavelength's soundfonts folder.)

The brief listed COMMERCIAL upgrades (Bitwig "California" kit, Bitwig "Rhodes" multisample) as optional swaps; they were not used.
