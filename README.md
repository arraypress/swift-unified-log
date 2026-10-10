# swift-unified-log

The Mac's unified log as data, from Swift: query a window by process, subsystem,
category, level or text — evaluated by the log store itself — summarise who is
talking, or tail it live.

```swift
import UnifiedLog

let errors = try UnifiedLog.entries(LogQuery(since: .now.addingTimeInterval(-3600),
                                             processes: ["Mail"], minimumLevel: .error))
let summary = try UnifiedLog.summary(LogQuery(since: .now.addingTimeInterval(-900)))
try await UnifiedLog.stream(LogQuery(since: .now, processes: ["myapp"]), limit: 20, duration: 30) { entry in
    print(entry.message)
}
```

## Two engines, chosen by measurement

History is read in-process with `OSLogStore(scope: .system)`; live tailing runs
`/usr/bin/log stream --style ndjson`, because OSLogStore has no live tail. Both
were timed on this Mac, the same query each way, parsing included:

| Query | OSLogStore | `log show` + parse |
|---|---|---|
| launchd, last 5 min | 2,859 in **1.2 s** | 2,857 in 1.5 s |
| errors, last 5 min | 13,059 in **1.5 s** | 13,002 in 2.8 s |
| launchd, last hour | 17,919 in **4.1 s** | 17,901 in 6.4 s |
| errors, last hour | 114,003 in **7.8 s** | 114,079 in 21.6 s |

Same entries either way (within the half-percent the log grows by between
runs); OSLogStore is faster everywhere and returns typed fields.

## The predicate traps

Every filter becomes one NSPredicate the store evaluates — filtering after the
fact would mean reading 2.4 million entries for an unfiltered hour (34 s).
Probed key by key: `process`, `processIdentifier`, `subsystem`, `category`,
`composedMessage`, `messageType` and `sender` are all evaluated by the store.
Two things are not what they seem:

- **`messageType IN {"error", "fault"}` matches nothing** — no error, an empty
  result — while the same levels as `==` joined by OR match. Every level filter
  would have come back empty; a test now logs a message and finds it through the
  level filter.
- **`IN` sets are slow even where they work.** `process == "launchd"` took 3.9 s
  over an hour and `process IN {"launchd"}` 7.7 s for the same 20,034 entries;
  two processes ORed, 7.5 s against 9.3 s. Every multi-value filter is written
  as ORed equalities.

Filters are built from argument arrays, never by pasting strings, so a quote in
a process name or a search phrase cannot change what the predicate means. A raw
`predicate` is parsed through a ten-line Objective-C `@try`: NSPredicate raises
an Objective-C exception on bad syntax, which Swift cannot catch, and a typo
would otherwise crash the caller.

## Privileges

`OSLogStore(scope: .system)` worked headless and unsigned **for an admin user**
on macOS 27; a standard user is refused, which surfaces as
`UnifiedLogError.notPermitted` rather than an empty result. **Untested on a
standard account.** Values a process logged as private read `<private>`.

A test runner's own `Logger` messages were never persisted when probed — not
even to its current-process store — so the live test logs through
`/usr/bin/logger`, a real separate process, and finds the message again.

## Layout

`Core/UnifiedLog` · `Support/` PredicateBuilder, StreamLine, Summarizer (Tally)
· `Models/` LogEntry, LogQuery, LogSummary · `Enums/` LogLevel · `Errors/`
UnifiedLogError · `SafePredicate` (Objective-C target).

## Requirements

macOS 14, Swift 6.2.

## License

MIT — see [LICENSE](LICENSE).
