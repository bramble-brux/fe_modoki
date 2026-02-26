import UserNotifications
import AudioToolbox

class NotificationManager {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()

    private init() {}

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

        let request = UNNotificationRequest(identifier: "TIMER_ALERT", content: content, trigger: nil)
        center.add(request)
    }

    // MARK: - アラート音

    func playAlert() {
        AudioServicesPlayAlertSound(SystemSoundID(1005))
    }

    // MARK: - バックグラウンド通知予約

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
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(remainingSeconds), repeats: false)
        let request = UNNotificationRequest(identifier: "TIMER_ALERT_BG", content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - バックグラウンド通知キャンセル

    func cancelBackgroundNotification() {
        center.removePendingNotificationRequests(withIdentifiers: ["TIMER_ALERT_BG"])
    }

    // MARK: - 全通知クリア

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
