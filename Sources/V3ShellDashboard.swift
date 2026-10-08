import SwiftUI
import SwiftData

struct V3Shell: View {
    @Binding var selectedTab: Int
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \WorkoutTemplate.createdAt, order: .reverse) private var templates: [WorkoutTemplate]
    @State private var active: WorkoutSession?
    @State private var pending: WorkoutSession?
    @State private var showLauncher = false
    @State private var showAccount = false
    @State private var keyboardVisible = false
    @AppStorage("activeGymID") private var gymID = GymProfileStore.defaultID

    var body: some View {
        ZStack {
            V3Backdrop()
            switch selectedTab {
            case 1:
                V3Studio(onStart: { active = $0 })
            case 2:
                V3Journey(onStart: { showLauncher = true }, onAccount: { showAccount = true })
            default:
                V3Dashboard(
                    sessions: sessions,
                    templates: templates,
                    onStart: { showLauncher = true },
                    onResume: { active = $0 },
                    onStudio: { selectedTab = 1 },
                    onJourney: { selectedTab = 2 },
                    onAccount: { showAccount = true }
                )
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !keyboardVisible {
                V3NavigationDock(tab: $selectedTab, onStart: openSession)
            }
        }
        .sheet(isPresented: $showLauncher, onDismiss: {
            if let pending {
                active = pending
                self.pending = nil
            }
        }) {
            V3SessionLauncher(
                sessions: sessions,
                templates: templates,
                onSelect: { session in
                    pending = session
                    showLauncher = false
                }
            )
        }
        .sheet(isPresented: $showAccount) {
            V3AccountPanel()
        }
        .fullScreenCover(item: $active) { session in
            V3WorkoutView(session: session)
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillShowNotification
        )) { _ in keyboardVisible = true }
        .onReceive(NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillHideNotification
        )) { _ in keyboardVisible = false }
    }

    private func openSession() {
        if let existing = sessions.first(where: { $0.endedAt == nil }) {
            active = existing
        } else {
            showLauncher = true
        }
    }
}

struct V3Dashboard: View {
    let sessions: [WorkoutSession]
    let templates: [WorkoutTemplate]
    let onStart: () -> Void
    let onResume: (WorkoutSession) -> Void
    let onStudio: () -> Void
    let onJourney: () -> Void
    let onAccount: () -> Void
    @AppStorage("activeGymID") private var gymID = GymProfileStore.defaultID

