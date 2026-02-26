import SwiftUI

struct ContentView: View {
    @Environment(TimerManager.self) private var timerManager
    @State private var showSettings = false
    @State private var showCalendar = false

    var body: some View {
        Group {
            switch timerManager.phase {
            case .idle:
                StartView(showSettings: $showSettings, showCalendar: $showCalendar)
            case .running, .paused, .alerting:
                TimerView()
            case .finished:
                ResultView()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showCalendar) {
            CalendarScreenView()
        }
    }
}
