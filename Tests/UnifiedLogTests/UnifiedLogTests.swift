//
//  UnifiedLogTests.swift
//  UnifiedLogTests
//
//  Created by David Sherlock on 2026.
//
//  The query-to-predicate rules with known answers, the ndjson parser on a
//  line `log` really wrote, and — against this Mac's own log — a message
//  this test logs itself and then finds.
//

import Foundation
import OSLog
import Testing
@testable import UnifiedLog

@Suite("Predicates")
struct PredicateTests {

    let since = Date(timeIntervalSince1970: 0)

    @Test("An empty query narrows nothing beyond the default level")
    func empty() throws {
        let predicate = try PredicateBuilder.predicate(for: LogQuery(since: since, minimumLevel: .debug))
        #expect(predicate == nil)
    }

    @Test("Each filter becomes a clause, ANDed")
    func clauses() throws {
        let query = LogQuery(since: since, processes: ["launchd", "kernel"], subsystems: ["com.apple.network"],
                             minimumLevel: .error, contains: "timeout")
        let format = try #require(try PredicateBuilder.predicate(for: query)).predicateFormat
        #expect(format.contains("process == \"launchd\" OR process == \"kernel\""),
                "ORed equalities: an IN-set halves the store's speed")
        #expect(format.contains("subsystem BEGINSWITH \"com.apple.network.\""))
        #expect(format.contains("messageType == \"error\" OR messageType == \"fault\""),
                "ORed equalities: an IN-set on messageType silently matches nothing in OSLogStore")
        #expect(format.contains("composedMessage CONTAINS[c] \"timeout\""))
    }

    @Test("A quote in a filter cannot change what the predicate means")
    func injection() throws {
        let query = LogQuery(since: since, processes: ["x\" OR TRUEPREDICATE OR process == \"y"], minimumLevel: .debug)
        let predicate = try #require(try PredicateBuilder.predicate(for: query))
        #expect(predicate.evaluate(with: ["process": "anything"]) == false)
    }

    @Test("A malformed raw predicate is an error, not a crash")
    func malformed() {
        #expect(throws: UnifiedLogError.self) {
            try PredicateBuilder.predicate(for: LogQuery(since: since, predicate: "process == == )"))
        }
    }

    @Test("Levels order and name as log names them")
    func levels() {
        #expect(LogLevel.error.andAbove == [.error, .fault])
        #expect(LogLevel(name: "Default") == .default)
        #expect(LogLevel(name: "notice") == .default)
        #expect(LogLevel(name: "loud") == nil)
    }
}

@Suite("Stream lines")
struct StreamLineTests {

    @Test("A log event becomes an entry; an activity does not")
    func lines() throws {
        let event = #"{"eventType":"logEvent","messageType":"Info","timestamp":"2026-10-10 17:25:39.961971+0700","processImagePath":"\/usr\/libexec\/opendirectoryd","processID":562,"subsystem":"com.apple.opendirectoryd","category":"session","eventMessage":"hello","senderImagePath":"\/usr\/lib\/x.dylib"}"#
        let entry = try #require(StreamLine.entry(from: Substring(event)))
        #expect(entry.process == "opendirectoryd")
        #expect(entry.level == .info)
        #expect(entry.pid == 562)
        #expect(entry.sender == "x.dylib")
        // 17:25:39.961971 at +0700 is 10:25:39.961971 UTC; DateFormatter keeps milliseconds.
        #expect(abs(entry.date.timeIntervalSince1970 - 1_791_627_939.961971) < 0.001, "the +0700 offset is honoured")
        #expect(StreamLine.entry(from: #"{"eventType":"activityCreateEvent","timestamp":"2026-10-10 17:25:39.961971+0700"}"#) == nil)
        #expect(StreamLine.entry(from: "not json") == nil)
    }
}

@Suite("Counting")
struct TallyTests {

    @Test("Counts by level and process, busiest first")
    func tally() {
        var tally = Tally()
        let now = Date()
        for (process, level) in [("a", LogLevel.error), ("a", .info), ("b", .fault), ("a", .error)] {
            tally.add(LogEntry(date: now, level: level, process: process, pid: 1, subsystem: "", category: "", message: "", sender: ""))
        }
        let summary = tally.summary()
        #expect(summary.total == 4)
        #expect(summary.byLevel["error"] == 2)
        #expect(summary.byProcess.first == LogSummary.ProcessCount(process: "a", total: 3, errors: 2, faults: 0))
    }
}

@Suite("This Mac's log")
struct LiveTests {

    @Test("A message logged by another process is found again, by process and text")
    func roundTrip() async throws {
        // Logged through /usr/bin/logger, a real separate process: the test
        // runner's own Logger messages were never persisted when probed —
        // not even to its current-process store — while logger's arrive.
        let marker = "unified-log-test-\(UUID().uuidString)"
        let start = Date().addingTimeInterval(-2)
        let logger = Process()
        logger.executableURL = URL(fileURLWithPath: "/usr/bin/logger")
        logger.arguments = [marker]
        try logger.run()
        logger.waitUntilExit()
        var found: [LogEntry] = []
        for _ in 0..<30 where found.isEmpty {
            try await Task.sleep(nanoseconds: 200_000_000)
            found = try UnifiedLog.entries(LogQuery(since: start, processes: ["logger"], contains: marker))
        }
        let entry = try #require(found.first)
        #expect(entry.message == marker)
        #expect(entry.process == "logger")
        #expect(entry.pid == Int(logger.processIdentifier))
        let summary = try UnifiedLog.summary(LogQuery(since: start, processes: ["logger"], contains: marker))
        #expect(summary.total == 1)
        // The level filter must find it too — the trap this test guards.
        #expect(try UnifiedLog.entries(LogQuery(since: start, processes: ["logger"], minimumLevel: .default,
                                                 contains: marker)).count == 1)
    }
}
