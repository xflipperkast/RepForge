import SwiftUI
import SwiftData

/// Estimated time includes setup, warm-up, working sets, transitions and suggested rest.
/// It is not a promise: actual pace, equipment availability and experience vary.
struct CoachWorkout: Identifiable {
    let name: String
    let category: String
    let level: String
    let equipment: String
    let focus: String
    let warmupMinutes: Int
    let restSeconds: Int
    let exercises: [ProgramExercise]

    var id: String {
        name.lowercased().replacingOccurrences(
            of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression
        )
    }

    var estimatedMinutes: Int {
        let workingSeconds = exercises.reduce(0) { total, exercise in
            let cardio = ExerciseCatalog.findByName(exercise.name)?.movement == "cardio"
            let repSeconds = cardio ? 8 * 60 : 42
            return total + (exercise.sets * repSeconds)
                + (max(0, exercise.sets - 1) * (cardio ? 30 : restSeconds))
        }
        let switchingSeconds = max(0, exercises.count - 1) * 70
        let seconds = warmupMinutes * 60 + workingSeconds + switchingSeconds
        return max(15, Int(ceil(Double(seconds) / 300)) * 5)
    }

    var totalSets: Int { exercises.reduce(0) { $0 + $1.sets } }

    init(_ name: String, category: String, level: String, equipment: String, focus: String,
         warmup: Int = 5, rest: Int = 90, plan: String) {
        self.name = name
        self.category = category
        self.level = level
        self.equipment = equipment
        self.focus = focus
        self.warmupMinutes = warmup
        self.restSeconds = rest
        self.exercises = plan.split(separator: ";").compactMap { raw in
            let parts = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 3, let sets = Int(parts[1]) else { return nil }
            return ProgramExercise(parts[0], max(1, sets), parts[2],
                                   note: parts.count > 3 ? parts[3] : nil)
        }
    }
}

struct CoachTrainingSplit: Identifiable {
    let id: String
    let title: String
    let description: String
    let level: String
    let workoutIDs: [String]

    var workouts: [CoachWorkout] {
        workoutIDs.compactMap { key in CoachWorkoutLibrary.all.first(where: { $0.id == key }) }
    }

    var weeklyMinutes: Int { workouts.reduce(0) { $0 + $1.estimatedMinutes } }
}

