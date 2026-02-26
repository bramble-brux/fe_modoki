import SwiftUI

struct TimerView: View {
    @Environment(TimerManager.self) private var timerManager

    var body: some View {
        let mode = timerManager.mode
        let phase = timerManager.phase
        let isOvertime = timerManager.isOvertime
        let isFreeAlerting = (mode == .free && (phase == .alerting || isOvertime))

        ZStack {
            // Gradient background
            AppTheme.timerGradient(for: mode)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Mode label - top area
                modeHeader(mode: mode)
                    .padding(.top, 60)

                Spacer()

                // Timer display
                Text(TimeFormatHelper.format(seconds: timerManager.displaySeconds))
                    .font(.system(size: 88, weight: .ultraLight, design: .monospaced))
                    .foregroundColor(timerColor)
                    .monospacedDigit()

                Spacer()

                // Big forward button (main action)
                mainSwitchButton(mode: mode)
                    .padding(.bottom, 32)

                // Small utility buttons
                utilityButtons(phase: phase, isFreeAlerting: isFreeAlerting)
                    .padding(.bottom, 50)
            }
        }
    }

    // MARK: - Timer Color

    private var timerColor: Color {
        let remaining = timerManager.target - timerManager.elapsed
        if remaining > 0 {
            return .white
        } else if timerManager.mode == .work {
            return AppTheme.overtimeWork
        } else {
            return AppTheme.overtimeFree
        }
    }

    // MARK: - Mode Header

    @ViewBuilder
    private func modeHeader(mode: TimerMode) -> some View {
        HStack(spacing: 8) {
            Image(systemName: mode == .work ? "flame.fill" : "cup.and.saucer.fill")
                .font(.subheadline)
            Text(mode == .work ? "WORK" : "FREE")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .tracking(4)
        }
        .foregroundColor(.white.opacity(0.5))
    }

    // MARK: - Main Switch Button (big)

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
            .background(accentColor.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(accentColor.opacity(0.5), lineWidth: 1.5)
            )
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Utility Buttons

    @ViewBuilder
    private func utilityButtons(phase: TimerPhase, isFreeAlerting: Bool) -> some View {
        HStack(spacing: 48) {
            // Pause / Resume
            if isFreeAlerting {
                Color.clear.frame(width: 52, height: 52)
            } else {
                smallButton(
                    icon: phase == .paused ? "play.fill" : "pause.fill"
                ) {
                    timerManager.togglePause()
                }
            }

            // Stop
            smallButton(icon: "stop.fill") {
                timerManager.finishSession()
            }
        }
    }

    @ViewBuilder
    private func smallButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 52, height: 52)
                .background(.white.opacity(0.08))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )
        }
    }
}
