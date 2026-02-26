import SwiftUI

struct SettingsView: View {
    @Environment(SettingsManager.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                Section("Work 目標時間") {
                    Picker("分", selection: $settings.workMinutes) {
                        ForEach(0..<60, id: \.self) { n in
                            Text("\(n)分").tag(n)
                        }
                    }
                    Picker("秒", selection: $settings.workSeconds) {
                        ForEach(0..<60, id: \.self) { n in
                            Text("\(n)秒").tag(n)
                        }
                    }
                }

                Section("Free 目標時間") {
                    Picker("分", selection: $settings.freeMinutes) {
                        ForEach(0..<60, id: \.self) { n in
                            Text("\(n)分").tag(n)
                        }
                    }
                    Picker("秒", selection: $settings.freeSeconds) {
                        ForEach(0..<60, id: \.self) { n in
                            Text("\(n)秒").tag(n)
                        }
                    }
                }

                Section("通知") {
                    Toggle("Work 目標達成時に通知", isOn: $settings.alertInWork)
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
