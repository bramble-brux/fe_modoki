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

    var color: Color {
        switch self {
        case .work: return .indigo
        case .free: return .mint
        }
    }

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
        let m = durationSeconds / 60
        let s = durationSeconds % 60
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
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }

    func toHex() -> String {
        let components = cgColor?.components ?? [0, 0, 0]
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}

// ──────────────────────────────────────────────
// MARK: - App Phase
// ──────────────────────────────────────────────

enum AppPhase {
    case idle       // Before start
    case running    // Timer counting
    case paused     // Timer paused
    case alerting   // Free target reached
    case finished   // Session complete, showing summary
}

enum AppScreen {
    case start
    case timer
    case calendar
    case result
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
    @AppStorage("alertInWork")  private var alertInWork  = true // User said Work alert persists in mock? Wait, spec says "Alert ON/OFF"
    @AppStorage("history")      private var history: [SessionRecord] = []
    @AppStorage("workHexColor") private var workHexColor = "4B0082" // Indigo
    @AppStorage("freeHexColor") private var freeHexColor = "00F5D4" // Mint

    // ── Runtime state ──
    @StateObject private var notificationManager = NotificationManager()
    @State private var screen: AppScreen   = .start
    @State private var mode: TimerMode     = .work
    @State private var elapsed: Int        = 0
    @State private var phase: AppPhase     = .idle
    @State private var workAlertFired      = false
    @State private var freeAlertCount      = 0 // To track 1-minute repeat notifications

    // ── Session aggregation ──
    @State private var sessionWorkSeconds: Int = 0 // Temporary storage for current session result

    // ── Timer Helper ──
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var target: Int {
        mode == .work
            ? workMinutes * 60 + workSeconds
            : freeMinutes * 60 + freeSeconds
    }

    private var isOvertime: Bool {
        mode == .work && elapsed >= target
    }

    private var isActive: Bool {
        phase == .running || phase == .alerting
    }

    private var activeDisplayColor: Color {
        if mode == .free && phase == .alerting { return .red }
        if isOvertime { return Color.green } // Bright green for Work overtime
        return .white
    }

    /// What to show on the timer display
    private var displayTime: String {
        if isOvertime {
            // Work overtime: show how much past target
            return formatTime(elapsed - target)
        } else {
            // Countdown: show remaining
            let remaining = max(target - elapsed, 0)
            return formatTime(remaining)
        }
    }

