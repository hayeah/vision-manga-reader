import SwiftUI

enum OrnamentPanel {
    case series
    case volumes
}

struct PanelListRowButton<Accessory: View>: View {
    let title: String
    let isCurrent: Bool
    let verticalPadding: CGFloat
    let action: () -> Void
    @ViewBuilder let accessory: () -> Accessory

    private let cornerRadius: CGFloat = 3

    private var rowShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                    .lineLimit(1)
                    .font(.callout)
                    .foregroundStyle(isCurrent ? .primary : .secondary)

                Spacer(minLength: 0)

                accessory()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, verticalPadding)
            .contentShape(rowShape)
            // Keep the selected fill and the gaze highlight on the same clipped shape.
            // visionOS applies the hover treatment on top, so the selected row gets a
            // stronger version of the same rectangle when looked at.
            .background(isCurrent ? .white.opacity(0.14) : .clear, in: rowShape)
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .clipShape(rowShape)
    }
}

struct ReaderView: View {
    var appState: AppState
    var windowID: UUID
    @Bindable var book: MangaBook
    @Binding var currentVolumeID: String?

    private let panelOrnamentTrailingInset: CGFloat = 84
    private let panelMaxWidth: CGFloat = 320
    private let panelMaxHeight: CGFloat = 420

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
        .ornament(
            visibility: expandedPanel == nil ? .hidden : .visible,
            attachmentAnchor: .scene(.leading),
            contentAlignment: .trailing
        ) {
            panelOrnament
        }
        .ornament(visibility: .automatic, attachmentAnchor: .scene(.leading), contentAlignment: .trailing) {
            ornamentButtons
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

    private var panelOrnament: some View {
        Group {
            switch expandedPanel {
            case .series:
                seriesPanel
            case .volumes:
                volumesPanel
            case nil:
                EmptyView()
            }
        }
        .glassBackgroundEffect()
        .padding(.trailing, panelOrnamentTrailingInset)
    }

    private var seriesPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(library.series) { s in
                    let isCurrent = currentSeriesID == s.id
                    PanelListRowButton(
                        title: s.title,
                        isCurrent: isCurrent,
                        verticalPadding: 8,
                        action: { openSeries(s) }
                    ) {
                        EmptyView()
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 20)
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: panelMaxWidth, maxHeight: panelMaxHeight, alignment: .topLeading)
    }

    private var volumesPanel: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if let currentSeries {
                        ForEach(currentSeries.volumes) { vol in
                            let isCurrent = vol.id == currentVolumeID
                            PanelListRowButton(
                                title: vol.title,
                                isCurrent: isCurrent,
                                verticalPadding: 6,
                                action: { openVolume(vol) }
                            ) {
                                if let prog = library.history.progress[vol.id], prog.isCompleted {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.caption)
                                }
                            }
                            .id(vol.id)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 20)
            }
            .fixedSize(horizontal: true, vertical: false)
            .frame(maxWidth: panelMaxWidth, maxHeight: panelMaxHeight, alignment: .topLeading)
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
        .glassBackgroundEffect()
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

        let spreadIndex: Int
        if let progress = library.history.progress[vol.id] {
            spreadIndex = min(progress.lastSpreadIndex, max(0, book.spreadCount - 1))
        } else {
            spreadIndex = 0
        }
        book.currentSpreadIndex = spreadIndex
        appState.updateWindowVolume(windowID: windowID, volumeID: vol.id, spreadIndex: spreadIndex)
    }
}
