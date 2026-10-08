import SwiftUI
import SwiftData

struct NextTodayView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \WorkoutTemplate.createdAt, order: .reverse) private var templates: [WorkoutTemplate]
    @State private var current: WorkoutSession?
    @State private var pendingTemplate: WorkoutTemplate?
    @State private var showTemplates = false
    @State private var showStudio = false
    @State private var showSettings = false
    @State private var showPrograms = false
    @AppStorage("activeGymID") private var gymID = GymProfileStore.defaultID

    private var complete: [WorkoutSession] { sessions.filter { $0.endedAt != nil } }
    private var active: WorkoutSession? { sessions.first(where: { $0.endedAt == nil }) }
    private var progress: ForgeProgress { ForgeProgress(sessions: sessions) }
    private var featured: CoachWorkout? {
        CoachWorkoutLibrary.all.first(where: { $0.id == "machine-only-full-body" })
            ?? CoachWorkoutLibrary.all.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: NextStyle.space) {
                    greeting
                    launchCard
                    if active != nil {
                        activeCard
                    }
                    dashboardNumbers
                    forgeJourney

                    NextHeading(
                        title: L10n.text("Your consistency", "Jouw consistentie"),
                        subtitle: L10n.text("Every session moves you forward",
                                            "Elke training telt mee")
                    )
                    WorkoutActivityHeatmap(sessions: sessions, condensed: true)

                    if let featured {
                        NextHeading(
                            title: L10n.text("Made for today", "Voor vandaag"),
                            subtitle: L10n.text("A ready-to-run session", "Klaar om te starten")
                        )
                        featuredCard(featured)
                    }

                    NextHeading(
                        title: L10n.text("Your toolkit", "Jouw gereedschap"),
                        subtitle: L10n.text("Everything a serious training app needs",
                                            "Alles voor een goede training")
                    )
                    Button {
                        showStudio = true
                    } label: {
                        NextLinkRow(symbol: "square.stack.3d.up.fill",
                                    title: L10n.text("Workout studio", "Workoutstudio"),
                                    description: L10n.text(
                                        "Your templates, schedules, editing and quick start",
                                        "Je templates, planning, bewerken en snel starten"
                                    ))
                    }
                    .buttonStyle(NextPressStyle())

                    NavigationLink {
                        MuscleIntelligenceScreen()
                    } label: {
                        NextLinkRow(symbol: "figure.strengthtraining.traditional",
                                    title: L10n.text("Body intelligence", "Spierinzichten"),
                                    description: L10n.text(
                                        "Your animated-feel anatomical training and recovery maps",
                                        "Anatomische kaarten van belasting en herstel"
                                    ))
                    }
                    .buttonStyle(NextPressStyle())

                    if let last = complete.first {
                        NextHeading(title: L10n.text("Most recent", "Laatste training"))
                        NavigationLink {
                            SessionDetailView(session: last)
                        } label: {
                            NextLinkRow(
                                symbol: "checkmark.seal.fill",
                                title: last.title,
                                description: last.startedAt.formatted(date: .abbreviated, time: .shortened),
                                badge: durationString(last.duration)
                            )
                        }
                        .buttonStyle(NextPressStyle())
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 24)
                .padding(.bottom, 30)
            }
            .nextCanvas()
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(item: $current) { session in
                ActiveWorkoutView(session: session)
            }
            .sheet(isPresented: $showStudio) {
                StartWorkoutView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showPrograms) {
                TrainingHubView()
            }
            .sheet(isPresented: $showTemplates, onDismiss: {
                if let pendingTemplate {
                    self.pendingTemplate = nil
                    startTemplate(pendingTemplate)
                }
            }) {
                NavigationStack {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(templates) { template in
                                Button {
                                    pendingTemplate = template
                                    showTemplates = false
                                } label: {
                                    NextLinkRow(symbol: "play.rectangle.fill",
                                                title: template.name,
                                                badge: "\(template.exerciseIDs.count)")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                    .nextCanvas()
                    .navigationTitle(L10n.text("Start a routine", "Start een schema"))
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(L10n.done) { showTemplates = false }
                        }
                    }
                }
            }
        }
    }

    private var greeting: some View {
        HStack(alignment: .top) {
            NextScreenHeader(
                eyebrow: "REP FORGE / NEXT",
                title: L10n.text("Built by showing up.", "Groei door te trainen."),
                detail: L10n.text("The work adds up. Make this one count.",
                                  "Elke herhaling telt. Maak er wat van.")
            )
            Spacer(minLength: 2)
            Button {
                showSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(width: 46, height: 46)
                    .background(NextStyle.panel, in: Circle())
            }
            .accessibilityLabel(L10n.settings)
        }
    }

    private var launchCard: some View {
        VStack(alignment: .leading, spacing: 19) {
            HStack {
                Label(L10n.text("READY WHEN YOU ARE", "KLAAR OM TE BEGINNEN"),
                      systemImage: "bolt.fill")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.1)
                    .foregroundStyle(NextStyle.electric)
                Spacer()
                GymQuickPicker(activeGymID: $gymID)
            }
            Text(L10n.text("Stronger starts here.", "Sterker begint hier."))
                .font(.system(size: 32, weight: .black, design: .rounded))
                .tracking(-1)
                .lineLimit(2)

            Text(L10n.text(
                "No clutter. No setup ritual. Just you and the next set.",
                "Geen gedoe. Gewoon jij en je volgende set."
            ))
            .font(.subheadline)
            .foregroundStyle(NextStyle.muted)

            NextPrimaryButton(
                title: active == nil
                    ? L10n.text("Start training", "Begin training")
                    : L10n.text("Resume workout", "Training hervatten"),
                symbol: "arrow.up.right"
            ) {
                if let active { current = active }
                else { createEmptySession() }
            }

            HStack(spacing: 10) {
                Button {
                    showTemplates = true
                } label: {
                    Label(L10n.text("My routines", "Mijn schema's"),
                          systemImage: "square.stack.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                Button {
                    showPrograms = true
                } label: {
                    Label(L10n.text("Find a plan", "Zoek een schema"), systemImage: "sparkle.magnifyingglass")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
            }
        }
        .nextSurface(prominent: true, radius: 28)
    }

    @ViewBuilder
    private var activeCard: some View {
        if let active {
            Button {
                current = active
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "waveform.path")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(NextStyle.electric)
                        .frame(width: 44, height: 44)
                        .background(NextStyle.electric.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.text("WORKOUT IN PROGRESS", "TRAINING BEZIG"))
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(1)
                            .foregroundStyle(NextStyle.electric)
                        Text(active.title).font(.headline).foregroundStyle(.primary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .foregroundStyle(NextStyle.electric)
                }
                .nextSurface()
            }
            .buttonStyle(NextPressStyle())
        }
    }

    private var dashboardNumbers: some View {
        HStack(spacing: 10) {
            NextStat(symbol: "flame.fill", value: "\(progress.weeklyStreak)",
                     title: L10n.text("Week streak", "Wekenreeks"))
            NextStat(symbol: "checkmark.circle", value: "\(progress.completedSessions)",
                     title: L10n.text("Sessions", "Trainingen"))
            NextStat(symbol: "bolt.fill", value: "\(progress.points)",
                     title: "XP")
        }
    }

    private var forgeJourney: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    NextEyebrow(text: L10n.text("YOUR JOURNEY", "JOUW TRAJECT"))
                    Text(L10n.text("Progress, earned.", "Verdien je vooruitgang."))
                        .font(.title3.weight(.bold))
                }
                Spacer()
                Text("LVL \(progress.level)")
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .foregroundStyle(NextStyle.electric)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(NextStyle.electric.opacity(0.13), in: Capsule())
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(NextStyle.panelLift)
                    Capsule().fill(
                        LinearGradient(
                            colors: [NextStyle.electric, NextStyle.positive],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progress.levelProgress)
                }
            }
            .frame(height: 9)
            .accessibilityLabel("\(Int(progress.levelProgress * 100))%")
            Text("\(progress.pointsToNextLevel) XP " +
                L10n.text("until your next level", "tot je volgende niveau"))
                .font(.caption)
                .foregroundStyle(NextStyle.muted)
        }
        .nextSurface()
    }

    private func featuredCard(_ workout: CoachWorkout) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                NextEyebrow(text: workout.category)
                Spacer()
                Label("~\(workout.estimatedMinutes) min", systemImage: "clock")
                    .font(.caption.bold())
                    .foregroundStyle(NextStyle.muted)
            }
            Text(workout.name)
                .font(.system(size: 23, weight: .bold, design: .rounded))
            Text(workout.focus)
                .font(.subheadline)
                .foregroundStyle(NextStyle.muted)
            HStack(spacing: 12) {
                Text("\(workout.exercises.count) " + L10n.text("exercises", "oefeningen"))
                Text("•")
                Text(workout.level)
            }
            .font(.caption)
            .foregroundStyle(NextStyle.muted)
            NextPrimaryButton(title: L10n.text("Train this", "Train deze"), symbol: "play.fill") {
                startPlan(workout)
            }
        }
        .nextSurface()
    }

    private func createEmptySession() {
        let session = WorkoutSession(
            title: L10n.text("New workout", "Nieuwe training"), gymID: gymID
        )
        context.insert(session)
        try? context.save()
        current = session
    }

    private func startPlan(_ workout: CoachWorkout) {
        current = CoachWorkoutActions.start(
            name: workout.name, plan: workout.exercises, gymID: gymID, in: context
        )
    }

    private func startTemplate(_ template: WorkoutTemplate) {
        let plan = template.plannedExercises
            ?? template.exerciseIDs.compactMap { id -> ProgramExercise? in
                guard let exercise = ExerciseCatalog.find(id) else { return nil }
                return ProgramExercise(exercise.name, AppPreferences.defaultSets, "8–12")
            }
        current = CoachWorkoutActions.start(
            name: template.name, plan: plan, gymID: gymID, in: context
        )
    }
}
