//
//  PredicateBuilder.swift
//  UnifiedLog
//
//  Created by David Sherlock on 2026.
//
//  A query into one NSPredicate. Built from argument arrays, never by
//  pasting strings, so a process name or a search phrase with a quote in it
//  cannot change what the predicate means. PROBED: OSLogStore evaluates
//  process, processIdentifier, subsystem, category, composedMessage,
//  messageType and sender itself, and IN-sets on process — but NOT an
//  IN-set on messageType, which silently matches nothing.
//

import Foundation
import SafePredicate

/// Turns a query into a predicate the log store evaluates.
public enum PredicateBuilder {

    /// The predicate for a query, or nil when nothing narrows it.
    ///
    /// - Throws: ``UnifiedLogError/badPredicate(_:)`` for a raw predicate
    ///   that does not parse.
    public static func predicate(for query: LogQuery) throws -> NSPredicate? {
        var parts: [NSPredicate] = []
        if let any = anyOf("process", query.processes) { parts.append(any) }
        if let any = anyOf("processIdentifier", query.pids) { parts.append(any) }
        if !query.subsystems.isEmpty {
            parts.append(NSCompoundPredicate(orPredicateWithSubpredicates: query.subsystems.map {
                NSPredicate(format: "subsystem == %@ OR subsystem BEGINSWITH %@", $0, $0 + ".")
            }))
        }
        if let any = anyOf("category", query.categories) { parts.append(any) }
        if query.minimumLevel > .debug {
            // MEASURED: `messageType IN {"error", "fault"}` matches NOTHING in
            // OSLogStore — no error, just an empty result — while the same
            // levels as ORed equalities match. Every level filter would have
            // come back empty.
            parts.append(NSCompoundPredicate(orPredicateWithSubpredicates: query.minimumLevel.andAbove.map {
                NSPredicate(format: "messageType == %@", $0.rawValue)
            }))
        }
        if let text = query.contains, !text.isEmpty {
            parts.append(NSPredicate(format: "composedMessage CONTAINS[c] %@", text))
        }
        if let raw = query.predicate, !raw.isEmpty {
            parts.append(try parse(raw))
        }
        switch parts.count {
        case 0: return nil
        case 1: return parts[0]
        default: return NSCompoundPredicate(andPredicateWithSubpredicates: parts)
        }
    }

    /// `key == a OR key == b`, never `key IN {a, b}`.
    ///
    /// MEASURED on an hour of this Mac's log: `process == "launchd"` took
    /// 3.9 s and `process IN {"launchd"}` 7.7 s for the same 20,034
    /// entries; two values ORed took 7.5 s against 9.3 s as an IN-set. The
    /// store has a fast path for equality and none for sets.
    static func anyOf(_ key: String, _ values: [some CVarArg]) -> NSPredicate? {
        guard !values.isEmpty else { return nil }
        let each = values.map { NSPredicate(format: "%K == %@", key, $0 as! NSObject) }
        return each.count == 1 ? each[0] : NSCompoundPredicate(orPredicateWithSubpredicates: each)
    }

    /// A raw predicate, refused cleanly rather than crashing when malformed —
    /// NSPredicate(format:) raises an Objective-C exception on bad syntax,
    /// which Swift cannot catch, so the syntax is checked first.
    static func parse(_ raw: String) throws -> NSPredicate {
        guard let predicate = SafePredicate.make(raw) else {
            throw UnifiedLogError.badPredicate(raw)
        }
        return predicate
    }
}
