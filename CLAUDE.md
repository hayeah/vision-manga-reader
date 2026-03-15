# Vision Manga Reader

## Build

- Target hardware: Apple Vision Pro (visionOS device, not simulator)
- Device ID: `00008142-000251DC2EF1401C`
- Use Release configuration with no dSYM for better runtime performance:

```sh
xcodebuild -project VisionMangaReader.xcodeproj \
  -scheme VisionMangaReader \
  -configuration Release \
  -destination 'platform=visionOS,id=00008142-000251DC2EF1401C' \
  DEBUG_INFORMATION_FORMAT=dwarf \
  build
```

- Code signing from CLI requires keychain to be unlocked. If `errSecInternalComponent` occurs, build from Xcode GUI instead.
