# Vision Manga Reader

A visionOS manga reader for Apple Vision Pro with intelligent two-page spread layout and right-to-left (RTL) reading support.

![Platform](https://img.shields.io/badge/platform-visionOS-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-green)

## Features

- **Smart spread layout** — auto-detects single vs. paired pages from image dimensions. Landscape images display solo; portrait images are paired into two-page spreads.
- **RTL reading order** — proper right-to-left pagination for Japanese manga. Swipe right to advance, swipe left to go back.
- **Page shift** — nudge the spread alignment by one page when the pairing is off.
- **Multi-window** — open duplicate reader windows to view different parts of the same volume simultaneously.
- **Image performance** — async loading with 200MB cache, downsampling for large images, EXIF orientation handling.
- **Persistent state** — remembers the last opened folder via security-scoped bookmarks.
- **Subject extraction** — Vision framework integration to isolate foreground subjects from manga panels.

## How It Works

- Select a folder containing manga page images (JPG, PNG, WebP)
- Pages are sorted and automatically arranged into spreads
- Navigate with swipe gestures or toolbar buttons
- Spread counter shows current position

## Project Structure

```
VisionMangaReader/
├── Models/
│   ├── MangaBook.swift          # Core data model & spread layout logic
│   └── ReaderWindowID.swift     # Multi-window state management
├── Views/
│   ├── ContentView.swift        # Main UI & folder picker
│   ├── SpreadView.swift         # Two-page spread display
│   ├── PageView.swift           # Single page image rendering
│   ├── ReaderToolbar.swift      # Navigation controls
│   └── DuplicatedReaderView.swift
├── Services/
│   ├── ImageLoader.swift        # Async loading & caching
│   ├── FolderAccess.swift       # Security-scoped bookmarks
│   └── SubjectExtractor.swift   # Vision framework integration
└── VisionMangaReaderApp.swift
```

## Requirements

- Xcode 15+
- visionOS 1.0+ SDK
- Apple Vision Pro (device or simulator)

## License

MIT
