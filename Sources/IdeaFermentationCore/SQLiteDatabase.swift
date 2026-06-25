import Foundation
import SQLite3

public enum SQLiteValue: Equatable, Sendable {
    case text(String)
    case int(Int64)
    case double(Double)
    case bool(Bool)
    case null
}

public final class SQLiteDatabase {
    private var handle: OpaquePointer?
    private var transactionDepth = 0

    public init(path: String) throws {
        if sqlite3_open(path, &handle) != SQLITE_OK {
            throw IdeaStoreError.sqlite("Could not open database at \(path).")
        }
        try execute("PRAGMA foreign_keys = ON")
        try execute("PRAGMA journal_mode = WAL")
    }

    deinit {
        sqlite3_close(handle)
    }

    /// Runs `body` inside a single transaction so a multi-statement write either
    /// fully commits or fully rolls back — no half-written rows, no FTS index left
    /// out of sync with its base table. Re-entrant: a nested call joins the outer
    /// transaction instead of starting a second `BEGIN` (which SQLite forbids).
    @discardableResult
    public func transaction<T>(_ body: () throws -> T) throws -> T {
        if transactionDepth > 0 {
            transactionDepth += 1
            defer { transactionDepth -= 1 }
            return try body()
        }
        try execute("BEGIN IMMEDIATE")
        transactionDepth = 1
        do {
            let result = try body()
            transactionDepth = 0
            try execute("COMMIT")
            return result
        } catch {
            transactionDepth = 0
            try? execute("ROLLBACK")
            throw error
        }
    }

    public func execute(_ sql: String, _ bindings: [SQLiteValue] = []) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            throw error()
        }
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement)

        while true {
            let status = sqlite3_step(statement)
            if status == SQLITE_DONE { return }
            if status == SQLITE_ROW { continue }
            throw error()
        }
    }

    public func query(_ sql: String, _ bindings: [SQLiteValue] = []) throws -> [[String: String?]] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            throw error()
        }
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement)

        var rows: [[String: String?]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            var row: [String: String?] = [:]
            for column in 0..<sqlite3_column_count(statement) {
                let name = String(cString: sqlite3_column_name(statement, column))
                switch sqlite3_column_type(statement, column) {
                case SQLITE_INTEGER:
                    row[name] = String(sqlite3_column_int64(statement, column))
                case SQLITE_FLOAT:
                    row[name] = String(sqlite3_column_double(statement, column))
                case SQLITE_TEXT:
                    row[name] = String(cString: sqlite3_column_text(statement, column))
                case SQLITE_NULL:
                    row[name] = nil
                default:
                    row[name] = nil
                }
            }
            rows.append(row)
        }
        return rows
    }

    private func bind(_ values: [SQLiteValue], to statement: OpaquePointer?) throws {
        for (index, value) in values.enumerated() {
            let position = Int32(index + 1)
            let status: Int32
            switch value {
            case .text(let text):
                status = sqlite3_bind_text(statement, position, text, -1, SQLITE_TRANSIENT)
            case .int(let int):
                status = sqlite3_bind_int64(statement, position, int)
            case .double(let double):
                status = sqlite3_bind_double(statement, position, double)
            case .bool(let bool):
                status = sqlite3_bind_int(statement, position, bool ? 1 : 0)
            case .null:
                status = sqlite3_bind_null(statement, position)
            }
            guard status == SQLITE_OK else { throw error() }
        }
    }

    private func error() -> IdeaStoreError {
        let message = handle.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "Unknown SQLite error."
        return .sqlite(message)
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
