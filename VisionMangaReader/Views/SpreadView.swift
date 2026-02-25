import SwiftUI

struct SpreadView: View {
    @Bindable var book: MangaBook

    @State private var dragOffset: CGFloat = 0
    @State private var wasSinglePage: Bool = false

    private var pages: (right: Int?, left: Int?) {
        book.pagesForSpread(book.currentSpreadIndex)
    }

    private var isSinglePage: Bool {
        pages.right != nil && pages.left == nil
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // Left page first in HStack (later page, higher number)
                if let leftIdx = pages.left {
                    PageView(url: book.pageURLs[leftIdx])
                        .frame(width: geo.size.width / 2, height: geo.size.height, alignment: .trailing)
                        .clipped()
                }

                // Right page second in HStack (earlier page, lower number)
                if let rightIdx = pages.right {
                    PageView(url: book.pageURLs[rightIdx])
                        .frame(
                            width: isSinglePage ? geo.size.width : geo.size.width / 2,
                            height: geo.size.height,
                            alignment: isSinglePage ? .center : .leading
                        )
                        .clipped()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .offset(x: dragOffset)
            .gesture(
                DragGesture(minimumDistance: 50)
                    .onChanged { value in
                        dragOffset = value.translation.width * 0.3
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 100
                        withAnimation(.easeInOut(duration: 0.25)) {
                            if value.translation.width > threshold {
                                // Swipe right → next spread (RTL manga: advance)
                                book.nextSpread()
                            } else if value.translation.width < -threshold {
                                // Swipe left → previous spread (RTL manga: go back)
                                book.previousSpread()
                            }
                            dragOffset = 0
                        }
                    }
            )
        }
        .background(.black)
        .animation(isSinglePage != wasSinglePage ? nil : .easeInOut(duration: 0.25), value: book.currentSpreadIndex)
        .onChange(of: book.currentSpreadIndex) {
            wasSinglePage = isSinglePage
        }
    }
}
