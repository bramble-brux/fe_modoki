import SwiftUI
import AudioToolbox

// ──────────────────────────────────────────────
// MARK: - Data Models
// ──────────────────────────────────────────────

enum TimerMode: String, Codable {
    case work = "Work"
    case free = "Free"

    var color: Color {
        switch self {
        case .work: return .red
        case .free: return .green
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

    init(mode: TimerMode, durationSeconds: Int) {
        self.id = UUID()
        self.date = Date()
        self.mode = mode
        self.durationSeconds = durationSeconds
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
// MARK: - App State
// ──────────────────────────────────────────────

/// Two possible phases of the timer
enum TimerPhase {
    case running    // Counting up
    case alerting   // Free target reached, alarm ringing
}

// ──────────────────────────────────────────────
// MARK: - ContentView
// ──────────────────────────────────────────────

struct ContentView: View {

    // ── Persistent settings ──
    @AppStorage("workMinutes")  private var workMinutes  = 15
    @AppStorage("workSeconds")  private var workSeconds  = 0
    @AppStorage("freeMinutes")  private var freeMinutes  = 15
    @AppStorage("freeSeconds")  private var freeSeconds  = 0
    @AppStorage("alertInWork")  private var alertInWork  = false
    @AppStorage("history")      private var history: [SessionRecord] = []

    // ── Runtime state ──
    @State private var mode: TimerMode     = .work
    @State private var elapsed: Int        = 0
    @State private var phase: TimerPhase   = .running
    @State private var workAlertFired      = false

    // ── Sheet toggles ──
    @State private var showSettings = false
    @State private var showHistory  = false

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

    // ── Body ──
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {

                // ─── Top bar ───
                topBar

                Spacer()

                // ─── Mode label ───
                Text(mode.rawValue)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(mode.color)

                // ─── Timer display ───
                Text(formatTime(elapsed))
                    .font(.system(size: 90, weight: .thin, design: .monospaced))
                    .foregroundColor(isOvertime ? .orange : .white)
                    .padding(.vertical, 16)

                Spacer()

                // ─── The ONE control area ───
                controlArea
                    .padding(.bottom, 32)

                // ─── Version ───
                Text("v1.5.0")
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.4))
                    .padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                workMin: $workMinutes, workSec: $workSeconds,
                freeMin: $freeMinutes, freeSec: $freeSeconds,
                alertInWork: $alertInWork,
                onDone: { elapsed = 0; phase = .running }
            )
        }
        .sheet(isPresented: $showHistory) {
            HistoryView(records: $history)
        }
        .onReceive(tick) { _ in handleTick() }
    }

    // ──────────────────────────────────────────
    // MARK: - Sub-views
    // ──────────────────────────────────────────

    private var topBar: some View {
        HStack {
            Button { showHistory = true } label: {
                Image(systemName: "list.bullet.rectangle.portrait")
                    .font(.title2).foregroundColor(.gray)
            }
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2).foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    /// Single button — always in the same position
    private var controlArea: some View {
        Button(action: buttonTapped) {
            VStack(spacing: 6) {
                Image(systemName: phase == .alerting ? "stop.fill" : "arrow.left.arrow.right")
                    .font(.system(size: 36, weight: .bold))
                Text(phase == .alerting ? "STOP" : "\(mode.opposite.rawValue) に切替")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(width: 130, height: 130)
            .background(
                Circle().fill(phase == .alerting ? Color.red : mode.opposite.color.opacity(0.8))
            )
        }
    }

    // ──────────────────────────────────────────
    // MARK: - Actions
    // ──────────────────────────────────────────

    /// Single handler for the one button
    private func buttonTapped() {
        recordSession()
        mode = mode.opposite
        elapsed = 0
        workAlertFired = false
        phase = .running
    }

    // ──────────────────────────────────────────
    // MARK: - Timer logic
    // ──────────────────────────────────────────

    private func handleTick() {
        if phase == .alerting {
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
            }
        case .work:
            if alertInWork && elapsed == target && !workAlertFired {
                workAlertFired = true
                playSound()
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
    var onDone: () -> Void

    var body: some View {
        NavigationView {
            Form {
                Section("Work Duration") {
                    Stepper("Minutes: \(workMin)", value: $workMin, in: 0...120)
                    Stepper("Seconds: \(workSec)", value: $workSec, in: 0...59)
                }
                Section("Free Duration") {
                    Stepper("Minutes: \(freeMin)", value: $freeMin, in: 0...120)
                    Stepper("Seconds: \(freeSec)", value: $freeSec, in: 0...59)
                }
                Section("Notifications") {
                    Toggle("Alert at Work target", isOn: $alertInWork)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDone(); dismiss() }
                }
            }
        }
    }
}

// ──────────────────────────────────────────────
// MARK: - HistoryView
// ──────────────────────────────────────────────

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var records: [SessionRecord]

    var body: some View {
        NavigationView {
            List {
                if records.isEmpty {
                    Text("No sessions recorded yet.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(records) { r in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(r.mode.rawValue)
                                    .fontWeight(.bold)
                                    .foregroundColor(r.mode.color)
                                Text(r.date, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(r.formattedDuration)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                    .onDelete { records.remove(atOffsets: $0) }
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { EditButton() }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

#Preview { ContentView() }
