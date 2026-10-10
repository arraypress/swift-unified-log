//
//  LogEntry.swift
//  UnifiedLog
//
//  Created by David Sherlock on 2026.
//
//  One message from the unified log, with the fields a person filters on
//  and nothing else — `log`'s own ndjson carries some thirty keys per line,
//  most of them UUIDs and offsets.
//

import Foundation

/// A log message.
public struct LogEntry: Sendable, Codable, Equatable {
    public let date: Date
    public let level: LogLevel
    /// The process name: `launchd`, `Safari`.
    public let process: String
    public let pid: Int
    /// The subsystem, e.g. `com.apple.network`; empty when none.
    public let subsystem: String
    public let category: String
    /// The message as composed. Values logged as private read `<private>`.
    public let message: String
    /// The library or binary that logged it.
    public let sender: String

    public init(date: Date, level: LogLevel, process: String, pid: Int, subsystem: String,
                category: String, message: String, sender: String) {
        self.date = date
        self.level = level
        self.process = process
        self.pid = pid
        self.subsystem = subsystem
        self.category = category
        self.message = message
        self.sender = sender
    }
}
