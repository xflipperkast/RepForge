import SwiftUI

/// Presentation-only surface: workout state and timers stay in the existing,
/// battle-tested logging engine. Only data relevant to this card is observed.
struct NextWorkoutHeader: View {
    let session: WorkoutSession
    let completedSets: Int
    let totalSets: Int
    let bpm: Int?
    let focusEnabled: Bool
    let hasNote: Bool
    let onFinish: () -> Void
    let onFocus: () -> Void
    let onNote: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var progress: Double {
        totalSets == 0 ? 0 : Double(completedSets) / Double(totalSets)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack {
                Label(L10n.text("SESSION LIVE", "TRAINING LIVE"),
                      systemImage: "circle.fill")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.5)
                    .foregroundStyle(NextStyle.electric)
                    .accessibilityLabel(L10n.text("Workout in progress", "Training bezig"))
                Spacer()
                Button(action: onFinish) {
                    Label(L10n.finish, systemImage: "checkmark")
                        .font(.subheadline.bold())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 15)
                        .frame(minHeight: 44)
                        .background(NextStyle.electric, in: Capsule())
                }
                .buttonStyle(NextPressStyle())
            }

            HStack(alignment: .center, spacing: 13) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(session.title)
                        .font(.system(.title, design: .rounded, weight: .black))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(3)
                    Label(
                        GymProfileStore.profile(id: session.gymID).name,
                        systemImage: "mappin.and.ellipse"
                    )
                    .font(.caption)
                    .foregroundStyle(NextStyle.muted)
                }
                Spacer(minLength: 8)
                progressRing
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.text("SETS COMPLETED", "SETS VOLTOOID"))
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.1)
                        .foregroundStyle(NextStyle.muted)
                    Text("\(completedSets) / \(totalSets)")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .monospacedDigit()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(L10n.text("ELAPSED", "DUUR"))
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.1)
                        .foregroundStyle(NextStyle.muted)
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text(durationString(session.duration))
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .monospacedDigit()
                    }
                }
            }

            ProgressView(value: progress)
                .tint(NextStyle.electric)
                .scaleEffect(x: 1, y: 1.5)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: progress)
                .accessibilityLabel(L10n.text("Workout progress", "Trainingsvoortgang"))

            HStack(spacing: 10) {
                Button(action: onFocus) {
                    Label(
                        focusEnabled
                            ? L10n.text("All sets", "Alle sets")
                            : L10n.text("Focus mode", "Focusmodus"),
                        systemImage: focusEnabled ? "rectangle.stack" : "scope"
                    )
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                Button(action: onNote) {
                    Label(
                        hasNote
                        ? L10n.text("Edit note", "Notitie wijzigen")
                        : L10n.text("Add note", "Notitie"),
                        systemImage: "square.and.pencil"
                    )
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                if let bpm {
                    Label("\(bpm)", systemImage: "heart.fill")
                        .font(.caption.bold())
                        .foregroundStyle(NextStyle.positive)
                        .accessibilityLabel("\(bpm) bpm")
                }
            }
            .font(.caption.weight(.semibold))
        }
        .nextSurface(prominent: true, radius: 26)
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(NextStyle.panelLift, lineWidth: 7)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    NextStyle.electric,
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: progress)
            VStack(spacing: 2) {
                Text("\(Int(progress * 100))")
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .monospacedDigit()
                Text("%").font(.caption2.bold())
                    .foregroundStyle(NextStyle.muted)
            }
        }
        .frame(width: 75, height: 75)
        .accessibilityLabel("\(Int(progress * 100)) " +
                            L10n.text("percent complete", "procent voltooid"))
        .accessibilityElement(children: .ignore)
    }
}
