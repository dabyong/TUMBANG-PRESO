# Tumbang Preso: Philippine Adventure
## Game Design Document — Phase 2: Gameplay Systems

**Version:** 3.0  
**Status:** Gameplay specification finalized  
**Platforms:** Android and iOS  
**Genre:** Educational 2D arcade / geography adventure  
**Art direction:** Retro pixel art  
**Gameplay model:** Single-player, offline-first  
**Development:** Codex-assisted, milestone-based implementation

---

# 1. Game Overview

Tumbang Preso: Philippine Adventure is a Filipino-inspired educational arcade game that combines the traditional Tumbang Preso concept with a journey across the provinces of the Philippines.

Players progress through a connected Philippine map, beginning in Batanes and exploring provincial destinations through a geographically sensible travel network.

Each province functions as a playable level containing five educational questions about local geography, history, culture, cuisine, and landmarks.

Players answer by selecting and throwing one of five tsinelas toward a tin can. Correct answers knock the can down, while incorrect answers count as misses.

The long-term objective is to complete the planned 82-province campaign, achieve three-star ratings, and explore the country's cultural and geographic diversity.

The official province roster, geographic identifiers, administrative classifications, and travel connections must be verified against authoritative Philippine geographic data before the full campaign is implemented.

# 2. Core Gameplay Loop

1. The player opens the Philippine Adventure Map.
2. The player selects an unlocked province.
3. The Province Discovery screen introduces the destination.
4. The player chooses Easy, Normal, or Hard.
5. A gameplay session begins with five questions.
6. Five tsinelas display the answer choices.
7. The player selects a tsinelas, triggering the throwing animation.
8. The system evaluates the selected answer.
9. Correct answers knock the tin can down and advance the question.
10. Incorrect answers increase the miss counter, display feedback, and allow another attempt.
11. The player wins by answering all five questions before reaching five misses.
12. The system awards stars, saves progress, and unlocks eligible destinations.
13. The player returns to the map or replays the level.

# 3. Province Level Structure

Every province uses the same reusable gameplay structure.

**Standard configuration**

- Five questions per session.
- Five answer choices per question.
- Five total allowed misses.
- One correct answer per question.
- One active question at a time.
- No session timer.
- Five correct answers required for victory.
- Five accumulated incorrect attempts trigger failure.
- Question selection is randomized without repetition within the same session.

A province may be replayed any number of times.

The game must not advance to the next question until the current question has been answered correctly, unless the player has failed the session.

Only the first incorrect selection of a particular answer option counts as a miss. Previously rejected answers become disabled for that question.

# 4. Difficulty System

Players can choose their difficulty before entering any unlocked province.

Difficulty does not alter the map progression requirements or the number of questions.

| Feature | Easy | Normal | Hard |
|---|---|---|---|
| Questions | 5 | 5 | 5 |
| Answer choices | 5 | 5 | 5 |
| Maximum misses | 5 | 5 | 5 |
| Knowledge complexity | Basic | Intermediate | Advanced |
| Hints | Available before answering | Appears after first miss | Appears after second miss |
| Answer explanations | Yes | Yes | Yes |
| Stars available | 3 | 3 | 3 |

**Easy:** Emphasizes recognizable facts, famous places, and introductory knowledge.

**Normal:** Emphasizes province-specific history, traditions, geography, and cultural distinctions.

**Hard:** Uses more detailed factual questions and plausible distractors. Questions must remain fair, clearly worded, and verifiable.

Difficulty is selected independently for each session.

Stars are recorded separately for each difficulty. Completing a province on any difficulty counts toward map progression; harder difficulties are optional mastery challenges.

# 5. Scoring System

The scoring system rewards correct answers with fewer incorrect attempts.

## 5.1 Points per question

| Incorrect attempts before correct answer | Points awarded |
|---|---:|
| 0 | 100 |
| 1 | 75 |
| 2 | 50 |
| 3 | 25 |
| 4 | 10 |

The maximum base score per province is 500 points.

Points are awarded only after a correct answer. Hints do not directly deduct points; their availability is already balanced by the difficulty settings and missed attempts.

