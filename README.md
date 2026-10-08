# RepForge

**RepForge is a free, local-first strength-training app for iPhone.**  
Track workouts, build routines, follow progress, import existing Strong history, run rest timers from the Dynamic Island, and keep control of your own training data.

[![iOS 17+](https://img.shields.io/badge/iOS-17%2B-black?logo=apple)](https://www.apple.com/ios/)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-orange?logo=swift)](https://developer.apple.com/xcode/swiftui/)
[![SwiftData](https://img.shields.io/badge/Data-SwiftData-blue)](https://developer.apple.com/xcode/swiftdata/)
[![License](https://img.shields.io/badge/price-free-brightgreen)](#support-repforge)

> No subscription. No account required. No workout feature paywall.

## Why RepForge?

A workout logger should help you train, not get in the way. RepForge is designed around fast logging, useful history, local ownership of your data, and features that normally end up split across several paid fitness apps.

The project is currently distributed primarily as an **unsigned IPA for sideloading**. GitHub Actions builds the IPA automatically on every push to `main`.

## Highlights

### Workout logging

- Create and reuse workout templates
- Start empty workouts instantly
- Log weight, reps, sets, RPE/RIR and notes
- Warm-up and working-set support
- Previous-set references while training
- Per-exercise rest times
- Automatic rest timer workflow
- Compact workout mode
- Optional high-contrast workout presentation
- Gym-specific workout records
- Safe deletion of individual workout-history entries

### Progress and history

- Complete workout history
- Workout search and filtering
- Calendar view for completed and planned sessions
- Training volume tracking
- Per-exercise history
- Best-weight tracking
- Estimated 1RM charts
- Personal-record indicators
- Body measurements and profile statistics
- Gym-specific PR/history scopes

### Cardio

RepForge also supports cardio-style exercises rather than forcing every activity into kilograms and repetitions.

- Duration
- Distance
- Incline
- Calories
- Average heart rate
- Cardio-focused workout summaries

### Rest timer, Live Activities and Dynamic Island

On supported iPhones, the rest timer integrates with iOS Live Activities and the Dynamic Island.

- Compact Dynamic Island countdown
- Lock Screen Live Activity
- Direct return to the active workout
- Countdown haptics and rest notifications

### Exercise library

- Large built-in exercise catalog
- Exercise search
- Search aliases
- Muscle and equipment metadata
- Favorites
- Recently used exercises
- Custom exercises
- Exercise instructions and technique cues
- Programmatic exercise visuals
- Missing Strong exercises can be created automatically during import

### Planning

- Workout templates
- Built-in training program
- Editable program days
- Workout scheduling
- Calendar planning
- Rescheduling and skipping planned sessions
- Multiple gym profiles

### Strong migration

Moving from Strong does not require starting over.

RepForge can import a Strong CSV export including:

- workout dates and names
- completed sets
- weights and reps
- RPE
- notes
- cardio duration/distance fields
- rest timer information

Duplicate workouts with the same date and name are skipped on re-import, and exercises that do not already exist in RepForge can be created automatically.

### Backup and portability

RepForge includes a full JSON backup/restore system covering the important user-owned data.

The full backup includes:

- workout history
- templates
- profile data
- body measurements
- custom exercises
- gym profiles
- scheduled workouts
- edited program days
- favorites and recent exercises
- app settings

Workout history and templates can also be exported separately.

> **Important:** RepForge is currently local-first. Before deleting the app, make a Full RepForge Backup if the data matters to you.

### Bluetooth heart-rate sensors

RepForge can connect to devices implementing the standard Bluetooth Heart Rate Service.

When connected, live BPM can be shown during a workout and used with cardio logging.

### Personalization

RepForge currently includes:

- **16 visual themes**
- English
- Dutch
- Spanish
- German
- French
- Metric and imperial units
- Multiple text-size options
- Haptics and workout-behavior preferences

## RepForge 0.3 — Arena rebuild

RepForge 0.3 replaces the old five-tab/Next presentation with a new, purpose-built UI. The original **blue metallic dumbbell R** icon has been restored.

### Navigation and ownership

- **Dashboard / Arena** — immediate workout launch/resume, workout-history-driven level and streak, activity heatmap, muscle snapshot, and your next training.
- **Studio** — curated sessions, timed multi-day splits, custom routines, machine and exercise search, and the independent editable three-week program. Every plan can start an existing SwiftData-compatible workout.
- **Journey / Atlas** — anatomy-driven training-load and recovery visualizations, full activity calendar, milestones, recent sessions, and detailed history.
- **Dedicated Start button** — visible in the bottom dock; choose an empty workout, personal template, curated plan, or scheduled session.
- **Athlete control center** — profile, measurements, gyms, settings, imports, backup/export, and integrations.

### Entirely new workout UI

- **One exercise at a time** with explicit queue/jump controls, not an overfull swipe-enabled table.
- Weight and rep fields staged until edit completion to avoid a SwiftData write for every digit.
- Strength set logging and cardio interval metrics, previous-set values, one-tap copying, warm-ups, RPE, RIR, notes, sets, and per-exercise rest configuration.
- Rest timer runs in a separate view with iOS Live Activity and notifications; no whole-workout view invalidation on every timer tick.
- Completion shows actual earned XP and the anatomy of the trained muscles; advanced summaries and PR analysis remain available.

### App architecture

The old 10,000-line mixed SwiftUI entrypoint has been separated into:

- `Sources/Core/RepForgeEngine.swift` — unmodified persistence contracts, models, exercise catalog, metrics, media and service helpers.
- `Sources/RepForgeApp.swift` — lean app and link-routing entrypoint.
- `Sources/V3*.swift` — the new independent product screens and workout flow.
- `Sources/Legacy/AdvancedFeatures.swift` — less-frequent controls retained for feature and import/export compatibility while their core functions stay available.

The obsolete `Sources/Next*.swift` presentation files are removed. Existing bundle identifiers, models and storage paths are unchanged. No destructive migration is performed.

This release aims for minimum 44-point touch controls, system Dynamic Type where feasible, meaningful accessibility labels and reduced-motion-aware effects. The CI device compilation and simulator launch checks help catch regressions, but manual iPhone accessibility, frame pacing and data-restore tests remain necessary.

### Training and recovery

The **28 workouts** and **six splits** are general educational examples, not certified individual prescriptions. Time estimates include warm-up, work, rest and equipment changes. The recovery map is a heuristic based on logged workouts, **not a physiological measurement**.

## Data and privacy

RepForge is designed as a local-first application.

Core persistent user data is stored with **SwiftData**. Lightweight interface preferences use `UserDefaults`.

RepForge does not require an account to log workouts, view history, manage exercises or use the core training functionality.

There is currently no mandatory cloud service or subscription required to use the app.

## Sideloading

GitHub Actions builds an unsigned device IPA.

1. Open this repository's **Actions** tab.
2. Open the latest successful **iOS build** workflow.
3. Download the `RepForge-unsigned-ipa` artifact.
4. Sign the IPA with your own valid iOS signing method.
5. Install it on your iPhone.

Because the CI artifact is unsigned, it cannot be installed directly on a normal iPhone without signing.

When updating RepForge, installing over the existing app with a compatible bundle identity is preferable to deleting the app first. Make a backup before experimenting with signing identities or clean installs.

## Build locally

Requirements:

- macOS
- Xcode with iOS 17 SDK or newer
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

```bash
brew install xcodegen
xcodegen generate
open RepForge.xcodeproj
```

The repository uses `project.yml` as the XcodeGen project definition.

## Project structure

```text
RepForge/
├── Sources/                    # Main SwiftUI app and persistence
├── Shared/                     # Shared Live Activity models
├── RepForgeLiveActivity/       # Live Activity / Dynamic Island extension
├── RepForge/                   # Main app Info.plist and resources
├── .github/workflows/ios.yml   # Unsigned IPA CI build
└── project.yml                 # XcodeGen configuration
```

The app is built primarily with:

- Swift
- SwiftUI
- SwiftData
- Swift Charts
- ActivityKit / WidgetKit
- CoreBluetooth

## Development philosophy

RepForge aims to remain useful without artificial feature restrictions.

The focus is on:

- fast workout entry
- reliable data ownership
- practical progress tracking
- migration from other workout apps
- native iOS integration
- a clean sideloading workflow
- avoiding recurring costs for features that can run entirely on-device

## Support RepForge

RepForge is free to use. If the project is useful to you and you want to support continued development, donations are optional and appreciated.

### ☕ [Support RepForge on Ko-fi](https://ko-fi.com/flippyy)

No core feature is unlocked by donating.

## Current status

RepForge is under active development. Expect features, persistence details and UI to continue evolving.

If you are testing development builds, keeping a recent full backup is recommended.
