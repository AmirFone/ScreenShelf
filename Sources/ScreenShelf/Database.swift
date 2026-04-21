import Foundation
import GRDB

final class AppDatabase: Sendable {
    let dbPool: DatabasePool

    init() throws {
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ScreenShelf", isDirectory: true)
        try FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)

        let dbPath = appSupportDir.appendingPathComponent("screenshelf.db").path
        dbPool = try DatabasePool(path: dbPath)
        try migrate()
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()

        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("v1_create_screenshots") { db in
            try db.create(table: "screenshots") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("filePath", .text).notNull().unique()
                t.column("fileName", .text).notNull()
                t.column("thumbPath", .text)
                t.column("fileSize", .integer).notNull().defaults(to: 0)
                t.column("width", .integer).notNull().defaults(to: 0)
                t.column("height", .integer).notNull().defaults(to: 0)
                t.column("capturedAt", .datetime).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("deletedAt", .datetime)
            }
            try db.create(index: "idx_screenshots_captured", on: "screenshots", columns: ["capturedAt"])
        }

        try migrator.migrate(dbPool)
    }

    func insert(_ screenshot: inout Screenshot) throws {
        try dbPool.write { db in
            try screenshot.insert(db)
        }
    }

    func fetchPage(limit: Int, offset: Int) throws -> [Screenshot] {
        try dbPool.read { db in
            try Screenshot
                .filter(Screenshot.Columns.deletedAt == nil)
                .order(Screenshot.Columns.capturedAt.desc)
                .limit(limit, offset: offset)
                .fetchAll(db)
        }
    }

    func exists(filePath: String) throws -> Bool {
        try dbPool.read { db in
            try Screenshot
                .filter(Screenshot.Columns.filePath == filePath)
                .fetchCount(db) > 0
        }
    }

    func count() throws -> Int {
        try dbPool.read { db in
            try Screenshot
                .filter(Screenshot.Columns.deletedAt == nil)
                .fetchCount(db)
        }
    }

    func softDelete(id: Int64) throws {
        try dbPool.write { db in
            try Screenshot
                .filter(Screenshot.Columns.id == id)
                .updateAll(db, Screenshot.Columns.deletedAt.set(to: Date()))
        }
    }
}
