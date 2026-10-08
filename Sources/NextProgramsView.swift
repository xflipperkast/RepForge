import SwiftUI
import SwiftData

struct NextProgramsView: View {
    @Environment(\.modelContext) private var context
    @State private var category = "All"
    @State private var query = ""
    @State private var active: WorkoutSession?
    @State private var scheduled: ScheduledWorkoutRecord?
    @State private var toast: String?
    @AppStorage("activeGymID") private var gymID = GymProfileStore.defaultID

    private var filtered: [CoachWorkout] {
        CoachWorkoutLibrary.all.filter { workout in
            (category == "All" || workout.category == category) &&
            (query.isEmpty || workout.name.localizedCaseInsensitiveContains(query)
              || workout.focus.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 21) {
                    NextScreenHeader(
                        eyebrow: L10n.text("PROGRAM DESIGN", "TRAININGSSCHEMA'S"),
                        title: L10n.text("Follow a plan.\nOwn the result.", "Volg een schema.\nZie resultaat."),
                        detail: L10n.text("Smart sessions, your pace. Zero subscription traps.",
                                          "Slimme trainingen, op jouw tempo.")
                    )

                    featuredSplit

                    HStack {
                        NextHeading(title: L10n.text("Training programs", "Trainingsprogramma's"),
                                    subtitle: L10n.text("Structured for consistency",
                                                        "Structuur voor elke week"))
                        Spacer(minLength: 0)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(CoachWorkoutLibrary.categories, id: \.self) { value in
                                Button {
                                    category = value
                                } label: {
                                    Text(value == "All"
                                         ? L10n.text("All", "Alles") : value)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(category == value
                                                         ? Color.black : Color.primary)
                                        .padding(.horizontal, 17)
                                        .frame(minHeight: 42)
                                        .background(category == value ? NextStyle.electric : NextStyle.panel,
                                                    in: Capsule())
                                }
                                .buttonStyle(NextPressStyle())
                                .accessibilityAddTraits(category == value ? .isSelected : [])
                            }
                        }
                    }

                    ForEach(filtered) { workout in
                        NavigationLink {
                            workoutDetail(workout)
                        } label: {
                            programRow(workout)
                        }
                        .buttonStyle(NextPressStyle())
                    }

                    NavigationLink {
                        TrainingHubView()
                    } label: {
                        NextLinkRow(
                            symbol: "calendar.badge.clock",
                            title: L10n.text("My editable 3-week plan", "Mijn bewerkbare 3-wekenplan"),
                            description: L10n.text(
                                "Your original program, customization, sharing and scheduling",
                                "Je bestaande programma, wijzigingen, delen en plannen"
                            )
                        )
                    }
                    .buttonStyle(NextPressStyle())

                    NavigationLink {
                        StartWorkoutView()
                    } label: {
                        NextLinkRow(
                            symbol: "square.stack.3d.up.fill",
                            title: L10n.text("Personal routines & schedule", "Eigen schema's en agenda"),
                            description: L10n.text(
                                "Create, edit, duplicate, share and schedule workouts",
                                "Maak, bewerk, kopieer, deel en plan trainingen"
                            )
                        )
                    }
                    .buttonStyle(NextPressStyle())
                }
                .padding(.horizontal, 18)
                .padding(.top, 23)
                .padding(.bottom, 35)
            }
            .nextCanvas()
            .toolbar(.hidden, for: .navigationBar)
            .searchable(text: $query,
                        prompt: L10n.text("Search programs", "Zoek trainingsschema's"))
            .fullScreenCover(item: $active) { session in
                ActiveWorkoutView(session: session)
            }
            .sheet(item: $scheduled) { record in
                ScheduleWorkoutSheet(seed: record) { updated in
                    WorkoutScheduleStore.update(updated)
                }
            }
            .alert(L10n.text("Saved", "Opgeslagen"), isPresented: Binding(
                get: { toast != nil }, set: { if !$0 { toast = nil } }
            )) {
                Button(L10n.done) { toast = nil }
            } message: { Text(toast ?? "") }
        }
    }

    private var featuredSplit: some View {
        VStack(alignment: .leading, spacing: 13) {
            NextEyebrow(text: L10n.text("MULTI-DAY SYSTEMS", "MEERDAAGSE SCHEMA'S"))
            Text(L10n.text("Build your week.", "Bouw je trainingsweek."))
                .font(.system(size: 28, weight: .black, design: .rounded))
            Text(L10n.text(
                "Choose a professional-style split with planned sessions and realistic duration estimates.",
                "Kies een trainingssplit met vaste sessies en realistische tijdsinschattingen."
            ))
            .font(.subheadline)
            .foregroundStyle(NextStyle.muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(CoachWorkoutLibrary.splits) { split in
                        NavigationLink {
                            NextSplitDetailView(split: split, start: { workout in start(workout) })
                        } label: {
                            VStack(alignment: .leading, spacing: 11) {
                                Text(split.level.uppercased())
                                    .font(.system(size: 10, weight: .heavy))
                                    .tracking(1)
                                    .foregroundStyle(NextStyle.electric)
                                Text(split.title)
                                    .font(.system(size: 19, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                Spacer(minLength: 0)
                                Label("\(split.workouts.count) " + L10n.text("days", "dagen"),
                                      systemImage: "calendar")
                                Label("~\(split.weeklyMinutes) " + L10n.text("min/week", "min/week"),
                                      systemImage: "clock")
                            }
                            .font(.caption.weight(.medium))
                            .foregroundStyle(NextStyle.muted)
                            .frame(width: 180, height: 132, alignment: .leading)
                            .padding(17)
                            .background(NextStyle.panelLift.opacity(0.65),
                                        in: RoundedRectangle(cornerRadius: 20))
                            .overlay(RoundedRectangle(cornerRadius: 20)
                                .stroke(RFTheme.cardBorder))
                        }
                        .buttonStyle(NextPressStyle())
                    }
                }
            }
        }
        .nextSurface(prominent: true, radius: 28)
    }

    private func programRow(_ workout: CoachWorkout) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(NextStyle.electric.opacity(0.13))
                Image(systemName: symbol(for: workout))
                    .font(.title3.bold())
                    .foregroundStyle(NextStyle.electric)
            }
            .frame(width: 58, height: 66)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(workout.category.uppercased())
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.3)
                    .foregroundStyle(NextStyle.electric)
                Text(workout.name)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                HStack(spacing: 10) {
                    Label("~\(workout.estimatedMinutes)m", systemImage: "clock")
                    Text(workout.level)
                    Text("\(workout.exercises.count) " + L10n.text("moves", "oef."))
                }
                .font(.caption2)
                .foregroundStyle(NextStyle.muted)
            }
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.right")
                .foregroundStyle(NextStyle.electric)
        }
        .nextSurface()
    }

    private func symbol(for workout: CoachWorkout) -> String {
        switch workout.category {
        case "Strength": return "dumbbell.fill"
        case "Conditioning": return "heart.text.clipboard"
        case "Express": return "bolt.fill"
        case "Targeted": return "scope"
        default: return "figure.strengthtraining.traditional"
        }
    }

    private func workoutDetail(_ workout: CoachWorkout) -> some View {
        CoachWorkoutDetailView(
            workout: workout,
            onStart: { start(workout) },
            onSave: {
                CoachWorkoutActions.saveTemplate(workout, in: context)
                toast = workout.name
            },
            onSchedule: {
                scheduled = ScheduledWorkoutRecord(
                    date: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now,
                    title: workout.name,
                    exerciseIDs: workout.exercises.compactMap {
                        ExerciseCatalog.findByName($0.name)?.id
                    },
                    plan: workout.exercises,
                    gymID: gymID,
                    sourceLabel: L10n.text("Workout library", "Trainingsbibliotheek")
                )
            }
        )
    }

    private func start(_ workout: CoachWorkout) {
        active = CoachWorkoutActions.start(
            name: workout.name, plan: workout.exercises,
            gymID: gymID, in: context
        )
    }
}

