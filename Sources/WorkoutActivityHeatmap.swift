import SwiftUI

/// A calendar-accurate, tappable 13-week activity heatmap sourced from completed sessions.
struct WorkoutActivityHeatmap: View {
    let sessions: [WorkoutSession]
    var condensed = false
    @State private var selectedDay: Date?

    private let calendar = Calendar.current

    private var startOfGrid: Date {
        let monday = calendar.dateInterval(of: .weekOfYear, for: .now)?.start
            ?? calendar.startOfDay(for: .now)
        return calendar.date(byAdding: .weekOfYear, value: -12, to: monday) ?? monday
    }

    private var dailyCounts: [Date: Int] {
        var counts: [Date: Int] = [:]
        for session in sessions where session.endedAt != nil {
            let day = calendar.startOfDay(for: session.startedAt)
            counts[day, default: 0] += 1
        }
        return counts
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.text("CONSISTENCY", "CONSISTENTIE"))
                        .font(.caption2.weight(.heavy))
                        .tracking(1.5)
                        .foregroundStyle(RFTheme.accent)
                    Text(L10n.text("Show up. Stack days.", "Kom opdagen. Bouw dagen op."))
                        .font(condensed ? .subheadline.bold() : .title3.bold())
                }
                Spacer()
                Image(systemName: "calendar")
                    .foregroundStyle(RFTheme.accent)
            }

            HStack(alignment: .top, spacing: 3) {
                ForEach(0..<13, id: \.self) { week in
                    VStack(spacing: 3) {
                        ForEach(0..<7, id: \.self) { day in
                            if let date = calendar.date(byAdding: .day, value: week * 7 + day, to: startOfGrid) {
                                let value = dailyCounts[calendar.startOfDay(for: date)] ?? 0
                                Button {
                                    selectedDay = date
                                } label: {
                                    RoundedRectangle(cornerRadius: condensed ? 3 : 4)
                                        .fill(fill(for: value, isFuture: date > .now))
                                        .aspectRatio(1, contentMode: .fit)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: condensed ? 3 : 4)
                                                .stroke(
                                                    selectedDay.map { calendar.isDate(date, inSameDayAs: $0) } == true
                                                        ? RFTheme.accent : .clear,
                                                    lineWidth: 1.5
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                                .disabled(date > .now)
                                .accessibilityLabel(
                                    date.formatted(date: .abbreviated, time: .omitted) +
                                    ", \(value) " + L10n.text("workouts", "trainingen")
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity)

            HStack {
                if let selectedDay {
                    let count = dailyCounts[calendar.startOfDay(for: selectedDay)] ?? 0
                    Text(selectedDay.formatted(date: .abbreviated, time: .omitted) +
                         " • \(count) " + L10n.text("sessions", "sessies"))
                        .font(.caption)
                } else {
                    Text(L10n.text("Tap any day for details", "Tik op een dag voor details"))
                        .font(.caption)
                }
                Spacer()
                Text(L10n.text("Less", "Minder"))
                    .font(.caption2).foregroundStyle(.secondary)
                ForEach(0..<4, id: \.self) { n in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(fill(for: n, isFuture: false))
                        .frame(width: 11, height: 11)
                }
                Text(L10n.text("More", "Meer"))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(condensed ? 14 : 19)
        .background(RFTheme.surface, in: RoundedRectangle(cornerRadius: RFLayout.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: RFLayout.cornerRadius)
                .stroke(RFTheme.cardBorder)
        )
    }

    private func fill(for count: Int, isFuture: Bool) -> Color {
        if isFuture { return RFTheme.raised.opacity(0.35) }
        switch count {
        case 0: return RFTheme.raised
        case 1: return RFTheme.accent.opacity(0.48)
        case 2: return RFTheme.accent.opacity(0.75)
        default: return RFTheme.success
        }
    }
}

/// Real-time session heatmap; lights up as sets are completed, independent
/// of the full historical training-load / recovery dashboard.
struct LiveWorkoutHeatmap: View {
    let session: WorkoutSession

    private var intensities: [String: Double] {
        var totals: [String: Double] = [:]
        for log in session.exercises {
            guard let exercise = ExerciseCatalog.find(log.exerciseID) else { continue }
            let completed = Double(log.sets.filter(\.completed).count)
            guard completed > 0 else { continue }
            for muscle in exercise.detailedMuscles {
                totals[muscle.muscle, default: 0] += completed * muscle.weight
            }
        }
        return totals.mapValues { min(1, $0 / 6.0) }
    }

    var body: some View {
        if !intensities.isEmpty {
            HStack(alignment: .center, spacing: 16) {
                HStack(alignment: .top, spacing: 8) {
                    BodyMuscleFigure(side: .front, intensity: intensities)
                    BodyMuscleFigure(side: .back, intensity: intensities)
                }
                .frame(width: 120)

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.text("Your work, visualized", "Jouw inzet, zichtbaar"))
                        .font(.subheadline.bold())
                    Text(L10n.text(
                        "Muscles light up as you complete sets.",
                        "Spieren lichten op terwijl je sets voltooit."
                    ))
                    .font(.caption)
                    .foregroundStyle(RFTheme.muted)
                    MuscleHeatLegend()
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(RFTheme.raised, in: RoundedRectangle(cornerRadius: 14))
            .accessibilityElement(children: .combine)
        }
    }
}

struct ExerciseTargetHeatmap: View {
    let exercise: ExerciseDefinition

    private var intensity: [String: Double] {
        Dictionary(uniqueKeysWithValues: exercise.detailedMuscles.map {
            ($0.muscle, min(1, max(0, $0.weight)))
        })
    }

    var body: some View {
        if !intensity.isEmpty {
            HStack(spacing: 12) {
                HStack(alignment: .top, spacing: 8) {
                    BodyMuscleFigure(side: .front, intensity: intensity)
                    BodyMuscleFigure(side: .back, intensity: intensity)
                }
                .frame(width: 136)

                VStack(alignment: .leading, spacing: 7) {
                    Text(L10n.text("Targeted muscles", "Doelspieren"))
                        .font(.headline)
                    Text(L10n.text(
                        "Primary and supporting muscles highlighted anatomically.",
                        "Primaire en ondersteunende spieren anatomisch gemarkeerd."
                    ))
                    .font(.caption)
                    .foregroundStyle(RFTheme.muted)
                    MuscleHeatLegend()
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RFTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        }
    }
}
