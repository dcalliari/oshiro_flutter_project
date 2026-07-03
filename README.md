# Oshiro

[![CI](https://github.com/dcalliari/oshiro_flutter_project/actions/workflows/ci.yml/badge.svg)](https://github.com/dcalliari/oshiro_flutter_project/actions/workflows/ci.yml)
![Flutter](https://img.shields.io/badge/Flutter-3.35.7-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.9-0175C2?logo=dart&logoColor=white)
![Riverpod](https://img.shields.io/badge/state-Riverpod-4B6BEE)
![Firebase](https://img.shields.io/badge/backend-Firebase-FFCA28?logo=firebase&logoColor=black)

A Flutter **audiobook library**. Browse a catalog stored in Cloud Firestore,
search by title / author / ISBN (including barcode scanning), add books to your
library, download their tracks for offline use, and listen with a full
background player. Book metadata lives in Firestore (the `books` collection) and
the MP3 tracks in Firebase Storage (`/books/{id}/audios/`); per-user state
(library, favorites, downloads, playback position) is persisted on-device with
Isar.

The app ships with a **mock mode** so it runs — fully browsable and playable,
with sample data — without any Firebase credentials, which is also how it runs
on desktop.

> **Status (July 2026):** a portfolio project. The app is feature-complete:
> catalog, search, downloads, the background player and the mock mode are all
> implemented and working (`flutter analyze` clean, existing tests passing,
> playback verified on Linux). A broader automated test suite is still being
> written; the CI badge above turns green once the project is pushed to GitHub.

## Screenshots

_Add screenshots / a demo GIF here._

| Home (Library / Favorites) | Search & scan | Track list & download | Player |
| :------------------------: | :-----------: | :-------------------: | :----: |
| _placeholder_              | _placeholder_ | _placeholder_         | _placeholder_ |

## Features

- **Library home** — `All` / `Favorites` tabs, a list/grid toggle (persisted),
  drag-and-drop reordering, and a selection mode to remove books or clear their
  downloads. Loading / error / empty states throughout, with graceful image
  fallbacks for covers.
- **Search** — title / author / ISBN search over the catalog, plus ISBN barcode
  scanning via the camera (`mobile_scanner`, on Android / iOS; hidden on
  platforms without a scanner).
- **Downloads** — download a book's tracks for offline playback; files are
  scoped per book so tracks never collide. Delete individual downloads or a
  whole book.
- **Player** — built on `just_audio` + `audio_service`. The whole book is a
  playlist with real next / prev / seek, per-track resume position (persisted in
  Isar), playback speed (0.5x–2x) and volume. On Android / iOS it shows track
  metadata in the notification and lock-screen controls and plays in the
  background; on Linux / Windows desktop it plays through
  `just_audio_media_kit` (without OS media controls). In mock mode every track
  plays a bundled 30-second sample (`assets/audio/`).

## Architecture

The app follows a **Models + Repository + Riverpod** layering, with a runtime
switch between the real Firebase backend and in-memory mocks.

```
        UI (screens/, widgets/)
                 │  watch / read
                 ▼
        Riverpod providers (providers/)
                 │
        ┌────────┴─────────┐
        ▼                  ▼
  Repositories        LocalStore (Isar)
  (repositories/)     (data/local/)
        │                  │
        ▼                  ▼
  Firebase              on-device DB
  Firestore + Storage   library / favorites /
  (or in-memory mock)   downloads / positions
```

- **Models** (`lib/models/`) — typed `Book` / `Track`, tolerant parsers for the
  loose Firestore schema.
- **Repositories** (`lib/repositories/`) — `BookRepository` (catalog + search)
  and `StorageRepository` (downloads on disk). Each has a Firebase
  implementation and a mock one; `providers.dart` picks based on `useMock`.
- **LocalStore** (`lib/data/local/`) — a typed facade over Isar and the single
  source of truth for per-user state (replaces the old `.txt` + SharedPreferences
  approach). Generated code lives in `entities.g.dart` (committed).
- **Audio** (`lib/audio/`) — `OshiroAudioHandler`, an `audio_service` handler
  wrapping `just_audio`: it owns the per-book playlist, background playback and
  the notification / lock-screen controls, and persists resume positions.
- **Providers** (`lib/providers/`) — expose catalog, library, favorites, search
  and download state (`providers.dart`) plus player state (`player_providers.dart`)
  to the UI.

### Mock mode

`lib/config/app_mode.dart` exposes `useMock`, which is `true` when
`--dart-define=USE_MOCK=true` is passed **or** on any platform without Firebase
configured (Linux / macOS / Windows desktop). In mock mode the repositories
serve sample books from `lib/data/mock/`, and every track plays a bundled
30-second sample from `assets/audio/`, so the app is fully browsable **and
playable** with no backend.

## Getting started

Requires **Flutter 3.35.7** (stable) / Dart 3.9.

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Isar codegen
```

### Run with mock data (no Firebase needed)

Works on Linux / desktop out of the box:

```bash
flutter run --dart-define=USE_MOCK=true
```

### Run against real Firebase

The committed `lib/firebase_options.dart` targets the project's Firebase
instance. To point it at your own project instead, run:

```bash
flutterfire configure
```

Then run normally on Android / iOS / web:

```bash
flutter run
```

## Project structure

```
lib/
  config/         app mode (mock vs real)
  models/         Book, Track
  repositories/   BookRepository, StorageRepository (+ mocks)
  data/
    local/        Isar entities + LocalStore
    mock/         sample catalog for mock mode
  audio/          audio_service handler (just_audio)
  providers/      Riverpod providers (app + player)
  screens/        Home, Search, BookSelected, TrackList, Player
  widgets/        shared widgets
  firebase_options.dart
assets/audio/     bundled sample track for mock playback
test/             unit + widget tests
```

## Firebase security rules

Rules live in `firestore.rules` and `storage.rules`: the `books` catalog and
`/books` storage assets are **public to read**, and all writes are **denied**
(the catalog is seeded out-of-band). Deploy them with:

```bash
firebase deploy --only firestore:rules,storage
```

## Continuous integration

`.github/workflows/ci.yml` runs on every push / PR to `main`: `flutter pub get`,
Isar code generation, `flutter analyze` and `flutter test`. No secrets required
(tests run against mocks / fakes).

## App identity

The app ships under its own identity — display name **Oshiro**, application id /
bundle id **`dev.calliari.oshiro`** on Android and iOS.

## License

No license file yet — add one before making the repository public.
