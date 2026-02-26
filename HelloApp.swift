import SwiftUI

@main
struct HelloApp: App {
    @State private var timerManager = TimerManager()
    @State private var settingsManager = SettingsManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(timerManager)
                .environment(settingsManager)
                .onAppear {
                    timerManager.settings = settingsManager
                    NotificationManager.shared.requestAuthorization()
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    switch newPhase {
                    case .background:
                        timerManager.handleBackgroundTransition()
                    case .active:
                        timerManager.handleForegroundTransition()
                    default:
                        break
                    }
                }
        }
    }
}
