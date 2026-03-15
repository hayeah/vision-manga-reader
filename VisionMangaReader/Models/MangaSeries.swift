import Foundation

struct MangaSeries: Identifiable {
    let id: String          // folder name
    let url: URL
    let title: String       // folder name (or info.json title if present)
    var volumes: [MangaVolume]
}

struct MangaVolume: Identifiable {
    let id: String          // relative path: "烙印战士/第01卷"
    let url: URL
    let title: String       // folder name
    let seriesID: String
    let sortIndex: Int
}
