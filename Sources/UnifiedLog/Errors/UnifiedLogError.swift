//
//  UnifiedLogError.swift
//  UnifiedLog
//
//  Created by David Sherlock on 2026.
//
//  Failures a caller can act on.
//

import Foundation

/// Why the log could not be read.
public enum UnifiedLogError: Error, LocalizedError, Sendable, Equatable {
    /// The system log store refused this user — reading it needs an admin
    /// account, or root.
    case notPermitted(String)
    /// The predicate was not understood.
    case badPredicate(String)
    /// `log stream` failed to start or stopped early.
    case streamFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notPermitted(let why): return "the system log is not readable by this user: \(why)"
        case .badPredicate(let why): return "the predicate was not understood: \(why)"
        case .streamFailed(let why): return "log stream failed: \(why)"
        }
    }
}
