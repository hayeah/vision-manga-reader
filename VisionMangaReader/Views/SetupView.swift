import SwiftUI
import UniformTypeIdentifiers

struct SetupView: View {
    var appState: AppState
    @Binding var windowState: ReaderWindowState?
    @State private var showFilePicker = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.pages")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("VisionMangaReader")
                .font(.largeTitle)

            Text("Select your manga folder")
                .foregroundStyle(.secondary)

            Button("Select Folder") {
                showFilePicker = true
            }
            .buttonStyle(.borderedProminent)
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                appState.library.setRoot(url)
                // After setting root, create a reader for the first volume
                if let first = appState.prepareInitialWindowState() {
                    windowState = first
                }
            }
        }
        .onAppear {
            appState.boot()
        }
    }
}
