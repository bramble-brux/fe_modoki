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
    @State private var secondsRemaining: Int = 10
    @State private var isActive = false
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            VStack(spacing: 40) {
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

                Button(action: switchMode) {
                    Text("Switch to \(mode == .work ? "Free" : "Work")")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(15)
                }
                .padding(.horizontal, 40)
            }
        }
        .onReceive(timer) { _ in
            guard isActive else { return }

            if mode == .free {
                if secondsRemaining > 0 {
                    secondsRemaining -= 1
                } else {
                    isActive = false
                }
            } else {
                // Work mode: continues indefinitely
                secondsRemaining -= 1
            }
        }
    }

    private var timeColor: Color {
        if secondsRemaining < 0 {
            return .orange // Overtime
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
        secondsRemaining = 10
    }

    private func switchMode() {
        isActive = false
        mode = (mode == .work ? .free : .work)
        secondsRemaining = 10
    }
}

#Preview {
    ContentView()
}
