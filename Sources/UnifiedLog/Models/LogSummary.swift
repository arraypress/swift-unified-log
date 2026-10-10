//
//  LogSummary.swift
//  UnifiedLog
//
//  Created by David Sherlock on 2026.
//
//  A stretch of the log counted rather than read: who is talking, and how
//  much of it is errors — the first question when something is wrong.
//

import Foundation

/// Counts over a set of log entries.
public struct LogSummary: Sendable, Codable, Equatable {
    /// One process's share.
    public struct ProcessCount: Sendable, Codable, Equatable {
        public let process: String
        public let total: Int
        public let errors: Int
        public let faults: Int

        public init(process: String, total: Int, errors: Int, faults: Int) {
            self.process = process
            self.total = total
            self.errors = errors
            self.faults = faults
        }
    }

    public let total: Int
    public let byLevel: [String: Int]
    /// Busiest first.
    public let byProcess: [ProcessCount]
    public let from: Date?
    public let to: Date?

    public init(total: Int, byLevel: [String: Int], byProcess: [ProcessCount], from: Date?, to: Date?) {
        self.total = total
        self.byLevel = byLevel
        self.byProcess = byProcess
        self.from = from
        self.to = to
    }
}