Points are not influenced by animation duration, device performance, or response time.

## 5.2 Star rating

Stars are awarded based on the number of accumulated misses during a successfully completed session.

| Misses | Reward |
|---|---|
| 0–1 | ★★★ |
| 2–3 | ★★ |
| 4 | ★ |
| 5 | Failed — no completion reward |

A successful run always receives at least one star.

The game stores each difficulty's best star rating and best score. A replay never overwrites a better previous result.

## 5.3 Reward limitations

Version 3.0 uses stars as its primary performance reward.

There is no virtual currency, paid progression, consumable item economy, or randomized purchasable reward system in the initial release.

# 6. Question and Answer Mechanics

## 6.1 Question bank

Questions must be stored separately from gameplay logic using structured data.

Each question record must contain:

- Unique question ID
- Province ID
- Difficulty
- Category
- Question text
- Exactly five answer options
- Correct answer ID
- Hint text
- Answer explanation
- Fact source or reference
- Content verification status
- Language identifier
- Content version

Questions must be factual, understandable, and relevant to the designated province.

Before a difficulty becomes playable, its province must have at least five approved and unique questions. Ten to fifteen approved questions per difficulty are recommended to improve replay variety.

Unverified or incomplete question records must not enter the playable question pool.

## 6.2 Answer selection

When a player chooses a tsinelas:

1. The selection is registered.
2. All other input is temporarily disabled.
3. The selected tsinelas performs its throwing animation.
4. The answer is evaluated exactly once.
5. The appropriate success or failure animation plays.
6. The game updates the score or miss counter.
7. The game displays feedback.
8. Input is restored when the next valid interaction becomes available.

## 6.3 Correct answers

A correct answer must:

- Trigger the tin-can knockdown animation.
- Display positive feedback.
- Award points according to attempts used.
- Show the answer explanation.
- Increment completed questions by one.
- Advance only after the player acknowledges the feedback.

## 6.4 Incorrect answers

An incorrect answer must:

- Trigger a missed-throw animation.
- Increment the miss counter by one.
- Disable the incorrectly selected answer option.
- Display feedback without revealing the correct option.
- Display the hint if its difficulty threshold is met.
- Allow the player to retry the same question if fewer than five misses have accumulated.

## 6.5 Session question selection

Questions are randomly drawn from the approved pool for the chosen province and difficulty.

A question must not repeat within the same session. Shuffled answer positions must preserve the correct answer mapping.

The question bank must support future content additions without modifying the core game logic.

# 7. Level Progression and World Map

## 7.1 Campaign structure

The adventure is organized into four gameplay chapters:

1. Northern Luzon
2. Central and Southern Luzon
3. Visayas
4. Mindanao and the Southern Islands

These chapter divisions are gameplay groupings, not official administrative regions.

The first playable province is Batanes.

Progression uses a connected map of provincial nodes rather than a simple fixed numerical sequence.

## 7.2 Province states

Each province node has one of four states:

- **Locked:** Not yet accessible.
- **Unlocked:** Accessible but not successfully completed.
- **Completed:** Finished with at least one star on any difficulty.
- **Mastered:** Three stars earned on all three difficulty settings.

## 7.3 Unlock rules

- Batanes is unlocked at the beginning of a new save.
- Completing a province reveals all directly connected provinces permitted by the campaign progression configuration.
- Players may select any currently unlocked province.
- Chapter gateways may require completing designated provincial nodes before opening.
- Completing a province on Easy, Normal, or Hard qualifies for normal progression.
- Replays and additional difficulty completions do not remove existing unlocks.
- No province may become permanently unreachable due to a player decision.

The final map configuration must be validated so that all campaign provinces are reachable from the starting province.

Island crossings are explicitly defined as travel connections. The system must not assume that provinces are connected solely because they have similar geographic coordinates.

# 8. Screens and Navigation

## 8.1 Splash and loading screen

Displays the official game logo and initializes required assets and saved data.

## 8.2 Main menu

Required actions:

- Play
- Continue
- Settings
- Credits

