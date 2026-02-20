import SwiftUI

struct PageView: View {
    let url: URL

    @State private var image: UIImage?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: url) {
            isLoading = true
            image = await ImageLoader.shared.load(url: url)
            isLoading = false
        }
    }
}
