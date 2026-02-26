import SwiftUI

struct SpreadView: View {
    private struct PinchHoldState {
        var startTimestamp: TimeInterval
        var startLocation: CGPoint
        var didTrigger = false
    }

    @Bindable var book: MangaBook

    @State private var dragOffset: CGFloat = 0
    @State private var wasSinglePage: Bool = false
    @State private var leftHalfHovered = false
    @State private var leftCaretHovered = false
    @State private var rightHalfHovered = false
    @State private var rightCaretHovered = false
    @State private var subjectStatusMessage: String?
    @State private var subjectStatusTask: Task<Void, Never>?
    @State private var isExtractingSubject = false
    @State private var suppressNavigationUntil = Date.distantPast
    @State private var pinchHolds: [SpatialEventCollection.Event.ID: PinchHoldState] = [:]

    private var leftActive: Bool { leftHalfHovered || leftCaretHovered }
    private var rightActive: Bool { rightHalfHovered || rightCaretHovered }

    private var pages: (right: Int?, left: Int?) {
        book.pagesForSpread(book.currentSpreadIndex)
    }

    private var isSinglePage: Bool {
        pages.right != nil && pages.left == nil
    }

    private func canNavigate() -> Bool {
        Date() >= suppressNavigationUntil
    }

    private func targetPageIndex(forLeftHalf isLeftHalf: Bool) -> Int? {
        if let leftIdx = pages.left, let rightIdx = pages.right {
            return isLeftHalf ? leftIdx : rightIdx
        }
        return pages.right ?? pages.left
    }

    private func showSubjectStatus(_ message: String, autoHide: Bool = true) {
        subjectStatusTask?.cancel()
        subjectStatusMessage = message
        guard autoHide else { return }

        subjectStatusTask = Task { [message] in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            await MainActor.run {
                if subjectStatusMessage == message {
                    subjectStatusMessage = nil
                }
            }
        }
    }

    private func extractSubject(fromLeftHalf isLeftHalf: Bool) {
        guard !isExtractingSubject else { return }
        guard let pageIndex = targetPageIndex(forLeftHalf: isLeftHalf),
              pageIndex >= 0, pageIndex < book.pageURLs.count else {
            showSubjectStatus("No page available")
            return
        }

        suppressNavigationUntil = Date().addingTimeInterval(0.35)
        isExtractingSubject = true
        showSubjectStatus("Extracting subject...", autoHide: false)

        let pageURL = book.pageURLs[pageIndex]
        Task {
            guard let image = await ImageLoader.shared.load(url: pageURL) else {
                await MainActor.run {
                    isExtractingSubject = false
                    showSubjectStatus("Failed to load page")
                }
                return
            }

            let subjectImage = await SubjectExtractor.extractSubject(from: image)
            await MainActor.run {
                isExtractingSubject = false
                guard let subjectImage else {
                    showSubjectStatus("No subject detected")
                    return
                }
                SubjectExtractor.copyToClipboard(subjectImage)
                showSubjectStatus("Subject copied to clipboard")
            }
        }
    }

    private func handleSpatialEvents(_ events: SpatialEventCollection, size: CGSize) {
        for event in events {
            let isPinchEvent: Bool
            switch event.kind {
            case .directPinch, .indirectPinch:
                isPinchEvent = true
            default:
                isPinchEvent = false
            }
            guard isPinchEvent else { continue }

            switch event.phase {
            case .active:
                var hold = pinchHolds[event.id] ?? PinchHoldState(
                    startTimestamp: event.timestamp,
                    startLocation: event.location
                )
                let dx = event.location.x - hold.startLocation.x
                let dy = event.location.y - hold.startLocation.y
                let travel = sqrt(dx * dx + dy * dy)
                let heldLongEnough = (event.timestamp - hold.startTimestamp) >= 0.75

                if !hold.didTrigger, heldLongEnough, travel <= 40 {
                    hold.didTrigger = true
                    extractSubject(fromLeftHalf: event.location.x < (size.width / 2))
                }
                pinchHolds[event.id] = hold

            case .ended, .cancelled:
                pinchHolds.removeValue(forKey: event.id)
            @unknown default:
                pinchHolds.removeValue(forKey: event.id)
            }
        }
    }

    private var swipeGesture: some Gesture {
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

                // Full-half tap buttons (RTL: left=next, right=prev)
                // Invisible buttons for tap sound; hover drives caret opacity
                HStack(spacing: 0) {
                    Button {
                        guard canNavigate() else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            book.nextSpread()
                        }
                    } label: {
                        Color.clear.contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .hoverEffectDisabled()
                    .onHover { leftHalfHovered = $0 }

                    Button {
                        guard canNavigate() else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            book.previousSpread()
                        }
                    } label: {
                        Color.clear.contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .hoverEffectDisabled()
                    .onHover { rightHalfHovered = $0 }
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

                if let subjectStatusMessage {
                    Text(subjectStatusMessage)
                        .font(.footnote)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, 12)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .simultaneousGesture(swipeGesture)
            .simultaneousGesture(
                SpatialEventGesture(coordinateSpace: .local)
                    .onChanged { events in
                        handleSpatialEvents(events, size: geo.size)
                    }
                    .onEnded { events in
                        handleSpatialEvents(events, size: geo.size)
                    }
            )
        }
        .background(.black)
        .animation(isSinglePage != wasSinglePage ? nil : .easeInOut(duration: 0.25), value: book.currentSpreadIndex)
        .onChange(of: book.currentSpreadIndex) {
            wasSinglePage = isSinglePage
        }
        .onDisappear {
            subjectStatusTask?.cancel()
        }
    }
}
