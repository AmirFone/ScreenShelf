import Foundation
import GRDB

struct Screenshot: Codable, Identifiable, FetchableRecord, PersistableRecord, Hashable {
    static let databaseTableName = "screenshots"

    var id: Int64?
    var filePath: String
    var fileName: String
    var thumbPath: String?
    var fileSize: Int64
    var width: Int
    var height: Int
    var capturedAt: Date
    var createdAt: Date
    var deletedAt: Date?

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let filePath = Column(CodingKeys.filePath)
        static let capturedAt = Column(CodingKeys.capturedAt)
        static let deletedAt = Column(CodingKeys.deletedAt)
    }
}
