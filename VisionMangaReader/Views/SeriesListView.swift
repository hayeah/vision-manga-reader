import SwiftUI
import UniformTypeIdentifiers

struct SeriesListView: View {
    var library: MangaLibrary
    var currentVolumeID: String?
    var onSelectSeries: (MangaSeries) -> Void

    @State private var showFolderPicker = false

    private var currentSeriesID: String? {
        currentVolumeID?.components(separatedBy: "/").first
    }

    var body: some View {
        VStack(spacing: 0) {
            if library.series.isEmpty {
                emptyState
            } else {
                seriesList
            }
        }
        .frame(minWidth: 200, idealWidth: 260, maxWidth: 320)
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [UTType.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                library.setRoot(url)
            }
        }
    }

    private var seriesList: some View {
        List {
            ForEach(library.series) { s in
                Button {
                    onSelectSeries(s)
                } label: {
                    HStack {
                        Text(s.title)
                            .lineLimit(1)
                            .foregroundStyle(s.id == currentSeriesID ? .primary : .secondary)

                        Spacer()

                        if let prog = readingIndicator(for: s) {
                            Text(prog)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    s.id == currentSeriesID
                        ? Color.accentColor.opacity(0.15)
                        : Color.clear
                )
            }

            Section {
                Button {
                    showFolderPicker = true
                } label: {
                    Label("Change Folder", systemImage: "folder")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("No manga found")
                .foregroundStyle(.secondary)

            Button("Select Folder") {
                showFolderPicker = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func readingIndicator(for s: MangaSeries) -> String? {
        let readCount = s.volumes.filter { library.history.progress[$0.id]?.isCompleted == true }.count
        if readCount > 0 {
            return "\(readCount)/\(s.volumes.count)"
        }
        return nil
    }
}
