# Tumbang Preso: Philippine Adventure v3.0

Godot 4.7.2-stable foundation for an offline-first educational 2D province adventure.

## Milestone 2.1 scope

The project provides an offline boot screen, campaign and question validation, and the gameplay session and save domain for the Batanes vertical slice. The bundled catalog is the empty foundation fixture. The automated gameplay suites use synthetic approved questions.

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
    python3 architecture_tests/phase3_acceptance.py --adapter python3 architecture_tests/phase3_adapter.py
    python3 architecture_tests/phase3_acceptance.py --domain-adapter python3 architecture_tests/phase3_adapter.py

Use Python 3 and put Godot on the path or set `GODOT` to the headless executable. CI also confirms that an intentional failed check exits with status 1 and verifies the clean mobile staging project. The gameplay contract documents the Phase 3 failure fixture correction and the explicit save recovery decisions.

- [Local persistence contract](docs/save-foundation.md)
- [Gameplay session and Phase 3 adapter](docs/gameplay-domain.md)
- [Mobile export procedure and prerequisites](docs/mobile-export.md)
- [Asset handling and provenance](assets/README.md)
- [Authoritative Phase 2 Game Design Document](docs/phase-2-game-design-document.md)
