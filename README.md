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

Flutter 3.47.7 targets and validation CI exist. Pure 8/16-page imposition, private project store, image/PDF page import, editing and sheet preview exist. Cupertino iOS, Material 3 Android and Fluent Windows shells use platform controls; narrow layouts switch Pages/Sheets while wide layouts show the editor and preview together. Print-sheet PDF and portable ZIP backups now export with local save dialogs; restore creates a new local project after validation. A real OpenAI-generated launcher icon is wired into Windows, Android and iOS; store review and device appearance still need human checks. `AppStore/description.txt` describes the implemented workflow.

Icon source: OpenAI Images `gpt-image-2.5-flare` via `spark-media --project zine-fold image`. Saved output: `~/media/zine-fold/images/20261112T054535Z_openai_52d50f.png`. Prompt: "analyze the repo and AppStore description to generate an icon that does not have any text or marketing, transparency, borders or corner radius. The image needs to be square, be edge-to-edge graphics and a modern colorful representation of the function provided by the app or game. If a logo or symbol is used, then there should be a gradient background or other abstract background behind the logo. Product: Zine Fold, offline zine booklet planner; arrange 8/16-page mini-zines in reading order and fold sheets. Show a clean bold folded paper booklet with layered vivid colorful pages on a rich gradient background, high legibility at launcher size, no text." Source measured 1024×1024 RGB with colored corner pixels; resized to native launcher sizes. Visual/store review remains manual.

## Build quickstart

Install Flutter 3.47.7 (revision in `toolchain.json`); run `flutter pub get --enforce-lockfile`, `flutter test`, `flutter run -d windows` on Windows. CI validates Windows release build, Android debug APK and unsigned iOS simulator compile. Linux tests can use a pinned Flutter Docker image. `.github/workflows/release.yml` publishes a portable Windows ZIP only from an existing `vMAJOR.MINOR.PATCH` tag, either through tag push or manual dispatch with that tag as input. Validate its release asset URL and positive size after a real tagged run; PR CI alone does not exercise publishing.

## Manual setup required

App Store Connect bundle identifier `com.infinityball.zinefold` not registered: `FAILED bundleId lookup rejected: FORBIDDEN_ERROR.PLA_NOT_ACCEPTED`. Account owner must accept current Apple Program License Agreement, then retry registration. Secrets are already installed; no credential values stored here.
