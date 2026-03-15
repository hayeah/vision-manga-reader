import Foundation

struct VolumeProgress: Codable {
    var lastSpreadIndex: Int
    var totalSpreads: Int
    var lastReadDate: Date
    var isCompleted: Bool
}

struct SavedWindow: Codable {
    var id: UUID
    var volumeID: String
    var spreadIndex: Int
}

struct ReadingHistory: Codable {
    var progress: [String: VolumeProgress] = [:]    // key: volume relative path
    var recentSeriesIDs: [String] = []              // ordered by last-read time
    var lastActiveVolumeID: String?                  // for "continue reading"
    var windows: [SavedWindow] = []                 // open reader windows
}
