# Tumbang Preso: Philippine Adventure v3.0

Godot 4.7.2-stable foundation for an offline-first educational 2D province adventure.

## Milestone 1 scope

This branch contains the project shell, offline boot screen, data contracts, campaign validation, recoverable local-save foundation, automated foundation test entry point, asset policy, and mobile export preparation. It does not contain Batanes gameplay, province question content, or the restricted legacy music in a release path.

## Repository policy

main is the stable release branch. develop is the integration branch for approved work. legacy/v2-original and tag v2-legacy are immutable historical references. Never force-push or rewrite archived history. Do not commit API keys, signing certificates, credentials, or export secrets. Root PNG assets remain historical references. The root MP3 is excluded from commercial builds.

## Prerequisites

- Godot 4.7.2-stable and matching export templates.
- Android Studio, Android SDK, OpenJDK 17, and a signed AAB workflow.
- macOS with Xcode, Apple Developer access, Team ID, bundle identifier, signing, and provisioning for iOS.

## Local verification

From the repository root:

    godot --headless --path . --editor --quit
    godot --headless --path . --script res://tests/foundation_test.gd

The first command verifies project import. The second runs campaign, content, save recovery, and offline boot checks. CI also confirms that an intentional failed check exits with status 1 and verifies the clean mobile staging project.

- [Local persistence contract](docs/save-foundation.md)
- [Mobile export procedure and prerequisites](docs/mobile-export.md)
- [Asset handling and provenance](assets/README.md)
- [Authoritative Phase 2 Game Design Document](docs/phase-2-game-design-document.md)

Milestone 2 begins only after explicit approval.
