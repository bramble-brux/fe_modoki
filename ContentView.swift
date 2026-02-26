import SwiftUI
import AudioToolbox
import UserNotifications
import Charts

// ──────────────────────────────────────────────
// MARK: - Data Models
// ──────────────────────────────────────────────

enum TimerMode: String, Codable {
    case work = "Work"
    case free = "Free"

    var icon: String {
        switch self {
        case .work: return "dumbbell.fill"
        case .free: return "gamecontroller.fill"
        }
    }

    var opposite: TimerMode {
        self == .work ? .free : .work
    }
}

struct SessionRecord: Identifiable, Codable {
    let id: UUID
    let date: Date
    let mode: TimerMode
    let durationSeconds: Int
    var notes: String

    init(mode: TimerMode, durationSeconds: Int, notes: String = "") {
        self.id = UUID()
        self.date = Date()
        self.mode = mode
        self.durationSeconds = durationSeconds
        self.notes = notes
    }

    var formattedDuration: String {
        let h = durationSeconds / 3600
        let m = (durationSeconds % 3600) / 60
        let s = durationSeconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%dm %02ds", m, s)
    }
}

// ──────────────────────────────────────────────
// MARK: - AppStorage helper
// ──────────────────────────────────────────────

extension Array: @retroactive RawRepresentable where Element: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([Element].self, from: data)
        else { return nil }
        self = decoded
    }
    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let str = String(data: data, encoding: .utf8)
        else { return "[]" }
        return str
    }
}

// ──────────────────────────────────────────────
// MARK: - Color Helper
// ──────────────────────────────────────────────

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// ──────────────────────────────────────────────
// MARK: - App Phase & Screen
// ──────────────────────────────────────────────

enum AppPhase {
    case idle       // Before start
    case running    // Timer counting
    case paused     // Timer paused
    case alerting   // Free target reached, alarm sounding
    case finished   // Session complete, showing summary
}

enum AppScreen {
    case start
    case timer
    case calendar
    case result
}

// ──────────────────────────────────────────────
// MARK: - Design Constants
// ──────────────────────────────────────────────

private enum Theme {
    static let wineRed  = Color(hex: "722F37")
    static let navy     = Color(hex: "000080")
    static let success  = Color.green         // Work 超過時の文字色
    static let warning  = Color.red           // Free 超過時の文字色
}

// ──────────────────────────────────────────────
// MARK: - Notification Manager
// ──────────────────────────────────────────────

class NotificationManager: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    @Published var actionReceived: Bool = false

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == "STOP_ACTION" {
            DispatchQueue.main.async {
                self.actionReceived = true
            }
        }
        completionHandler()
    }
}

