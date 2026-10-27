import Foundation
import Combine

public enum LogLevel: String, Sendable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
}

public struct LogEntry: Identifiable, Sendable {
    public let id = UUID()
    public let timestamp: Date
    public let level: LogLevel
    public let tag: String
    public let message: String

    public var formattedText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return "[\(formatter.string(from: timestamp))] [\(level.rawValue)] [\(tag)] \(message)"
    }
}

public final class DebugLogger: @unchecked Sendable, ObservableObject {
    public static let shared = DebugLogger()

    @Published public private(set) var entries: [LogEntry] = []
    private let queue = DispatchQueue(label: "com.ufukcelen.youtubewidget.debuglogger", qos: .utility)
    public let logFileURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("YouTubeWidget", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.logFileURL = dir.appendingPathComponent("debug.log")

        log(.info, tag: "System", message: "DebugLogger initialized. Log file: \(logFileURL.path)")
    }

    public func log(_ level: LogLevel, tag: String, message: String) {
        let entry = LogEntry(timestamp: Date(), level: level, tag: tag, message: message)
        let formatted = entry.formattedText
        print(formatted)

        queue.async { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.entries.append(entry)
                if self.entries.count > 500 {
                    self.entries.removeFirst(self.entries.count - 500)
                }
            }

            // Append to disk file
            if let data = (formatted + "\n").data(using: .utf8) {
                if let fileHandle = try? FileHandle(forWritingTo: self.logFileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    try? fileHandle.close()
                } else {
                    try? data.write(to: self.logFileURL, options: .atomic)
                }
            }
        }
    }

    public func getRecentLogsText() -> String {
        return entries.map { $0.formattedText }.joined(separator: "\n")
    }

    public func clear() {
        entries.removeAll()
        try? FileManager.default.removeItem(at: logFileURL)
    }
}

