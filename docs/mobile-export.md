# Mobile export readiness

The project is pinned to Godot 4.7.2-stable and uses the Compatibility renderer for the 2D foundation.

## Android

Install OpenJDK 17, Android Studio, the Android SDK platform and build tools required by the release window, and Godot export templates. Configure the Java SDK and Android SDK paths in the Godot editor. Set the final reverse-DNS package name, signing keystore, release alias, and passwords through the editor or protected CI secrets. Export a signed Android App Bundle for internal testing.

This repository intentionally contains no keystore, signing certificate, password, package identifier, or release export. An Android build has not been run in this workspace.

## iOS

Build iOS exports on macOS with Xcode and the matching iOS SDK. Configure the Apple Team ID, bundle identifier, signing, provisioning, and TestFlight credentials outside the repository. Export the Xcode project and validate it on a physical iPhone before release.

This repository intentionally contains no certificates, provisioning profiles, Team ID, or Apple credentials. An iOS build has not been run in this workspace.

## Offline foundation

The boot scene only reads bundled JSON content and local scripts. It does not require HTTP, a login, or a remote content service. The release build must keep all approved content and production media bundled.
