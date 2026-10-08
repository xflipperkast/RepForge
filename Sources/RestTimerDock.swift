import SwiftUI

/// Isolated one-second updates: only the timer dock redraws, never all set fields.
struct RestTimerDock: View {
    let endDate: Date
    let exerciseName: String
    let totalSeconds: Int
    let onAdjust: (Int) -> Void
    let onReset: () -> Void
    let onSkip: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let seconds = max(0, Int(ceil(endDate.timeIntervalSince(timeline.date))))

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(RFTheme.accent.opacity(0.15), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: min(1, Double(seconds) / Double(max(totalSeconds, 1))))
                        .stroke(
                            RFTheme.accent,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "timer")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(RFTheme.accent)
                }
                .frame(width: 38, height: 38)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(String(format: "%02d:%02d", seconds / 60, seconds % 60))
                        .font(.title3.weight(.bold).monospacedDigit())
                        .contentTransition(.numericText())
                    Text(exerciseName)
                        .font(.caption)
                        .foregroundStyle(RFTheme.muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Menu {
                    Button {
                        onAdjust(-15)
                    } label: {
                        Label("−15s", systemImage: "minus.circle")
                    }
                    Button {
                        onAdjust(15)
                    } label: {
                        Label("+15s", systemImage: "plus.circle")
                    }
                    Button(action: onReset) {
                        Label(L10n.text("Reset timer", "Timer opnieuw starten"),
                              systemImage: "arrow.counterclockwise")
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .background(RFTheme.field, in: RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityLabel(L10n.text("Adjust rest", "Rusttijd aanpassen"))

                Button(action: onSkip) {
                    Image(systemName: "forward.end.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(RFTheme.accent, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.text("Skip rest", "Rust overslaan"))
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20).stroke(RFTheme.cardBorder)
            )
            .shadow(color: .black.opacity(0.10), radius: 8, y: 3)
        }
    }
}
