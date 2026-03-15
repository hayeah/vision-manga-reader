import SwiftUI

struct VolumeDrawer: View {
    var volumes: [MangaVolume]
    var currentVolumeID: String?
    var onSelectVolume: (MangaVolume) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) {
                    ForEach(volumes) { vol in
                        volumeDot(vol)
                            .id(vol.id)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 4)
            }
            .onChange(of: currentVolumeID) { _, newID in
                if let newID {
                    withAnimation {
                        proxy.scrollTo(newID, anchor: .center)
                    }
                }
            }
            .onAppear {
                if let currentVolumeID {
                    proxy.scrollTo(currentVolumeID, anchor: .center)
                }
            }
        }
        .frame(width: 44)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func volumeDot(_ vol: MangaVolume) -> some View {
        let isCurrent = vol.id == currentVolumeID

        Button {
            onSelectVolume(vol)
        } label: {
            ZStack {
                Circle()
                    .fill(isCurrent ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 28, height: 28)

                Text("\(vol.sortIndex + 1)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(isCurrent ? .white : .secondary)
            }
        }
        .buttonStyle(.plain)
        .help(vol.title)
    }
}