Continue opens the map at the last accessible province or most recently selected destination.

## 8.3 Philippine Adventure Map

Displays the campaign chapters, provincial nodes, unlock states, earned stars, and available travel connections.

Players can inspect an available destination before entering it.

## 8.4 Province Discovery

Displays:

- Province name
- Region
- Province-themed pixel-art illustration
- Short educational introduction
- Preview of question categories
- Play button
- Back button

## 8.5 Difficulty Selection

Provides Easy, Normal, and Hard selections.

Each option displays its description and previously earned stars.

## 8.6 Gameplay

Required visible elements:

- Province name
- Question number, from 1 to 5
- Score
- Miss counter, from 0 to 5
- Question text
- Tin-can sprite
- Five interactive tsinelas
- Context-sensitive hint display
- Pause button

## 8.7 Answer Feedback

Displays the result of an answer and the factual explanation for correct responses.

## 8.8 Pause Menu

Provides Resume, Restart Level, Settings, and Return to Map.

## 8.9 Victory Screen

Displays:

- Province completion status
- Selected difficulty
- Total score
- Number of misses
- Earned stars
- Newly unlocked destinations
- Replay and Continue buttons

## 8.10 Failure Screen

Displays a failure animation and provides Retry and Return to Map actions.

## 8.11 Settings

Provides independent music and sound-effect controls, accessibility preferences, and an option to review game information.

## 8.12 Progress Overview

Displays completed provinces, earned stars, and chapter completion statistics.

# 9. Visual and Animation Requirements

The game preserves the original pixel-art identity.

**Art requirements**

- Consistent pixel density and sprite scaling.
- Province-inspired environmental backgrounds.
- Recognizable tsinelas sprites.
- Distinct idle and knocked-down tin-can sprites.
- Legible pixel typography.
- High-contrast answer labels and UI controls.
- Touch-friendly interactive elements.

**Gameplay animations**

- Subtle idle movement for the tin can.
- Parabolic tsinelas throwing.
- Correct-answer knockdown with a 720-degree rotation.
- Incorrect-answer missed throw.
- Visual reaction when a miss occurs.
- Viewport shake and failure overlay after the fifth miss.
- Star-award animation following victory.

Every animation must conclude in a deterministic gameplay state. Game logic must not rely on animations to calculate whether an answer is correct.

Reduced-motion settings should remove unnecessary shaking and excessive rotation while preserving essential gameplay feedback.

# 10. Save and Progress System

The initial release uses local offline progress storage.

The system saves:

- Completed provinces
- Unlocked provinces
- Best score per province and difficulty
- Best star rating per province and difficulty
- Most recently selected province
- Settings and preferences
- Save schema version

Progress must be saved after completing a level and after unlocking new destinations.

Players must not lose previously confirmed progress after an application restart.

Save data must support schema migrations for future versions.

A new game starts with Batanes unlocked and all other provinces in their configured initial states.

# 11. Edge Cases and Error Handling

| Scenario | Required behavior |
|---|---|
| Rapid multiple taps | Register exactly one answer |
| Incorrect answer already selected | Ignore subsequent taps on that option |
| Fifth miss occurs | End the session immediately after feedback; do not accept further attempts |
| Pause during animation | Suspend safely and resume without repeating score updates |
| App moves to background | Preserve a valid session state |
| App closes unexpectedly | Restore the last committed progress; restart an incomplete level if reliable session restoration is unavailable |
| Missing question data | Prevent level start and display a recoverable content error |
| Fewer than five approved questions | Mark the selected difficulty as unavailable |
| Missing image or audio asset | Provide a safe fallback where possible without blocking core gameplay |
| Device has no internet | Continue core gameplay normally |
| Player changes difficulty | Start a new session; preserve existing records |
| Player replays province | Preserve highest historical stars and score |
| Province has multiple unlocked neighbors | Present all eligible destinations |
| Map has an unreachable province | Fail content validation before release |
| Save data version changes | Migrate safely or recover from a valid backup |
| Device aspect ratio varies | Maintain readable content and usable controls without clipping |

# 12. Accessibility and User Experience