// ──────────────────────────────────────────────
// MARK: - ContentView
// ──────────────────────────────────────────────

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var backgroundDate: Date? = nil

    // ── Persistent settings ──
    @AppStorage("workMinutes")  private var workMinutes  = 15
    @AppStorage("workSeconds")  private var workSeconds  = 0
    @AppStorage("freeMinutes")  private var freeMinutes  = 15
    @AppStorage("freeSeconds")  private var freeSeconds  = 0
    @AppStorage("alertInWork")  private var alertInWork  = true
    @AppStorage("history")      private var history: [SessionRecord] = []

    // ── Runtime state ──
    @StateObject private var notificationManager = NotificationManager()
    @State private var screen: AppScreen   = .start
    @State private var mode: TimerMode     = .work
    @State private var elapsed: Int        = 0
    @State private var phase: AppPhase     = .idle
    @State private var workAlertFired      = false
    @State private var freeAlertCount      = 0
    @State private var showSettings        = false

    // ── Session aggregation ──
    @State private var sessionWorkSeconds: Int = 0

    // ── Timer ──
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // ── Computed ──
    private var target: Int {
        mode == .work
            ? workMinutes * 60 + workSeconds
            : freeMinutes * 60 + freeSeconds
    }

    private var isOvertime: Bool {
        mode == .work && elapsed >= target
    }

    private var timerDisplayColor: Color {
        if mode == .free && phase == .alerting { return Theme.warning }
        if isOvertime { return Theme.success }
        return .white
    }

    private var displayTime: String {
        if isOvertime {
            return formatTime(elapsed - target)
        } else {
            return formatTime(max(target - elapsed, 0))
        }
    }

    private var backgroundColor: Color {
        guard screen == .timer else { return .black }
        return mode == .work ? Theme.wineRed : Theme.navy
    }

    // ──────────────────────────────────────────
    // MARK: - Body
    // ──────────────────────────────────────────

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                VStack(spacing: 0) {
                    switch screen {
                    case .start:    startView
                    case .timer:    timerView
                    case .calendar: calendarView
                    case .result:   resultView
                    }

                    Spacer()

                    Text("v2.0.1")
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.4))
                        .padding(.bottom, 8)
                }
            }
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showSettings) {
                SettingsView(
                    workMin: $workMinutes, workSec: $workSeconds,
                    freeMin: $freeMinutes, freeSec: $freeSeconds,
                    alertInWork: $alertInWork
                )
            }
            .onAppear(perform: requestNotificationPermission)
            .onReceive(tick) { _ in handleTick() }
            .onReceive(notificationManager.$actionReceived) { received in
                if received {
                    stopAndSwitch()
                    notificationManager.actionReceived = false
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                handleScenePhaseChange(newPhase)
            }
        }
    }

    // ──────────────────────────────────────────
    // MARK: - Start Screen
    // ──────────────────────────────────────────

    private var startView: some View {
        VStack(spacing: 60) {
            Spacer()

            HStack(spacing: 30) {
                modeStartButton(.work)
                modeStartButton(.free)
            }

            HStack(spacing: 60) {
                Button { screen = .calendar } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "calendar").font(.title)
                        Text("カレンダー").font(.caption)
                    }.foregroundColor(.white.opacity(0.7))
                }
                Button { showSettings = true } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "gearshape.fill").font(.title)
                        Text("設定").font(.caption)
                    }.foregroundColor(.white.opacity(0.7))
                }
            }

            Spacer()
        }
    }

    private func modeStartButton(_ m: TimerMode) -> some View {
        let bg = m == .work ? Theme.wineRed : Theme.navy
        return Button { beginWith(m) } label: {
            VStack(spacing: 12) {
                Image(systemName: m.icon)
                    .font(.system(size: 40))
                Text(m == .work ? "Work スタート" : "Free スタート")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(width: 130, height: 130)
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .fill(bg)
                    .shadow(color: bg.opacity(0.5), radius: 12, y: 6)
            )
        }
    }

    // ──────────────────────────────────────────
    // MARK: - Timer Screen
    // ──────────────────────────────────────────

    private var timerView: some View {
        VStack(spacing: 0) {
            // Mode header
            HStack(spacing: 12) {
                Image(systemName: mode.icon)
                Text(mode.rawValue)
            }
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.top, 40)

            Spacer()

            // Timer display
            Text(displayTime)
                .font(.system(size: 100, weight: .thin, design: .monospaced))
                .foregroundColor(timerDisplayColor)
                .padding(.vertical, 20)
                .contentTransition(.numericText())

            Spacer()

            // Controls
            VStack(spacing: 30) {
                // 大ボタン: モード切り替え
                Button { stopAndSwitch() } label: {
                    Text(mode == .work ? "Free へ" : "Work へ")
                        .font(.title2.bold())
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Capsule().fill(Color.white))
                        .padding(.horizontal, 40)
                }

                // 小ボタン: 一時停止 & 終了（固定レイアウト）
                HStack(spacing: 0) {
                    // 一時停止 / 再開
                    Group {
                        if mode == .free && phase == .alerting {
                            // Free 超過時は一時停止非表示（でもスペース維持）
                            Color.clear
                        } else {
                            Button {
                                if phase == .running { phase = .paused }
                                else if phase == .paused { phase = .running }
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: phase == .paused ? "play.fill" : "pause.fill")
                                        .font(.title)
                                    Text(phase == .paused ? "再開" : "一時停止")
                                        .font(.caption)
                                }
                                .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                    .frame(width: 100, height: 60)

                    Spacer().frame(width: 40)

                    // 終了
                    Button { finishSession() } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "flag.checkered")
                                .font(.title)
                            Text("終了")
                                .font(.caption)
                        }
                        .foregroundColor(.white.opacity(0.8))
                    }
                    .frame(width: 100, height: 60)
                }
            }
            .padding(.bottom, 60)
        }
    }

    // ──────────────────────────────────────────
    // MARK: - Result Screen
    // ──────────────────────────────────────────

    private var resultView: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(Theme.success)

            Text("お疲れ様でした")
                .font(.title.bold())
                .foregroundColor(.white)

            VStack(spacing: 8) {
                Text("今回の Work 合計時間")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text(formatTime(sessionWorkSeconds))
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.06)))

            Spacer()

            Button { backToStart() } label: {
                Text("スタートに戻る")
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 15)
                    .background(Capsule().fill(Color.white))
            }
            .padding(.bottom, 60)
        }
    }

    // ──────────────────────────────────────────
    // MARK: - Calendar Screen
    // ──────────────────────────────────────────

    private var calendarView: some View {
        HistoryView(records: $history, onDismiss: { screen = .start })
    }

    // ──────────────────────────────────────────
    // MARK: - Actions
    // ──────────────────────────────────────────

    private func beginWith(_ startMode: TimerMode) {
        mode = startMode
        elapsed = 0
        workAlertFired = false
        sessionWorkSeconds = 0
        freeAlertCount = 0
        phase = .running
        screen = .timer
    }

    private func stopAndSwitch() {
        if mode == .work { sessionWorkSeconds += elapsed }
        mode = mode.opposite
        elapsed = 0
        workAlertFired = false
        freeAlertCount = 0
        phase = .running
    }

    private func finishSession() {
        if mode == .work { sessionWorkSeconds += elapsed }
        // Only record if there was actual Work time
        if sessionWorkSeconds > 0 {
            let record = SessionRecord(mode: .work, durationSeconds: sessionWorkSeconds)
            history.insert(record, at: 0)
            if history.count > 100 { history.removeLast() }
        }
        screen = .result
        phase = .finished
    }

    private func backToStart() {
        screen = .start
        phase = .idle
    }

    // ──────────────────────────────────────────
    // MARK: - Timer Logic
    // ──────────────────────────────────────────

    private func handleTick() {
        // Free alerting: sound loop + periodic notifications
        if phase == .alerting {
            if mode == .free {
                // elapsed は target で停止済み。経過秒数だけ追跡して通知回数を管理
                freeAlertCount += 1
                if freeAlertCount % 60 == 0 {
                    let mins = freeAlertCount / 60
                    scheduleNotification(
                        title: "workの時間です",
                        body: "free時間を\(mins)分超過しています。"
                    )
                }
            }
            playSound()
            return
        }

        guard phase == .running else { return }

        elapsed += 1

        switch mode {
        case .free:
            if elapsed >= target {
                elapsed = target
                phase = .alerting
                freeAlertCount = 0
                scheduleNotification(title: "workの時間です", body: "free時間を超過しています。")
            }
        case .work:
            if alertInWork && elapsed == target && !workAlertFired {
                workAlertFired = true
                playSound()
                scheduleNotification(title: "work終了です、お疲れ様でした", body: "")
            }
        }
    }

    // ──────────────────────────────────────────
    // MARK: - Helpers
    // ──────────────────────────────────────────

    private func formatTime(_ total: Int) -> String {
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    private func playSound() {
        AudioServicesPlaySystemSound(1005)
    }

    // ──────────────────────────────────────────
    // MARK: - Notifications
    // ──────────────────────────────────────────

    private func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if granted { setupNotificationActions() }
        }
    }

    private func setupNotificationActions() {
        let action = UNNotificationAction(identifier: "STOP_ACTION", title: "STOP / 次へ", options: [.foreground])
        let category = UNNotificationCategory(identifier: "TIMER_CATEGORY", actions: [action], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    private func scheduleNotification(title: String, body: String, delay: TimeInterval? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "TIMER_CATEGORY"

        var trigger: UNNotificationTrigger? = nil
        if let d = delay, d > 0 {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: d, repeats: false)
        }

        let id = delay != nil ? "TIMER_ALERT_BG" : "TIMER_ALERT"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // ──────────────────────────────────────────
    // MARK: - Scene Phase Handling
    // ──────────────────────────────────────────

    private func handleScenePhaseChange(_ newScenePhase: ScenePhase) {
        switch newScenePhase {
        case .background:
            backgroundDate = Date()
            // バックグラウンド移行時に目標到達の通知を予約
            if phase == .running && !isOvertime {
                let remaining = TimeInterval(target - elapsed)
                if remaining > 0 {
                    let title = mode == .work
                        ? "work終了です、お疲れ様でした"
                        : "workの時間です"
                    let body = mode == .work
                        ? ""
                        : "free時間を超過しています。"
                    scheduleNotification(title: title, body: body, delay: remaining)
                }
            }
        case .active:
            if let start = backgroundDate {
                let diff = Int(Date().timeIntervalSince(start))
                if phase == .running {
                    elapsed += diff
                    if mode == .free && elapsed >= target {
                        elapsed = target
                        phase = .alerting
                        freeAlertCount = 0
                    }
                } else if phase == .paused {
                    // Paused 中はタイマーを進めない
                }
                backgroundDate = nil
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["TIMER_ALERT_BG"])
            }
        default:
            break
        }
    }
}

