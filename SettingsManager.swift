import SwiftUI

@Observable
class SettingsManager {
    // Work目標時間
    var workMinutes: Int {
        didSet { UserDefaults.standard.set(workMinutes, forKey: "workMinutes") }
    }
    var workSeconds: Int {
        didSet { UserDefaults.standard.set(workSeconds, forKey: "workSeconds") }
    }

    // Free目標時間
    var freeMinutes: Int {
        didSet { UserDefaults.standard.set(freeMinutes, forKey: "freeMinutes") }
    }
    var freeSeconds: Int {
        didSet { UserDefaults.standard.set(freeSeconds, forKey: "freeSeconds") }
    }

    // Work目標達成時に通知
    var alertInWork: Bool {
        didSet { UserDefaults.standard.set(alertInWork, forKey: "alertInWork") }
    }

    var workTargetSeconds: Int {
        workMinutes * 60 + workSeconds
    }

    var freeTargetSeconds: Int {
        freeMinutes * 60 + freeSeconds
    }

    func targetSeconds(for mode: TimerMode) -> Int {
        switch mode {
        case .work: return workTargetSeconds
        case .free: return freeTargetSeconds
        }
    }

    init() {
        let defaults = UserDefaults.standard

        // デフォルト値を登録（初回のみ）
        defaults.register(defaults: [
            "workMinutes": 15,
            "workSeconds": 0,
            "freeMinutes": 15,
            "freeSeconds": 0,
            "alertInWork": true
        ])

        self.workMinutes = defaults.integer(forKey: "workMinutes")
        self.workSeconds = defaults.integer(forKey: "workSeconds")
        self.freeMinutes = defaults.integer(forKey: "freeMinutes")
        self.freeSeconds = defaults.integer(forKey: "freeSeconds")
        self.alertInWork = defaults.bool(forKey: "alertInWork")
    }
}