    private var finished: [WorkoutSession] { sessions.filter { $0.endedAt != nil } }
    private var progress: ForgeProgress { ForgeProgress(sessions: sessions) }
    private var running: WorkoutSession? { sessions.first { $0.endedAt == nil } }
    private var week: Int {
        finished.filter {
            Calendar.current.isDate($0.startedAt, equalTo: .now, toGranularity: .weekOfYear)
        }.count
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 23) {
                topBar
                featured
                metricGrid
                V3SectionTitle(
                    title: L10n.text("Your training pulse", "Je trainingsritme"),
                    detail: L10n.text("Every session leaves its mark", "Elke training telt")
                )
                activityStrip
                V3SectionTitle(
                    title: L10n.text("Body under load", "Spieren in actie"),
                    detail: L10n.text("A map of what you actually trained", "Inzicht in getrainde spieren")
                )
                bodySnapshot
                V3SectionTitle(
                    title: L10n.text("Next moves", "Volgende stap"),
                    detail: L10n.text("Your week, not somebody else's", "Jouw trainingsweek")
                )
                nextSession
                if !finished.isEmpty {
                    V3SectionTitle(title: L10n.text("Latest workout", "Laatste training"))
                    recent
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()).uppercased())
                    .font(.caption2.weight(.heavy))
                    .tracking(2.5)
                    .foregroundStyle(V3.accent)
                Text(L10n.text("Your arena.", "Jouw arena."))
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer()
            Button(action: onAccount) {
                Image(systemName: "person.crop.circle")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(V3.accent)
                    .frame(width: 50, height: 50)
                    .background(V3.card, in: Circle())
            }
            .accessibilityLabel(L10n.text("Account and settings", "Account en instellingen"))
        }
    }

    private var featured: some View {
        V3Panel(highlighted: true) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 13) {
                    V3Tag(text: running == nil ? "START STRONG" : "IN SESSION")
                    Text(running == nil
                         ? L10n.text("Own the next rep.", "Maak die volgende rep.")
                         : L10n.text("Finish what you started.", "Maak je training af."))
                        .font(.system(.title, design: .rounded, weight: .heavy))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(running == nil
                         ? L10n.text("One session closer to stronger.", "Elke training maakt je sterker.")
                         : (running?.title ?? ""))
                        .font(.subheadline)
                        .foregroundStyle(V3.faint)
                    V3CapsuleButton(
                        title: running == nil ? L10n.text("Let's train", "Start training")
                                              : L10n.text("Continue", "Verdergaan"),
                        symbol: "arrow.up.right",
                        filled: true,
                        action: {
                            if let running { onResume(running) }
                            else { onStart() }
                        }
                    )
                }
                Spacer(minLength: 0)
                V3ProgressArc(
                    value: progress.levelProgress,
                    title: L10n.text("Level progress", "Niveauvoortgang"),
                    diameter: 98
                )
            }
        }
    }

    private var metricGrid: some View {
        HStack(spacing: 9) {
            V3BigNumber(amount: "\(progress.level)", caption: "LEVEL", symbol: "trophy")
            V3BigNumber(amount: "\(week)", caption: L10n.text("THIS WEEK", "DEZE WEEK"), symbol: "calendar")
            V3BigNumber(amount: "\(progress.weeklyStreak)",
                        caption: L10n.text("WEEK STREAK", "WEKEN REEKS"),
                        symbol: "flame.fill", tint: V3.energy)
        }
    }

    private var activityStrip: some View {
        Button(action: onJourney) {
            VStack(alignment: .leading, spacing: 10) {
                WorkoutActivityHeatmap(sessions: sessions, condensed: true)
                    .allowsHitTesting(false)
                HStack {
                    Text(L10n.text("Open your training history", "Bekijk je trainingsgeschiedenis"))
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .foregroundStyle(V3.accent)
                .padding(.horizontal, 5)
            }
        }
        .buttonStyle(.plain)
    }

    private var bodySnapshot: some View {
        Button(action: onJourney) {
            MuscleIntelligencePanel(sessions: sessions, compact: true)
                .allowsHitTesting(false)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.text("View muscle heatmap", "Bekijk spierkaart"))
    }

    private var nextSession: some View {
        VStack(spacing: 10) {
            Button(action: onStudio) {
                HStack(spacing: 15) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.title2).foregroundStyle(V3.accent)
                        .frame(width: 50, height: 50)
                        .background(V3.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 15))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(L10n.text("Training studio", "Trainingstudio"))
                            .font(.headline.weight(.bold))
                        Text(L10n.text("Plans, routines and every exercise", "Schema's, routines en oefeningen"))
                            .font(.caption).foregroundStyle(V3.faint)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right").foregroundStyle(V3.accent)
                }
            }
            .buttonStyle(V3TapStyle())
            .padding(16)
            .background(V3.card, in: RoundedRectangle(cornerRadius: 20))
            if !templates.isEmpty {
                Text("\(templates.count) " +
                     L10n.text("custom routines waiting for you", "eigen schema's beschikbaar"))
                    .font(.caption).foregroundStyle(V3.faint)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var recent: some View {
        if let last = finished.first {
            V3Panel {
                HStack {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(last.title).font(.headline)
                        Text(last.startedAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption).foregroundStyle(V3.faint)
                        Text("\(last.exercises.flatMap(\.sets).filter(\.completed).count) " +
                             L10n.text("sets recorded", "sets vastgelegd"))
                            .font(.caption.bold()).foregroundStyle(V3.accent)
                    }
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .font(.largeTitle).foregroundStyle(V3.positive)
                }
            }
        }
    }
}
