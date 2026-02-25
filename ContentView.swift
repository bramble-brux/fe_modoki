import SwiftUI
import AudioToolbox

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
    // Current Mode
    @State private var mode: TimerMode = .work
    
    // Target Durations
    @State private var workMinutes: Int = 15
    @State private var workSeconds: Int = 0
    @State private var freeMinutes: Int = 15
    @State private var freeSeconds: Int = 0
    
    // Timer State
    @State private var secondsElapsed: Int = 0
    @State private var isActive = false
    @State private var isAlerting = false
    
    // Settings
    @State private var alertInWork = false
    @State private var showingSettings = false

    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            VStack(spacing: 40) {
                // Header / Settings
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

                // Mode Label
                Text(mode.label)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(mode.color)

                // Time Display
                Text(formatTime(secondsElapsed))
                    .font(.system(size: 80, weight: .medium, design: .monospaced))
                    .foregroundColor(timeColor)

                // Controls
                HStack(spacing: 30) {
                    if isAlerting {
                        // Alert Stop Button
                        Button(action: stopAlert) {
                            Text("STOP")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 120, height: 120)
                                .background(Color.red)
                                .clipShape(Circle())
                                .overlay(
                                    Circle().stroke(Color.white, lineWidth: 4)
                                )
                        }
                    } else {
                        // Play/Pause Button
                        Button(action: toggleTimer) {
                            Image(systemName: isActive ? "pause.fill" : "play.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                                .frame(width: 100, height: 100)
                                .background(isActive ? Color.orange : Color.blue)
                                .clipShape(Circle())
                        }

                        // Reset Button - Requirement says "Reset" icon but user simplified list to (Play, Switch Mode). 
                        // I'll keep Reset for usability as it was in "Editable Durations" requirement before.
                        Button(action: resetTimer) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                                .frame(width: 100, height: 100)
                                .background(Color.gray)
                                .clipShape(Circle())
                        }
                    }
                }

                // Manual Switch
                Button(action: { manualSwitch() }) {
                    Text("Switch to \(mode == .work ? "Free" : "Work")")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(15)
                }
                .padding(.horizontal, 40)
                .disabled(isAlerting)
                
                Spacer()

                Text("v1.1.0")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.6))
                    .padding(.bottom, 10)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                workMinutes: $workMinutes,
                workSeconds: $workSeconds,
                freeMinutes: $freeMinutes,
                freeSeconds: $freeSeconds,
                alertInWork: $alertInWork,
                onSave: {
                    resetTimer()
                }
            )
        }
        .onReceive(timer) { _ in
            guard isActive else { return }

            secondsElapsed += 1
            let target = getTargetSeconds(for: mode)

            if mode == .free {
                if secondsElapsed >= target {
                    // Reach target in Free mode
                    secondsElapsed = target // Pin to target
                    isActive = false
                    isAlerting = true
                }
            } else {
                // Work mode
                if alertInWork && secondsElapsed == target {
                    isAlerting = true
                    // Work doesn't stop, alert plays once or until stopped depending on implementation choice.
                    // User said "Alert continues to ring until stopped" for Free. 
                    // For Work, I'll make it behave similarly if enabled.
                }
            }
            
            if isAlerting {
                playSound()
            }
        }
    }

    private var timeColor: Color {
        let target = getTargetSeconds(for: mode)
        if mode == .work && secondsElapsed >= target {
            return .orange
        }
        return .white
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let seconds = totalSeconds
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remSeconds = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remSeconds)
        } else {
            return String(format: "%02d:%02d", minutes, remSeconds)
        }
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
        isActive = false
        isAlerting = false
        mode = (mode == .work ? .free : .work)
        secondsElapsed = 0
    }

    private func stopAlert() {
        isAlerting = false
        if mode == .free {
            // "When Free mode stops, switch to Work mode and timer starts automatically"
            mode = .work
            secondsElapsed = 0
            isActive = true
        } else {
            // Work mode alert stop
            isActive = true // Ensure it keeps counting
        }
    }

    private func getTargetSeconds(for mode: TimerMode) -> Int {
        switch mode {
        case .work: return (workMinutes * 60) + workSeconds
        case .free: return (freeMinutes * 60) + freeSeconds
        }
    }

    private func playSound() {
        // System Sound ID 1005 (Alarm/Tri-tone) or 1000
        AudioServicesPlaySystemSound(1005)
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var workMinutes: Int
    @Binding var workSeconds: Int
    @Binding var freeMinutes: Int
    @Binding var freeSeconds: Int
    @Binding var alertInWork: Bool
    var onSave: () -> Void

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

                Section(header: Text("Options")) {
                    Toggle("Alert in Work Mode", isOn: $alertInWork)
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
