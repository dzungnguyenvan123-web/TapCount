# TapCount

A lightweight, native macOS click-counter app for tracking daily habits and recurring tasks—such as glasses of water, stretch breaks, or coffee cups—right from your Menu Bar or a dedicated desktop window.

## Features

- **Menu Bar + Main Window**: Click the TapCount icon in the macOS menu bar for instant 1-click tapping anywhere, or open the main window to manage tasks and explore history.
- **Per-Task Auto-Reset Schedules**: Configure each task to auto-reset **Daily** (at local midnight), **Weekly**, or **Never** (continuous count).
- **Goals & Progress Bars**: Set an optional target count per period with visual progress indicators and goal completion badges.
- **Mistake-Safe Controls**: Decrement (`-1`) or **Undo (`⌘Z`)** accidental taps, resets, or deletions.
- **History & Statistics**: Built-in inspector with 14-day and 8-week bar charts, streaks, 7-day averages, all-time totals, and a timestamped tap log.
- **Customizable Tasks**: Pick from 12 colors and 32 SF Symbols for each task.
- **Launch at Login**: Optional macOS startup toggle in Settings (`⌘,`) powered by `SMAppService`.
- **Local Persistence**: Automatically saved to `~/Library/Application Support/TapCount/store.json`.

## Build, Test & Run

Requires macOS 14+ and Swift 6+ (no Xcode project required).

```bash
# Run unit tests
swift test

# Build, package into TapCount.app, and launch
./Scripts/compile_and_run.sh

# Package only (outputs ./TapCount.app)
./Scripts/package_app.sh release
```

## Keyboard Shortcuts

- `⌘N` — Create a new task
- `⌘Z` — Undo the last tap, decrement, reset, or deletion
- `⌘I` — Toggle the History & Stats Inspector
- `⌘,` — Open Settings (Launch at Login, Menu Bar badge, Data folder)
