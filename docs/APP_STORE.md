# Releasing Spolo

Spolo ships two ways from the same code: the **Mac App Store** (the `AppStore` build configuration) and a **download on tang-spark.no** (the `Release` configuration, signed with Developer ID and notarized). Both run in the App Sandbox with no network entitlement; they differ only in signing and in the Help menu, where the website build links to its download page to check for a new version.

## Every release

1. Bump `MARKETING_VERSION` (and for the App Store, `CURRENT_PROJECT_VERSION`) in `project.yml`, and add the release to `CHANGELOG.md`.
2. Check everything:
   ```bash
   scripts/preflight.sh
   scripts/test-merge.sh
   ```
3. App Store: build, then upload.
   ```bash
   scripts/appstore.sh upload
   ```
4. Website: build, sign, notarize and staple.
   ```bash
   scripts/release.sh
   ```

## One-time setup

| What | Status |
|---|---|
| Developer ID Application certificate (Feiyang Tang, X933P26489) | In the login keychain |
| Notarization profile `kvikkshot` | In the keychain, shared with Kvikkshot |
| App Store distribution signing | Cloud-managed by Xcode |
| Bundle ID `com.feiyangtang.Spolo` | Registered by Xcode on the first archive |
| App record | Created 22 October 2026: Apple ID 6825929542; build 1.0.0 (1) uploaded |

## App Store Connect

| Field | Value |
|---|---|
| Platform | macOS |
| Name | Spolo: Merge Videos & Photos |
| Bundle ID | `com.feiyangtang.Spolo` |
| Apple ID | 6825929542 |
| SKU | `spolo-macos` |
| Primary language | English (U.S.) |
| Version | 1.0.0 |
| Price | Free (Pro comes in 1.1 as a one-time in-app purchase) |
| App Privacy | Data Not Collected |
| Export compliance | No encryption (`ITSAppUsesNonExemptEncryption` is false) |
| Copyright | 2026 TangSpark |

Still to fill in before submitting for review: categories (Photo & Video, Utilities), age rating, support, marketing and privacy policy URLs (the tang-spark.no pages don't exist yet), the description, keywords and screenshots in all four localizations, and review notes.
