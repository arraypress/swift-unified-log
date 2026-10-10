//
//  LogLevel.swift
//  UnifiedLog
//
//  Created by David Sherlock on 2026.
//
//  The five levels of the unified log, in order, under the names `log`
//  itself uses — so a filter typed here means what it means there.
//

import Foundation
import OSLog

/// How serious a log message is.
public enum LogLevel: String, CaseIterable, Sendable, Codable, Comparable {
    case debug, info
    /// What `os_log` writes with no level: "Default" in `log`'s own output.
    case `default`
    case error, fault

    /// The order, least serious first.
    var rank: Int { Self.allCases.firstIndex(of: self)! }

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool { lhs.rank < rhs.rank }

    /// This level and everything more serious.
    public var andAbove: [LogLevel] { Self.allCases.filter { $0 >= self } }

    /// From OSLogStore's level.
    public init?(_ level: OSLogEntryLog.Level) {
        switch level {
        case .debug: self = .debug
        case .info: self = .info
        case .notice: self = .default
        case .error: self = .error
        case .fault: self = .fault
        default: return nil
        }
    }

    /// From a name as typed or as `log --style ndjson` writes it: "Info",
    /// "default", "notice", "warning" (taken as error).
    public init?(name: String) {
        switch name.lowercased() {
        case "debug": self = .debug
        case "info": self = .info
        case "default", "notice": self = .default
        case "error", "warning": self = .error
        case "fault": self = .fault
        default: return nil
        }
    }
}
