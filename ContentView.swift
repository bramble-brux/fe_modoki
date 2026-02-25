import SwiftUI

enum TimerMode {
    case work
    case free

    var label: String {
        switch self {
        case .work: return "Work"
        case .free: return "Free"
        }
    }

    var color: Color {
        switch self {
        case .work: return .red
        case .free: return .green
        }
    }
}

struct ContentView: View {
    @State private var mode: TimerMode = .work
    @State private var workMinutes: Int = 15
    @State private var freeMinutes: Int = 15
    @State private var secondsRemaining: Int = 15 * 60
    @State private var isActive = false
    @State private var showingAlert = false
    @State private var showingSettings = false

    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            VStack(spacing: 40) {
                HStack {
                    Spacer()
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    }
                    .padding()
                }

                Spacer()

                Text(mode.label)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(mode.color)

                Text(formatTime(secondsRemaining))
                    .font(.system(size: 80, weight: .medium, design: .monospaced))
                    .foregroundColor(timeColor)

                HStack(spacing: 30) {
                    Button(action: toggleTimer) {
                        Image(systemName: isActive ? "pause.fill" : "play.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                            .frame(width: 100, height: 100)
                            .background(isActive ? Color.orange : Color.blue)
                            .clipShape(Circle())
                    }

                    Button(action: resetTimer) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                            .frame(width: 100, height: 100)
                            .background(Color.gray)
                            .clipShape(Circle())
                    }
                }

                Button(action: { switchMode(to: mode == .work ? .free : .work) }) {
                    Text("Switch to \(mode == .work ? "Free" : "Work")")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(15)
                }
                .padding(.horizontal, 40)
                
                Spacer()
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(workMinutes: $workMinutes, freeMinutes: $freeMinutes, onSave: {
                resetTimer()
            })
        }
        .alert("Free Time Ended", isPresented: $showingAlert) {
            Button("Start Working", role: .cancel) {
                switchMode(to: .work)
                isActive = true
            }
        } message: {
            Text("Switching to Work mode automatically.")
        }
        .onReceive(timer) { _ in
            guard isActive else { return }

            if mode == .free {
                if secondsRemaining > 0 {
                    secondsRemaining -= 1
                } else {
                    isActive = false
                    showingAlert = true
                }
            } else {
                secondsRemaining -= 1
            }
        }
    }

    private var timeColor: Color {
        if secondsRemaining < 0 {
            return .orange
        }
        return .white
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let isNegative = totalSeconds < 0
        let seconds = abs(totalSeconds)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remSeconds = seconds % 60

        let prefix = isNegative ? "-" : ""
        if hours > 0 {
            return String(format: "%@%d:%02d:%02d", prefix, hours, minutes, remSeconds)
        } else {
            return String(format: "%@%02d:%02d", prefix, minutes, remSeconds)
        }
    }

    private func toggleTimer() {
        isActive.toggle()
    }

    private func resetTimer() {
        isActive = false
        secondsRemaining = (mode == .work ? workMinutes : freeMinutes) * 60
    }

    private func switchMode(to newMode: TimerMode) {
        isActive = false
        mode = newMode
        secondsRemaining = (mode == .work ? workMinutes : freeMinutes) * 60
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var workMinutes: Int
    @Binding var freeMinutes: Int
    var onSave: () -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Durations (Minutes)")) {
                    Stepper("Work: \(workMinutes) min", value: $workMinutes, in: 1...120)
                    Stepper("Free: \(freeMinutes) min", value: $freeMinutes, in: 1...120)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                Button("Done") {
                    onSave()
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
