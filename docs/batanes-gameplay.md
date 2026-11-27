# Batanes gameplay

The temporary offline flow is Boot → Batanes entry → Difficulty → Gameplay → Results. The entry offers Resume or View saved result when a session exists. Use the pause menu to resume, explicitly restart, or return to the province entry while preserving the current session. Starting from the difficulty screen warns when the selected difficulty will replace an active attempt. Replay and Retry create a fresh session and carry forward committed records.

The campaign graph unlocks Cagayan after a successful Batanes run on any difficulty. The entry and result screens show that route access separately from question availability. Cagayan and Isabela have empty pools.

## Scene and input contracts

Boot loads bundled campaign and catalog data, validates the production pools, and configures the reusable `gameplay.tscn` scene with one `GameplayStore` for the save directory. Its controller projects verified snapshots into the HUD, question, five-tsinela answer container, hint, feedback, tin-can, pause, difficulty, and result scenes. The background, tin can, and sandal placeholders use built-in Godot controls and drawing. Mobile export staging already includes the required scenes, scripts, and JSON for offline play.

The tsinela buttons each emit the stable question and option IDs from the current render. Native button activation handles mouse and touch through Godot's existing input mapping. The controller uses a deterministic command ID for the session, question, and option tuple, and disables input during committed feedback. It advances only after a successful acknowledgement. The `answer_presented(outcome, question_id, option_id)` signal follows verified answer publication and is a presentation boundary for later animation. Animation completion must never submit or acknowledge an answer.

The landscape layout was exercised at 960×540 and 640×360. Question and answer content scrolls while the score, misses, and pause control remain visible. Signed exports and native device input remain to be checked on Android and iOS. The complete Philippine map, discovery flow, production menu, animations, and art belong to later work.

## Save compatibility and diagnostics

The former bundled `foundation-1` catalog and campaign version 1 had empty pools. They could not start a production session. M2.2 keeps the same save envelope and payload schema. Compatible progression-only payloads restore directly and retain their records. Empty save directories initialize through the existing first-launch path. No migration is needed for this transition.

An existing session still requires the exact campaign and catalog fingerprint. A session from different content, unsupported save schema, semantic corruption, or a pending recovery decision opens a diagnostic screen with the available generation details. **Check save again** runs the same read-only restore after the underlying issue has been addressed. The screen does not choose a candidate, promote a stage, or reset a save. Production recovery controls remain deferred. [Storage and recovery contract](save-foundation.md)

## M2.3 integration requirements

- Add a presentation gate between a committed answer and visible feedback or results. Block answer input and feedback acknowledgement while an animation is active. For terminal failure, complete the failure animation before displaying the result screen.
- Let production navigation select any eligible province and pass that selection to the gameplay controller. Keep one serialized `GameplayStore` for the save directory across navigation and gameplay.
- Add production recovery controls that use the existing explicit recovery decisions.
