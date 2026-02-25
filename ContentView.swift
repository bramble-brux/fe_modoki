import SwiftUI
import AudioToolbox

// MARK: - Models

enum TimerMode: String, CaseIterable, Codable {
    case work = "Work"
    case free = "Free"

    var color: Color {
        switch self {
        case .work: return .red
        case .free: return .green
        }
    }
}

struct SessionRecord: Identifiable, Codable {
    let id: UUID
    let date: Date
    let mode: TimerMode
    let duration: Int // in seconds
    
    init(mode: TimerMode, duration: Int) {
        self.id = UUID()
        self.date = Date()
        self.mode = mode
        self.duration = duration
    }
}

// MARK: - AppStorage Helpers

extension Array: @retroactive RawRepresentable where Element: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([Element].self, from: data)
        else { return nil }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else { return "[]" }
        return result
    }
}

// MARK: - Views

struct ContentView: View {
    // Persistent Settings
    @AppStorage("workMinutes") private var workMinutes = 15
    @AppStorage("workSeconds") private var workSeconds = 0
    @AppStorage("freeMinutes") private var freeMinutes = 15
    @AppStorage("freeSeconds") private var freeSeconds = 0
    @AppStorage("alertInWork") private var alertInWork = false
    @AppStorage("sessionHistory") private var history: [SessionRecord] = []
    
    // Timer State
    @State private var mode: TimerMode = .work
    @State private var secondsElapsed: Int = 0
    @State private var isActive = false
    @State private var isAlerting = false
    
    @State private var showingSettings = false
    @State private var showingHistory = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let appVersion = "v1.2.0"

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            VStack(spacing: 40) {
                // Header
                HStack {
                    Button(action: { showingHistory = true }) {
                        Image(systemName: "list.bullet.rectangle.portrait")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    }
                }
                .padding()

                Spacer()

                // Mode Display
                Text(mode.rawValue)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(mode.color)
                    .padding(.bottom, 10)

                // Main Time Display
                Text(formatTime(secondsElapsed))
                    .font(.system(size: 100, weight: .medium, design: .monospaced))
                    .foregroundColor(timeColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(mode.color.opacity(0.3), lineWidth: 2)
                            .padding(-20)
                    )

                Spacer()

                // Unified Control Section
                VStack(spacing: 30) {
                    HStack(spacing: 40) {
                        // Play / Pause / Stop Alert
                        Button(action: mainButtonAction) {
                            ZStack {
                                Circle()
                                    .fill(mainButtonColor)
                                    .frame(width: 120, height: 120)
                                    .shadow(color: mainButtonColor.opacity(0.5), radius: 10)
                                
                                Image(systemName: mainButtonIcon)
                                    .font(.system(size: 50, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }

                        // Reset / Manual Switch
                        Button(action: resetOrSwitchAction) {
                            ZStack {
                                Circle()
                                    .stroke(Color.gray, lineWidth: 3)
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: resetOrSwitchIcon)
                                    .font(.system(size: 30))
                                    .foregroundColor(.gray)
                            }
                        }
                        .disabled(isAlerting)
                    }
                    
                    // Switch Mode Toggle-like Button
                    if !isAlerting {
                        Button(action: manualSwitch) {
                            Text("Switch to \(mode == .work ? "Free" : "Work")")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                                .background(Capsule().fill(Color.gray.opacity(0.2)))
                        }
                    }
                }

                Spacer()

                Text(appVersion)
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.5))
                    .padding(.bottom, 10)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                workMinutes: $workMinutes,
                workSeconds: $workSeconds,
                freeMinutes: $freeMinutes,
                freeSeconds: $freeSeconds,
                alertInWork: $alertInWork
            )
        }
        .sheet(isPresented: $showingHistory) {
            HistoryView(history: $history)
        }
        .onReceive(timer) { _ in
            if isAlerting {
                playSound()
            }
            
            guard isActive else { return }

            secondsElapsed += 1
            let target = getTargetSeconds(for: mode)

            if mode == .free {
                if secondsElapsed >= target {
                    secondsElapsed = target // Pin at target
                    isActive = false
                    isAlerting = true
                    recordSession()
                }
            } else {
                // Work mode
                if alertInWork && secondsElapsed == target {
                    // Play sound once for Work mode
                    playSound()
                }
            }
        }
    }

    // MARK: - Logic Helpers

    private var timeColor: Color {
        let target = getTargetSeconds(for: mode)
        if mode == .work && secondsElapsed >= target {
            return .orange
        }
        return .white
    }

    private var mainButtonIcon: String {
        if isAlerting { return "stop.fill" }
        return isActive ? "pause.fill" : "play.fill"
    }

    private var mainButtonColor: Color {
        if isAlerting { return .red }
        return isActive ? .orange : .blue
    }

    private var resetOrSwitchIcon: String {
        return "arrow.clockwise"
    }

    private func mainButtonAction() {
        if isAlerting {
            stopAlert()
        } else {
            toggleTimer()
        }
    }

    private func resetOrSwitchAction() {
        resetTimer()
    }

    private func toggleTimer() {
        isActive.toggle()
    }

    private func resetTimer() {
        isActive = false
        isAlerting = false
        secondsElapsed = 0
    }

    private func manualSwitch() {
        recordSession()
        isActive = false
        isAlerting = false
        mode = (mode == .work ? .free : .work)
        secondsElapsed = 0
    }

    private func stopAlert() {
        isAlerting = false
        if mode == .free {
            // Requirements: Stop alert -> Switch to Work -> Auto start
            mode = .work
            secondsElapsed = 0
            isActive = true
        } else {
            // Work mode alert stop: just keep counting
            isActive = true
        }
    }

    private func recordSession() {
        if secondsElapsed > 0 {
            let record = SessionRecord(mode: mode, duration: secondsElapsed)
            history.insert(record, at: 0)
            // Limit to last 50 records
            if history.count > 50 {
                history.removeLast()
            }
        }
    }

    private func getTargetSeconds(for mode: TimerMode) -> Int {
        switch mode {
        case .work: return (workMinutes * 60) + workSeconds
        case .free: return (freeMinutes * 60) + freeSeconds
        }
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    private func playSound() {
        AudioServicesPlaySystemSound(1005)
    }
}

// MARK: - Subviews

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var workMinutes: Int
    @Binding var workSeconds: Int
    @Binding var freeMinutes: Int
    @Binding var freeSeconds: Int
    @Binding var alertInWork: Bool

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Work Duration")) {
                    Stepper("Minutes: \(workMinutes)", value: $workMinutes, in: 0...120)
                    Stepper("Seconds: \(workSeconds)", value: $workSeconds, in: 0...59)
                }
                
                Section(header: Text("Free Duration")) {
                    Stepper("Minutes: \(freeMinutes)", value: $freeMinutes, in: 0...120)
                    Stepper("Seconds: \(freeSeconds)", value: $freeSeconds, in: 0...59)
                }

                Section(header: Text("Notifications")) {
                    Toggle("Alarm in Work Mode", isOn: $alertInWork)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct HistoryView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var history: [SessionRecord]

    var body: some View {
        NavigationView {
            List {
                if history.isEmpty {
                    Text("No records found").foregroundColor(.secondary)
                } else {
                    ForEach(history) { record in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(record.mode.rawValue)
                                    .fontWeight(.bold)
                                    .foregroundColor(record.mode.color)
                                Text(record.date, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(formatDuration(record.duration))
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                    .onDelete(perform: deleteRecords)
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
        }
    }

    private func deleteRecords(at offsets: IndexSet) {
        history.remove(atOffsets: offsets)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%dm %ds", m, s)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
