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
// カラーコーディネート方針:
//   ベース: ニュートラルな暗色（ほぼ黒）
//   Work: 暖色系アクセント（銅／琥珀） — 集中と活力
//   Free: 寒色系アクセント（ティール／シアン） — 休息と静寂
//   トーン: 両アクセントとも彩度を抑え、明度を揃えることで統一感を確保
//   超過: Work=セージグリーン（ポジティブ）、Free=コーラル（警告、攻撃的すぎない）

struct AppTheme {
    // --- Base ---
    static let bgPrimary   = Color(red: 0.07, green: 0.06, blue: 0.08)    // #110F14
    static let bgSecondary = Color(red: 0.04, green: 0.04, blue: 0.05)    // #0B0A0D
    static let surface     = Color(red: 0.11, green: 0.10, blue: 0.12)    // #1C1A1F
    static let surfaceAlt  = Color(red: 0.14, green: 0.13, blue: 0.15)    // #242126

    // --- Work (暖色: 銅・琥珀) ---
    static let workBgTop    = Color(red: 0.18, green: 0.10, blue: 0.07)   // はっきり暖かいダークブラウン
    static let workBgBottom = Color(red: 0.12, green: 0.06, blue: 0.04)
    static let workAccent   = Color(red: 0.87, green: 0.62, blue: 0.40)   // 銅・コッパー（少し明るめ）

    // --- Free (寒色: ティール・シアン) ---
    static let freeBgTop    = Color(red: 0.05, green: 0.10, blue: 0.18)   // はっきり冷たいダークブルー
    static let freeBgBottom = Color(red: 0.03, green: 0.06, blue: 0.12)
    static let freeAccent   = Color(red: 0.45, green: 0.70, blue: 0.78)   // ティール（少し明るめ）

    // --- Semantic ---
    static let overtimeGood = Color(red: 0.55, green: 0.75, blue: 0.51)   // #8CC082 セージグリーン
    static let overtimeBad  = Color(red: 0.83, green: 0.48, blue: 0.48)   // #D47B7B コーラル

    // --- Text ---
    static let textPrimary   = Color.white
    static let textSecondary = Color.white.opacity(0.55)
    static let textTertiary  = Color.white.opacity(0.25)
    static let textDisabled  = Color.white.opacity(0.15)

    // --- Derived ---
    static func timerGradient(for mode: TimerMode) -> LinearGradient {
        switch mode {
        case .work: return LinearGradient(colors: [workBgTop, workBgBottom], startPoint: .top, endPoint: .bottom)
        case .free: return LinearGradient(colors: [freeBgTop, freeBgBottom], startPoint: .top, endPoint: .bottom)
        }
    }

    static func accent(for mode: TimerMode) -> Color {
        switch mode {
        case .work: return workAccent
        case .free: return freeAccent
        }
    }

    static var startGradient: LinearGradient {
        LinearGradient(colors: [bgPrimary, bgSecondary], startPoint: .top, endPoint: .bottom)
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
