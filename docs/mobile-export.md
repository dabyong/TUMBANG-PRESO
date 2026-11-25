# Mobile export readiness

Use Godot 4.7.2-stable, matching export templates and the Compatibility renderer.

## Stage the release project

From a checkout, run `python3 tools/stage_mobile_release.py <new-directory>` with Python 3. Use a fresh directory outside the checkout. Open that staged `project.godot` and create the mobile presets there. Include `content/**/*.json` in the preset's non-resource filters so the offline boot can read bundled data. Place signed outputs outside the staged project.

The staging tool copies runtime scripts, scenes and content only. The restricted historical Sakura Girl MP3, historical art, and prototype assets remain in Git for reference and are absent from the staged project. The current milestone has no production media. Any future production-media allowlist must match the approved asset manifest. Inspect the final package contents before distribution.

## Android

Install OpenJDK 17, Android Studio, the required Android SDK components, and matching Godot templates. Set the Java and SDK paths in Godot Editor Settings. Configure the package ID and use a debug APK for a device smoke test. For Play distribution, configure Gradle and a release keystore and export a signed AAB. Keep credentials outside Git. Confirm the Play target API and toolchain requirements at release time. [Godot Android export guide](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)

## iOS

On macOS, install Xcode, the applicable iOS SDK, and matching Godot templates. Set the Apple Team ID and bundle ID, export the Xcode project, and configure signing and provisioning outside Git. Build and test on a physical iPhone before preparing a TestFlight archive. [Godot iOS export guide](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html)

## Verification scope

CI imports and boots the staged project headlessly and verifies that restricted audio is absent. Android APK/AAB export, iOS Xcode export and archive, signing, store submission, and on-device smoke tests remain unverified.