// ──────────────────────────────────────────────
// MARK: - SettingsView
// ──────────────────────────────────────────────

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var workMin: Int
    @Binding var workSec: Int
    @Binding var freeMin: Int
    @Binding var freeSec: Int
    @Binding var alertInWork: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    durationRow(icon: "dumbbell.fill", label: "分", selection: $workMin, range: 0...120)
                    durationRow(icon: "clock",         label: "秒", selection: $workSec, range: 0...59)
                } header: {
                    Text("仕事の時間")
                }

                Section {
                    durationRow(icon: "gamecontroller.fill", label: "分", selection: $freeMin, range: 0...120)
                    durationRow(icon: "clock",               label: "秒", selection: $freeSec, range: 0...59)
                } header: {
                    Text("休憩の時間")
                }

                Section {
                    Toggle(isOn: $alertInWork) {
                        HStack {
                            Image(systemName: "bell.fill")
                            Text("Work目標達成時に通知")
                        }
                    }
                } header: {
                    Text("通知設定")
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }.fontWeight(.bold)
                }
            }
        }
    }

    private func durationRow(icon: String, label: String, selection: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Image(systemName: icon)
            Text(label)
            Spacer()
            Picker("", selection: selection) {
                ForEach(range, id: \.self) { Text("\($0)").tag($0) }
            }.pickerStyle(.menu)
        }
    }
}

