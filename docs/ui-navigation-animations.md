# Production navigation and presentation

## Screens and theme

Boot draws the title treatment for one frame when a renderer is available, then reads and validates the bundled campaign and question catalog. Invalid content stops before construction of the gameplay controller or store. A valid restore opens the main menu. A restore requiring a decision opens Save Recovery.

Play opens the Adventure Map. Continue focuses the last selected accessible province, or the saved session province when that preference is unavailable. The main menu also offers a direct saved-attempt or saved-result action. Choosing a destination opens the reusable Discovery screen, which offers the same action for its matching session. Starting a different run, or restarting from Pause, requires confirmation while a run is active. Returning to the map preserves the committed attempt.

The campaign schematic draws the configured directed links. Sea routes are dashed and land routes are solid. Both are also named in text. The layout uses campaign order as a north-to-south schematic, and the selection list uses chapter and province metadata. It represents the current three-node campaign. Locked, unlocked, completed, and mastered states are written explicitly, independently of question availability. Mastery requires three stars in each difficulty. The progress screen uses committed records to summarize chapters and provinces.

Discovery uses one scene for every province. It shows the configured region, chapter, verified question categories, records, and a procedural illustration. The Batanes introduction uses the DOT description of Basco Lighthouse and Mount Iraya. The Cagayan and Isabela introductions use their PSGC regional classification. Presentation metadata lives in UI code, outside the campaign and question fingerprint. [Department of Tourism](https://www.tourism.gov.ph/sports/venues/basco-lighthouse) · [Philippine Statistics Authority](https://psa.gov.ph/classification/psgc/provinces)

`scenes/ui/adventure_theme.tres` supplies high-contrast text, panel borders, and separate normal, hover, pressed, focused, and disabled controls. Theme typography uses Godot's built-in font. The tin can, tsinelas, terrain and schematic are drawn by Godot, with no external media. The landscape viewport stays 960×540. The HUD remains above the scroll area, long answer labels wrap inside touch targets, and safe-area insets are mapped from the mobile display into the current viewport. Desktop integration covers 960×540, 640×360 and 844×390, including injected mouse and touch-emulation events.

## Presentation state machine

One controller owns one serialized `GameplayStore`. A button passes the stable question and option IDs. Before calling the store, the controller locks every answer and disables acknowledgement. Its stable command ID hashes the session, question and option IDs. On successful publication it captures the committed outcome and starts the presentation. The HUD, explanation, and terminal screen remain gated until the appropriate phase. A write failure shows a retry or recovery message and starts no throw.

| Phase | Normal | Reduced motion |
| --- | ---: | ---: |
| Throw | 440 ms parabolic trajectory | 120 ms stationary landing cue |
| Correct impact | 480 ms, two full can rotations followed by tip-over | 100 ms tip-over |
| Miss impact | 200 ms subtle can reaction | 100 ms stationary cue |
| Fifth-miss overlay | 550 ms with shake | 220 ms with no shake |
| Victory reward | 600 ms star reveal | 150 ms star reveal |

The throw reads the selected tsinela and can positions in viewport space each frame. Misses end away from the target. The presentation calculates no hit detection, gameplay outcome, points or rewards. The miss reaction ends before a fifth-miss overlay, which ends before the failure screen. Incorrect feedback leaves the answer undisclosed. Acknowledgement returns to the same question and then applies the domain hint threshold. Correct feedback displays the catalog explanation and requires explicit acknowledgement. The fifth correct acknowledgement commits victory. The result reads the committed score, misses, difficulty, stars and new unlocks, then reveals the stars before enabling Replay and Continue.

The presentation clock uses frame deltas. It carries the presentation token and session ID across phases and ignores callbacks for an old attempt. Pausing or backgrounding suspends phase time. Returning from Pause to the map cancels transient effects and keeps the committed attempt. Restarting after confirmation invalidates the old token. Process restart restores the stable committed question, feedback or result without replaying a mutation or a visual frame. Normal and reduced-motion checks advance the same clock deterministically.

## Settings and recovery

Music and sound effects use separate named Godot buses with independent volume and mute. Reduced motion and the last selected province are also stored. The version 1 preferences payload uses a separate save-generation directory at `user://preferences/`. Missing or malformed preferences use 80% volume on each bus, normal motion and no initial preferred province. A preference write leaves gameplay generations untouched. This milestone contains no music or sound effects.

Save Recovery shows the reason, newest committed generation, an available inspection snapshot, and an eligible stage or older candidates. Each publishing or deferral action has an explicit confirmation. Staged promotion revalidates the stage, and deferral preserves the original bytes. Older committed recovery confirms rollback and passes both the selected and observed newest generations to the store. If the latest generation changes before confirmation, the decision fails and the screen refreshes. Unsupported, incompatible or unrecoverable data stays protected. The desktop screen offers to open the save folder for manual copying, and all platforms display the preserved location. Gameplay resumes after a successful valid restore. [Persistence contract](save-foundation.md)

## Deferred work and verification limits

Final province paintings and pixel sprites, licensed production audio, and device usability refinement are deferred to M2.4. On-device Android and iOS touch and lifecycle behavior, safe-area placement, signed exports, and physical power-loss durability remain unverified. Native support-file sharing is also deferred. The full-catalog fingerprint migration and growing session-ID history remain tracked. The current content leaves Cagayan and Isabela unavailable for play, so the broader multi-province GDD vertical slice remains open.
