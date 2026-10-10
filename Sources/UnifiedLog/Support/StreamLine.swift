//
//  StreamLine.swift
//  UnifiedLog
//
//  Created by David Sherlock on 2026.
//
//  One line of `log stream --style ndjson` into an entry. Activity and
//  boundary events share the stream with log messages; only messages
//  (`eventType` logEvent) become entries.
//

import Foundation

/// Parses `log`'s ndjson.
public enum StreamLine {

    /// The entry on one line, or nil for a line that is not a log message.
    public static func entry(from line: Substring) -> LogEntry? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["eventType"] as? String == "logEvent",
              let stamp = object["timestamp"] as? String, let date = date(from: stamp) else { return nil }
        return LogEntry(date: date,
                        level: LogLevel(name: object["messageType"] as? String ?? "default") ?? .default,
                        process: lastComponent(object["processImagePath"] as? String),
                        pid: object["processID"] as? Int ?? 0,
                        subsystem: object["subsystem"] as? String ?? "",
                        category: object["category"] as? String ?? "",
                        message: object["eventMessage"] as? String ?? "",
                        sender: lastComponent(object["senderImagePath"] as? String))
    }

    /// `2026-10-10 17:25:39.961401+0700`, as `log` writes it.
    static func date(from text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSZ"
        return formatter.date(from: text)
    }

    static func lastComponent(_ path: String?) -> String {
        guard let path, !path.isEmpty else { return "" }
        return (path as NSString).lastPathComponent
    }
}
