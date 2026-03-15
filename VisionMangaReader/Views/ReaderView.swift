import SwiftUI

enum OrnamentPanel {
    case series
    case volumes
}

struct ReaderView: View {
    var appState: AppState
    @Bindable var book: MangaBook
    @Binding var currentVolumeID: String?

    @State private var showEndOfVolumePrompt = false
    @State private var expandedPanel: OrnamentPanel?
    @Environment(\.openWindow) private var openWindow

    private var library: MangaLibrary { appState.library }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            SpreadView(book: book)

            if showEndOfVolumePrompt {
                endOfVolumePrompt
            }

            if book.spreadCount > 0 {
                Text("\(book.currentSpreadIndex + 1) / \(book.spreadCount)")
                    .monospacedDigit()
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 20)
                    .padding(.bottom, 16)
            }
        }
        .ornament(visibility: .automatic, attachmentAnchor: .scene(.leading), contentAlignment: .trailing) {
            ornamentContent
        }
        .onChange(of: book.currentSpreadIndex) { _, newIndex in
            guard let currentVolumeID else { return }
            library.updateProgress(
                volumeID: currentVolumeID,
                spreadIndex: newIndex,
                totalSpreads: book.spreadCount
            )
            if newIndex >= book.spreadCount - 1 {
                showEndOfVolumePrompt = true
            } else {
                showEndOfVolumePrompt = false
            }
        }
    }

    // MARK: - Ornament

    private func togglePanel(_ panel: OrnamentPanel) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedPanel == panel {
                expandedPanel = nil
            } else {
                expandedPanel = panel
            }
        }
    }

    private func duplicateWindow() {
        guard let currentVolumeID else { return }
        appState.openNewReader(
            volumeID: currentVolumeID,
            spreadIndex: book.currentSpreadIndex,
            openWindow: openWindow
        )
    }

    private var ornamentContent: some View {
        HStack(alignment: .top, spacing: 0) {
            if let expandedPanel {
                switch expandedPanel {
                case .series:
                    seriesPanel
                case .volumes:
                    volumesPanel
                }
            }

            ornamentButtons
        }
        .fixedSize(horizontal: false, vertical: true)
        .glassBackgroundEffect()
    }

    private var seriesPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(library.series) { s in
                    let isCurrent = currentSeriesID == s.id
                    Button {
                        openSeries(s)
                    } label: {
                        Text(s.title)
                            .lineLimit(1)
                            .foregroundStyle(isCurrent ? .primary : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            isCurrent ? Color.accentColor.opacity(0.15) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 20)
        }
        .frame(width: 240, alignment: .top)
    }

    private var volumesPanel: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 4) {
                    if let currentSeries {
                        ForEach(currentSeries.volumes) { vol in
                            let isCurrent = vol.id == currentVolumeID
                            Button {
                                openVolume(vol)
                            } label: {
                                HStack {
                                    Text(vol.title)
                                        .lineLimit(1)
                                        .font(.callout)
                                        .foregroundStyle(isCurrent ? .primary : .secondary)

                                    Spacer()

                                    if let prog = library.history.progress[vol.id] {
                                        if prog.isCompleted {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.green)
                                                .font(.caption)
                                        }
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    isCurrent ? Color.accentColor.opacity(0.15) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 6)
                                )
                            }
                            .buttonStyle(.plain)
                            .id(vol.id)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 20)
            }
            .frame(width: 200, alignment: .top)
            .onAppear {
                if let currentVolumeID {
                    proxy.scrollTo(currentVolumeID, anchor: .center)
                }
            }
            .onChange(of: currentVolumeID) { _, newID in
                if let newID {
                    withAnimation {
                        proxy.scrollTo(newID, anchor: .center)
                    }
                }
            }
        }
    }

    private var ornamentButtons: some View {
        VStack(spacing: 12) {
            Button { togglePanel(.volumes) } label: {
                Label("Volumes", systemImage: "list.number")
            }
            .help("Show volume list")

            Button { togglePanel(.series) } label: {
                Label("Library", systemImage: "books.vertical")
            }
            .help("Show series list")

            Button { duplicateWindow() } label: {
                Label("Duplicate", systemImage: "plus.rectangle.on.rectangle")
            }
            .help("Open in new window")

            Divider()

            Button { book.toggleShift() } label: {
                Label("Toggle page pairing", systemImage: "arrow.left.arrow.right")
                    .symbolVariant(book.isCurrentSequenceShifted ? .fill : .none)
            }
            .help("Toggle page pairing offset")
            .disabled(!book.canToggleShift)
        }
        .labelStyle(.iconOnly)
        .padding(8)
    }

    // MARK: - End of volume prompt

    private var endOfVolumePrompt: some View {
        HStack(spacing: 12) {
            if let currentVolumeID, let nextVol = library.nextVolume(after: currentVolumeID) {
                Text("Open \(nextVol.title)?")
                    .font(.subheadline)
                Button("Next") {
                    openVolume(nextVol)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                Text("Volume complete")
                    .font(.subheadline)
            }
            Button("Dismiss") {
                showEndOfVolumePrompt = false
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.top, 12)
    }

    // MARK: - Helpers

    private var currentSeriesID: String? {
        currentVolumeID?.components(separatedBy: "/").first
    }

    private var currentSeries: MangaSeries? {
        guard let currentVolumeID else { return nil }
        return library.seriesFor(volumeID: currentVolumeID)
    }

    func openSeries(_ s: MangaSeries) {
        if let lastRead = library.lastReadVolume(forSeries: s.id) {
            openVolume(lastRead)
        } else if let first = s.volumes.first {
            openVolume(first)
        }
    }

    func openVolume(_ vol: MangaVolume) {
        showEndOfVolumePrompt = false
        book.loadPages(from: vol.url)
        currentVolumeID = vol.id

        if let progress = library.history.progress[vol.id] {
            book.currentSpreadIndex = min(progress.lastSpreadIndex, max(0, book.spreadCount - 1))
        }
    }
}