    // ── Body ──
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                VStack(spacing: 0) {
                    switch screen {
                    case .start:
                        startView
                    case .timer:
                        timerView
                    case .calendar:
                        calendarView
                    case .result:
                        resultView
                    }
                    
                    Spacer()
                    
                    Text("v2.0.0")
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
                    alertInWork: $alertInWork,
                    workHex: $workHexColor, freeHex: $freeHexColor
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
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handleScenePhaseChange(newPhase)
            }
        }
    }

    private var backgroundColor: Color {
        if screen == .timer {
            if mode == .free && phase == .alerting { return Color(hex: "000080") } // Navy
            return mode == .work ? Color(hex: "722F37") : Color(hex: "000080") // Wine Red / Navy
        }
        return .black
    }

    @State private var showSettings = false

    // ──────────────────────────────────────────
    // MARK: - Screen Views
    // ──────────────────────────────────────────

    private var startView: some View {
        VStack(spacing: 60) {
            Spacer().frame(height: 40)

            HStack(spacing: 30) {
                modeStartButton(.work)
                modeStartButton(.free)
            }

            HStack(spacing: 60) {
                Button { screen = .calendar } label: {
                    VStack {
                        Image(systemName: "calendar").font(.title)
                        Text("カレンダー").font(.caption)
                    }.foregroundColor(.white)
                }
                Button { showSettings = true } label: {
                    VStack {
                        Image(systemName: "gearshape.fill").font(.title)
                        Text("設定").font(.caption)
                    }.foregroundColor(.white)
                }
            }
            .padding(.top, 20)
        }
    }

    private func modeStartButton(_ m: TimerMode) -> some View {
        Button { beginWith(m) } label: {
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
                    .fill(m == .work ? Color(hex: "722F37") : Color(hex: "000080")) // Wine Red / Navy
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
            )
        }
    }

    private var timerView: some View {
        VStack(spacing: 0) {
            // Mode icon + label
            HStack(spacing: 12) {
                Image(systemName: mode.icon)
                Text(mode.rawValue)
            }
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.top, 40)

            Spacer()

            // Timer Display
            Text(displayTime)
                .font(.system(size: 100, weight: .thin, design: .monospaced))
                .foregroundColor(activeDisplayColor)
                .padding(.vertical, 20)

            Spacer()

            // Controls
            VStack(spacing: 30) {
                // Large Next Button
                Button { stopAndSwitch() } label: {
                    Text(mode == .work ? "Free へ" : "Work へ")
                        .font(.title2.bold())
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Capsule().fill(Color.white))
                        .padding(.horizontal, 40)
                }
                .disabled(mode == .free && phase == .alerting && elapsed >= target) // Free overtime shouldn't disable Next, but spec says "Workへボタン(大)" is available.

                HStack(spacing: 40) {
                    // Constant layout for Pause/Finish buttons
                    // Use opacity and disabled state to keep positions stable
                    Button {
                        if phase == .running { phase = .paused }
                        else if phase == .paused { phase = .running }
                    } label: {
                        VStack {
                            Image(systemName: phase == .paused ? "play.fill" : "pause.fill")
                                .font(.title)
                            Text(phase == .paused ? "再開" : "一時停止")
                                .font(.caption)
                        }
                        .frame(width: 80)
                    }
                    .opacity(mode == .free && phase == .alerting ? 0 : 1)
                    .disabled(mode == .free && phase == .alerting)

                    // Finish
                    Button { finishSession() } label: {
                        VStack {
                            Image(systemName: "flag.checkered")
                                .font(.title)
                            Text("終了")
                                .font(.caption)
                        }
                        .frame(width: 80)
                    }
                }
                .foregroundColor(.white.opacity(0.8))
            }
            .padding(.bottom, 60)
        }
    }

    private var resultView: some View {
        VStack(spacing: 30) {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                Text("お疲れ様でした")
                    .font(.title.bold())
            }
            .padding(.top, 60)

            VStack(spacing: 8) {
                Text("今回の Work 合計時間")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text(formatTime(sessionWorkSeconds))
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.05)))

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
        phase = .running
                screen = .timer
        freeAlertCount = 0
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
        recordSession()
        screen = .result
        phase = .finished
    }

    private func backToStart() {
        screen = .start
        phase = .idle
    }

    // ──────────────────────────────────────────
    // MARK: - Timer logic
    // ──────────────────────────────────────────

    private func handleTick() {
        if phase == .alerting {
            // Free mode overtime notification logic
            if mode == .free && elapsed >= target {
                // Check if 60 seconds passed since last alert count
                let overtime = elapsed - target
                let currentCount = overtime / 60
                if currentCount > freeAlertCount {
                    freeAlertCount = currentCount
                    scheduleNotification(title: "workの時間です", body: "free時間を\(currentCount)分超過しています。")
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

    private func recordSession() {
        guard elapsed > 0 else { return }
        let record = SessionRecord(mode: mode, durationSeconds: elapsed)
        history.insert(record, at: 0)
        if history.count > 50 { history.removeLast() }
    }

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
            if granted {
                setupNotificationActions()
            }
        }
    }

    private func setupNotificationActions() {
        let stopAction = UNNotificationAction(identifier: "STOP_ACTION", title: "STOP / 次へ", options: [.foreground])
        let category = UNNotificationCategory(identifier: "TIMER_CATEGORY", actions: [stopAction], intentIdentifiers: [], options: [])
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

        let request = UNNotificationRequest(identifier: "TIMER_ALERT", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // ──────────────────────────────────────────
    // MARK: - Scene Phase Handling
    // ──────────────────────────────────────────

    private func handleScenePhaseChange(_ newScenePhase: ScenePhase) {
        switch newScenePhase {
        case .background:
            backgroundDate = Date()
            // Schedule future notification if timer is running
            if self.phase == .running && !isOvertime {
                let remaining = TimeInterval(target - elapsed)
                if remaining > 0 {
                    let title = mode == .work ? "Work 目標達成" : "Free 終了"
                    let body = mode == .work ? "お疲れ様です！延長も可能です。" : "Work に切り替えてください"
                    scheduleNotification(title: title, body: body, delay: remaining)
                }
            }
        case .active:
            if let start = backgroundDate {
                let diff = Int(Date().timeIntervalSince(start))
                if self.phase == .running {
                    elapsed += diff
                    // Catch up logic: check if we should be alerting now
                    if mode == .free && elapsed >= target {
                        elapsed = target
                        self.phase = .alerting
                    }
                    // For Work mode, it just continues as overtime, color changes automatically
                }
                backgroundDate = nil
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["TIMER_ALERT"])
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
    @Binding var workHex: String
    @Binding var freeHex: String

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: "dumbbell.fill").foregroundColor(.white)
                        Text("分")
                        Spacer()
                        Picker("", selection: $workMin) {
                            ForEach(0...120, id: \.self) { Text("\($0)").tag($0) }
                        }.pickerStyle(.menu)
                    }
                    HStack {
                        Image(systemName: "clock").foregroundColor(.white)
                        Text("秒")
                        Spacer()
                        Picker("", selection: $workSec) {
                            ForEach(0...59, id: \.self) { Text("\($0)").tag($0) }
                        }.pickerStyle(.menu)
                    }
                } header: {
                    Text("仕事の時間").foregroundColor(.white)
                }

                Section {
                    HStack {
                        Image(systemName: "gamecontroller.fill").foregroundColor(.white)
                        Text("分")
                        Spacer()
                        Picker("", selection: $freeMin) {
                            ForEach(0...120, id: \.self) { Text("\($0)").tag($0) }
                        }.pickerStyle(.menu)
                    }
                    HStack {
                        Image(systemName: "clock").foregroundColor(.white)
                        Text("秒")
                        Spacer()
                        Picker("", selection: $freeSec) {
                            ForEach(0...59, id: \.self) { Text("\($0)").tag($0) }
                        }.pickerStyle(.menu)
                    }
                } header: {
                    Text("休憩の時間").foregroundColor(.white)
                }

                Section {
                    Toggle(isOn: $alertInWork) {
                        HStack {
                            Image(systemName: "bell.fill").foregroundColor(.white)
                            Text("Work目標達成時に通知")
                        }
                    }
                } header: {
                    Text("通知設定").foregroundColor(.white)
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .foregroundColor(.white)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }.fontWeight(.bold).foregroundColor(.white)
                }
            }
        }
    }
}

