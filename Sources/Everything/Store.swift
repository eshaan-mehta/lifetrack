import Foundation
import Observation
import SQLite3

/// Owns the single SQLite database the app stores everything in.
/// Lives in Application Support so it is kept across reinstalls of the same bundle ID.
@Observable
final class Store {
    let url: URL
    private(set) var sqliteVersion = ""
    private(set) var openError: String?

    @ObservationIgnored private var db: OpaquePointer?

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        url = dir.appendingPathComponent("everything.sqlite")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        open()
    }

    deinit {
        sqlite3_close(db)
    }

    private func open() {
        guard sqlite3_open(url.path, &db) == SQLITE_OK else {
            openError = String(cString: sqlite3_errmsg(db))
            return
        }
        sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA foreign_keys=ON;", nil, nil, nil)
        sqliteVersion = String(cString: sqlite3_libversion())
    }
}
