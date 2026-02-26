import SwiftUI

struct ResultView: View {
    @Environment(TimerManager.self) private var timerManager

    var body: some View {
        ZStack {
            AppTheme.startGradient.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "checkmark.circle")
                    .font(.system(size: 64, weight: .ultraLight))
                    .foregroundColor(AppTheme.workAccent)

                Text("お疲れ様でした")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                VStack(spacing: 8) {
                    Text("WORK 合計")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                        .tracking(3)
                    Text(TimeFormatHelper.format(seconds: timerManager.sessionWorkSeconds))
                        .font(.system(size: 52, weight: .ultraLight, design: .monospaced))
                        .foregroundColor(AppTheme.workAccent)
                }

                Spacer()

                Button {
                    timerManager.reset()
                } label: {
                    Text("スタートに戻る")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
    }
}
