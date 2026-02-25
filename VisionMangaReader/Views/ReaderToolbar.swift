import SwiftUI

struct ReaderToolbar: View {
    @Bindable var book: MangaBook
    @Environment(\.openWindow) private var openWindow
    var onOpenFolder: () -> Void = {}

    var body: some View {
        HStack(spacing: 16) {
            Button {
                book.toggleShift()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .symbolVariant(book.isCurrentSequenceShifted ? .fill : .none)
            }
            .help("Toggle page pairing offset")
            .disabled(!book.canToggleShift)

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

            HStack(spacing: 12) {
                // Open folder
                Button {
                    onOpenFolder()
                } label: {
                    Label("Open", systemImage: "folder")
                }
                .help("Open another folder")

                // Duplicate window
                Button {
                    duplicateWindow()
                } label: {
                    Label("Duplicate", systemImage: "plus.rectangle.on.rectangle")
                }
                .help("Open in new window")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func duplicateWindow() {
        guard let folderURL = book.folderURL else { return }
        guard let windowID = try? ReaderWindowID(
            folderURL: folderURL,
            spreadIndex: book.currentSpreadIndex
        ) else { return }
        openWindow(id: "reader", value: windowID)
    }
}
