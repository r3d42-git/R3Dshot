import OSLog

enum AppLogger {
    static let subsystem = "org.r3d.R3Dshot"

    static let application = Logger(subsystem: subsystem, category: "application")
    static let capture = Logger(subsystem: subsystem, category: "capture")
    static let storage = Logger(subsystem: subsystem, category: "storage")
    static let shortcuts = Logger(subsystem: subsystem, category: "shortcuts")
}
