import SwiftUI
import SwiftData

struct ForgeMilestone: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let current: Int
    let target: Int
    var unlocked: Bool { current >= target }
    var progress: Double { min(1, Double(current) / Double(max(1, target))) }
}

struct ForgeProgress {
    let sessions: [WorkoutSession]

    private var finished: [WorkoutSession] {
        sessions.filter { $0.endedAt != nil }
    }

    var completedSessions: Int { finished.count }
    var completedSets: Int {
        finished.reduce(0) { count, session in
            count + session.exercises.flatMap(\.sets).filter(\.completed).count
        }
    }
    var activeDays: Int {
        Set(finished.map { Calendar.current.startOfDay(for: $0.startedAt) }).count
    }

    var points: Int {
        // Computed from actual saved workouts, so reinstalls/restores never lose rewards.
        completedSessions * 25 + completedSets * 5
    }
    var level: Int { points / 300 + 1 }
    var levelProgress: Double { Double(points % 300) / 300.0 }
    var pointsToNextLevel: Int { 300 - points % 300 }

    var weeklyStreak: Int {
        let cal = Calendar.current
        let weeks = Set(finished.compactMap { cal.dateInterval(of: .weekOfYear, for: $0.startedAt)?.start })
        guard let current = cal.dateInterval(of: .weekOfYear, for: .now)?.start else { return 0 }
        var cursor = current
        if !weeks.contains(cursor) {
            guard let previous = cal.date(byAdding: .weekOfYear, value: -1, to: cursor),
                  weeks.contains(previous) else { return 0 }
            cursor = previous
        }
        var count = 0
        while weeks.contains(cursor) {
            count += 1
            guard let previous = cal.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    var milestones: [ForgeMilestone] {
        [
            ForgeMilestone(id: "first", title: L10n.text("First workout", "Eerste training"),
                           symbol: "flag.checkered", current: completedSessions, target: 1),
            ForgeMilestone(id: "consistent", title: L10n.text("10 sessions", "10 sessies"),
                           symbol: "checkmark.seal", current: completedSessions, target: 10),
            ForgeMilestone(id: "regular", title: L10n.text("25 active days", "25 actieve dagen"),
                           symbol: "calendar.badge.checkmark", current: activeDays, target: 25),
            ForgeMilestone(id: "hundred", title: L10n.text("100 working entries", "100 ingevulde sets"),
                           symbol: "bolt.fill", current: completedSets, target: 100),
            ForgeMilestone(id: "hundred-workouts", title: L10n.text("100 workouts", "100 trainingen"),
                           symbol: "trophy.fill", current: completedSessions, target: 100)
        ]
    }
}

struct ForgeMomentumCard: View {
    let sessions: [WorkoutSession]
    var condensed = false

    private var progress: ForgeProgress { ForgeProgress(sessions: sessions) }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center, spacing: 15) {
                ZStack {
                    Circle()
                        .stroke(RFTheme.accent.opacity(0.14), lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: progress.levelProgress)
                        .stroke(
                            AngularGradient(colors: [RFTheme.accent, RFTheme.success, RFTheme.accent],
                                            center: .center),
                            style: StrokeStyle(lineWidth: 7, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(progress.level)")
                            .font(.title.bold().monospacedDigit())
                        Text("LVL")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(RFTheme.muted)
                    }
                }
                .frame(width: condensed ? 68 : 87, height: condensed ? 68 : 87)
                .accessibilityLabel(L10n.text("Training level", "Trainingsniveau") + " \(progress.level)")

                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.text("YOUR MOMENTUM", "JOUW VOORTGANG"))
                        .font(.caption2.weight(.black))
                        .tracking(1.7)
                        .foregroundStyle(RFTheme.accent)
                    Text(progress.completedSessions == 0 ?
                         L10n.text("Your first session awaits", "Je eerste training wacht op je") :
                         L10n.text("Keep your momentum", "Blijf vooruitgaan"))
                        .font(.headline)
                    Text("\(progress.points) XP • \(progress.pointsToNextLevel) " +
                         L10n.text("to next level", "tot volgend niveau"))
                        .font(.caption)
                        .foregroundStyle(RFTheme.muted)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 9) {
                miniStat(icon: "flame.fill", value: "\(progress.weeklyStreak)",
                         label: L10n.text("week streak", "wekenreeks"))
                miniStat(icon: "checkmark.circle.fill", value: "\(progress.completedSessions)",
                         label: L10n.text("sessions", "sessies"))
                miniStat(icon: "square.stack.3d.up.fill", value: "\(progress.completedSets)",
                         label: L10n.text("sets logged", "sets"))
            }

            if !condensed {
                Divider()
                HStack {
                    Text(L10n.text("Milestones", "Mijlpalen"))
                        .font(.subheadline.bold())
                    Spacer()
                    Text("\(progress.milestones.filter(\.unlocked).count)/\(progress.milestones.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(RFTheme.muted)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(progress.milestones) { milestone in
                            VStack(alignment: .leading, spacing: 7) {
                                Image(systemName: milestone.symbol)
                                    .font(.headline)
                                    .foregroundStyle(milestone.unlocked ? RFTheme.success : RFTheme.muted)
                                Text(milestone.title)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(2)
                                ProgressView(value: milestone.progress)
                                    .tint(milestone.unlocked ? RFTheme.success : RFTheme.accent)
                            }
                            .frame(width: 122, height: 88, alignment: .leading)
                            .padding(10)
                            .background(RFTheme.raised, in: RoundedRectangle(cornerRadius: 13))
                        }
                    }
                }
            }
        }
        .padding(condensed ? 15 : 20)
        .background(RFTheme.heroGradient,
                    in: RoundedRectangle(cornerRadius: RFLayout.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: RFLayout.cornerRadius)
                .stroke(RFTheme.cardBorder)
        )
    }

    private func miniStat(icon: String, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(value, systemImage: icon)
                .font(.subheadline.bold())
                .foregroundStyle(RFTheme.accent)
            Text(label)
                .font(.caption2)
                .foregroundStyle(RFTheme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RFTheme.field, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct ForgeSessionRewards: View {
    let session: WorkoutSession
    let sessions: [WorkoutSession]

    private var current: ForgeProgress { ForgeProgress(sessions: sessions) }
    private var previous: ForgeProgress {
        ForgeProgress(sessions: sessions.filter { $0.id != session.id })
    }
    private var newlyUnlocked: [ForgeMilestone] {
        let before = Set(previous.milestones.filter(\.unlocked).map(\.id))
        return current.milestones.filter { $0.unlocked && !before.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(RFTheme.accent)
                VStack(alignment: .leading) {
                    Text(L10n.text("Progress earned", "Voortgang verdiend")).font(.headline)
                    Text("+\(25 + session.exercises.flatMap(\.sets).filter(\.completed).count * 5) XP")
                        .font(.title2.bold().monospacedDigit())
                }
                Spacer()
                Text(L10n.text("Level", "Niveau") + " \(current.level)")
                    .font(.subheadline.bold())
            }

            ProgressView(value: current.levelProgress)
                .tint(RFTheme.accent)

            if !newlyUnlocked.isEmpty {
                ForEach(newlyUnlocked) { badge in
                    Label(
                        L10n.text("Milestone unlocked: ", "Mijlpaal behaald: ") + badge.title,
                        systemImage: badge.symbol
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RFTheme.success)
                }
            }

            let heat = MuscleAnalytics.sessionVolume(session)
            if !heat.isEmpty {
                Text(L10n.text("Muscles trained today", "Spieren getraind vandaag"))
                    .font(.headline)
                compactHeatmap(heat)
            }
        }
        .padding(18)
        .background(RFTheme.heroGradient, in: RoundedRectangle(cornerRadius: 20))
    }

    private func compactHeatmap(_ entries: [MuscleVolumeEntry]) -> some View {
        let maxSets = max(1, entries.map(\.sets).max() ?? 1)
        let intensity = Dictionary(uniqueKeysWithValues: entries.map {
            ($0.muscle, min(1, $0.sets / maxSets))
        })

        return HStack(alignment: .top, spacing: 14) {
            BodyMuscleFigure(side: .front, intensity: intensity)
            BodyMuscleFigure(side: .back, intensity: intensity)
        }
        .frame(maxWidth: 325)
        .frame(maxWidth: .infinity)
    }
}

/// Accessible, multi-period anatomical view of observed training volume and modelled recovery.
/// Only displays values computed from completed sessions; it does not invent body measurements.
struct MuscleIntelligencePanel: View {
    let sessions: [WorkoutSession]
    var compact = false

    @State private var mode = 0
    @State private var period = 0
    @State private var highlightedMuscle: String?
    @AppStorage("activeGymID") private var gymID = GymProfileStore.defaultID
    @AppStorage("separateRecordsByGym") private var separateRecordsByGym = true

    private var scopedSessions: [WorkoutSession] {
        guard separateRecordsByGym else { return sessions }
        return sessions.filter { GymProfileStore.sessionGymID($0) == gymID }
    }

    private var entries: [MuscleVolumeEntry] {
        switch period {
        case 1:
            return MuscleAnalytics.weeklyVolume(sessions: scopedSessions, weeksBack: 1)
        case 2:
            let from = Calendar.current.date(byAdding: .day, value: -28, to: .now) ?? .distantPast
            return MuscleAnalytics.volume(sessions: scopedSessions, since: from)
        default:
            return MuscleAnalytics.weeklyVolume(sessions: scopedSessions)
        }
    }

    private var recoveries: [MuscleRecoveryEntry] {
        MuscleAnalytics.recovery(sessions: scopedSessions)
    }

    private var plot: [(muscle: String, amount: Double, detail: String)] {
        if mode == 1 {
            return recoveries.map {
                (
                    muscle: $0.muscle,
                    amount: max(0, 1 - $0.recovery),
                    detail: "\(Int($0.recovery * 100))% " + L10n.text("estimated recovery", "geschat herstel")
                )
            }
        }
        return entries.map {
            (
                muscle: $0.muscle,
                amount: $0.sets,
                detail: $0.sets.formatted(.number.precision(.fractionLength(0...1))) +
                    " " + L10n.text("effective sets", "effectieve sets")
            )
        }
    }

    private var intensity: [String: Double] {
        // Load scaling is stable (12 effective sets) instead of rescaling to the
        // strongest body part each week, which would misrepresent a light week.
        Dictionary(uniqueKeysWithValues: plot.map {
            ($0.muscle, min(1, max(0, mode == 1 ? $0.amount : $0.amount / 12)))
        })
    }

    private var topMuscle: String? { plot.max(by: { $0.amount < $1.amount })?.muscle }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.text("MUSCLE INTELLIGENCE", "SPIERINZICHT"))
                        .font(.caption2.weight(.black))
                        .tracking(1.5)
                        .foregroundStyle(RFTheme.accent)
                    Text(L10n.text("Your training heatmap", "Jouw trainingsheatmap"))
                        .font(.title2.bold())
                }
                Spacer()
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title2)
                    .foregroundStyle(RFTheme.accent)
            }

            Picker(L10n.text("Muscle metric", "Spierstatistiek"), selection: $mode) {
                Text(L10n.text("Training load", "Trainingsbelasting")).tag(0)
                Text(L10n.text("Recovery estimate", "Herstelschatting")).tag(1)
            }
            .pickerStyle(.segmented)

            if mode == 0 {
                Picker(L10n.text("Period", "Periode"), selection: $period) {
                    Text(L10n.text("This week", "Deze week")).tag(0)
                    Text(L10n.text("Last week", "Vorige week")).tag(1)
                    Text(L10n.text("28 days", "28 dagen")).tag(2)
                }
                .pickerStyle(.segmented)
            }

            if plot.isEmpty {
                ContentUnavailableView(
                    L10n.text("No training heat yet", "Nog geen trainingsheat"),
                    systemImage: "figure.strengthtraining.traditional",
                    description: Text(L10n.text(
                        "Finish and log your workouts to reveal your training map.",
                        "Voltooi en log je trainingen om de spierkaart te vullen."
                    ))
                )
            } else {
                VStack(spacing: 12) {
                    HStack(alignment: .top, spacing: 18) {
                        BodyMuscleFigure(side: .front, intensity: intensity)
                        BodyMuscleFigure(side: .back, intensity: intensity)
                    }
                    .frame(maxWidth: compact ? 340 : 480)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(
                        LinearGradient(colors: [RFTheme.raised, RFTheme.bg.opacity(0.65)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 18)
                    )

                    MuscleHeatLegend()

                    if let topMuscle {
                        HStack {
                            Image(systemName: "scope")
                                .foregroundStyle(RFTheme.accent)
                            Text(mode == 0 ?
                                 L10n.text("Most trained: ", "Meest getraind: ") + topMuscle :
                                 L10n.text("Highest estimated fatigue: ", "Hoogste geschatte vermoeidheid: ") + topMuscle)
                                .font(.caption.weight(.semibold))
                            Spacer()
                        }
                    }
                }

                if !compact {
                    Text(L10n.text("Muscle breakdown", "Uitsplitsing per spier"))
                        .font(.headline)
                    ForEach(Array(plot.sorted(by: { $0.amount > $1.amount }).prefix(12)), id: \.muscle) { item in
                        Button {
                            highlightedMuscle = highlightedMuscle == item.muscle ? nil : item.muscle
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(item.muscle)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text(item.detail)
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(RFTheme.muted)
                                }
                                ProgressView(value: intensity[item.muscle] ?? 0)
                                    .tint(MuscleHeatPalette.color(for: intensity[item.muscle] ?? 0))
                                if highlightedMuscle == item.muscle {
                                    Text(mode == 0 ?
                                         L10n.text("Weighted across primary and secondary muscle contributions.",
                                                   "Gewogen op primaire en secundaire spierbelasting.") :
                                         L10n.text("Modelled from elapsed time and recently logged sets.",
                                                   "Geschat op basis van verstreken tijd en recent gelogde sets."))
                                        .font(.caption2)
                                        .foregroundStyle(RFTheme.muted)
                                }
                            }
                            .padding(9)
                            .background(RFTheme.raised, in: RoundedRectangle(cornerRadius: 11))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Text(mode == 1 ?
                 L10n.text(
                    "Brighter areas mean more estimated residual fatigue, not a medical recovery measure.",
                    "Helderdere delen betekenen meer geschatte restvermoeidheid, geen medische herstelmeting."
                 ) :
                 L10n.text(
                    "Brighter areas reflect more logged effective sets, capped at 12 sets per muscle for display.",
                    "Helderdere delen geven meer gelogde effectieve sets weer, visueel begrensd op 12 per spier."
                 ))
                .font(.caption2)
                .foregroundStyle(RFTheme.muted)
        }
        .padding(compact ? 15 : 20)
        .background(RFTheme.surface, in: RoundedRectangle(cornerRadius: RFLayout.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: RFLayout.cornerRadius).stroke(RFTheme.cardBorder))
    }
}

struct MuscleIntelligenceScreen: View {
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                MuscleIntelligencePanel(sessions: sessions)
                Text(L10n.text(
                    "Workout suggestions and recovery estimates are informational, not individualized medical or training advice.",
                    "Trainingssuggesties en herstelschattingen zijn informatief, geen persoonlijk medisch of trainingsadvies."
                ))
                .font(.caption)
                .foregroundStyle(RFTheme.muted)
            }
            .padding()
        }
        .background(RFTheme.bg)
        .navigationTitle(L10n.text("Muscle map", "Spierkaart"))
    }
}
