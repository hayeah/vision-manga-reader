import Foundation
import Observation
import SwiftUI

@Observable
class AppState {
    let library = MangaLibrary()

    private static let savedWindowsKey = "OpenReaderWindows"
    private var didBoot = false

    // MARK: - Boot

    var hasRoot: Bool {
        UserDefaults.standard.data(forKey: "MangaLibraryRootBookmark") != nil
    }

    func boot() {
        guard !didBoot else { return }
        didBoot = true
        library.loadHistory()
        let _ = library.restoreRoot()
    }

    // MARK: - First window state

    var firstWindowState: ReaderWindowState? {
        let saved = loadSavedWindows()
        if let first = saved.first {
            return first
        }

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
        return state
    }

    func openRemainingWindows(openWindow: OpenWindowAction) {
        let saved = loadSavedWindows()
        for state in saved.dropFirst() {
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

    // MARK: - Persistence

    private func loadSavedWindows() -> [ReaderWindowState] {
        guard let data = UserDefaults.standard.data(forKey: Self.savedWindowsKey),
              let windows = try? JSONDecoder().decode([ReaderWindowState].self, from: data) else {
            return []
        }
        return windows
    }

    private func saveSavedWindows(_ windows: [ReaderWindowState]) {
        guard let data = try? JSONEncoder().encode(windows) else { return }
        UserDefaults.standard.set(data, forKey: Self.savedWindowsKey)
    }

    private func addSavedWindow(_ state: ReaderWindowState) {
        var windows = loadSavedWindows()
        windows.removeAll { $0.id == state.id }
        windows.append(state)
        saveSavedWindows(windows)
    }

    private func removeSavedWindow(id: UUID) {
        var windows = loadSavedWindows()
        windows.removeAll { $0.id == id }
        saveSavedWindows(windows)
    }
}
