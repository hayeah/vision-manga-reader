import SwiftUI

@main
struct VisionMangaReaderApp: App {
    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
        }

        WindowGroup(id: "reader", for: ReaderWindowID.self) { $windowID in
            if let windowID {
                DuplicatedReaderView(windowID: windowID)
            } else {
                Text("No reader data")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
