import SwiftUI
import SwiftData
import Charts

struct NextProgressView: View {
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @State private var period = 30
    @State private var showAdvancedHistory = false
    private var finished: [WorkoutSession] { sessions.filter { $0.endedAt != nil } }
    private var scoped: [WorkoutSession] {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -period, to: .now)
        else { return finished }
        return finished.filter { $0.startedAt >= cutoff }
    }
    private var loggedSets: Int {
        scoped.reduce(0) { $0 + $1.exercises.flatMap(\.sets).filter(\.completed).count }
    }
    private var volume: Double { scoped.reduce(0) { $0 + $1.totalVolume } }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: NextStyle.space) {
                    NextScreenHeader(
                        eyebrow: L10n.text("YOUR WORK. YOUR DATA.", "JOUW WERK. JOUW DATA."),
                        title: L10n.text("Proof of progress.", "Je vooruitgang telt."),
                        detail: L10n.text(
                            "No fake rewards. Every number comes from your logged workouts.",
                            "Geen verzonnen beloningen. Alles komt uit je trainingen."
                        )
                    )
                    periodPicker
                    HStack(spacing: 9) {
                        NextStat(symbol: "calendar",
                                 value: "\(scoped.count)",
                                 title: L10n.text("Sessions", "Sessies"))
                        NextStat(symbol: "checkmark.seal",
                                 value: "\(loggedSets)",
                                 title: L10n.text("Completed sets", "Voltooide sets"))
                        NextStat(symbol: "scalemass",
                                 value: "\(Int(AppPreferences.displayVolume(volume)))",
                                 title: AppPreferences.weightLabel + " " +
                                    L10n.text("volume", "volume"))
                    }

                    NextHeading(
                        title: L10n.text("Consistency is everything", "Consistentie is alles"),
                        subtitle: L10n.text("13 weeks, one square per day", "13 weken, elke dag een vakje")
                    )
                    WorkoutActivityHeatmap(sessions: sessions)

                    ForgeMomentumCard(sessions: sessions)
                    NextHeading(
                        title: L10n.text("See the work", "Bekijk je inzet"),
                        subtitle: L10n.text("Anatomical training and recovery intelligence",
                                            "Anatomische belasting en herstel")
                    )
                    MuscleIntelligencePanel(sessions: sessions)

                    NextHeading(
                        title: L10n.text("Session history", "Trainingsgeschiedenis"),
                        subtitle: L10n.text("Pick up where you left off",
                                            "Bekijk je laatste trainingen")
                    )
                    if finished.isEmpty {
                        Text(L10n.text("Complete your first workout to see history.",
                                       "Voltooi je eerste training om geschiedenis te zien."))
                            .foregroundStyle(NextStyle.muted)
                            .nextSurface()
                    }

                    ForEach(Array(finished.prefix(7))) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            NextLinkRow(
                                symbol: "checkmark.seal.fill",
                                title: session.title,
                                description: session.startedAt.formatted(
                                    date: .abbreviated, time: .shortened
                                ),
                                badge: durationString(session.duration)
                            )
                        }
                        .buttonStyle(NextPressStyle())
                    }

                    Button {
                        showAdvancedHistory = true
                    } label: {
                        NextLinkRow(
                            symbol: "calendar.badge.clock",
                            title: L10n.text("Full history & advanced filters", "Alle trainingen en filters"),
                            description: L10n.text(
                                "Calendar, records, gym filtering, search and deletion",
                                "Kalender, records, gymlocaties, zoeken en verwijderen"
                            ))
                    }
                    .buttonStyle(NextPressStyle())
                }
                .padding(.horizontal, 18)
                .padding(.top, 24)
                .padding(.bottom, 35)
            }
            .nextCanvas()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAdvancedHistory) {
                HistoryView()
            }
        }
    }

    private var periodPicker: some View {
        HStack(spacing: 7) {
            ForEach([7, 30, 90, 365], id: \.self) { days in
                Button {
                    period = days
                } label: {
                    Text(days == 365 ? L10n.text("Year", "Jaar") : "\(days)d")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(period == days ? Color.black : Color.primary)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(period == days ? NextStyle.electric : NextStyle.panel,
                                    in: RoundedRectangle(cornerRadius: 13))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(period == days ? .isSelected : [])
            }
        }
    }
}

