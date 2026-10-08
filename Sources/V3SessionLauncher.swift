import SwiftUI
import SwiftData

struct V3SessionLauncher: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let sessions: [WorkoutSession]
    let templates: [WorkoutTemplate]
    let onSelect: (WorkoutSession) -> Void
    @AppStorage("activeGymID") private var gymID = GymProfileStore.defaultID
    @AppStorage("scheduleRevision") private var scheduleRevision = 0
    @State private var selected = 0

    private var scheduled: [ScheduledWorkoutRecord] {
        _ = scheduleRevision
        return WorkoutScheduleStore.load().filter { !$0.skipped }.sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    V3Tag(text: "SESSION / LAUNCH")
                    Text(L10n.text("How are we training?", "Wat gaan we trainen?"))
                        .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    if let running = sessions.first(where: { $0.endedAt == nil }) {
                        V3PrimaryAction(
                            title: L10n.text("Resume", "Hervatten") + ": " + running.title,
                            symbol: "arrow.up.right"
                        ) { onSelect(running) }
                    }
                    V3PrimaryAction(
                        title: L10n.text("Blank workout", "Lege training"),
                        symbol: "plus.circle.fill"
                    ) { startEmpty() }

                    Picker(L10n.text("Workout source", "Trainingsbron"), selection: $selected) {
                        Text(L10n.text("Routines", "Schema's")).tag(0)
                        Text(L10n.text("Coached", "Workouts")).tag(1)
                        Text(L10n.text("Scheduled", "Gepland")).tag(2)
                    }
                    .pickerStyle(.segmented)

                    if selected == 0 {
                        if templates.isEmpty {
                            Text(L10n.text("No personal routines saved yet.",
                                           "Nog geen eigen schema's opgeslagen."))
                                .foregroundStyle(V3.faint)
                        }
                        ForEach(templates) { template in
                            launchRow(
                                title: template.name,
                                subtitle: "\(template.exerciseIDs.count) " +
                                    L10n.text("exercises", "oefeningen"),
                                action: { startTemplate(template) }
                            )
                        }
                    } else if selected == 1 {
                        ForEach(CoachWorkoutLibrary.all) { workout in
                            launchRow(
                                title: workout.name,
                                subtitle: "~\(workout.estimatedMinutes) min • " + workout.category,
                                action: {
                                    if let session = CoachWorkoutActions.start(
                                        name: workout.name, plan: workout.exercises,
                                        gymID: gymID, in: context
                                    ) { onSelect(session) }
                                }
                            )
                        }
                    } else {
                        if scheduled.isEmpty {
                            Text(L10n.text("Nothing scheduled. Plan workouts in Studio.",
                                           "Geen trainingen gepland. Plan trainingen in Studio."))
                                .foregroundStyle(V3.faint)
                        }
                        ForEach(scheduled) { item in
                            launchRow(
                                title: item.title,
                                subtitle: item.date.formatted(date: .abbreviated, time: .omitted),
                                action: { startScheduled(item) }
                            )
                        }
                    }
                }
                .padding(19)
            }
            .background(V3Backdrop())
            .navigationTitle(L10n.text("Start training", "Training starten"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("Close", "Sluiten")) { dismiss() }
                }
            }
        }
    }

    private func launchRow(title: String, subtitle: String,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: "play.circle.fill")
                    .font(.title2).foregroundStyle(V3.accent)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    Text(subtitle).font(.caption).foregroundStyle(V3.faint)
                }
                Spacer(minLength: 3)
                Image(systemName: "arrow.up.right").foregroundStyle(V3.accent)
            }
            .padding(16)
            .background(V3.card, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private func startEmpty() {
        let session = WorkoutSession(
            title: L10n.text("New workout", "Nieuwe training"),
            gymID: gymID
        )
        context.insert(session)
        try? context.save()
        onSelect(session)
    }

    private func startTemplate(_ template: WorkoutTemplate) {
        let planned: [ExerciseLog]
        if let plan = template.plannedExercises, !plan.isEmpty {
            planned = plan.enumerated().compactMap { index, exercise in
                guard let definition = ExerciseCatalog.findByName(exercise.name) else { return nil }
                return ExerciseLog(
                    exerciseID: definition.id, order: index,
                    targetReps: exercise.reps, coachingNote: exercise.note,
                    supersetGroup: exercise.superset,
                    sets: (0..<max(1, exercise.sets)).map { WorkoutSet(order: $0) }
                )
            }
        } else {
            planned = template.exerciseIDs.enumerated().map { i, id in
                ExerciseLog(exerciseID: id, order: i,
                            sets: (0..<AppPreferences.defaultSets).map { WorkoutSet(order: $0) })
            }
        }
        let session = WorkoutSession(title: template.name, exercises: planned, gymID: gymID)
        context.insert(session)
        try? context.save()
        onSelect(session)
    }

    private func startScheduled(_ scheduled: ScheduledWorkoutRecord) {
        let plan: [ExerciseLog]
        if let exercises = scheduled.plan, !exercises.isEmpty {
            plan = exercises.enumerated().compactMap { index, exercise in
                guard let definition = ExerciseCatalog.findByName(exercise.name) else { return nil }
                return ExerciseLog(
                    exerciseID: definition.id, order: index,
                    targetReps: exercise.reps, coachingNote: exercise.note,
                    supersetGroup: exercise.superset,
                    sets: (0..<max(1, exercise.sets)).map { WorkoutSet(order: $0) }
                )
            }
        } else {
            plan = scheduled.exerciseIDs.enumerated().map { index, id in
                ExerciseLog(exerciseID: id, order: index,
                    sets: (0..<AppPreferences.defaultSets).map { WorkoutSet(order: $0) })
            }
        }
        let session = WorkoutSession(title: scheduled.title, exercises: plan, gymID: scheduled.gymID)
        context.insert(session)
        WorkoutScheduleStore.remove(id: scheduled.id)
        try? context.save()
        onSelect(session)
    }
}
