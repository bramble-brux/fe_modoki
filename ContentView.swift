import SwiftUI

struct ContentView: View {
    @Environment(TimerManager.self) private var timerManager
    @State private var showSettings = false
    @State private var showCalendar = false

    private var screenKey: String {
        switch timerManager.phase {
        case .idle: return "start"
        case .running, .paused, .alerting: return "timer"
        case .finished: return "result"
        }
    }

    var body: some View {
        Group {
            switch timerManager.phase {
            case .idle:
                StartView(showSettings: $showSettings, showCalendar: $showCalendar)
                    .transition(.opacity)
            case .running, .paused, .alerting:
                TimerView()
                    .transition(.opacity)
            case .finished:
                ResultView()
                    .transition(.opacity)
            }
        }
        .id(screenKey)
        .animation(.easeInOut(duration: 0.25), value: screenKey)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showCalendar) {
            CalendarScreenView()
        }
    }
}
