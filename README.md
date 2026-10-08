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

## Training experience

### Home and motivation

The main navigation is **Train / Plans / Exercises / History / Profile**. Settings live in the Profile toolbar.

- Real workout-history-based XP and level progression. Points are earned from completed sessions and set entries, not manual check-ins.
- Milestone cards and weekly consistency streaks derived from stored training history; no new account or persistent progression schema.
- An interactive, 13-week session-activity heatmap and today's anatomical muscle activation preview.
- During a workout, the live anatomical heatmap illuminates muscles as sets are logged.
- Workout summaries display earned XP, newly earned milestones and a workout-specific muscle map.

### Workout and training-plan library

**Plans** is a separate area containing 28 goal-oriented training examples, six multi-session splits and the original, editable three-week program.

- Filter ready-made workouts by goal or experience level.
- Review exercise order, prescribed sets, rep ranges, optional cues and estimated training time.
- Start immediately, save a session as a custom template or schedule it for later.
- The original three-week program retains its saved edits, sharing, scheduling and manual-reset functionality.
- Estimated time includes warm-up, work, suggested rest and station transitions. Equipment availability and actual duration will vary.

The workouts are original general-purpose examples and are **not represented as certified professional prescriptions**, medical guidance or customized coaching. For general training guidance see the [2026 ACSM resistance-training position stand](https://acsm.org/science-spotlight-acsm-releases-new-position-stand-on-resistance-training/) and [NSCA training-frequency guidance](https://www.nsca.com/education/articles/kinetic-select/determination-of-resistance-training-frequency/).

### Muscle intelligence

- Front/back anatomical heatmap of effective muscle sets for this week, last week or the previous 28 days.
- Toggle to an estimated-recovery view computed from prior sessions.
- Tap muscle breakdown rows for additional context.
- The exercise detail page shows primary and assisting muscles anatomically.
- Recovery is a heuristic inferred from logged sets and elapsed time—not a physiological or medical measurement.

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
