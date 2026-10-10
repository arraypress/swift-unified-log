//
//  Summarizer.swift
//  UnifiedLog
//
//  Created by David Sherlock on 2026.
//
//  Counting entries by level and by process, as they pass — an unfiltered
//  hour is millions of entries, and a summary should not hold them all.
//

import Foundation

/// A running count of log entries.
public struct Tally: Sendable {
    private var total = 0
    private var levels: [String: Int] = [:]
    private var processes: [String: (total: Int, errors: Int, faults: Int)] = [:]
    private var first: Date?
    private var last: Date?

    public init() {}

    /// How many entries have been counted.
    public var count: Int { total }

    /// Counts one more entry.
    public mutating func add(_ entry: LogEntry) {
        total += 1
        levels[entry.level.rawValue, default: 0] += 1
        var count = processes[entry.process] ?? (0, 0, 0)
        count.total += 1
        if entry.level == .error { count.errors += 1 }
        if entry.level == .fault { count.faults += 1 }
        processes[entry.process] = count
        first = min(first ?? entry.date, entry.date)
        last = max(last ?? entry.date, entry.date)
    }

    /// The counts so far, with the busiest `top` processes.
    public func summary(top: Int = 20) -> LogSummary {
        let ranked = processes.map { LogSummary.ProcessCount(process: $0.key, total: $0.value.total,
                                                             errors: $0.value.errors, faults: $0.value.faults) }
            .sorted { ($0.total, $1.process) > ($1.total, $0.process) }
        return LogSummary(total: total, byLevel: levels, byProcess: Array(ranked.prefix(top)), from: first, to: last)
    }
}
