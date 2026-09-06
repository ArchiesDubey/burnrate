import os

/// An agent app has no window to print into, so anything worth diagnosing has
/// to go somewhere you can read it:
///
///     log stream --predicate 'subsystem == "com.burnrate.burnrate"' --level debug
enum Log {
    static let usage = Logger(subsystem: "com.burnrate.burnrate", category: "usage")
    static let sessions = Logger(subsystem: "com.burnrate.burnrate", category: "sessions")
}