enum CoachWorkoutLibrary {
    // These are original, general-purpose example sessions inspired by widely used
    // strength-programming principles. Not clinical advice or individually prescribed.
    static let all: [CoachWorkout] = [
        .init("Full Body Foundation A", category: "Full body", level: "Beginner", equipment: "Machines", focus: "Learn fundamental patterns", rest: 90,
              plan: "Converging Chest Press|2|10–12;Lever Horizontal Leg Press|3|10–12;Cable Pulldown|3|10–12;Lever Seated Leg Curl|2|12–15;Lever Seated Calf Raise|2|12–15"),
        .init("Full Body Foundation B", category: "Full body", level: "Beginner", equipment: "Machines", focus: "Balanced machine strength", rest: 90,
              plan: "Sled Hack Squat|2|8–12;Chest Supported Machine Row|3|10–12;Seated Dumbbell Shoulder Press|2|10–12;Lever Leg Extension|2|12–15;Pec Deck Fly|2|12–15"),
        .init("Full Body Foundation C", category: "Full body", level: "Beginner", equipment: "Mixed", focus: "Build repeatable technique",
              plan: "Goblet Squat|3|10–12;Incline Dumbbell Bench Press|3|8–12;Cable Close Grip Lat Pulldown|3|10–12;Lever Seated Leg Curl|2|10–12;Cable Rope Triceps Pushdown|2|12–15"),
        .init("Total Body Strength", category: "Strength", level: "Intermediate", equipment: "Mixed", focus: "Compound lifting with longer recovery", warmup: 8, rest: 180,
              plan: "Barbell Flat Bench Press|4|4–6;Squat (Barbell)|4|4–6;Chest Supported Machine Row|3|6–8;Romanian Deadlift (Barbell)|3|6–8;Cable Rope Triceps Pushdown|2|10–12"),
        .init("Strength Push", category: "Strength", level: "Intermediate", equipment: "Mixed", focus: "Heavy chest, shoulders, triceps", warmup: 8, rest: 180,
              plan: "Barbell Flat Bench Press|4|4–6;Standing Barbell Overhead Press (Military Press)|3|5–7;Incline Dumbbell Bench Press|3|6–8;Cable Rope Triceps Pushdown|3|8–12"),
        .init("Strength Pull", category: "Strength", level: "Intermediate", equipment: "Mixed", focus: "Horizontal and vertical pulling", warmup: 8, rest: 150,
              plan: "Deadlift (Barbell)|3|4–6;Chest Supported Machine Row|4|6–8;Wide Grip Cable Lat Pulldown|3|8–10;EZ-Bar Biceps Curl|3|8–10"),
        .init("Strength Legs", category: "Strength", level: "Intermediate", equipment: "Mixed", focus: "Squat, hinge and unilateral stability", warmup: 8, rest: 180,
              plan: "Squat (Barbell)|4|4–6;Romanian Deadlift (Barbell)|3|6–8;Lever Leg Extension|3|8–10;Lever Seated Leg Curl|3|8–10;Lever Standing Calf Raise|3|10–12"),
        .init("Hypertrophy Push", category: "Muscle growth", level: "Intermediate", equipment: "Mixed", focus: "Chest, delts and triceps volume", rest: 90,
              plan: "Incline Dumbbell Bench Press|3|8–12;Converging Chest Press|3|10–12;Pec Deck Fly|3|12–15;Standing Dumbbell Lateral Raise|4|12–15;Cable Rope Triceps Pushdown|3|10–15"),
        .init("Hypertrophy Pull", category: "Muscle growth", level: "Intermediate", equipment: "Mixed", focus: "Back width and thickness", rest: 90,
              plan: "Wide Grip Cable Lat Pulldown|3|8–12;Chest Supported Machine Row|3|8–12;Cable One Arm Lateral Pulldown|3|10–12;Reverse Pec Deck Machine|3|12–15;EZ-Bar Biceps Curl|3|10–12"),
        .init("Hypertrophy Legs", category: "Muscle growth", level: "Intermediate", equipment: "Machines", focus: "Quad, hamstring and glute development", rest: 120,
              plan: "Sled Hack Squat|3|8–12;Lever Horizontal Leg Press|3|10–15;Lever Seated Leg Curl|3|10–15;Lever Leg Extension|3|12–15;Lever Seated Calf Raise|4|12–15"),
        .init("Upper A", category: "Muscle growth", level: "Intermediate", equipment: "Mixed", focus: "Horizontal upper-body emphasis", rest: 105,
              plan: "Barbell Flat Bench Press|3|6–8;Chest Supported Machine Row|3|8–10;Incline Dumbbell Bench Press|3|8–12;Cable Close Grip Lat Pulldown|3|10–12;Standing Dumbbell Lateral Raise|3|12–15"),
        .init("Upper B", category: "Muscle growth", level: "Intermediate", equipment: "Mixed", focus: "Vertical pressing and arms", rest: 90,
              plan: "Seated Dumbbell Shoulder Press|3|8–10;Wide Grip Cable Lat Pulldown|3|8–12;Converging Chest Press|3|10–12;Reverse Pec Deck Machine|3|12–15;EZ-Bar Biceps Curl|3|10–12;Cable Rope Triceps Pushdown|3|10–12"),
        .init("Lower A", category: "Muscle growth", level: "Intermediate", equipment: "Mixed", focus: "Quad-dominant lower day", rest: 120,
              plan: "Squat (Barbell)|3|6–8;Lever Horizontal Leg Press|3|10–12;Lever Leg Extension|3|12–15;Lever Lying Leg Curl|3|10–12;Lever Standing Calf Raise|3|12–15"),
        .init("Lower B", category: "Muscle growth", level: "Intermediate", equipment: "Mixed", focus: "Posterior-chain emphasis", rest: 120,
              plan: "Romanian Deadlift (Barbell)|3|6–10;Sled Hack Squat|3|8–12;Lever Seated Leg Curl|3|10–12;Lever Seated Hip Abduction|3|12–15;Lever Seated Calf Raise|3|12–15"),
        .init("Chest & Triceps", category: "Targeted", level: "All levels", equipment: "Mixed", focus: "Push-focused accessory session",
              plan: "Converging Chest Press|3|8–12;Incline Dumbbell Bench Press|3|8–12;Pec Deck Fly|3|12–15;Cable Rope Triceps Pushdown|3|10–15;Cable Rope Overhead Triceps Extension|2|12–15"),
        .init("Back & Biceps", category: "Targeted", level: "All levels", equipment: "Mixed", focus: "Lats, mid-back and elbow flexors",
              plan: "Wide Grip Cable Lat Pulldown|3|8–12;Chest Supported Machine Row|3|8–12;Cable Straight Arm Pulldown|2|12–15;EZ-Bar Biceps Curl|3|10–12;Dumbbell Seated Preacher Curl|2|10–12"),
        .init("Shoulder Builder", category: "Targeted", level: "All levels", equipment: "Mixed", focus: "Front, lateral and rear delts", rest: 75,
              plan: "Seated Dumbbell Shoulder Press|3|8–12;Standing Dumbbell Lateral Raise|4|12–15;Reverse Pec Deck Machine|3|12–15;Cable Rear Delt Row (with rope)|3|12–15"),
        .init("Glutes & Hamstrings", category: "Targeted", level: "All levels", equipment: "Mixed", focus: "Hip-hinge and posterior-chain volume",
              plan: "Dumbbell Romanian Deadlift|3|8–12;Lever Seated Leg Curl|3|10–12;Hip Thrust (Barbell)|3|8–12;Lever Seated Hip Abduction|3|12–15;Lever Seated Calf Raise|3|12–15"),
        .init("Machine-Only Full Body", category: "Full body", level: "All levels", equipment: "Machines", focus: "No barbell or free-weight stations", rest: 90,
              plan: "Converging Chest Press|3|8–12;Lever Horizontal Leg Press|3|10–12;Wide Grip Cable Lat Pulldown|3|10–12;Lever Seated Leg Curl|3|10–12;Lever Seated Hip Abduction|2|12–15"),
        .init("Express Upper", category: "Express", level: "All levels", equipment: "Mixed", focus: "Short high-value upper session", warmup: 3, rest: 60,
              plan: "Converging Chest Press|3|8–12;Chest Supported Machine Row|3|8–12;Standing Dumbbell Lateral Raise|2|12–15"),
        .init("Express Lower", category: "Express", level: "All levels", equipment: "Machines", focus: "Short lower-body session", warmup: 4, rest: 75,
              plan: "Lever Horizontal Leg Press|3|8–12;Lever Seated Leg Curl|3|10–12;Lever Seated Calf Raise|2|12–15"),
        .init("Express Arms", category: "Express", level: "All levels", equipment: "Cables", focus: "Efficient upper-arm accessories", warmup: 3, rest: 60,
              plan: "Cable Rope Triceps Pushdown|3|10–12;Cable Biceps Curl|3|10–12;Cable Rope Overhead Triceps Extension|2|12–15;EZ-Bar Biceps Curl|2|12–15"),
        .init("Cable Station Full Body", category: "Full body", level: "All levels", equipment: "Cables", focus: "Station-centered workout", rest: 75,
              plan: "Cable Pulldown|3|10–12;Cable Rope Triceps Pushdown|3|10–12;Cable Biceps Curl|3|10–12;Cable One-Arm Twisting Seated Row|3|10–12;Cable Kneeling Crunch|3|12–15"),
        .init("Core & Conditioning", category: "Conditioning", level: "All levels", equipment: "Mixed", focus: "Core strength plus steady cardio", rest: 45,
              plan: "Cable Kneeling Crunch|3|12–15;Plank|3|30–45s;Side Plank|2|30s/side;Cycling|2|cardio|Steady effort, ~8 minutes per block"),
        .init("Cardio Base", category: "Conditioning", level: "Beginner", equipment: "Cardio", focus: "Low-complexity aerobic training", warmup: 5, rest: 30,
              plan: "Cycling|3|cardio|Three ~8-minute aerobic blocks"),
        .init("Cardio Mix", category: "Conditioning", level: "All levels", equipment: "Cardio", focus: "Variety across cardio equipment", warmup: 5, rest: 30,
              plan: "Running|1|cardio|Comfortable pace; ~8 minutes;Rowing|1|cardio|Steady pace; ~8 minutes;Elliptical|1|cardio|Steady pace; ~8 minutes"),
        .init("Recovery Circuit", category: "Conditioning", level: "All levels", equipment: "Mixed", focus: "Light activity; avoid maximal loading", warmup: 3, rest: 45,
              plan: "Cycling|2|cardio|Gentle pace;Shoulder Press (Dumbbell)|2|12–15|Light and controlled;Goblet Squat|2|12–15|Comfortable range"),
        .init("Back & Posture", category: "Targeted", level: "All levels", equipment: "Mixed", focus: "Controlled pulling and rear-deltoid work", rest: 75,
              plan: "Chest Supported Machine Row|3|10–12;Cable Close Grip Lat Pulldown|3|10–12;Reverse Pec Deck Machine|3|12–15;Cable Rear Delt Row (with rope)|2|12–15")
    ]

