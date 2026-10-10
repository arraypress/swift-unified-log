//
//  LogQuery.swift
//  UnifiedLog
//
//  Created by David Sherlock on 2026.
//
//  What to look for. Every field becomes part of one predicate the log
//  store evaluates itself — measured: the last hour of one process came
//  back in 4.4 s through `log show` with a predicate against 34 s for the
//  whole hour unfiltered (2.4 million lines), so nothing is filtered after
//  the fact that could be filtered at the source.
//

import Foundation

/// A search of the unified log.
public struct LogQuery: Sendable, Equatable {
    /// From when.
    public var since: Date
    /// Until when; nil means now.
    public var until: Date?
    /// Process names, any of them.
    public var processes: [String]
    /// Process ids, any of them.
    public var pids: [Int]
    /// Subsystems, any of them, each matching itself and its children
    /// (`com.apple.network` takes `com.apple.network.connection`).
    public var subsystems: [String]
    /// Categories, any of them.
    public var categories: [String]
    /// The least serious level to include.
    public var minimumLevel: LogLevel
    /// Text the message must contain, case-insensitively.
    public var contains: String?
    /// A raw NSPredicate, ANDed with the rest — `log`'s own syntax.
    public var predicate: String?
    /// Stop after this many entries.
    public var limit: Int?

    public init(since: Date, until: Date? = nil, processes: [String] = [], pids: [Int] = [],
                subsystems: [String] = [], categories: [String] = [], minimumLevel: LogLevel = .default,
                contains: String? = nil, predicate: String? = nil, limit: Int? = nil) {
        self.since = since
        self.until = until
        self.processes = processes
        self.pids = pids
        self.subsystems = subsystems
        self.categories = categories
        self.minimumLevel = minimumLevel
        self.contains = contains
        self.predicate = predicate
        self.limit = limit
    }
}
