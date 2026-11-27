# Tumbang Preso: Philippine Adventure v3.0

Godot 4.7.2-stable foundation for an offline-first educational 2D province adventure.

## Milestone 2.3 scope

Batanes is playable offline on Easy, Normal, and Hard. From the Adventure Map, open Batanes to start a session, resume a saved attempt, or view a saved result. The playable catalog contains 45 sourced English questions. Completing Batanes unlocks campaign access to Cagayan, whose question pools are still empty.

## Repository policy

main is the stable release branch. develop is the integration branch for approved work. legacy/v2-original and tag v2-legacy are immutable historical references. Never force-push or rewrite archived history. Do not commit API keys, signing certificates, credentials, or export secrets. Root PNG assets remain historical references. The root MP3 is excluded from commercial builds.

## Prerequisites

- Godot 4.7.2-stable and matching export templates.
- Android Studio, Android SDK, OpenJDK 17, and a signed AAB workflow.
- macOS with Xcode, Apple Developer access, Team ID, bundle identifier, signing, and provisioning for iOS.

## Local verification

From the repository root:

    godot --headless --path . --import
    godot --headless --path . --script res://tests/foundation_test.gd
    godot --headless --path . --script res://tests/gameplay_domain_test.gd
    godot --headless --path . --script res://tests/production_content_test.gd
    godot --headless --path . --script res://tests/gameplay_integration_test.gd
    godot --headless --path . --script res://tests/ui_navigation_presentation_test.gd
    godot --headless --path . --script res://tests/ui_settings_recovery_test.gd
    python3 architecture_tests/phase3_acceptance.py --adapter python3 architecture_tests/phase3_adapter.py
    python3 architecture_tests/phase3_acceptance.py --domain-adapter python3 architecture_tests/phase3_adapter.py

Use Python 3 and put Godot on the path or set `GODOT` to the headless executable. CI also confirms that an intentional failed check exits with status 1 and verifies the clean mobile staging project. The gameplay contract documents the Phase 3 failure fixture correction and the explicit save recovery decisions.

- [Local persistence contract](docs/save-foundation.md)
- [Gameplay session and Phase 3 adapter](docs/gameplay-domain.md)
- [Batanes gameplay flow and save compatibility](docs/batanes-gameplay.md)
- [Production navigation, presentation, settings and recovery](docs/ui-navigation-animations.md)
- [Batanes question verification](docs/batanes-content-verification.md)
- [Mobile export procedure and prerequisites](docs/mobile-export.md)
- [Asset handling and provenance](assets/README.md)
- [Authoritative Phase 2 Game Design Document](docs/phase-2-game-design-document.md)