// ──────────────────────────────────────────────
// MARK: - HistoryView
// ──────────────────────────────────────────────

struct HistoryView: View {
    @Binding var records: [SessionRecord]
    var onDismiss: () -> Void
    @State private var editMode: EditMode = .inactive
    
    // Aggregation logic for chart
    struct DailyTotal: Identifiable {
        let id = UUID()
        let day: Int
        let seconds: Int
    }
    
    private var chartData: [DailyTotal] {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date())
        let currentYear = calendar.component(.year, from: Date())
        
        let filtered = records.filter { r in
            r.mode == .work &&
            calendar.component(.month, from: r.date) == currentMonth &&
            calendar.component(.year, from: r.date) == currentYear
        }
        
        var dailyMap: [Int: Int] = [:]
        for r in filtered {
            let day = calendar.component(.day, from: r.date)
            dailyMap[day, default: 0] += r.durationSeconds
        }
        
        return dailyMap.map { DailyTotal(day: $0.key, seconds: $0.value) }.sorted { $0.day < $1.day }
    }
    
    private var monthlyWorkTotal: Int {
        chartData.reduce(0) { $0 + $1.seconds }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("今月の Work 合計").font(.caption).foregroundColor(.gray)
                                Text(formatSeconds(monthlyWorkTotal))
                                    .font(.title.bold())
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            Image(systemName: "chart.bar.fill").foregroundColor(.gray)
                        }
                        
                        if !chartData.isEmpty {
                            Chart(chartData) { item in
                                BarMark(
                                    x: .value("Day", item.day),
                                    y: .value("Seconds", item.seconds)
                                )
                                .foregroundStyle(Color.green.gradient)
                            }
                            .frame(height: 100)
                            .chartXAxis {
                                AxisMarks(values: .stride(by: 5))
                            }
                        } else {
                            Text("データがありません").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("月間統計")
                }

                if records.isEmpty {
                    VStack(spacing: 20) {
                        Spacer().frame(height: 40)
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("履歴がありません")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                } else {
                    Section("Work 履歴") {
                        ForEach($records) { $r in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(r.date, style: .date)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Text(r.date, style: .time)
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Text(r.formattedDuration)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(.white)
                                }
                                
                                TextField("メモ...", text: $r.notes)
                                    .font(.caption)
                                    .padding(8)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(8)
                            }
                            .padding(.vertical, 4)
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
                    Button(action: {
                        editMode = (editMode == .inactive) ? .active : .inactive
                    }) {
                        Image(systemName: editMode == .inactive ? "pencil.circle" : "checkmark.circle.fill")
                            .foregroundColor(.white)
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
    
    private func formatSeconds(_ total: Int) -> String {
        let h = total / 3600
        let m = (total % 3600) / 60
        return String(format: "%dh %02dm", h, m)
    }
}

#Preview { ContentView() }