    static let categories = ["All"] + Array(Set(all.map(\.category))).sorted()

    static let splits: [CoachTrainingSplit] = [
        .init(id: "first-steps", title: "Beginner • 3 days", description: "Alternating full-body fundamentals, spaced over the week.", level: "Beginner", workoutIDs: ["full-body-foundation-a", "full-body-foundation-b", "full-body-foundation-c"]),
        .init(id: "upper-lower", title: "Upper / Lower • 4 days", description: "Two upper and two lower sessions, with recovery between repeated muscle groups.", level: "Intermediate", workoutIDs: ["upper-a", "lower-a", "upper-b", "lower-b"]),
        .init(id: "push-pull-legs", title: "Push / Pull / Legs", description: "Three distinct hypertrophy workouts to rotate throughout the week.", level: "Intermediate", workoutIDs: ["hypertrophy-push", "hypertrophy-pull", "hypertrophy-legs"]),
        .init(id: "strength-base", title: "Strength • 3 days", description: "Progression-focused heavy compound movements.", level: "Intermediate", workoutIDs: ["strength-push", "strength-pull", "strength-legs"]),
        .init(id: "time-crunch", title: "Busy week • 3 days", description: "Short sessions when time is limited.", level: "All levels", workoutIDs: ["express-upper", "express-lower", "express-arms"]),
        .init(id: "full-body-machine", title: "Machines • 3 days", description: "Accessible strength training built around common gym stations.", level: "All levels", workoutIDs: ["machine-only-full-body", "full-body-foundation-b", "full-body-foundation-a"])
    ]
}

