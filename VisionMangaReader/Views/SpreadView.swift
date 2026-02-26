import SwiftUI

struct SpreadView: View {
    @Bindable var book: MangaBook

    @State private var dragOffset: CGFloat = 0
    @State private var wasSinglePage: Bool = false
    @State private var leftHalfHovered = false
    @State private var leftCaretHovered = false
    @State private var rightHalfHovered = false
    @State private var rightCaretHovered = false

    private var leftActive: Bool { leftHalfHovered || leftCaretHovered }
    private var rightActive: Bool { rightHalfHovered || rightCaretHovered }

    private var pages: (right: Int?, left: Int?) {
        book.pagesForSpread(book.currentSpreadIndex)
    }

    private var isSinglePage: Bool {
        pages.right != nil && pages.left == nil
    }

    /// Compute the blank margin widths on left and right edges of the window.
    private func margins(in size: CGSize) -> (left: CGFloat, right: CGFloat) {
        let slotWidth = isSinglePage ? size.width : size.width / 2

        func renderedWidth(pageIndex: Int) -> CGFloat {
            let pageSize = book.pageSizes[pageIndex]
            let aspect = pageSize.width / pageSize.height
            return min(slotWidth, aspect * size.height)
        }

        if let leftIdx = pages.left, let rightIdx = pages.right {
            // Pair: left page aligned .trailing, right page aligned .leading
            return (left: slotWidth - renderedWidth(pageIndex: leftIdx),
                    right: slotWidth - renderedWidth(pageIndex: rightIdx))
        } else if let rightIdx = pages.right {
            // Single: centered
            let blank = (size.width - renderedWidth(pageIndex: rightIdx)) / 2
            return (left: blank, right: blank)
        }
        return (left: 0, right: 0)
    }

    var body: some View {
        GeometryReader { geo in
            let m = margins(in: geo.size)

            ZStack {
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
                                    book.nextSpread()
                                } else if value.translation.width < -threshold {
                                    book.previousSpread()
                                }
                                dragOffset = 0
                            }
                        }
                )

                // Full-half tap buttons (RTL: left=next, right=prev)
                // Invisible buttons for tap sound; hover drives caret opacity
                HStack(spacing: 0) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            book.nextSpread()
                        }
                    } label: {
                        Color.clear.contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .hoverEffectDisabled()
                    .onHover { leftHalfHovered = $0 }
                    .disabled(book.currentSpreadIndex >= book.spreadCount - 1)

                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            book.previousSpread()
                        }
                    } label: {
                        Color.clear.contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .hoverEffectDisabled()
                    .onHover { rightHalfHovered = $0 }
                    .disabled(book.currentSpreadIndex <= 0)
                }

                // Caret buttons — font color highlight, no background glow
                if m.left > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            book.nextSpread()
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(leftActive ? 0.7 : 0.15))
                            .padding(12)
                    }
                    .buttonStyle(.plain)
                    .hoverEffectDisabled()
                    .onHover { leftCaretHovered = $0 }
                    .disabled(book.currentSpreadIndex >= book.spreadCount - 1)
                    .padding(.leading, 4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .animation(.easeInOut(duration: 0.2), value: leftActive)
                }

                if m.right > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            book.previousSpread()
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(rightActive ? 0.7 : 0.15))
                            .padding(12)
                    }
                    .buttonStyle(.plain)
                    .hoverEffectDisabled()
                    .onHover { rightCaretHovered = $0 }
                    .disabled(book.currentSpreadIndex <= 0)
                    .padding(.trailing, 4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .animation(.easeInOut(duration: 0.2), value: rightActive)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(.black)
        .animation(isSinglePage != wasSinglePage ? nil : .easeInOut(duration: 0.25), value: book.currentSpreadIndex)
        .onChange(of: book.currentSpreadIndex) {
            wasSinglePage = isSinglePage
        }
    }
}
