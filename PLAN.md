# Zine Fold plan

## Scope and architecture

Flutter stable/Dart single codebase for Windows, Android and iOS phones/tablets. Pure Dart booklet-imposition function maps reading page numbers to sheet/side/slot, independent of UI or PDF renderer. Local project document tracks paper size, source pages, order, and explicit blanks; imported files are copied into app-owned storage. Image/PDF rendering and printable PDF export follow the deterministic map; malformed imports never overwrite saved work. No cloud backend.

Identifier: `com.infinityball.zinefold` for Android applicationId, iOS bundle identifier, and Windows MSIX identity if packaged. iOS and Android tablet support enabled.

UX strategy **A: platform-native adaptive**. One screen flow, small adaptive-widget layer: Cupertino navigation/dialogs on iOS, Material 3 on Android, Fluent desktop panes/command bars and shortcuts on Windows. OS-native file pickers, platform scroll/back/selection semantics, window resizing, safe areas, accessible focus and large text. Widget/golden checks under TargetPlatform.iOS, TargetPlatform.android and TargetPlatform.windows at phone/tablet/desktop widths. Screen readers announce page sequence and sheet face.

## Milestones / dependencies

1. Flutter skeleton with actual `windows/`, `android/`, `ios/` targets, pinned SDK recorded in `toolchain.json`, Windows test/build and Android debug build in CI. Linux test checks in pinned Docker.
2. Pure Dart imposition math for 8/16 pages, paper sizes, duplex flip metadata; table-driven self-checks for every page appearing once.
3. Safe local project storage and import of images/PDF, validation, atomic writes and migration path.
4. Page-grid editing and booklet side preview with explicit blank slots and print instructions.
5. Platform-authentic adaptive layouts, touch/keyboard/mouse affordances, accessibility and platform golden tests.
6. Portable backup/restore and PDF export; print one physical proof before claiming printer compatibility. Do not promise perfect registration or universal PDF support.
7. Generate and inspect `AppStore/icon.png` through OpenAI Images via spark-media; wire Windows ICO, Android and iOS icons. Audit `AppStore/description.txt` against shipped features. Add `.github/workflows/release.yml` on `v*`/manual dispatch, build Windows release on `windows-latest`, zip and publish GitHub release. Android/iOS including tablets kept compiling; TestFlight/Play later, ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8, ASC_TEAM_ID secret names only.

## Test and release gates

Pure Dart imposition bijection tests; malformed/short document and backup round-trip tests; PDF export page-count/sheet-orientation assertions; widget/golden tests per platform; Windows `flutter test` and `flutter build windows --release`, Android debug APK in CI. Apple compile requires macOS runner and is not proven on Linux. No app, suite, icon or build exists in this initial docs-only scaffold.

## Risks / non-goals

PDF page rendering and bleed vary by platform; test fixtures and physical proof needed. User controls paper size and duplex flip; show preview and print instructions rather than claiming hardware detection. Local imported content may be copyrighted; user owns rights. No print-shop preflight, arbitrary binding, OCR, cloud sync, collaboration, or account. React Native, Expo, Kotlin Multiplatform, .NET MAUI, Unity and native Swift/Xcode-only implementations are out of scope.