The game must provide:

- Clear visual feedback beyond color alone.
- Readable question text.
- Large interactive touch targets.
- Adjustable audio settings.
- Reduced-motion support.
- Safe-area support for mobile screens.
- No essential information hidden behind decorative artwork.
- Controls that remain usable across supported aspect ratios.
- Clear confirmation before destructive actions such as resetting saved progress.

The final engine and platform architecture must support suitable native accessibility functionality where feasible.

# 13. Codex Acceptance Criteria

## AC-01 — Game session

**Given** an unlocked province and selected difficulty, **when** the player starts, **then** a session containing exactly five unique valid questions must begin.

## AC-02 — Answer choices

Each question displays exactly five options, including one correct answer, with answer labels correctly mapped to the corresponding tsinelas.

## AC-03 — Correct answer

Selecting a correct option triggers one successful throw, increases the completed-question counter by exactly one, and awards the correct points.

## AC-04 — Incorrect answer

Selecting an incorrect option increments the miss counter by exactly one, disables that option, and permits another selection when the miss limit has not been reached.

## AC-05 — Spam protection

Multiple rapid inputs during an active animation must not produce multiple score changes, repeated throws, or unexpected state transitions.

## AC-06 — Victory

The victory screen appears only when five questions are correctly answered before the miss counter reaches five.

## AC-07 — Failure

The session fails immediately upon reaching five misses, including when this occurs before the final question.

## AC-08 — Star rating

A successful session with zero or one miss earns three stars, with two or three misses earns two stars, and with four misses earns one star.

## AC-09 — Difficulty

Easy, Normal, and Hard must load their own approved question pools, follow their respective hint rules, and maintain independent best-score and star records.

## AC-10 — Unlocking

Completing a province on any difficulty unlocks the next eligible provincial nodes according to the campaign graph configuration.

## AC-11 — Persistence

Saved progress survives app restarts. Replaying a level must not overwrite a better existing record with a worse result.

## AC-12 — Offline functionality

All core gameplay, questions, world-map progression, and saved progress remain functional without internet access.

## AC-13 — Responsive gameplay

All gameplay components remain visible and accessible on supported mobile resolutions and aspect ratios.

## AC-14 — Content integrity

Every playable question has exactly one verified correct answer, valid option mappings, and a complete explanation.

## AC-15 — Animation integrity

Game state remains valid after animations, pauses, interruptions, retries, and app backgrounding.

## AC-16 — Campaign validation

The map validator confirms unique province IDs, valid connections, valid unlock requirements, and reachability of all intended provincial nodes.

## AC-17 — Testing

Automated tests cover scoring, miss counts, star ratings, question selection, progression, save/load operations, and critical edge cases.

A gameplay milestone is not complete until its acceptance criteria have been tested and verified.

# 14. Initial Development Scope

The first vertical slice should implement:

- Main menu
- Philippine Adventure Map
- Batanes
- Cagayan
- At least one additional geographically connected province
- Three difficulty levels
- Full five-question gameplay
- Scoring and star awards
- Success and failure screens
- Local progress saving
- Basic audio controls
- Representative province backgrounds
- Automated gameplay tests

The vertical slice should validate the core experience before the complete provincial campaign is produced.

# 15. Scope Exclusions

The following are excluded from the initial gameplay specification:

- Multiplayer
- Online competitive leaderboards
- Real-money purchases
- Advertisements
- In-game currencies
- Account registration requirements
- Cloud save synchronization
- Daily challenges
- User-generated questions

These may be considered in later releases after the single-player experience is complete.

# 16. Phase 2 Completion Criteria

Phase 2 is considered finalized when:

- Core gameplay rules are defined.
- Question and difficulty behavior is documented.
- Scoring and star calculations are deterministic.
- Progression and unlock conditions are defined.
- Required screens are identified.
- Save data requirements are established.
- Edge-case behavior is documented.
- Codex acceptance criteria are testable.

**Status: Phase 2 — Finalized**

Next phase: Technical Architecture, repository assessment, data model specification, engine selection, and Codex development setup.

