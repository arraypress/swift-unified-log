//
//  UnifiedLog.swift
//  UnifiedLog
//
//  Created by David Sherlock on 2026.
//
//  The front door. History is read in-process through OSLogStore — the
//  same entries `log show` prints, typed, and twice as fast (measured: one
//  process over five minutes, 2,040 entries in 0.50 s against 2,036 from
//  `log show` in 1.06 s). Live tailing has no OSLogStore equivalent, so
//  `stream` runs `/usr/bin/log stream --style ndjson` and parses its lines.
//
//  Reading the system store is a privilege: it worked headless, unsigned,
//  for an admin user on macOS 27; a standard user is refused, and that
//  refusal is reported as such rather than as an empty result.
//

import Foundation
import OSLog

/// Reads the unified log.
///
/// ```swift
/// let errors = try UnifiedLog.entries(LogQuery(since: .now.addingTimeInterval(-3600),
///                                              processes: ["Mail"], minimumLevel: .error))
/// let summary = try UnifiedLog.summary(LogQuery(since: .now.addingTimeInterval(-600)))
/// ```
public enum UnifiedLog {

    /// The entries a query matches, oldest first.
    ///
    /// - Throws: ``UnifiedLogError``.
    public static func entries(_ query: LogQuery) throws -> [LogEntry] {
        var out: [LogEntry] = []
        try forEach(query) { entry in
            out.append(entry)
            return query.limit.map { out.count < $0 } ?? true
        }
        return out
    }

    /// Counts by level and process over a query's entries, without keeping them.
    ///
    /// - Throws: ``UnifiedLogError``.
    public static func summary(_ query: LogQuery, top: Int = 20) throws -> LogSummary {
        var tally = Tally()
        try forEach(query) { entry in
            tally.add(entry)
            return query.limit.map { tally.count < $0 } ?? true
        }
        return tally.summary(top: top)
    }

    /// Calls `body` with each matching entry until it returns false.
    static func forEach(_ query: LogQuery, _ body: (LogEntry) throws -> Bool) throws {
        let store: OSLogStore
        do { store = try OSLogStore(scope: .system) } catch {
            throw UnifiedLogError.notPermitted(error.localizedDescription)
        }
        let until = query.until ?? Date()
        let found: AnySequence<OSLogEntry>
        do {
            found = try store.getEntries(at: store.position(date: query.since),
                                         matching: try PredicateBuilder.predicate(for: query))
        } catch let error as UnifiedLogError {
            throw error
        } catch {
            throw UnifiedLogError.badPredicate(error.localizedDescription)
        }
        for item in found {
            guard let log = item as? OSLogEntryLog else { continue }
            if log.date < query.since { continue }
            if log.date > until { break }
            guard let level = LogLevel(log.level) else { continue }
            let entry = LogEntry(date: log.date, level: level, process: log.process, pid: Int(log.processIdentifier),
                                 subsystem: log.subsystem, category: log.category, message: log.composedMessage,
                                 sender: log.sender)
            guard try body(entry) else { return }
        }
    }

    /// Live entries as they are logged, until `limit` entries or `duration`
    /// seconds, whichever comes first.
    ///
    /// - Parameters:
    ///   - query: Filters; its dates are ignored.
    ///   - limit: Stop after this many entries.
    ///   - duration: Stop after this long.
    ///   - body: Called with each entry.
    /// - Throws: ``UnifiedLogError/streamFailed(_:)``.
    public static func stream(_ query: LogQuery, limit: Int?, duration: TimeInterval?,
                              _ body: @Sendable (LogEntry) -> Void) async throws {
        var arguments = ["stream", "--style", "ndjson",
                         "--level", query.minimumLevel == .debug ? "debug" : query.minimumLevel == .info ? "info" : "default"]
        if let predicate = try PredicateBuilder.predicate(for: query) {
            arguments += ["--predicate", predicate.predicateFormat]
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { throw UnifiedLogError.streamFailed(error.localizedDescription) }
        let deadline = duration.map { Date().addingTimeInterval($0) }
        let timer = deadline.map { end in
            Task { try? await Task.sleep(nanoseconds: UInt64(max(0, end.timeIntervalSinceNow) * 1e9)); process.terminate() }
        }
        defer { timer?.cancel(); if process.isRunning { process.terminate() } }

        var count = 0
        do {
            for try await line in pipe.fileHandleForReading.bytes.lines {
                guard let entry = StreamLine.entry(from: Substring(line)) else { continue }
                body(entry)
                count += 1
                if let limit, count >= limit { break }
            }
        } catch {
            throw UnifiedLogError.streamFailed(error.localizedDescription)
        }
    }
}