struct NextSplitDetailView: View {
    let split: CoachTrainingSplit
    let start: (CoachWorkout) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 15) {
                NextScreenHeader(
                    eyebrow: split.level,
                    title: split.title,
                    detail: split.description
                )
                HStack(spacing: 10) {
                    NextStat(symbol: "calendar",
                             value: "\(split.workouts.count)",
                             title: L10n.text("Sessions", "Sessies"))
                    NextStat(symbol: "clock",
                             value: "~\(split.weeklyMinutes)m",
                             title: L10n.text("Each cycle", "Per cyclus"))
                }
                ForEach(Array(split.workouts.enumerated()), id: \.element.id) { index, workout in
                    VStack(alignment: .leading, spacing: 12) {
                        NextEyebrow(text: L10n.text("DAY", "DAG") + " \(index + 1)")
                        Text(workout.name)
                            .font(.title3.weight(.bold))
                        Text(workout.focus)
                            .font(.subheadline)
                            .foregroundStyle(NextStyle.muted)
                        HStack {
                            Label("~\(workout.estimatedMinutes) min", systemImage: "clock")
                            Spacer()
                            Text(workout.level)
                        }
                        .font(.caption)
                        .foregroundStyle(NextStyle.muted)
                        NextPrimaryButton(
                            title: L10n.text("Start session", "Start sessie"),
                            symbol: "play.fill"
                        ) {
                            start(workout)
                        }
                    }
                    .nextSurface()
                }
                Text(L10n.text(
                    "Adapt training frequency and rest days to your experience.",
                    "Pas trainingsfrequentie en rustdagen aan je niveau aan."
                ))
                .font(.caption)
                .foregroundStyle(NextStyle.muted)
            }
            .padding(18)
        }
        .nextCanvas()
        .navigationTitle(split.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
