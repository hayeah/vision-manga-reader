---
overview: Spec for iCloud manga library integration — two-level series/volume browsing, reading history, and auto-advance to next volume.
repo: ~/github.com/hayeah/vision-manga-reader
tags:
  - spec
---

# iCloud Manga Library Integration

## Problem

The app currently opens one folder at a time via the system file picker. There's no awareness of the manga directory structure, no history of what you've read, and no way to quickly switch series or advance to the next volume.

## Directory Structure

The iCloud manga root at `~/Library/Mobile Documents/com~apple~CloudDocs/manga` has a consistent two-level layout:

```
manga/
  烙印战士/           ← series
    info.json         ← metadata (title, authors, genres, cover_url, chapters)
    第01卷/           ← volume (contains images)
    第02卷/
    ...
  火之鸟/
    info.json
    第01卷/
    ...
```

- **Level 1**: Series folders (may contain an `info.json`, but don't rely on it)
- **Level 2**: Volume folders — each contains page images (jpg/png/webp)
- Volumes sort naturally via `localizedStandardCompare` (第01卷 < 第02卷 < ...)
- Some series have extra chapters beyond volumes (第325回, etc.) — these are also just folders with images
- The two-level structure is the **primary source of truth** — `info.json` is optional enrichment, not required

## Feature Overview

- **Library browser** — replace the single "Open Folder" picker with a two-level series/volume browser
- **Reading history** — track which volumes have been opened and reading progress
- **Auto-advance** — when finishing a volume, prompt to open the next one
- **Recent series** — quick access to recently read series

---

## Data Model

### MangaLibrary (`@Observable`)

Owns the root URL bookmark and enumerates the directory tree. Does NOT load images — that stays in `MangaBook`.

```swift
@Observable
class MangaLibrary {
    var rootURL: URL?                      // bookmarked iCloud manga root
    var series: [MangaSeries] = []         // enumerated from rootURL
    var recentSeriesIDs: [String] = []     // ordered by last-read time
    var readingHistory: [String: VolumeProgress] = []  // key: volume path relative to root

    func scan()                            // enumerate root → series → volumes
    func seriesByID(_ id: String) -> MangaSeries?
}
```

### MangaSeries

```swift
struct MangaSeries: Identifiable {
    let id: String              // folder name (e.g. "烙印战士")
    let url: URL
    let title: String           // folder name (info.json title used only if present)
    var volumes: [MangaVolume]  // sorted naturally by folder name
}
```

Series are discovered purely by enumerating subdirectories of the root. If an `info.json` exists, its `title` field can override the folder name — but the app must work identically without it.

### MangaVolume

```swift
struct MangaVolume: Identifiable {
    let id: String              // relative path: "烙印战士/第01卷"
    let url: URL
    let title: String           // folder name (e.g. "第01卷")
    let seriesID: String        // parent series id
    var sortIndex: Int          // position within series
}
```

### VolumeProgress (Codable)

```swift
struct VolumeProgress: Codable {
    var lastSpreadIndex: Int
    var totalSpreads: Int
    var lastReadDate: Date
    var isCompleted: Bool       // reached the last spread
}
```

### Persistence

- **Root bookmark**: `UserDefaults` (same pattern as current `FolderAccess`)
- **Reading history**: JSON file in app's documents directory, keyed by relative volume path
- **Recent series**: stored alongside reading history

No CoreData/SwiftData needed — the data is small and append-mostly.

---

## UI Architecture: Two Windows

The UI uses two separate visionOS windows to avoid deep navigation hierarchies.

### Window 1: Series List (sidebar window)

A narrow, compact window showing just series names in a vertical scrollable list.

```
┌──────────────┐
│ 烙印战士   ← │  ← highlighted = currently reading
│ 火之鸟      │
│ 桐人传奇    │
│ 姊嫁物语    │
│ 电影少女    │
│ 鬼灭之刃    │
└──────────────┘
```

- Plain vertical list of series titles — no covers, no metadata, just names
- The currently active series is highlighted
- Tapping a series title → opens its **first volume** in the reader window (or resumes from last-read volume if history exists)
- At the bottom or top: a "Select Folder" button for initial setup / changing root
- This window can be shown/hidden independently of the reader

### Window 2: Reader (main window)

The existing reader view (`SpreadView` + toolbar), plus a **hidden right-edge volume drawer**.

#### Volume Drawer (right edge)

A slim drawer that slides in from the right edge of the reader window. Contains one **numbered dot per volume** in the current series.

```
                              ┌───┐
  ┌─────────────────────────┐ │ 1 │
  │                         │ │ 2 │
  │     SpreadView          │ │ 3 │  ← dot strip
  │     (manga pages)       │ │ ●4│  ← filled = current volume
  │                         │ │ 5 │
  │                         │ │ 6 │
  └─────────────────────────┘ │ 7 │
  ┌─────────────────────────┐ │ 8 │
  │     ReaderToolbar       │ │ 9 │
  └─────────────────────────┘ └───┘
```

- Each dot shows its volume number (1, 2, 3...)
- Current volume is visually distinct (filled/highlighted)
- Completed volumes could use a different style (e.g. checkmark or dimmed)
- Tapping a dot → loads that volume into `MangaBook`
- The drawer is hidden by default — revealed by a swipe or toggle button in the toolbar
- Keeps the reader uncluttered while giving quick volume switching without leaving the reader

### End-of-Volume Prompt

When the user reaches the last spread:

- A non-intrusive overlay: "Open 第XX卷?" with **Next** and **Dismiss**
- If no next volume: "Volume complete" with **Back to Library**
- Does NOT block navigation (user can still swipe back to re-read)

---

## Navigation Flow

```
App Launch
  ↓
Has saved root bookmark?
  ├─ No  → File picker (one-time, select manga root)
  └─ Yes → Series List window + Reader window (last-read volume)

Series List window:
  tap series → Reader loads first (or last-read) volume of that series
             → Volume drawer updates with new series' volumes

Reader window:
  volume drawer dot tap → loads that volume
  end of volume → prompt to open next
  toolbar "Library" button → show/hide Series List window
```

### Integration with Existing Code

- The app already uses two `WindowGroup`s (`"main"` and `"reader"`). Repurpose `"main"` as the series list, keep `"reader"` as the reader.
- `MangaBook` stays as-is — it loads a single folder's images. `MangaLibrary` hands it volume URLs.
- The volume drawer is an overlay/sheet within the reader window, not a separate window.
- Bookmark handling: bookmark the **root** once. All volume URLs derive from it (same security scope).

---

## Implementation Plan

### Phase 1: Core Library Model

- `MangaLibrary` class with root bookmark, scan, series/volume enumeration
- Optionally parse `info.json` for display title (not required — folder names are sufficient)
- `VolumeProgress` persistence (JSON file in app documents)
- Unit-testable without UI

### Phase 2: Series List Window

- Compact vertical list of series names
- Tapping → loads first volume into reader
- Highlight currently active series
- "Select Folder" button for root setup

### Phase 3: Volume Drawer

- Right-edge drawer in reader window with numbered dots
- Tap dot → switch volume within same series
- Toggle visibility from toolbar

### Phase 4: Reading Progress & Auto-Advance

- Save progress on spread change (debounced)
- Mark volume completed on reaching last spread
- End-of-volume prompt overlay
- Resume from last-read volume when tapping a series
- **Only the primary reader window tracks progress** — duplicated windows are stateless viewers (frozen at the position they were created, never write back to `VolumeProgress`)

---

## Security-Scoped Resource Handling

Key insight: bookmarking the **root** manga directory grants access to all subdirectories. This simplifies the current per-folder bookmark approach.

```
Root bookmark → startAccessingSecurityScopedResource()
  → enumerate series/volumes (no extra bookmarks)
  → load volume images (already within scope)
  → stopAccessingSecurityScopedResource() on app background/exit
```

The existing `FolderAccess.saveBookmark()` / `restoreBookmark()` can be reused by pointing at the root instead of a volume folder.

---

## Edge Cases

- **info.json missing**: Normal case — use folder name as series title
- **Empty series folder**: Show series but with "No volumes" indicator
- **Volumes with no images**: Show in list but display error when opened
- **iCloud files not downloaded**: Check before opening, show download prompt
- **Root folder moved/deleted**: Clear bookmark, show re-select prompt
- **Mixed content in folders** (non-volume subdirs, loose files): Ignore non-directory entries at level 2; only enumerate folders containing image files
