import Foundation

struct VolumeProgress: Codable {
    var lastSpreadIndex: Int
    var totalSpreads: Int
    var lastReadDate: Date
    var isCompleted: Bool
}

struct ReadingHistory: Codable {
    var progress: [String: VolumeProgress] = [:]    // key: volume relative path
    var recentSeriesIDs: [String] = []              // ordered by last-read time
    var lastActiveVolumeID: String?                  // for "continue reading"
}
