import SwiftUI

struct TimerView: View {
    @Environment(TimerManager.self) private var timerManager

    var body: some View {
        let mode = timerManager.mode
        let phase = timerManager.phase
        let isOvertime = timerManager.isOvertime
        let isFreeAlerting = (mode == .free && (phase == .alerting || isOvertime))

        ZStack {
            AppTheme.timerGradient(for: mode)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Mode label
                modeHeader(mode: mode)
                    .padding(.top, 60)

                Spacer()

                // Timer
                Text(TimeFormatHelper.format(seconds: timerManager.displaySeconds))
                    .font(.system(size: 88, weight: .ultraLight, design: .monospaced))
                    .foregroundColor(timerColor)
                    .monospacedDigit()

                Spacer()

                // Big switch button
                mainSwitchButton(mode: mode)
                    .padding(.bottom, 32)

                // Utility buttons
                utilityButtons(phase: phase, isFreeAlerting: isFreeAlerting)
                    .padding(.bottom, 50)
            }
        }
    }

    private var timerColor: Color {
        let remaining = timerManager.target - timerManager.elapsed
        if remaining > 0 {
            return .white
        } else if timerManager.mode == .work {
            return AppTheme.overtimeGood
        } else {
            return AppTheme.overtimeBad
        }
    }

    @ViewBuilder
    private func modeHeader(mode: TimerMode) -> some View {
        HStack(spacing: 8) {
            Image(systemName: mode == .work ? "flame.fill" : "cup.and.saucer.fill")
                .font(.subheadline)
            Text(mode == .work ? "WORK" : "FREE")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .tracking(4)
        }
        .foregroundColor(AppTheme.accent(for: mode).opacity(0.7))
    }

    @ViewBuilder
    private func mainSwitchButton(mode: TimerMode) -> some View {
        let nextMode: TimerMode = (mode == .work) ? .free : .work
        let label = nextMode == .work ? "Work へ" : "Free へ"
        let icon = nextMode == .work ? "flame.fill" : "cup.and.saucer.fill"
        let accentColor = AppTheme.accent(for: nextMode)

        Button {
            timerManager.stopAndSwitch()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                Text(label)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(accentColor.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(accentColor.opacity(0.4), lineWidth: 1.5)
            )
        }
        .padding(.horizontal, 32)
    }

    @ViewBuilder
    private func utilityButtons(phase: TimerPhase, isFreeAlerting: Bool) -> some View {
        HStack(spacing: 48) {
            // Pause / Resume — Free超過時は非活性（表示はするがdisabled）
            smallButton(
                icon: phase == .paused ? "play.fill" : "pause.fill",
                disabled: isFreeAlerting
            ) {
                timerManager.togglePause()
            }

            // Stop
            smallButton(icon: "stop.fill", disabled: false) {
                timerManager.finishSession()
            }
        }
    }

    @ViewBuilder
    private func smallButton(icon: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(disabled ? AppTheme.textDisabled : AppTheme.textSecondary)
                .frame(width: 52, height: 52)
                .background(disabled ? .white.opacity(0.03) : .white.opacity(0.08))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(disabled ? .white.opacity(0.05) : .white.opacity(0.12), lineWidth: 1)
                )
        }
        .disabled(disabled)
    }
}