@MainActor
enum CoachWorkoutActions {
    static func start(name: String, plan: [ProgramExercise], gymID: String, in context: ModelContext) -> WorkoutSession? {
        let logs = plan.enumerated().compactMap { index, element -> ExerciseLog? in
            guard let exercise = ExerciseCatalog.findByName(element.name) else { return nil }
            return ExerciseLog(
                exerciseID: exercise.id, order: index, targetReps: element.reps,
                coachingNote: element.note, supersetGroup: element.superset,
                sets: (0..<max(1, element.sets)).map { WorkoutSet(order: $0) }
            )
        }
        guard !logs.isEmpty else { return nil }
        let session = WorkoutSession(title: name, exercises: logs, gymID: gymID)
        context.insert(session)
        try? context.save()
        return session
    }

    static func saveTemplate(_ workout: CoachWorkout, in context: ModelContext) {
        context.insert(WorkoutTemplate(
            name: workout.name,
            exerciseIDs: workout.exercises.compactMap { ExerciseCatalog.findByName($0.name)?.id },
            plan: workout.exercises
        ))
        try? context.save()
        Haptics.success()
    }
}

/// First-class training catalogue, separate from the user's editable 3-week program.
struct TrainingHubView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var personalPlan = ProgramPlanStore()
    @State private var section = 0
    @State private var category = "All"
    @State private var level = "All"
    @State private var search = ""
    @State private var week = 1
    @State private var selectedSession: WorkoutSession?
    @State private var editingDay: ProgramDay?
    @State private var templateDay: ProgramDay?
    @State private var scheduleSeed: ScheduledWorkoutRecord?
    @State private var confirmation: String?
    @AppStorage("activeGymID") private var gymID = GymProfileStore.defaultID

    private var visible: [CoachWorkout] {
        CoachWorkoutLibrary.all.filter {
            (category == "All" || $0.category == category) &&
            (level == "All" || $0.level == level || $0.level == "All levels") &&
            (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) ||
             $0.focus.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.text("TRAIN SMARTER", "TRAIN SLIMMER"))
                            .font(.caption.weight(.black))
                            .tracking(2)
                            .foregroundStyle(RFTheme.accent)
                        Text(L10n.text("Find your next session", "Vind je volgende training"))
                            .font(.system(size: 30, weight: .black, design: .rounded))
                        Text(L10n.text("Structured training, ready to log.", "Trainingsschema's die je direct kunt starten."))
                            .font(.subheadline)
                            .foregroundStyle(RFTheme.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(RFTheme.heroGradient, in: RoundedRectangle(cornerRadius: 24))

                    Picker(L10n.text("Training area", "Trainingsgedeelte"), selection: $section) {
                        Text(L10n.text("Workouts", "Workouts")).tag(0)
                        Text(L10n.text("Splits", "Splits")).tag(1)
                        Text(L10n.text("My 3 weeks", "Mijn 3 weken")).tag(2)
                    }
                    .pickerStyle(.segmented)

                    if section == 0 {
                        workoutLibrary
                    } else if section == 1 {
                        splitsLibrary
                    } else {
                        threeWeekPlan
                    }
                }
                .padding(RFLayout.pagePadding)
            }
            .background(RFTheme.bg)
            .navigationTitle(L10n.text("Training plans", "Trainingsschema's"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: L10n.text("Find a workout", "Zoek een training"))
            .sheet(item: $editingDay) { day in
                ProgramDayEditorView(day: day) { updated in
                    personalPlan.save(updated)
                }
            }
            .sheet(item: $templateDay) { day in
                TemplateEditorView(prefill: day)
            }
            .sheet(item: $scheduleSeed) { record in
                ScheduleWorkoutSheet(seed: record) { updated in
                    WorkoutScheduleStore.update(updated)
                }
            }
            .fullScreenCover(item: $selectedSession) { session in
                ActiveWorkoutView(session: session)
            }
            .alert(L10n.text("Saved to templates", "Opgeslagen als template"),
                   isPresented: Binding(
                    get: { confirmation != nil },
                    set: { if !$0 { confirmation = nil } }
                   )) {
                Button(L10n.done) { confirmation = nil }
            } message: { Text(confirmation ?? "") }
        }
    }

    private var workoutLibrary: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("\(visible.count) " + L10n.text("ready-to-use workouts", "kant-en-klare trainingen"))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Menu {
                    ForEach(["All", "Beginner", "Intermediate"], id: \.self) { value in
                        Button(value == "All" ? L10n.text("All levels", "Alle niveaus") : value) {
                            level = value
                        }
                    }
                } label: {
                    Label(level == "All" ? L10n.text("Level", "Niveau") : level,
                          systemImage: "slider.horizontal.3")
                        .font(.subheadline)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(CoachWorkoutLibrary.categories, id: \.self) { value in
                        Button {
                            category = value
                        } label: {
                            Text(value == "All" ? L10n.text("All goals", "Alle doelen") : value)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .foregroundStyle(category == value ? RFTheme.accent : .primary)
                                .background(category == value ? RFTheme.accent.opacity(0.16) : RFTheme.surface,
                                            in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            ForEach(visible) { workout in
                NavigationLink {
                    CoachWorkoutDetailView(
                        workout: workout,
                        onStart: { start(workout.name, plan: workout.exercises) },
                        onSave: {
                            CoachWorkoutActions.saveTemplate(workout, in: context)
                            confirmation = workout.name
                        },
                        onSchedule: { schedule(workout.name, plan: workout.exercises) }
                    )
                } label: {
                    CoachWorkoutCard(workout: workout)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var splitsLibrary: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.text(
                "Choose a weekly structure. Leave rest days between repeated muscle groups.",
                "Kies een weekindeling. Plan rustdagen tussen dezelfde spiergroepen."
            ))
            .font(.subheadline)
            .foregroundStyle(RFTheme.muted)

            ForEach(CoachWorkoutLibrary.splits) { split in
                VStack(alignment: .leading, spacing: 11) {
                    Text(split.title).font(.title3.bold())
                    Text(split.description).font(.subheadline).foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Label("\(split.workouts.count) " + L10n.text("sessions", "sessies"),
                              systemImage: "calendar")
                        Label("~\(split.weeklyMinutes) min/" + L10n.text("week", "week"),
                              systemImage: "clock")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RFTheme.accent)

                    ForEach(Array(split.workouts.enumerated()), id: \.element.id) { index, workout in
                        NavigationLink {
                            CoachWorkoutDetailView(
                                workout: workout,
                                onStart: { start(workout.name, plan: workout.exercises) },
                                onSave: {
                                    CoachWorkoutActions.saveTemplate(workout, in: context)
                                    confirmation = workout.name
                                },
                                onSchedule: { schedule(workout.name, plan: workout.exercises) }
                            )
                        } label: {
                            HStack {
                                Text("\(index + 1)")
                                    .font(.caption.bold())
                                    .frame(width: 27, height: 27)
                                    .background(RFTheme.accent.opacity(0.15), in: Circle())
                                Text(workout.name).font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("~\(workout.estimatedMinutes)m")
                                    .font(.caption).foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(17)
                .background(RFTheme.surface, in: RoundedRectangle(cornerRadius: 20))
            }
        }
    }

    private var threeWeekPlan: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.text("Your editable 3-week plan", "Jouw bewerkbare 3-wekenplan"))
                        .font(.title3.bold())
                    Text(L10n.text("Personal program • separate from the workout library",
                                   "Persoonlijk programma • los van de workoutbibliotheek"))
                        .font(.caption).foregroundStyle(RFTheme.muted)
                }
                Spacer()
                ShareLink(item: RepForgeShareCodec.programURL(
                    name: "RepForge 3-Week Program",
                    days: BuiltInProgram.days.map { personalPlan.day(for: $0) }
                )) {
                    Image(systemName: "square.and.arrow.up")
                }
            }

            Picker("Week", selection: $week) {
                Text("W1").tag(1)
                Text("W2").tag(2)
                Text("W3").tag(3)
            }
            .pickerStyle(.segmented)

            ForEach(personalPlan.days(for: week)) { day in
                ProgramDayCard(
                    day: day,
                    isCustomized: personalPlan.isCustomized(day),
                    onStart: { start("\(day.title) — \(day.focus)", plan: day.exercises) },
                    onEdit: { editingDay = day },
                    onSaveAsTemplate: { templateDay = day },
                    onSchedule: { schedule("\(day.title) — \(day.focus)", plan: day.exercises) },
                    onReset: { personalPlan.reset(day) }
                )
            }
        }
    }

    private func start(_ name: String, plan: [ProgramExercise]) {
        guard let session = CoachWorkoutActions.start(name: name, plan: plan, gymID: gymID, in: context)
        else { return }
        selectedSession = session
    }

    private func schedule(_ name: String, plan: [ProgramExercise]) {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        scheduleSeed = ScheduledWorkoutRecord(
            date: tomorrow, title: name,
            exerciseIDs: plan.compactMap { ExerciseCatalog.findByName($0.name)?.id },
            plan: plan, gymID: gymID,
            sourceLabel: L10n.text("Training library", "Trainingsbibliotheek")
        )
    }
}

