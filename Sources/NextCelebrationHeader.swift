import SwiftUI

struct NextCelebrationHeader: View {
    let session: WorkoutSession
    let recordCount: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    private var entries: Int {
        session.exercises.flatMap(\.sets).filter(\.completed).count
    }
    private var gainedXP: Int { 25 + entries * 5 }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    NextEyebrow(text: L10n.text("MISSION COMPLETE", "MISSIE VOLTOOID"))
                    Text(L10n.text("You did the work.", "Je hebt het gedaan."))
                        .font(.system(.largeTitle, design: .rounded, weight: .black))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(session.title)
                        .font(.subheadline)
                        .foregroundStyle(NextStyle.muted)
                }
                Spacer(minLength: 0)
                ZStack {
                    Circle().stroke(NextStyle.electric.opacity(0.3), lineWidth: 1.4)
                    Circle().trim(from: 0, to: revealed ? 0.93 : 0)
                        .stroke(NextStyle.electric,
                                style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(NextStyle.electric)
                        .scaleEffect(revealed ? 1 : 0.65)
                }
                .frame(width: 84, height: 84)
                .accessibilityHidden(true)
            }
            Rectangle()
                .fill(NextStyle.electric.opacity(0.2))
                .frame(height: 1)

            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.text("YOU EARNED", "JE HEBT VERDIEND"))
                        .font(.system(size: 10, weight: .black))
                        .tracking(2)
                        .foregroundStyle(NextStyle.muted)
                    Text("+\(gainedXP) XP")
                        .font(.system(.largeTitle, design: .rounded, weight: .black))
                        .foregroundStyle(NextStyle.electric)
                        .monospacedDigit()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    Text("\(entries)")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .monospacedDigit()
                    Text(L10n.text("SETS LOGGED", "SETS GELOGD"))
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(NextStyle.muted)
                    if recordCount > 0 {
                        Text("\(recordCount) " + L10n.text("NEW RECORDS", "NIEUWE RECORDS"))
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(NextStyle.electric)
                    }
                }
            }
        }
        .nextSurface(prominent: true, radius: 28)
        .onAppear {
            guard !revealed else { return }
            if reduceMotion {
                revealed = true
            } else {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
                    revealed = true
                }
            }
        }
    }
}