struct NextAthleteView: View {
    @Query private var profiles: [UserProfile]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]
    @State private var showMeasurements = false
    @State private var showAdvancedProfile = false
    @State private var showSettings = false

    private var profile: UserProfile? { profiles.first }
    private var progress: ForgeProgress { ForgeProgress(sessions: sessions) }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: NextStyle.space) {
                    NextScreenHeader(
                        eyebrow: L10n.text("ATHLETE IDENTITY", "ATLEETPROFIEL"),
                        title: L10n.text("You versus yesterday.", "Jij versus gisteren."),
                        detail: L10n.text(
                            "Your effort has a story. Keep writing it.",
                            "Elke training is een hoofdstuk van je verhaal."
                        )
                    )
                    athleteCard

                    HStack(spacing: 9) {
                        NextStat(symbol: "star.fill", value: "\(progress.level)",
                                 title: L10n.text("Athlete level", "Niveau"))
                        NextStat(symbol: "bolt.fill", value: "\(progress.points)",
                                 title: L10n.text("XP earned", "XP verdiend"))
                        NextStat(symbol: "flame.fill", value: "\(progress.weeklyStreak)",
                                 title: L10n.text("Week streak", "Wekenreeks"))
                    }

                    NextHeading(title: L10n.text("Milestones", "Mijlpalen"),
                                subtitle: L10n.text("Earned through real sessions",
                                                    "Verdiend met echte trainingen"))
                    milestones

                    NextHeading(title: L10n.text("Body & health", "Lichaam en metingen"))
                    if let profile {
                        BodyMeasurementsCard(
                            measurements: measurements,
                            onAdd: { showMeasurements = true }
                        )
                    }

                    NextHeading(
                        title: L10n.text("Your control center", "Jouw instellingen"),
                        subtitle: L10n.text("Every existing tool stays available",
                                            "Alle bestaande functies blijven beschikbaar")
                    )
                    Button {
                        showAdvancedProfile = true
                    } label: {
                        NextLinkRow(
                            symbol: "person.text.rectangle",
                            title: L10n.text("Profile and detailed analytics", "Profiel en analyses"),
                            description: L10n.text(
                                "Body measurements, strength data, recovery and gym profiles",
                                "Lichaamsmetingen, kracht, herstel en gyms"
                            )
                        )
                    }
                    .buttonStyle(NextPressStyle())

                    Button {
                        showSettings = true
                    } label: {
                        NextLinkRow(
                            symbol: "gearshape.2.fill",
                            title: L10n.text("Settings & data", "Instellingen en gegevens"),
                            description: L10n.text(
                                "Appearance, accessibility, units, backups and all integrations",
                                "Weergave, toegankelijkheid, eenheden, back-ups en koppelingen"
                            )
                        )
                    }
                    .buttonStyle(NextPressStyle())

                    Text(L10n.text(
                        "All progress remains stored locally with the existing RepForge data model.",
                        "Alle voortgang blijft lokaal opgeslagen met het bestaande RepForge-gegevensmodel."
                    ))
                    .font(.caption)
                    .foregroundStyle(NextStyle.muted)
                    .padding(.bottom, 12)
                }
                .padding(.horizontal, 18)
                .padding(.top, 24)
                .padding(.bottom, 35)
            }
            .nextCanvas()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAdvancedProfile) {
                ProfileView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showMeasurements) {
                if let profile { BodyMeasurementEditorView(profile: profile) }
            }
        }
    }

    private var athleteCard: some View {
        HStack(spacing: 15) {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(NextStyle.electric)
                .frame(width: 67, height: 67)
                .background(NextStyle.electric.opacity(0.1), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                NextEyebrow(text: L10n.text("REP FORGE ATHLETE", "REP FORGE ATLEET"))
                Text(profile?.displayName ?? "Athlete")
                    .font(.system(size: 25, weight: .heavy, design: .rounded))
                Text(profile?.bio ?? L10n.text("Consistency compounds.", "Groei door consistentie."))
                    .font(.caption)
                    .foregroundStyle(NextStyle.muted)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .nextSurface(prominent: true, radius: 25)
    }

    private var milestones: some View {
        VStack(spacing: 8) {
            ForEach(progress.milestones) { milestone in
                HStack(spacing: 14) {
                    Image(systemName: milestone.symbol)
                        .font(.headline)
                        .foregroundStyle(milestone.unlocked
                                         ? NextStyle.electric : NextStyle.muted)
                        .frame(width: 42, height: 42)
                        .background(NextStyle.electric.opacity(0.10),
                                    in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(milestone.title)
                            .font(.subheadline.weight(.bold))
                        ProgressView(value: milestone.progress)
                            .tint(NextStyle.electric)
                    }
                    Spacer(minLength: 5)
                    Text(milestone.unlocked
                         ? L10n.text("UNLOCKED", "BEHAALD")
                         : "\(milestone.current)/\(milestone.target)")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(milestone.unlocked
                                         ? NextStyle.electric : NextStyle.muted)
                        .monospacedDigit()
                }
                .nextSurface(radius: 18)
                .accessibilityElement(children: .combine)
            }
        }
    }
}
