import Foundation
import Observation
import SwiftUI

@Observable
class AppState {
    let library = MangaLibrary()

    private var didBoot = false
    private var initialWindowState: ReaderWindowState?
    private var didPrepareInitialWindowState = false
    private var didRestoreSavedWindows = false
    private var pendingRemainingWindowRestore = false

    // MARK: - Boot

    var hasRoot: Bool {
        UserDefaults.standard.data(forKey: "MangaLibraryRootBookmark") != nil
    }

    func boot() {
        guard !didBoot else { return }
        didBoot = true
        let _ = library.restoreRoot()
        library.loadState()
    }

    // MARK: - First window state

    func prepareInitialWindowState() -> ReaderWindowState? {
        boot()
        if didPrepareInitialWindowState {
            return initialWindowState
        }
        didPrepareInitialWindowState = true

        if !didRestoreSavedWindows,
           let first = library.history.windows.first {
            didRestoreSavedWindows = true
            pendingRemainingWindowRestore = true
            guard let rootURL = library.rootURL else { return nil }
            initialWindowState = try? ReaderWindowState(
                id: first.id,
                rootURL: rootURL,
                volumeID: first.volumeID,
                spreadIndex: first.spreadIndex
            )
            return initialWindowState
        }

        didRestoreSavedWindows = true

        // No saved windows — create one from last-read or first volume
        guard let rootURL = library.rootURL else { return nil }

        let vol: MangaVolume?
        if let lastID = library.history.lastActiveVolumeID,
           let lastVol = library.volume(id: lastID) {
            vol = lastVol
        } else {
            vol = library.series.first?.volumes.first
        }
        guard let vol else { return nil }

        let spreadIndex = library.history.progress[vol.id]?.lastSpreadIndex ?? 0

        guard let state = try? ReaderWindowState(
            rootURL: rootURL,
            volumeID: vol.id,
            spreadIndex: spreadIndex
        ) else { return nil }

        addSavedWindow(state)
        initialWindowState = state
        return initialWindowState
    }

    func openRemainingWindowsIfNeeded(openWindow: OpenWindowAction) {
        guard pendingRemainingWindowRestore else { return }
        pendingRemainingWindowRestore = false
        guard let rootURL = library.rootURL else { return }
        for saved in library.history.windows.dropFirst() {
            guard let state = try? ReaderWindowState(
                id: saved.id,
                rootURL: rootURL,
                volumeID: saved.volumeID,
                spreadIndex: saved.spreadIndex
            ) else { continue }
            openWindow(id: "reader", value: state)
        }
    }

    // MARK: - Window management

    func openNewReader(volumeID: String, spreadIndex: Int = 0, openWindow: OpenWindowAction) {
        guard let rootURL = library.rootURL else { return }
        guard let state = try? ReaderWindowState(
            rootURL: rootURL,
            volumeID: volumeID,
            spreadIndex: spreadIndex
        ) else { return }
        addSavedWindow(state)
        openWindow(id: "reader", value: state)
    }

    func openSeriesReader(_ series: MangaSeries, openWindow: OpenWindowAction) {
        let vol: MangaVolume?
        if let lastRead = library.lastReadVolume(forSeries: series.id) {
            vol = lastRead
        } else {
            vol = series.volumes.first
        }
        guard let vol else { return }

        let spreadIndex = library.history.progress[vol.id]?.lastSpreadIndex ?? 0
        openNewReader(volumeID: vol.id, spreadIndex: spreadIndex, openWindow: openWindow)
    }

    func registerWindow(_ state: ReaderWindowState) {
        addSavedWindow(state)
    }

    func unregisterWindow(id: UUID) {
        removeSavedWindow(id: id)
    }

    func updateWindowVolume(windowID: UUID, volumeID: String, spreadIndex: Int) {
        guard let idx = library.history.windows.firstIndex(where: { $0.id == windowID }) else {
            return
        }

        let saved = library.history.windows[idx]
        guard saved.volumeID != volumeID || saved.spreadIndex != spreadIndex else {
            return
        }

        library.history.windows[idx].volumeID = volumeID
        library.history.windows[idx].spreadIndex = spreadIndex
        library.saveState()
    }

    // MARK: - Window persistence

    private func addSavedWindow(_ state: ReaderWindowState) {
        let saved = SavedWindow(
            id: state.id,
            volumeID: state.volumeID,
            spreadIndex: state.spreadIndex
        )

        if let existing = library.history.windows.first(where: { $0.id == state.id }),
           existing.id == saved.id,
           existing.volumeID == saved.volumeID,
           existing.spreadIndex == saved.spreadIndex {
            return
        }

        library.history.windows.removeAll { $0.id == state.id }
        library.history.windows.append(saved)
        library.saveState()
    }

    private func removeSavedWindow(id: UUID) {
        guard library.history.windows.contains(where: { $0.id == id }) else {
            return
        }
        library.history.windows.removeAll { $0.id == id }
        library.saveState()
    }
}
