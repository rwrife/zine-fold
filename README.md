# Zine Fold

Offline zine booklet planner: arrange folded page order, preview spreads, and export print-ready sheets from phone, tablet, or Windows without accounts.

## Why / for whom

Artists, teachers and community organizers need to turn 8- or 16-page mini-zines into printable folded sheets without guessing page order. Unlike a general PDF editor, this tool focuses on one imposition workflow with a visual fold preview and explicit blank pages.

## Intended workflow

1. Choose 8- or 16-page saddle-fold booklet, A4 or US Letter paper, and portrait/landscape source pages.
2. Import local PDF pages or images; reorder pages in a numbered grid, add blank pages deliberately, and preview reading order and sheet sides.
3. Export a print-ready PDF with crop/fold guides and duplex flip instruction. Print one proof, fold, and correct the order if needed.
4. Save the project locally; export a portable project backup containing referenced page files, with no silent external-path dependency.

## MVP / limits

- Page grid, deterministic booklet imposition with tested 8/16-page signatures, front/back preview, image/PDF input, explicit missing/blank-page handling, print-sheet PDF export, local project save and portable backup.
- No print-shop preflight certification, arbitrary binding, collaborative editing, online templates, cloud sync, OCR, subscriptions, or claims that home printers align perfectly.
- Import must reject unsupported or malformed documents without discarding the project; page previews stay local.

## Platforms and privacy

Flutter stable single codebase; Windows 10/11 primary release, Android and iOS phones and tablets enabled. Touch, keyboard, mouse, window resize, safe areas and scalable text required. OS-native file pickers only on explicit user action; no network, login, telemetry, contact/location/camera/microphone permission. Local files remain user-owned; export to user-selected destination. `com.infinityball.zinefold` is Android applicationId and iOS bundle ID; Windows package identity uses same convention if MSIX is introduced.

UX strategy A: Cupertino on iOS/iPadOS, Material 3 on Android, Fluent on Windows, with small adaptive widget layer for navigation, dialogs and buttons. Never show phone UI on Windows. Screen reader labels for page numbers and side/order; high contrast and complete keyboard navigation.

## Status / milestones

Flutter 3.47.7 targets and validation CI exist. Pure 8/16-page imposition and a private project-store/import API exist. App still displays a development notice: project creation/import is not yet wired into UI. Editing, preview, export, backups, final icons and release packaging remain future work. Generated launcher icons are placeholders.

`AppStore/description.txt` remains planning copy, not a feature-complete listing. Generate actual `AppStore/icon.png` with OpenAI Images via spark-media after app development, inspect and wire into Windows, Android and iOS icon sets. No placeholder icons count as done.

## Build quickstart

Install Flutter 3.47.7 (revision in `toolchain.json`); run `flutter pub get --enforce-lockfile`, `flutter test`, `flutter run -d windows` on Windows. CI validates Windows release build, Android debug APK and unsigned iOS simulator compile. Linux tests can use a pinned Flutter Docker image. Windows release publishing remains future work.

## Manual setup required

App Store Connect bundle identifier `com.infinityball.zinefold` not registered: `FAILED bundleId lookup rejected: FORBIDDEN_ERROR.PLA_NOT_ACCEPTED`. Account owner must accept current Apple Program License Agreement, then retry registration. Secrets are already installed; no credential values stored here.
