import UserNotifications
import AudioToolbox
import AVFoundation

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()
    private var audioPlayer: AVAudioPlayer?

    private override init() {
        super.init()
        center.delegate = self
    }

    // MARK: - フォアグラウンドでも通知を表示する

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // MARK: - 権限リクエスト

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // MARK: - Work目標達成通知（1回のみ）

    func notifyWorkComplete() {
        let content = UNMutableNotificationContent()
        content.title = "work終了です、お疲れ様でした"
        content.sound = .default

        let request = UNNotificationRequest(identifier: "TIMER_ALERT", content: content, trigger: nil)
        center.add(request)
    }

    // MARK: - Free超過通知

    func notifyFreeOvertime(minutesOver: Int) {
        let content = UNMutableNotificationContent()
        content.title = "workの時間です"
        if minutesOver <= 0 {
            content.body = "free時間を超過しています。"
        } else {
            content.body = "free時間を\(minutesOver)分超過しています。"
        }
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let id = "TIMER_ALERT_\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        center.add(request)
    }

    // MARK: - アラート音（フォアグラウンド用）

    func playAlert() {
        AudioServicesPlayAlertSound(SystemSoundID(1005))
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }

    // MARK: - バックグラウンド通知予約（Free超過用: 10秒間隔で複数スケジュール）

    func scheduleFreeOvertimeBackgroundNotifications() {
        // 10秒間隔で最大30個（5分分）予約
        for i in 1...30 {
            let seconds = i * 10
            let minutesOver = seconds / 60

            let content = UNMutableNotificationContent()
            content.title = "workの時間です"
            if minutesOver <= 0 {
                content.body = "free時間を超過しています。"
            } else {
                content.body = "free時間を\(minutesOver)分超過しています。"
            }
            content.sound = .default
            content.interruptionLevel = .timeSensitive

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
            let request = UNNotificationRequest(identifier: "TIMER_ALERT_BG_\(i)", content: content, trigger: trigger)
            center.add(request)
        }
    }

    // MARK: - バックグラウンド通知予約（Work/Free カウントダウン中）

    func scheduleBackgroundNotification(mode: TimerMode, remainingSeconds: Int) {
        guard remainingSeconds > 0 else { return }

        let content = UNMutableNotificationContent()
        content.sound = .default

        switch mode {
        case .work:
            content.title = "work終了です、お疲れ様でした"
        case .free:
            content.title = "workの時間です"
            content.body = "free時間を超過しています。"
            // Freeの場合は目標到達時＋その後10秒間隔の通知も予約
            scheduleFreeOvertimeAfter(seconds: remainingSeconds)
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(remainingSeconds), repeats: false)
        let request = UNNotificationRequest(identifier: "TIMER_ALERT_BG_0", content: content, trigger: trigger)
        center.add(request)
    }

    /// Free目標到達後に10秒間隔で追加通知を予約
    private func scheduleFreeOvertimeAfter(seconds baseDelay: Int) {
        for i in 1...30 {
            let delay = baseDelay + (i * 10)
            let minutesOver = (i * 10) / 60

            let content = UNMutableNotificationContent()
            content.title = "workの時間です"
            if minutesOver <= 0 {
                content.body = "free時間を超過しています。"
            } else {
                content.body = "free時間を\(minutesOver)分超過しています。"
            }
            content.sound = .default
            content.interruptionLevel = .timeSensitive

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(delay), repeats: false)
            let request = UNNotificationRequest(identifier: "TIMER_ALERT_BG_\(i)", content: content, trigger: trigger)
            center.add(request)
        }
    }

    // MARK: - バックグラウンド通知キャンセル

    func cancelBackgroundNotifications() {
        let ids = (0...30).map { "TIMER_ALERT_BG_\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - 全通知クリア

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
}