// ──────────────────────────────────────────────
// MARK: - HistoryView (カレンダー)
// ──────────────────────────────────────────────

struct HistoryView: View {
    @Binding var records: [SessionRecord]
    var onDismiss: () -> Void
    @State private var editMode: EditMode = .inactive

    // Work 記録のみ表示
    private var workRecords: [SessionRecord] {
        records.filter { $0.mode == .work }
    }

    // 月間チャート用データ
    struct DailyTotal: Identifiable {
        let id = UUID()
        let day: Int
        let seconds: Int
    }

    private var chartData: [DailyTotal] {
        let cal = Calendar.current
        let now = Date()
        let month = cal.component(.month, from: now)
        let year  = cal.component(.year, from: now)

        var dailyMap: [Int: Int] = [:]
        for r in workRecords {
            if cal.component(.month, from: r.date) == month &&
               cal.component(.year, from: r.date) == year {
                let day = cal.component(.day, from: r.date)
                dailyMap[day, default: 0] += r.durationSeconds
            }
        }
        return dailyMap.map { DailyTotal(day: $0.key, seconds: $0.value) }
                       .sorted { $0.day < $1.day }
    }

    private var monthlyWorkTotal: Int {
        chartData.reduce(0) { $0 + $1.seconds }
    }

    var body: some View {
        NavigationStack {
            List {
                // ── 月間統計 ──
                Section("月間統計") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("今月の Work 合計")
                                    .font(.caption).foregroundColor(.gray)
                                Text(formatHM(monthlyWorkTotal))
                                    .font(.title.bold())
                            }
                            Spacer()
                        }

                        if !chartData.isEmpty {
                            Chart(chartData) { item in
                                BarMark(
                                    x: .value("Day", item.day),
                                    y: .value("Minutes", item.seconds / 60)
                                )
                                .foregroundStyle(Theme.success.gradient)
                                .cornerRadius(3)
                            }
                            .frame(height: 100)
                            .chartXAxisLabel("日")
                            .chartYAxisLabel("分")
                        } else {
                            Text("データがありません")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // ── 履歴リスト ──
                if workRecords.isEmpty {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            Text("履歴がありません")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .listRowBackground(Color.clear)
                    }
                } else {
                    Section("Work 履歴") {
                        ForEach($records) { $r in
                            if r.mode == .work {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(r.date, style: .date)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            Text(r.date, style: .time)
                                                .font(.caption2)
                                                .foregroundColor(.gray.opacity(0.7))
                                        }
                                        Spacer()
                                        Text(r.formattedDuration)
                                            .font(.system(.body, design: .monospaced))
                                    }

                                    TextField("メモ...", text: $r.notes)
                                        .font(.caption)
                                        .padding(8)
                                        .background(Color.white.opacity(0.05))
                                        .cornerRadius(8)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete { records.remove(atOffsets: $0) }
                    }
                }
            }
            .navigationTitle("カレンダー")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .environment(\.editMode, $editMode)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        editMode = (editMode == .inactive) ? .active : .inactive
                    } label: {
                        Image(systemName: editMode == .inactive ? "pencil.circle" : "checkmark.circle.fill")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }

    private func formatHM(_ total: Int) -> String {
        let h = total / 3600
        let m = (total % 3600) / 60
        return String(format: "%dh %02dm", h, m)
    }
}

#Preview { ContentView() }
