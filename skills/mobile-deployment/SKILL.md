---
name: mobile-deployment
description: Build and deploy mobile apps — EAS Build, Fastlane, code signing, App Store/Google Play submission, OTA updates, TestFlight beta, CI/CD pipelines, and phased rollouts
metadata:
  version: 1.5
  argument-hint: "platform (iOS/Android/both), store (App Store/Play Store), CI/CD tool, release type"
---

Implement mobile deployment for $ARGUMENTS.

## Tool Integration

- **browser automation** — capture screenshots for visual verification and regression testing

## Technology Selection

| Tool | Best for | Managed |
|------|----------|---------|
| EAS Build | Expo projects, cloud builds | Yes |
| Fastlane | Bare React Native, native apps | No |
| Xcode Cloud | Native iOS/macOS | Yes |
| GitHub Actions + Fastlane | Full control | Partial |

Decision: Expo -> EAS Build. Bare RN/native -> Fastlane + GH Actions. Flutter -> EAS Build (supports Flutter projects) or Fastlane + GitHub Actions. iOS only -> Xcode Cloud.

> **CodePush/AppCenter retired:** Microsoft retired CodePush and AppCenter in March 2025. Use **EAS Update** for OTA updates in Expo projects. For bare React Native, migrate to EAS Update or implement a custom update mechanism.

## Code Signing

### iOS

- Distribution Certificate (1yr) + Provisioning Profile + Push Key (.p8)
- Use **Fastlane Match**: certificates in encrypted Git repo, CI fetches read-only
- `fastlane match appstore --readonly` in CI

### Android

- Upload Keystore (.jks) signs the AAB; Google Play manages final signing key
- Store keystore in CI secrets, decode from base64 during build
- Never commit keystores; enable Google Play App Signing

### Rules

- Never commit signing keys to source control; use Match or CI secrets
- Separate identities for dev, ad-hoc, production
- Back up keystores securely; rotate upload keys periodically

## EAS Build (Expo)

```json
// eas.json
{
  "build": {
    "development": { "developmentClient": true, "distribution": "internal" },
    "preview": { "distribution": "internal", "channel": "preview" },
    "production": { "autoIncrement": true, "channel": "production" }
  },
  "submit": {
    "production": {
      "ios": { "appleId": "...", "ascAppId": "...", "appleTeamId": "..." },
      "android": { "serviceAccountKeyPath": "./google-sa.json", "track": "internal" }
    }
  }
}
```

Commands: `eas build --profile production --platform all`, `eas submit`, `eas update --channel production --message "Fix"`.

Rules: `autoIncrement` for production; separate channels; set `runtimeVersion` policy; store credentials as EAS secrets.

## Fastlane

### iOS

```ruby
lane :beta do
  setup_ci if is_ci
  match(type: "appstore", readonly: is_ci)
  increment_build_number(build_number: ENV["BUILD_NUMBER"] || (latest_testflight_build_number + 1))
  build_app(workspace: "MyApp.xcworkspace", scheme: "MyApp", export_method: "app-store")
  upload_to_testflight(skip_waiting_for_build_processing: true)
end
```

### Android

```ruby
lane :beta do
  gradle(task: "bundle", build_type: "Release", project_dir: "android/")
  upload_to_play_store(track: "internal", aab: "...app-release.aab", json_key: ENV["GP_KEY_PATH"])
end

lane :promote do
  upload_to_play_store(track: "internal", track_promote_to: "production", rollout: "0.1")
end
```

## CI/CD (GitHub Actions)

iOS: macos-14 runner, setup ruby + node, `npm ci`, `pod install`, `fastlane ios beta` with Match/ASC secrets.
Android: ubuntu runner, setup Java 17 + node, decode keystore from base64, `fastlane android beta`.
EAS: ubuntu runner, `expo/expo-github-action`, `eas build --non-interactive`, `eas submit`.

## Versioning

`{major}.{minor}.{patch} (buildNumber)` -- e.g., `1.2.3 (45)`.

- App version set manually on feature releases; build number auto-increments per CI build
- iOS build numbers unique per version; Android versionCode always increases
- Tag releases: `v1.2.3`; OTA updates do not change app version

## Beta Distribution

- **TestFlight** (iOS): internal (100 users, no review) + external (10K, Beta App Review)
- **Firebase App Distribution** (cross-platform): `firebase_app_distribution()` in Fastlane
- Internal: auto-distribute on push to main; external: tagged releases only
- Include release notes; set 90-day expiry on beta builds

## Store Submission

### App Store Checklist

Icon 1024x1024, screenshots per device family, privacy policy URL, privacy nutrition labels, TestFlight tested.
Watch: 2.1 completeness, 2.3 metadata accuracy, 3.1.1 IAP for digital goods, 5.1 privacy declarations.

### Google Play Checklist

AAB format, content rating, data safety section, target API level current year-1, managed publishing.

Automate via Fastlane/EAS Submit; submit to internal first; schedule weekday submissions.

## Phased Rollouts

Google Play: `upload_to_play_store(rollout: "0.1")` -> 0.5 -> 1.0. Halt: `rollout: "0.0"`.
App Store: phased release over 7 days (1% -> 100%); pause from ASC dashboard.

### Monitoring

| Metric | Alert |
|--------|-------|
| Crash-free rate | <99.5% halt |
| ANR rate (Android) | >0.5% |
| Error rate | >2x baseline |
| Ratings | <4.0 |

### Rollback

iOS: no true rollback; submit hotfix or revert via OTA (EAS Update). Use feature flags.
Android: halt staged rollout; submit hotfix; users already updated cannot downgrade.

## Anti-Patterns

- Committing keystores or certificates to source control -- credential exposure is irreversible
- APK instead of AAB for Play Store -- forfeits Google's dynamic delivery and size optimization
- No phased rollout with crash monitoring -- bad releases reach 100% of users before detection
- iOS builds attempted on Linux CI -- Xcode toolchain is macOS-only, builds will fail silently or not at all

## Output Format

```
Platform:          [iOS / Android / both]
Build Tool:        [EAS Build / Fastlane]
Code Signing:      [Match / EAS managed]
CI/CD:             [GitHub Actions / Bitrise]
Beta:              [TestFlight / Firebase App Distribution]
Store Submission:  [Fastlane / EAS Submit]
OTA:               [EAS Update]
Rollout:           [phased percentages + monitoring]
```

## Done Criteria

- Reproducible builds from any commit; automated code signing
- Beta auto-distributes on push to main; store submission automated
- Version/build numbers auto-increment; OTA deploys JS fixes without store review
- Phased rollout with monitoring; rollback plan documented and tested
- Both platforms build and deploy independently