struct CoachWorkoutCard: View {
    let workout: CoachWorkout

    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(RFTheme.accent.opacity(0.15))
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title2)
                    .foregroundStyle(RFTheme.accent)
            }
            .frame(width: 62, height: 67)
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(workout.category.uppercased())
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(RFTheme.accent)
                    Spacer()
                    Text(workout.level)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(workout.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(workout.focus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 13) {
                    Label("~\(workout.estimatedMinutes) min", systemImage: "clock")
                    Label("\(workout.exercises.count) " + L10n.text("moves", "oefeningen"),
                          systemImage: "list.bullet")
                    Text(workout.equipment)
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(RFTheme.muted)
                .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(RFTheme.surface, in: RoundedRectangle(cornerRadius: RFLayout.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: RFLayout.cornerRadius).stroke(RFTheme.cardBorder))
    }
}

struct CoachWorkoutDetailView: View {
    let workout: CoachWorkout
    let onStart: () -> Void
    let onSave: () -> Void
    let onSchedule: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(workout.category.uppercased())
                        .font(.caption.weight(.heavy))
                        .tracking(2)
                        .foregroundStyle(RFTheme.accent)
                    Text(workout.name)
                        .font(.system(size: 29, weight: .black, design: .rounded))
                    Text(workout.focus)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Label("~\(workout.estimatedMinutes) min", systemImage: "clock")
                        Label("\(workout.totalSets) " + L10n.text("sets", "sets"),
                              systemImage: "checkmark.circle")
                        Text(workout.level)
                    }
                    .font(.caption.bold())
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RFTheme.heroGradient, in: RoundedRectangle(cornerRadius: 23))

                Text(L10n.text("Session outline", "Trainingsopbouw"))
                    .font(.title3.bold())

                ForEach(Array(workout.exercises.enumerated()), id: \.offset) { index, exercise in
                    HStack(alignment: .top, spacing: 13) {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .frame(width: 28, height: 28)
                            .foregroundStyle(RFTheme.accent)
                            .background(RFTheme.accent.opacity(0.14), in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name).font(.subheadline.weight(.semibold))
                            Text("\(exercise.sets) × \(exercise.reps)")
                                .font(.caption).foregroundStyle(RFTheme.accent)
                            if let note = exercise.note {
                                Text(note).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RFTheme.surface, in: RoundedRectangle(cornerRadius: 14))
                }

                Text(L10n.text(
                    "Times are estimates including warm-up, sets, rest and station changes. Adjust loading and rest to your ability.",
                    "Tijden zijn schattingen inclusief warming-up, sets, rust en wisselen van toestel. Pas belasting en rust aan je niveau aan."
                ))
                .font(.caption)
                .foregroundStyle(RFTheme.muted)
            }
            .padding()
        }
        .background(RFTheme.bg)
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                Button(action: onStart) {
                    Label(L10n.text("Start workout", "Start training"), systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                }
                .buttonStyle(.borderedProminent)
                Button(action: onSave) {
                    Image(systemName: "bookmark")
                        .frame(width: 34, height: 38)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(L10n.text("Save as template", "Opslaan als template"))
                Button(action: onSchedule) {
                    Image(systemName: "calendar.badge.plus")
                        .frame(width: 34, height: 38)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(L10n.text("Schedule workout", "Training inplannen"))
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }
}
