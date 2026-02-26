import SwiftUI
import Combine

@Observable
class TimerManager {
    // MARK: - State
    var mode: TimerMode = .work
    var phase: TimerPhase = .idle
    var elapsed: Int = 0           // 経過秒数
    var target: Int = 0            // 目標秒数
    var sessionWorkSeconds: Int = 0 // セッション中のWork累計

    // 内部
    var backgroundDate: Date? = nil
    private var workNotificationSent = false
    private var freeOvertimeSeconds: Int = 0
    private var timer: Timer? = nil
    private var freeAlertTimer: Timer? = nil  // Free超過中のアラート繰り返し用

    var settings: SettingsManager? = nil

    // MARK: - Computed

    /// 表示用の残り時間（カウントダウン）または超過時間（カウントアップ）
    var displaySeconds: Int {
        let remaining = target - elapsed
        if remaining > 0 {
            return remaining
        } else if mode == .work {
            return elapsed - target
        } else {
            return 0
        }
    }

    /// 超過しているか
    var isOvertime: Bool {
        elapsed >= target
    }

    // MARK: - Actions

    func beginWith(mode: TimerMode) {
        guard let settings = settings else { return }
        self.mode = mode
        self.phase = .running
        self.elapsed = 0
        self.target = settings.targetSeconds(for: mode)
        self.sessionWorkSeconds = 0
        self.workNotificationSent = false
        self.freeOvertimeSeconds = 0
        stopFreeAlertTimer()
        startTimer()
    }

    func togglePause() {
        switch phase {
        case .running:
            phase = .paused
            stopTimer()
        case .paused:
            phase = .running
            startTimer()
        default:
            break
        }
    }

    func stopAndSwitch() {
        guard let settings = settings else { return }
        stopTimer()
        stopFreeAlertTimer()

        // Work時間の累積
        if mode == .work {
            sessionWorkSeconds += elapsed
        }

        // モード切替
        let newMode: TimerMode = (mode == .work) ? .free : .work
        self.mode = newMode
        self.elapsed = 0
        self.target = settings.targetSeconds(for: newMode)
        self.phase = .running
        self.workNotificationSent = false
        self.freeOvertimeSeconds = 0

        startTimer()
    }

    func finishSession() {
        stopTimer()
        stopFreeAlertTimer()

        // 最後のWork時間を加算
        if mode == .work {
            sessionWorkSeconds += elapsed
        }

        // レコード保存
        let record = SessionRecord(durationSeconds: sessionWorkSeconds)
        RecordStore.append(record)

        phase = .finished
        NotificationManager.shared.cancelAll()
    }

    func reset() {
        stopTimer()
        stopFreeAlertTimer()
        phase = .idle
        elapsed = 0
        sessionWorkSeconds = 0
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard phase == .running else { return }

        elapsed += 1

        // 目標到達チェック
        if elapsed >= target {
            if mode == .work {
                // Work: 通知のみ（1回）、計測継続
                if !workNotificationSent {
                    workNotificationSent = true
                    if settings?.alertInWork == true {
                        NotificationManager.shared.playAlert()
                        NotificationManager.shared.notifyWorkComplete()
                    }
                }
            } else {
                // Free: 超過 — 即座にアラート開始
                if elapsed >= target {
                    phase = .alerting
                    elapsed = target  // 固定
                    stopTimer()
                    NotificationManager.shared.playAlert()
                    NotificationManager.shared.notifyFreeOvertime(minutesOver: 0)
                    startFreeAlertTimer()
                }
            }
        }
    }

    // MARK: - Free超過アラート（アプリ起動中、10秒ごとにアラート＋通知）

    private func startFreeAlertTimer() {
        stopFreeAlertTimer()
        freeOvertimeSeconds = 0
        // 10秒ごとにアラート音＋通知を繰り返す
        freeAlertTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            guard let self = self, self.phase == .alerting else {
                self?.stopFreeAlertTimer()
                return
            }
            self.freeOvertimeSeconds += 10
            NotificationManager.shared.playAlert()
            let minutesOver = self.freeOvertimeSeconds / 60
            if minutesOver > 0 {
                NotificationManager.shared.notifyFreeOvertime(minutesOver: minutesOver)
            } else {
                NotificationManager.shared.notifyFreeOvertime(minutesOver: 0)
            }
        }
    }

    private func stopFreeAlertTimer() {
        freeAlertTimer?.invalidate()
        freeAlertTimer = nil
    }

    // MARK: - Background Support

    func handleBackgroundTransition() {
        backgroundDate = Date()
        stopFreeAlertTimer()  // BG中はフォアグラウンドアラートは不要

        if phase == .running && !isOvertime {
            let remaining = target - elapsed
            NotificationManager.shared.scheduleBackgroundNotification(mode: mode, remainingSeconds: remaining)
        } else if mode == .free && phase == .alerting {
            // すでにFree超過中にバックグラウンドへ → 10秒間隔のBG通知を予約
            NotificationManager.shared.scheduleFreeOvertimeBackgroundNotifications()
        }
    }

    func handleForegroundTransition() {
        guard let bgDate = backgroundDate else { return }
        let diff = Int(Date().timeIntervalSince(bgDate))
        backgroundDate = nil

        NotificationManager.shared.cancelBackgroundNotifications()

        guard phase == .running || phase == .alerting else { return }

        if phase == .running {
            elapsed += diff

            if mode == .free && elapsed >= target {
                elapsed = target
                phase = .alerting
                stopTimer()
                NotificationManager.shared.playAlert()
                NotificationManager.shared.notifyFreeOvertime(minutesOver: 0)
                startFreeAlertTimer()
            } else if mode == .work && elapsed >= target && !workNotificationSent {
                workNotificationSent = true
            }
        } else if phase == .alerting {
            // BG中もalertingだった場合、FG復帰でフォアグラウンドアラート再開
            NotificationManager.shared.playAlert()
            startFreeAlertTimer()
        }
    }
}
