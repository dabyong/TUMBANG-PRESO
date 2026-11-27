# M2.4A art direction

Tumbang Preso should read as a Filipino retro arcade adventure on first glance. A recognizable tin can anchors each throw, five flip-flops give the answer rows a physical identity, and each province has a distinct environment. Keep the question and answer lettering as live, scalable text. The existing landscape canvas uses 960×540 logical pixels. Retain the approved navigation, feedback timing, pause behavior, progression, persistence, and question catalog. [Phase 2 GDD](phase-2-game-design-document.md) · [Production UI and animations](ui-navigation-animations.md)

## Batanes and visual style

- Start with green rolling hills, a coastal horizon, and stone houses with thick walls, small openings, and cogon roofs. Use terrain and roof silhouette for recognition. Keep scenery details subordinate to the question and target. Draw the environment from approved references with recorded provenance. [Philippine Information Agency on Ivatan construction](https://pia.gov.ph/features/resilience-of-the-ivatans/) · [Department of Tourism on Basco Lighthouse and its setting](https://www.tourism.gov.ph/sports/venues/basco-lighthouse)
- Use a consistent upper-left light direction, three or four value steps per material, and a deliberate pixel grid. Use darker outlines for interactive props and less contrast in distant scenery. Limit highlights to meaningful edges. Use larger pixel clusters or flat tones behind the HUD and reading panel.
- Use sea blue, hill green, light stone, and warm amber for the landscape and UI accents. Give the can a warm metal silhouette with a dark rim and opening. Give each sandal a distinct shape or strap pattern as well as color. Reserve stronger contrast for text, focus rings, and feedback.
- Keep text, focus rings, and interactive panel edges sharp at their rendered scale. Use live labels and symbols to communicate lock state, focus, correctness, and misses. Check text and controls over the lightest and darkest scenery and review feedback with reduced motion enabled.

## Gameplay composition

Keep score, question number, misses, and Pause in the HUD. Give the can a fixed stage on wide layouts, beside the reading column and above foreground scenery. The question, five answer rows, and feedback use native wrapping and scrolling in the reading column. Each button pairs a sandal with a live answer label. Hints appear automatically when eligible under the approved rules. The sketches place the hint beside the reading column on wide layouts and in the reading column on compact screens. Keep it associated with the prompt in the reading order, and retain the feedback acknowledgement control after animation.

At narrower widths or when actual safe-area and font measurements leave too little text width, keep the full-width scroll flow and pin the target in the HUD. Preserve the current 54 logical pixel minimum for answer rows, 7 px row gap, 50 px Pause and feedback actions, and 55 px answer text inset. Grow answer rows as labels wrap. Keep the same reading and focus order across modes. Use real Godot safe-area insets in addition to the current scene margins of 30 px horizontal and 16 px vertical. The dimensions in these diagrams are logical pixels. Device touch sizes and insets still need validation.

| Reference viewport | Layout | Annotated wireframe |
| --- | --- | --- |
| 960×540 | Wide reading column with can stage, five rows visible in the short-text example, and scroll for longer strings or feedback | [960×540](m24-visuals/gameplay-wireframe-960x540.png) |
| 640×360 | Full-width reading column, target pinned to the HUD, wrapping and scrolling with additional choices below the fold | [640×360](m24-visuals/gameplay-wireframe-640x360.png) |
| 844×390 | Wide, shallow layout with a lateral stage and scrollable reading column | [844×390](m24-visuals/gameplay-wireframe-844x390.png) |

Measure width, height, text flow, and safe insets before adopting a wide layout. The diagrams illustrate composition and use sample copy. For a wide layout, the live can pivot must remain available to the effects overlay even while the list scrolls. Launch from the selected row's visible region, preserve the normalized trajectory and viewport clamping, and keep the overlay above scenery and the reading panel. Retain the M2.3 presentation gate, including reduced-motion timing, until feedback or results can be shown. Preserve the pinned HUD target as the verified fallback. [Production UI and animations](ui-navigation-animations.md)

## Integration sequence after approval

1. Review the wireframes, visual direction, and cultural references with the project owner and senior technical reviewer. Review the rights record for every source.
2. Establish one approved sample each for environment, sandal, can, and UI before producing the full family. Compare at the intended on-screen size, including long labels and grayscale.
3. Add only the approved media inventory to the stage allowlist after its validation rules and negative tests have landed. Introduce scenery and branding first, then sprites and effects, then audio using existing buses. Verify each change against the approved presentation contract.
4. Recheck all three reference canvases, wrapping and scroll, safe-area insets, contrast and focus, both motion modes, results and recovery navigation, and separate Music and SFX settings. Run the existing suites and clean mobile staging, then verify signed builds on representative Android and iOS devices before release. [Mobile export and validation](mobile-export.md)
