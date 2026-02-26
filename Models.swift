import SwiftUI

// MARK: - Enums

enum TimerMode: String, Codable {
    case work
    case free
}

enum TimerPhase: Equatable {
    case idle
    case running
    case paused
    case alerting  // Free超過時
    case finished
}

enum AppScreen {
    case start
    case timer
    case result
    case calendar
}

// MARK: - Data Model

struct SessionRecord: Identifiable, Codable {
    let id: UUID
    let date: Date
    let mode: TimerMode  // 常に .work
    let durationSeconds: Int
    var notes: String

    init(id: UUID = UUID(), date: Date = Date(), mode: TimerMode = .work, durationSeconds: Int, notes: String = "") {
        self.id = id
        self.date = date
        self.mode = mode
        self.durationSeconds = durationSeconds
        self.notes = notes
    }
}

// MARK: - Design System

struct AppTheme {
    // --- Core Palette ---
    // Work: Warm, deep tones
    static let workPrimary = Color(hue: 0.02, saturation: 0.65, brightness: 0.28)     // Deep charcoal-brown
    static let workGradientTop = Color(hue: 0.98, saturation: 0.50, brightness: 0.22)
    static let workGradientBottom = Color(hue: 0.02, saturation: 0.70, brightness: 0.18)
    static let workAccent = Color(hue: 0.08, saturation: 0.55, brightness: 0.90)       // Warm amber

    // Free: Cool, calm tones
    static let freePrimary = Color(hue: 0.62, saturation: 0.55, brightness: 0.25)      // Deep navy-slate
    static let freeGradientTop = Color(hue: 0.58, saturation: 0.45, brightness: 0.20)
    static let freeGradientBottom = Color(hue: 0.65, saturation: 0.60, brightness: 0.15)
    static let freeAccent = Color(hue: 0.55, saturation: 0.40, brightness: 0.85)       // Soft sky blue

    // Semantic
    static let overtimeWork = Color(hue: 0.38, saturation: 0.60, brightness: 0.85)     // Soft green (good)
    static let overtimeFree = Color(hue: 0.0, saturation: 0.65, brightness: 0.90)      // Soft red (warning)

    // Neutral
    static let surface = Color(hue: 0, saturation: 0, brightness: 0.10)                // Near-black
    static let surfaceAlt = Color(hue: 0, saturation: 0, brightness: 0.14)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)
    static let textTertiary = Color.white.opacity(0.35)

    // Start screen
    static let startGradientTop = Color(hue: 0, saturation: 0, brightness: 0.08)
    static let startGradientBottom = Color(hue: 0, saturation: 0, brightness: 0.04)

    // Calendar accent
    static let chartBar = Color(hue: 0.08, saturation: 0.55, brightness: 0.80)

    // Background gradient for timer
    static func timerGradient(for mode: TimerMode) -> LinearGradient {
        let colors: [Color]
        switch mode {
        case .work: colors = [workGradientTop, workGradientBottom]
        case .free: colors = [freeGradientTop, freeGradientBottom]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    static func accent(for mode: TimerMode) -> Color {
        switch mode {
        case .work: return workAccent
        case .free: return freeAccent
        }
    }
}

// MARK: - Helpers

struct TimeFormatHelper {
    static func format(seconds: Int) -> String {
        let absSeconds = abs(seconds)
        let h = absSeconds / 3600
        let m = (absSeconds % 3600) / 60
        let s = absSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%d:%02d", m, s)
        }
    }
}

// MARK: - Record Storage

class RecordStore {
    private static let key = "session_records"
    private static let maxRecords = 100

    static func load() -> [SessionRecord] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([SessionRecord].self, from: data)) ?? []
    }

    static func save(_ records: [SessionRecord]) {
        let trimmed = Array(records.prefix(maxRecords))
        if let data = try? JSONEncoder().encode(trimmed) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func append(_ record: SessionRecord) {
        var records = load()
        records.insert(record, at: 0)
        save(records)
    }
}
