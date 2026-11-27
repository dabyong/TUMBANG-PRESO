# M2.4A audio plan

Use two music loops and seven short cues. Keep the existing independent Godot `Music` and `SFX` buses and settings. Limit arrangements and level changes so players can read comfortably and recognize feedback with either bus muted. Make cues supplemental to existing visual and textual feedback. [Production UI and animations](ui-navigation-animations.md)

## Music

| Asset ID and proposed path under `assets/production/` | Duration and format | Entry, loop, and character |
| --- | --- | --- |
| `music-menu-exploration` · `audio/music/menu-exploration.ogg` | 90 s, Ogg Vorbis, 48 kHz stereo, about 128 kbps | Begin on the main menu and continue across exploration and map/discovery navigation. Use a light coastal rhythm and a spacious melody. Review any specific cultural references with the project owner. |
| `music-gameplay` · `audio/music/gameplay.ogg` | 120 s, Ogg Vorbis, 48 kHz stereo, about 128 kbps | Enter gameplay with a restrained rhythmic bed and soft transients. Keep the loop through answer presentation. Transition music on route changes and respect Pause and the Music setting. |

Route both through `Music`. Author seamless loops with tails folded into the loop and compatible waveform at the join. Test the exported files across several loop boundaries in Godot. If using an intro or loop offsets, confirm the importer and player repeat the intended sample window. Match both tracks around −18 LUFS integrated with source true peaks at or below −1 dBTP. Set final levels by listening to both buses together on mobile speakers and headphones. Crossfade during an eventual integration only if it preserves the existing route and pause behavior. [Godot audio import documentation](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_audio_samples.html)

## Sound effects

Use 48 kHz mono 16-bit PCM WAV and one-shot playback through `SFX` for every cue. The timings below are production directions for the approved gameplay presentation events.

| Asset ID and proposed path under `assets/production/` | Length | Event and sound |
| --- | --- | --- |
| `sfx-select` · `audio/sfx/select.wav` | 0.09 s | Play on intentional UI activation. Use a quiet tick that stays discrete with repeated taps. |
| `sfx-throw` · `audio/sfx/throw.wav` | 0.30 s | Play at launch after a successful answer commit. Use a short flip-flop swish with its strongest cue at the start so it fits both motion settings. |
| `sfx-correct-impact` · `audio/sfx/correct-impact.wav` | 0.24 s | Play at the transition to correct impact. Use a hollow metal hit with a quick rattle. Keep the initial hit audible at reduced-motion timing. |
| `sfx-miss` · `audio/sfx/miss.wav` | 0.22 s | Play on a regular miss at the miss point. Use a softer ground slap. Keep the terminal failure cue separate so layered playback does not double the transient. |
| `sfx-fifth-miss` · `audio/sfx/fifth-miss.wav` | 0.55 s | Play at the existing failure presentation event on the fifth miss. Use a brief falling accent. Place useful information early and trim or fade the tail where the reduced-motion window is 0.22 s. Keep the approved results transition timing. |
| `sfx-victory` · `audio/sfx/victory.wav` | 1.30 s | Play once when the authorized terminal success presentation or result opens after any required acknowledgement. Use a compact celebratory phrase with a decay that can continue over the results screen. |
| `sfx-star` · `audio/sfx/star.wav` | 0.18 s | Play when an earned star is first revealed. Use a light chime and space successive stars. Skip or coalesce overlapping chimes when multiple rewards reveal together. |

Keep very short cues consistent by ear and peak, with a starting source peak range of −8 to −4 dBFS. Verify levels when a loud effect overlaps music and another cue. Prevent duplicate cue playback from input repeats or rerendering. Limit concurrent effects and manage cue tails so fast transitions remain intelligible. The visual gate and committed result drive event timing independently of audio playback.

## Storage and rights

At 128 kbps, 210 seconds of music use approximately 3.36 MB (3.20 MiB). At 96–160 kbps the same material would use around 2.52–4.20 MB before container overhead. At 96,000 bytes per second, 2.88 seconds of mono PCM cues use about 276 KB (0.26 MiB). Budget approximately 3.5 MiB at the nominal settings before Godot import and packaging. Keep editable source sessions and full-resolution masters, such as 24-bit WAV, in the source archive outside the staged set.

Use newly created or documented commercial-use audio. Record composition, recording, sample, and performer rights, plus license or commissioned-use terms and any credit obligations. Obtain dated owner approval and store a SHA-256 for the release file. The historical Sakura Girl MP3 remains excluded under its noncommercial manifest classification. No audio assets were acquired for this checkpoint. [Current asset manifest](asset-manifest.json) · [Production release policy](m24-asset-specifications.md)
