import SwiftUI

struct ReaderToolbar: View {
    @Bindable var book: MangaBook

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

            if book.spreadCount > 0 {
                Text("\(book.currentSpreadIndex + 1) / \(book.spreadCount)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
