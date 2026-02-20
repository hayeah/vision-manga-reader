import SwiftUI

struct ReaderToolbar: View {
    @Bindable var book: MangaBook
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: 16) {
            // Spread offset buttons
            HStack(spacing: 8) {
                Button {
                    book.shiftOffset(by: -1)
                } label: {
                    Text("-1")
                }
                .disabled(book.offset <= 0)

                Text("Offset: \(book.offset)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                Button {
                    book.shiftOffset(by: 1)
                } label: {
                    Text("+1")
                }
                .disabled(book.offset >= book.pageURLs.count - 1)
            }

            Spacer()

            // Navigation + page indicator
            HStack(spacing: 12) {
                Button {
                    book.previousSpread()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(book.currentSpreadIndex <= 0)

                if book.spreadCount > 0 {
                    Text("\(book.currentSpreadIndex + 1) / \(book.spreadCount)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Button {
                    book.nextSpread()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(book.currentSpreadIndex >= book.spreadCount - 1)
            }

            Spacer()

            // Duplicate window
            Button {
                duplicateWindow()
            } label: {
                Label("Duplicate", systemImage: "plus.rectangle.on.rectangle")
            }
            .help("Open in new window")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func duplicateWindow() {
        guard let folderURL = book.folderURL else { return }
        guard let windowID = try? ReaderWindowID(
            folderURL: folderURL,
            spreadIndex: book.currentSpreadIndex,
            offset: book.offset
        ) else { return }
        openWindow(id: "reader", value: windowID)
    }
}
