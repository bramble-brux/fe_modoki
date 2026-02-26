import SwiftUI

struct StartView: View {
    @Environment(TimerManager.self) private var timerManager
    @Binding var showSettings: Bool
    @Binding var showCalendar: Bool

    var body: some View {
        ZStack {
            AppTheme.startGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Branding
                VStack(spacing: 8) {
                    Text("15")
                        .font(.system(size: 72, weight: .ultraLight, design: .rounded))
                        .foregroundColor(.white)
                    Text("min change")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                        .tracking(6)
                        .textCase(.uppercase)
                }
                .padding(.bottom, 60)

                // Work button
                Button {
                    timerManager.beginWith(mode: .work)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "flame.fill")
                            .font(.title3)
                        Text("Work")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(AppTheme.workAccent.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(AppTheme.workAccent.opacity(0.35), lineWidth: 1)
                    )
                }

                Spacer().frame(height: 16)

                // Free button
                Button {
                    timerManager.beginWith(mode: .free)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.title3)
                        Text("Free")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(AppTheme.freeAccent.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(AppTheme.freeAccent.opacity(0.3), lineWidth: 1)
                    )
                }

                Spacer()
                Spacer()

                // Bottom toolbar
                HStack(spacing: 0) {
                    Button {
                        showCalendar = true
                    } label: {
                        Image(systemName: "calendar")
                            .font(.title3)
                            .foregroundColor(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }

                    Rectangle()
                        .fill(AppTheme.textTertiary)
                        .frame(width: 1, height: 20)

                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.title3)
                            .foregroundColor(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 28)
        }
    }
}
