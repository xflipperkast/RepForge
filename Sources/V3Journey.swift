import SwiftUI
import SwiftData

struct V3Journey: View {
    let onStart: () -> Void
    let onAccount: () -> Void
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @State private var mode = 0
    @State private var period = 0
    @State private var showHistory = false
    @AppStorage("activeGymID") private var gymID = GymProfileStore.defaultID
    @AppStorage("separateRecordsByGym") private var separateRecords = true

    private var finished: [WorkoutSession] {
        sessions.filter {
            $0.endedAt != nil && (!separateRecords || GymProfileStore.sessionGymID($0) == gymID)
        }
    }
    private var volume: [MuscleVolumeEntry] {
        switch period {
        case 1: return MuscleAnalytics.weeklyVolume(sessions: finished, weeksBack: 1)
        case 2:
            return MuscleAnalytics.volume(sessions: finished,
                since: Calendar.current.date(byAdding: .day, value: -28, to: .now) ?? .distantPast)
        default: return MuscleAnalytics.weeklyVolume(sessions: finished)
        }
    }
    private var recovery: [MuscleRecoveryEntry] { MuscleAnalytics.recovery(sessions: finished) }
    private var intensity: [String: Double] {
        if mode == 1 {
            return Dictionary(uniqueKeysWithValues: recovery.map {
                ($0.muscle, min(1, max(0, 1 - $0.recovery)))
            })
        }
        return Dictionary(uniqueKeysWithValues: volume.map {
            ($0.muscle, min(1, max(0, $0.sets / 12.0)))
        })
    }
    private var progress: ForgeProgress { ForgeProgress(sessions: finished) }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    topBar
                    HStack(spacing: 9) {
                        V3BigNumber(amount: "\(progress.completedSessions)", caption: "SESSIONS",
                                    symbol: "checkmark.seal.fill")
                        V3BigNumber(amount: "\(progress.completedSets)", caption: "SETS",
                                    symbol: "dumbbell.fill")
                        V3BigNumber(amount: "\(progress.points)", caption: "XP",
                                    symbol: "bolt.fill", tint: V3.energy)
                    }
                    V3SectionTitle(title: L10n.text("Body atlas", "Spieratlas"),
                                   detail: L10n.text("Understand the pattern, not just the numbers",
                                                     "Zie waar je trainingsbelasting zit"))
                    bodyAtlas
                    V3SectionTitle(title: L10n.text("Consistency grid", "Consistentiekaart"),
                                   detail: L10n.text("13 weeks of showing up", "13 weken inzet"))
                    WorkoutActivityHeatmap(sessions: finished)
                    V3SectionTitle(title: L10n.text("Milestones", "Mijlpalen"),
                                   detail: L10n.text("Earned through real workouts", "Verdiend door te trainen"))
                    ForEach(progress.milestones) { milestone in
                        HStack(spacing: 11) {
                            Image(systemName: milestone.symbol)
                                .font(.title3).foregroundStyle(
                                    milestone.unlocked ? V3.energy : V3.accent)
                                .frame(width: 42, height: 42)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(milestone.title).font(.subheadline.weight(.semibold))
                                ProgressView(value: milestone.progress).tint(V3.accent)
                            }
                            Spacer(minLength: 3)
                            Text(milestone.unlocked ? "✓" : "\(milestone.current)/\(milestone.target)")
                                .font(.caption.bold()).foregroundStyle(V3.faint)
                        }
                        .padding(15)
                        .background(V3.card, in: RoundedRectangle(cornerRadius: 17))
                    }
                    V3SectionTitle(title: L10n.text("Recent sessions", "Recente trainingen"))
                    ForEach(Array(finished.prefix(12))) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(session.title).font(.headline).foregroundStyle(.primary)
                                    Text(session.startedAt.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption).foregroundStyle(V3.faint)
                                }
                                Spacer()
                                Text(durationString(session.duration))
                                    .font(.caption.bold()).foregroundStyle(V3.accent)
                                Image(systemName: "chevron.right").foregroundStyle(V3.faint)
                            }
                            .padding(16)
                            .background(V3.card, in: RoundedRectangle(cornerRadius: 17))
                        }
                        .buttonStyle(.plain)
                    }
                    Button { showHistory = true } label: {
                        Label(L10n.text("Open complete history and records",
                                        "Volledige geschiedenis en records"),
                              systemImage: "chart.bar.doc.horizontal")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity, minHeight: 54)
                    }
                    .buttonStyle(.bordered)
                    V3PrimaryAction(title: L10n.text("Start another workout", "Nieuwe training starten"),
                                    symbol: "plus", action: onStart)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 30)
            }
            .background(V3Backdrop())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showHistory) { HistoryView() }
        }
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 7) {
                V3Tag(text: "PROGRESS / ATLAS")
                Text(L10n.text("The journey.", "Jouw vooruitgang."))
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer()
            Button(action: onAccount) {
                Image(systemName: "person.crop.circle")
                    .font(.title2).foregroundStyle(V3.accent)
                    .frame(width: 47, height: 47)
                    .background(V3.card, in: Circle())
            }
            .accessibilityLabel(L10n.text("Profile and settings", "Profiel en instellingen"))
        }
    }

    private var bodyAtlas: some View {
        V3Panel(highlighted: true) {
            VStack(alignment: .leading, spacing: 14) {
                Picker(L10n.text("Muscle map view", "Spierkaartweergave"), selection: $mode) {
                    Text(L10n.text("Training load", "Belasting")).tag(0)
                    Text(L10n.text("Recovery estimate", "Herstelschatting")).tag(1)
                }
                .pickerStyle(.segmented)
                if mode == 0 {
                    Picker(L10n.text("Time range", "Periode"), selection: $period) {
                        Text(L10n.text("This week", "Deze week")).tag(0)
                        Text(L10n.text("Last week", "Vorige week")).tag(1)
                        Text("28D").tag(2)
                    }
                    .pickerStyle(.segmented)
                }
                if intensity.isEmpty {
                    VStack(alignment: .center, spacing: 9) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.largeTitle).foregroundStyle(V3.accent)
                        Text(L10n.text("Your atlas begins with a workout.",
                                        "De spieratlas begint met je eerste training."))
                            .font(.subheadline).foregroundStyle(V3.faint)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    HStack(alignment: .top, spacing: 15) {
                        BodyMuscleFigure(side: .front, intensity: intensity)
                        BodyMuscleFigure(side: .back, intensity: intensity)
                    }
                    .frame(maxWidth: 365)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    MuscleHeatLegend()
                    if mode == 0 {
                        ForEach(volume.prefix(6)) { entry in
                            muscleRow(entry.muscle, score: min(1, entry.sets / 12),
                                      label: entry.sets.formatted(
                                        .number.precision(.fractionLength(0...1))
                                      ) + " sets")
                        }
                    } else {
                        ForEach(recovery.prefix(6)) { entry in
                            muscleRow(entry.muscle, score: 1 - entry.recovery,
                                      label: "\(Int(entry.recovery * 100))%")
                        }
                    }
                }
                Text(mode == 0
                     ? L10n.text("Shading represents logged effective sets, scaled at 12 sets per muscle.",
                                  "Kleur toont gelogde effectieve sets, met 12 sets als schaalmaximum.")
                     : L10n.text("Recovery is a model based on recent sets and time, not a medical measurement.",
                                  "Herstel is een schatting op basis van sets en tijd, geen medische meting."))
                    .font(.caption2).foregroundStyle(V3.faint)
            }
        }
    }

    private func muscleRow(_ name: String, score: Double, label: String) -> some View {
        HStack(spacing: 10) {
            Text(name).font(.caption.weight(.semibold)).frame(width: 105, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(V3.inset)
                    Capsule().fill(V3.accent)
                        .frame(width: max(0, proxy.size.width * min(1, max(0, score))))
                }
            }
            .frame(height: 7)
            Text(label).font(.caption.monospacedDigit()).foregroundStyle(V3.faint)
                .frame(minWidth: 52, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

struct V3AccountPanel: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]
    @State private var editProfile = false
    @State private var addMeasurement = false
    @State private var showSettings = false
    @State private var showGymManager = false
    @State private var showAdvancedProfile = false
    @AppStorage("activeGymID") private var activeGymID = GymProfileStore.defaultID

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 15) {
                    V3Tag(text: "ATHLETE / CONTROL")
                    Text(profiles.first?.displayName ?? "Athlete")
                        .font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                    Text(L10n.text("Your training. Your rules.",
                                   "Jouw training. Jouw keuzes."))
                        .font(.subheadline).foregroundStyle(V3.faint)
                    if let profile = profiles.first {
                        V3Panel {
                            HStack {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.largeTitle).foregroundStyle(V3.accent)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(profile.displayName).font(.headline)
                                    Text(profile.bio).font(.caption).foregroundStyle(V3.faint)
                                }
                                Spacer()
                            }
                        }
                    }
                    item(title: L10n.text("Edit athlete", "Profiel bewerken"),
                         detail: L10n.text("Name and personal information", "Naam en profiel"),
                         symbol: "person.crop.circle", action: { editProfile = true })
                    item(title: L10n.text("Body measurements", "Lichaamsmetingen"),
                         detail: "\(measurements.count) " + L10n.text("records saved", "metingen opgeslagen"),
                         symbol: "scalemass", action: { addMeasurement = true })
                    item(title: L10n.text("Gyms & locations", "Gyms en locaties"),
                         detail: L10n.text("Manage your workout environments", "Beheer trainingslocaties"),
                         symbol: "mappin.circle", action: { showGymManager = true })
                    item(title: L10n.text("All settings and backups", "Alle instellingen en back-ups"),
                         detail: L10n.text("Appearance, notifications, data, integrations",
                                            "Weergave, meldingen, gegevens, koppelingen"),
                         symbol: "gearshape.2", action: { showSettings = true })
                    item(title: L10n.text("Detailed athlete analytics", "Uitgebreide analyses"),
                         detail: L10n.text("Performance, recovery and measurements",
                                            "Prestaties, herstel en metingen"),
                         symbol: "chart.xyaxis.line", action: { showAdvancedProfile = true })
                }
                .padding(20)
            }
            .background(V3Backdrop())
            .navigationTitle(L10n.profile)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) { dismiss() }
                }
            }
            .sheet(isPresented: $editProfile) {
                if let profile = profiles.first { EditProfileView(profile: profile) }
            }
            .sheet(isPresented: $addMeasurement) {
                if let profile = profiles.first { BodyMeasurementEditorView(profile: profile) }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showGymManager) { GymManagerView(activeGymID: $activeGymID) }
            .sheet(isPresented: $showAdvancedProfile) { ProfileView() }
        }
    }

    private func item(title: String, detail: String, symbol: String,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title3).foregroundStyle(V3.accent).frame(width: 35)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    Text(detail).font(.caption).foregroundStyle(V3.faint)
                }
                Spacer()
                Image(systemName: "arrow.up.right").foregroundStyle(V3.accent)
            }
            .padding(15)
            .background(V3.card, in: RoundedRectangle(cornerRadius: 17))
        }
        .buttonStyle(.plain)
    }
}
