import SwiftUI
import SwiftData
import Charts
import AVKit
import UIKit
import UniformTypeIdentifiers
import UserNotifications
import CoreBluetooth

struct GymQuickPicker: View {
    @Binding var activeGymID: String
    @State private var refresh = UUID()
    @AppStorage("gymRevision") private var gymRevision = 0

    var body: some View {
        Menu {
            ForEach(GymProfileStore.load()) { gym in
                Button {
                    activeGymID = gym.id
                    Haptics.light()
                    refresh = UUID()
                } label: {
                    if gym.id == activeGymID {
                        Label(gym.name, systemImage: "checkmark")
                    } else {
                        Text(gym.name)
                    }
                }
            }
        } label: {
            Label(
                GymProfileStore.profile(id: activeGymID).name,
                systemImage: "mappin.and.ellipse"
            )
            .font(.caption.bold())
            .lineLimit(1)
        }
        .id("\(refresh)-\(gymRevision)")
        .buttonStyle(.bordered)
    }
}

struct StartWorkoutView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutTemplate.createdAt, order: .reverse) private var templates: [WorkoutTemplate]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @State private var showTemplateEditor = false
    @State private var showTrainingHub = false
    @State private var templateSeed: ProgramDay?
    @State private var editingTemplate: WorkoutTemplate?
    @State private var activeSession: WorkoutSession?
    @State private var scheduleSeed: ScheduledWorkoutRecord?
    @AppStorage("activeGymID") private var activeGymID = GymProfileStore.defaultID
    @AppStorage("scheduleRevision") private var scheduleRevision = 0

    private var upcomingScheduled: [ScheduledWorkoutRecord] {
        _ = scheduleRevision
        let start = Calendar.current.startOfDay(for: .now)
        return WorkoutScheduleStore.load()
            .filter { !$0.skipped && $0.date >= start }
            .prefix(4)
            .map { $0 }
    }

    private var completedThisWeek: Int {
        sessions.filter {
            $0.endedAt != nil && Calendar.current.isDate(
                $0.startedAt, equalTo: .now, toGranularity: .weekOfYear
            )
        }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RFLayout.sectionSpacing) {
                    VStack(alignment: .leading, spacing: RFLayout.sectionSpacing) {
                        HStack(alignment: .top, spacing: 14) {
                            VStack(alignment: .leading, spacing: 9) {
                                Text(L10n.text("YOUR TRAINING SPACE", "JOUW TRAININGSRUIMTE"))
                                    .font(.caption2.weight(.heavy))
                                    .tracking(1.8)
                                    .foregroundStyle(RFTheme.accent)

                                Text(L10n.text("Make today's sets count.", "Haal meer uit elke set."))
                                    .font(RFLayout.heroFont)
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(L10n.text(
                                    "Start quickly. Log every rep. See your progress.",
                                    "Start direct. Log elke rep. Zie je vooruitgang."
                                ))
                                .font(.subheadline)
                                .foregroundStyle(RFTheme.muted)
                            }

                            Spacer(minLength: 0)

                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: RFLayout.style == "compact" ? 26 : 32, weight: .bold))
                                .foregroundStyle(RFTheme.accent)
                                .frame(width: RFLayout.style == "compact" ? 54 : 68,
                                       height: RFLayout.style == "compact" ? 54 : 68)
                                .background(RFTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 18))
                                .accessibilityHidden(true)
                        }

                        HStack(spacing: 10) {
                            Label("\(completedThisWeek) " + L10n.text("this week", "deze week"), systemImage: "checkmark.circle")
                            Spacer()
                            Label("\(templates.count) " + L10n.text("routines", "schema's"), systemImage: "rectangle.stack")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, RFLayout.style == "compact" ? 0 : 6)
                    }
                    .padding(RFLayout.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RFTheme.heroGradient)
                    .clipShape(RoundedRectangle(cornerRadius: RFLayout.cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: RFLayout.cornerRadius)
                            .stroke(RFTheme.cardBorder)
                    )

                    ForgeMomentumCard(sessions: sessions, condensed: true)

                    WorkoutActivityHeatmap(sessions: sessions, condensed: true)

                    NavigationLink {
                        MuscleIntelligenceScreen()
                    } label: {
                        MuscleIntelligencePanel(sessions: sessions, compact: true)
                    }
                    .buttonStyle(.plain)

                    HStack {
                        Text(L10n.text("Quick Start", "Snel starten"))
                            .font(.title2.bold())
                        Spacer()
                        GymQuickPicker(activeGymID: $activeGymID)
                    }

                    Button {
                        activeSession = createSession(title: "Workout", exerciseIDs: [])
                    } label: {
                        HStack {
                            Image(systemName: "bolt.fill")
                                .font(.title3.bold())
                            Text(L10n.text("Start an empty workout", "Lege training starten"))
                                .font(.headline)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.headline)
                        }
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RFLayout.style == "compact" ? 11 : 17)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(RFTheme.accent)

                    if !upcomingScheduled.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(L10n.text("Upcoming", "Gepland"))
                                    .font(.title2.bold())
                                Spacer()
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundStyle(RFTheme.accent)
                            }

                            ForEach(upcomingScheduled) { item in
                                ScheduledWorkoutCard(
                                    item: item,
                                    onStart: {
                                        activeSession = createSession(schedule: item)
                                    },
                                    onReschedule: {
                                        scheduleSeed = item
                                    },
                                    onSkip: {
                                        WorkoutScheduleStore.toggleSkipped(id: item.id)
                                    },
                                    onDelete: {
                                        WorkoutScheduleStore.remove(id: item.id)
                                    }
                                )
                            }
                        }
                    }

                    HStack {
                        Text(L10n.text("Your templates", "Jouw templates")).font(.title2.bold())
                        Spacer()
                        Button {
                            templateSeed = nil
                            showTemplateEditor = true
                        } label: {
                            Label("Template", systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                    }

                    if templates.isEmpty {
                        EmptyCard(
                            icon: "rectangle.stack.badge.plus",
                            title: "Build your first template",
                            text: "Save a repeatable workout, then launch it with one tap."
                        )
                    } else {
                        LazyVGrid(columns: RFLayout.templateColumns, spacing: RFLayout.style == "compact" ? 8 : 14) {
                            ForEach(templates) { template in
                                TemplateCard(
                                    template: template,
                                    onStart: {
                                        activeSession = createSession(template: template)
                                    },
                                    onEdit: {
                                        editingTemplate = template
                                    },
                                    onDuplicate: {
                                        duplicateTemplate(template)
                                    },
                                    onSchedule: {
                                        scheduleSeed = ScheduledWorkoutRecord(
                                            date: defaultScheduleDate(),
                                            title: template.name,
                                            exerciseIDs: template.exerciseIDs,
                                            plan: template.plannedExercises,
                                            gymID: activeGymID,
                                            sourceLabel: L10n.text("Template", "Template")
                                        )
                                    },
                                    onDelete: {
                                        context.delete(template)
                                        try? context.save()
                                    }
                                )
                            }
                        }
                    }

                    Button {
                        showTrainingHub = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "square.stack.3d.up.fill")
                                .font(.title2)
                                .foregroundStyle(RFTheme.accent)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(L10n.text("Explore training plans", "Bekijk trainingsschema's"))
                                    .font(.headline)
                                Text(L10n.text("Ready-made workouts and your personal 3-week plan",
                                               "Kant-en-klare workouts en jouw 3-wekenplan"))
                                    .font(.caption)
                                    .foregroundStyle(RFTheme.muted)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(RFTheme.accent)
                        }
                        .padding(17)
                        .background(RFTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)

                    if let current = sessions.first(where: { $0.endedAt == nil }) {
                        Button {
                            activeSession = current
                        } label: {
                            Label("Resume \(current.title)", systemImage: "arrowtriangle.right.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(RFLayout.pagePadding)
            }
            .background(RFTheme.bg)
            .navigationTitle(L10n.startWorkout)
            .sheet(isPresented: $showTrainingHub) {
                TrainingHubView()
            }
            .sheet(isPresented: $showTemplateEditor) {
                TemplateEditorView()
            }
            .sheet(item: $templateSeed, onDismiss: {
                templateSeed = nil
            }) { day in
                TemplateEditorView(prefill: day)
            }
            .sheet(item: $editingTemplate) { template in
                TemplateEditorView(template: template)
            }
            .sheet(item: $scheduleSeed) { seed in
                ScheduleWorkoutSheet(seed: seed) { updated in
                    WorkoutScheduleStore.update(updated)
                }
            }
            .fullScreenCover(item: $activeSession) { session in
                ActiveWorkoutView(session: session)
            }
        }
    }

    private func defaultScheduleDate() -> Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: .now) ?? .now
        return calendar.date(bySettingHour: 18, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    private func createSession(schedule: ScheduledWorkoutRecord) -> WorkoutSession {
        let logs: [ExerciseLog]

        if let plan = schedule.plan, !plan.isEmpty {
            logs = plan.enumerated().compactMap { index, item in
                guard let exercise = ExerciseCatalog.findByName(item.name) else { return nil }
                return ExerciseLog(
                    exerciseID: exercise.id,
                    order: index,
                    targetReps: item.reps,
                    coachingNote: item.note,
                    supersetGroup: item.superset,
                    sets: (0..<max(1, item.sets)).map { WorkoutSet(order: $0) }
                )
            }
        } else {
            logs = schedule.exerciseIDs.enumerated().map { index, id in
                ExerciseLog(
                    exerciseID: id,
                    order: index,
                    sets: (0..<AppPreferences.defaultSets).map { WorkoutSet(order: $0) }
                )
            }
        }

        let session = WorkoutSession(
            title: schedule.title,
            exercises: logs,
            gymID: schedule.gymID
        )
        context.insert(session)
        WorkoutScheduleStore.remove(id: schedule.id)
        try? context.save()
        return session
    }

    private func duplicateTemplate(_ template: WorkoutTemplate) {
        let copy = WorkoutTemplate(
            name: "\(template.name) \(L10n.text("Copy", "Kopie"))",
            exerciseIDs: template.exerciseIDs,
            plan: template.plannedExercises
        )
        context.insert(copy)
        try? context.save()
        Haptics.light()
    }

    private func createSession(title: String, exerciseIDs: [String]) -> WorkoutSession {
        let logs = exerciseIDs.enumerated().map { index, id in
            ExerciseLog(
                exerciseID: id,
                order: index,
                sets: (0..<AppPreferences.defaultSets).map { WorkoutSet(order: $0) }
            )
        }
        let session = WorkoutSession(title: title, exercises: logs, gymID: activeGymID)
        context.insert(session)
        try? context.save()
        return session
    }

    private func createSession(template: WorkoutTemplate) -> WorkoutSession {
        if let plan = template.plannedExercises, !plan.isEmpty {
            let logs = plan.enumerated().compactMap { index, item -> ExerciseLog? in
                guard let exercise = ExerciseCatalog.findByName(item.name) else { return nil }
                return ExerciseLog(
                    exerciseID: exercise.id,
                    order: index,
                    targetReps: item.reps,
                    coachingNote: item.note,
                    supersetGroup: item.superset,
                    sets: (0..<max(1, item.sets)).map { WorkoutSet(order: $0) }
                )
            }
            let session = WorkoutSession(title: template.name, exercises: logs, gymID: activeGymID)
            context.insert(session)
            try? context.save()
            return session
        }

        return createSession(title: template.name, exerciseIDs: template.exerciseIDs)
    }

    private func createSession(day: ProgramDay) -> WorkoutSession {
        let logs = day.exercises.enumerated().compactMap { index, item -> ExerciseLog? in
            guard let exercise = ExerciseCatalog.findByName(item.name) else { return nil }
            return ExerciseLog(
                exerciseID: exercise.id,
                order: index,
                targetReps: item.reps,
                coachingNote: item.note,
                supersetGroup: item.superset,
                sets: (0..<item.sets).map { WorkoutSet(order: $0) }
            )
        }
        let session = WorkoutSession(title: "\(day.title) — \(day.focus)", exercises: logs, gymID: activeGymID)
        context.insert(session)
        try? context.save()
        return session
    }
}

struct ScheduleWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var item: ScheduledWorkoutRecord
    let onSave: (ScheduledWorkoutRecord) -> Void

    init(seed: ScheduledWorkoutRecord, onSave: @escaping (ScheduledWorkoutRecord) -> Void) {
        _item = State(initialValue: seed)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.text("Workout", "Training")) {
                    TextField(L10n.text("Title", "Titel"), text: $item.title)

                    DatePicker(
                        L10n.text("Date & time", "Datum & tijd"),
                        selection: $item.date,
                        in: Date.now.addingTimeInterval(-86400)...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                Section(L10n.text("Gym", "Gym")) {
                    Picker(L10n.text("Location", "Locatie"), selection: $item.gymID) {
                        ForEach(GymProfileStore.load()) { gym in
                            Text(gym.name).tag(gym.id)
                        }
                    }
                }

                if let source = item.sourceLabel {
                    Section {
                        LabeledContent(L10n.text("Source", "Bron"), value: source)
                        LabeledContent(
                            L10n.text("Exercises", "Oefeningen"),
                            value: "\(item.plan?.count ?? item.exerciseIDs.count)"
                        )
                    }
                }
            }
            .navigationTitle(L10n.text("Schedule Workout", "Training inplannen"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("Cancel", "Annuleren")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("Save", "Opslaan")) {
                        onSave(item)
                        Haptics.success()
                        dismiss()
                    }
                    .bold()
                    .disabled(item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct ScheduledWorkoutCard: View {
    let item: ScheduledWorkoutRecord
    let onStart: () -> Void
    let onReschedule: () -> Void
    let onSkip: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(item.date.formatted(.dateTime.day()))
                    .font(.title2.bold())
                    .foregroundStyle(RFTheme.accent)
                Text(item.date.formatted(.dateTime.month(.abbreviated)))
                    .font(.caption.bold())
                    .foregroundStyle(RFTheme.muted)
            }
            .frame(width: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(
                    "\(item.date.formatted(date: .omitted, time: .shortened)) • \(GymProfileStore.profile(id: item.gymID).name)"
                )
                .font(.caption)
                .foregroundStyle(RFTheme.muted)
            }

            Spacer()

            Button(action: onStart) {
                Image(systemName: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(RFTheme.accent)

            Menu {
                Button(action: onReschedule) {
                    Label(L10n.text("Reschedule", "Verplaatsen"), systemImage: "calendar")
                }
                Button(action: onSkip) {
                    Label(L10n.text("Skip", "Overslaan"), systemImage: "forward.end")
                }
                Button(role: .destructive, action: onDelete) {
                    Label(L10n.text("Delete", "Verwijder"), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 32, height: 32)
            }
        }
        .padding(12)
        .background(RFTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ProgramDayCard: View {
    let day: ProgramDay
    let isCustomized: Bool
    let onStart: () -> Void
    let onEdit: () -> Void
    let onSaveAsTemplate: () -> Void
    let onSchedule: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 2) {
                    Text(day.day.prefix(3).uppercased())
                        .font(.caption2.bold())
                        .foregroundStyle(RFTheme.accent)
                    Text("\(day.exercises.count)")
                        .font(.title3.bold())
                }
                .frame(width: 46, height: 48)
                .background(RFTheme.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 13))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(day.title)
                            .font(.headline)
                            .lineLimit(1)

                        if isCustomized {
                            Text(L10n.text("Edited", "Bewerkt"))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(RFTheme.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(RFTheme.accent.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }

                    Text(day.focus)
                        .font(.caption.bold())
                        .foregroundStyle(RFTheme.accent)

                    Text(day.partner.capitalized)
                        .font(.caption2)
                        .foregroundStyle(RFTheme.muted)

                    Label("~\(TrainingTimeEstimator.minutes(for: day.exercises)) min", systemImage: "clock")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(RFTheme.muted)
                }

                Spacer()

                Menu {
                    Button(action: onEdit) {
                        Label(L10n.text("Edit Workout", "Training bewerken"), systemImage: "pencil")
                    }
                    Button(action: onSaveAsTemplate) {
                        Label(L10n.text("Add to New Template", "Aan nieuwe template toevoegen"), systemImage: "rectangle.stack.badge.plus")
                    }
                    Button(action: onSchedule) {
                        Label(L10n.text("Schedule", "Inplannen"), systemImage: "calendar.badge.plus")
                    }
                    ShareLink(
                        item: RepForgeShareCodec.templateURL(
                            name: "\(day.title) — \(day.focus)",
                            exercises: day.exercises
                        )
                    ) {
                        Label(L10n.text("Share Workout Link", "Trainingslink delen"), systemImage: "square.and.arrow.up")
                    }
                    if isCustomized {
                        Button(role: .destructive, action: onReset) {
                            Label(L10n.text("Reset to Original", "Herstel origineel"), systemImage: "arrow.counterclockwise")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline)
                        .foregroundStyle(RFTheme.muted)
                        .frame(width: 34, height: 34)
                        .background(RFTheme.field)
                        .clipShape(Circle())
                }
            }

            VStack(spacing: 7) {
                ForEach(Array(day.exercises.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 9) {
                        Text("\(index + 1)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(RFTheme.muted)
                            .frame(width: 20, height: 20)
                            .background(RFTheme.field)
                            .clipShape(Circle())

                        Text(item.name)
                            .font(.caption)
                            .lineLimit(1)

                        Spacer()

                        if let group = item.superset, !group.isEmpty {
                            Text("SS \(group)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(RFTheme.accent)
                        }

                        Text("\(item.sets) × \(item.reps)")
                            .font(.caption2.bold())
                            .foregroundStyle(RFTheme.muted)
                    }
                }
            }

            HStack(spacing: 8) {
                Button(action: onStart) {
                    Label(L10n.text("Start", "Start"), systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(RFTheme.accent)

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.bordered)

                Button(action: onSchedule) {
                    Image(systemName: "calendar.badge.plus")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [RFTheme.surface, RFTheme.raised.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(RFTheme.cardBorder)
        )
    }
}

struct ProgramDayEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ProgramDay
    @State private var showPicker = false
    @State private var pickerIDs: [String] = []
    let onSave: (ProgramDay) -> Void

    init(day: ProgramDay, onSave: @escaping (ProgramDay) -> Void) {
        _draft = State(initialValue: day)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Workout") {
                    TextField("Day", text: $draft.day)
                    TextField("Focus", text: $draft.focus)
                    TextField("Training partner / note", text: $draft.partner)
                }

                Section("Exercises") {
                    ForEach(draft.exercises.indices, id: \.self) { index in
                        ProgramExerciseEditorRow(item: $draft.exercises[index])
                    }
                    .onDelete { offsets in
                        draft.exercises.remove(atOffsets: offsets)
                    }
                    .onMove { source, destination in
                        draft.exercises.move(fromOffsets: source, toOffset: destination)
                    }

                    Button {
                        pickerIDs = []
                        showPicker = true
                    } label: {
                        Label("Add Exercises", systemImage: "plus")
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .background(RFTheme.bg)
            .navigationTitle("Edit \(draft.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .bold()
                    .disabled(draft.exercises.isEmpty)
                }
            }
            .sheet(isPresented: $showPicker, onDismiss: addPickedExercises) {
                ExercisePickerView(selectedIDs: $pickerIDs)
            }
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private func addPickedExercises() {
        let existing = Set(draft.exercises.map(\.name))
        for id in pickerIDs {
            guard let exercise = ExerciseCatalog.find(id),
                  !existing.contains(exercise.name) else { continue }
            draft.exercises.append(ProgramExercise(exercise.name, 3, "8–12"))
        }
        pickerIDs = []
    }
}

struct ProgramExerciseEditorRow: View {
    @Binding var item: ProgramExercise

    private var isCardio: Bool {
        ExerciseCatalog.findByName(item.name)?.movement == "cardio"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(item.name)
                    .font(.headline)

                Spacer()

                if isCardio {
                    Label("Cardio", systemImage: "figure.run")
                        .font(.caption2.bold())
                        .foregroundStyle(RFTheme.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(RFTheme.accent.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 14) {
                Stepper(
                    isCardio
                        ? "\(L10n.text("Intervals", "Intervallen")) \(item.sets)"
                        : "\(L10n.text("Sets", "Sets")) \(item.sets)",
                    value: $item.sets,
                    in: 1...10
                )

                if isCardio {
                    Text(L10n.text("Time • Distance • Pace", "Tijd • Afstand • Tempo"))
                        .font(.caption2.bold())
                        .foregroundStyle(RFTheme.muted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(RFTheme.field)
                        .clipShape(Capsule())
                } else {
                    TextField(L10n.text("Reps", "Reps"), text: $item.reps)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 86)
                        .multilineTextAlignment(.center)
                }
            }

            HStack {
                TextField(
                    L10n.text("Note (optional)", "Notitie (optioneel)"),
                    text: Binding(
                        get: { item.note ?? "" },
                        set: { item.note = $0.isEmpty ? nil : $0 }
                    )
                )
                .textFieldStyle(.roundedBorder)

                if !isCardio {
                    TextField(
                        "SS",
                        text: Binding(
                            get: { item.superset ?? "" },
                            set: { item.superset = $0.isEmpty ? nil : $0.uppercased() }
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 62)
                    .multilineTextAlignment(.center)
                }
            }
        }
        .padding(.vertical, 5)
        .onAppear {
            if isCardio && item.reps != "cardio" {
                item.reps = "cardio"
            }
        }
    }
}

struct TemplateCard: View {
    let template: WorkoutTemplate
    let onStart: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onSchedule: () -> Void
    let onDelete: () -> Void

    private var exerciseNames: [String] {
        template.plannedExercises?.map(\.name)
            ?? template.exerciseIDs.compactMap(ExerciseCatalog.find).map(\.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(RFTheme.accent.opacity(0.14))
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.title3.bold())
                        .foregroundStyle(RFTheme.accent)
                }
                .frame(width: 44, height: 44)

                Spacer()

                Label("\(exerciseNames.count)", systemImage: "list.bullet")
                    .font(.caption.bold())
                    .foregroundStyle(RFTheme.muted)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(RFTheme.field)
                    .clipShape(Capsule())
                    .accessibilityLabel("\(exerciseNames.count) \(L10n.text("exercises", "oefeningen"))")

                Menu {
                    Button(action: onEdit) {
                        Label(L10n.text("Edit Template", "Template bewerken"), systemImage: "pencil")
                    }
                    Button(action: onDuplicate) {
                        Label(L10n.text("Duplicate", "Dupliceren"), systemImage: "plus.square.on.square")
                    }
                    Button(action: onSchedule) {
                        Label(L10n.text("Schedule", "Inplannen"), systemImage: "calendar.badge.plus")
                    }
                    ShareLink(
                        item: RepForgeShareCodec.templateURL(
                            name: template.name,
                            exercises: template.plannedExercises ?? template.exerciseIDs.compactMap { id in
                                guard let ex = ExerciseCatalog.find(id) else { return nil }
                                return ProgramExercise(ex.name, AppPreferences.defaultSets, "8–12")
                            }
                        )
                    ) {
                        Label(L10n.text("Share Link", "Deellink"), systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive, action: onDelete) {
                        Label(L10n.text("Delete", "Verwijder"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline)
                        .foregroundStyle(RFTheme.muted)
                        .frame(width: 34, height: 34)
                        .background(RFTheme.field)
                        .clipShape(Circle())
                }
            }

            Text(template.name)
                .font(.headline)
                .lineLimit(2)

            if let plan = template.plannedExercises, !plan.isEmpty {
                Label("~\(TrainingTimeEstimator.minutes(for: plan)) min " +
                      L10n.text("estimated", "geschat"), systemImage: "clock")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(RFTheme.accent)
            }

            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(exerciseNames.prefix(3).enumerated()), id: \.offset) { index, name in
                    HStack(spacing: 7) {
                        Circle()
                            .fill(index == 0 ? RFTheme.accent : RFTheme.muted.opacity(0.5))
                            .frame(width: 5, height: 5)
                        Text(name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                if exerciseNames.count > 3 {
                    Text("+\(exerciseNames.count - 3) \(L10n.text("more", "meer"))")
                        .font(.caption2.bold())
                        .foregroundStyle(RFTheme.accent)
                }
            }

            Spacer(minLength: 2)

            Button(action: onStart) {
                HStack {
                    Image(systemName: "play.fill")
                    Text(L10n.text("Start", "Start"))
                        .font(.subheadline.bold())
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .padding(.vertical, 7)
            }
            .buttonStyle(.borderedProminent)
            .tint(RFTheme.accent)
        }
        .padding(14)
        .frame(minHeight: 198, alignment: .topLeading)
        .background(RFTheme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(RFTheme.cardBorder)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
    }
}

struct TemplateEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    private let template: WorkoutTemplate?

    @State private var name: String
    @State private var items: [ProgramExercise]
    @State private var showPicker = false
    @State private var pickerIDs: [String] = []

    init(prefill: ProgramDay? = nil, template: WorkoutTemplate? = nil) {
        self.template = template

        if let template {
            _name = State(initialValue: template.name)
            let existing = template.plannedExercises ??
                template.exerciseIDs.compactMap { id in
                    guard let exercise = ExerciseCatalog.find(id) else { return nil }
                    return ProgramExercise(
                        exercise.name,
                        exercise.movement == "cardio" ? 1 : 3,
                        exercise.movement == "cardio" ? "cardio" : "8–12"
                    )
                }
            _items = State(initialValue: existing)
        } else if let prefill {
            _name = State(initialValue: "\(prefill.day) — \(prefill.focus)")
            _items = State(initialValue: prefill.exercises)
        } else {
            _name = State(initialValue: "New Template")
            _items = State(initialValue: [])
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Template") {
                    TextField("Name", text: $name)
                }

                Section("Exercises") {
                    ForEach(items.indices, id: \.self) { index in
                        ProgramExerciseEditorRow(item: $items[index])
                    }
                    .onDelete { offsets in
                        items.remove(atOffsets: offsets)
                    }
                    .onMove { source, destination in
                        items.move(fromOffsets: source, toOffset: destination)
                    }

                    Button {
                        pickerIDs = []
                        showPicker = true
                    } label: {
                        Label("Add Exercises", systemImage: "plus")
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .background(RFTheme.bg)
            .navigationTitle(template == nil ? "New Template" : "Edit Template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTemplate()
                    }
                    .bold()
                    .disabled(items.isEmpty)
                }
            }
            .sheet(isPresented: $showPicker, onDismiss: addPickedExercises) {
                ExercisePickerView(selectedIDs: $pickerIDs)
            }
        }
    }

    private func saveTemplate() {
        let ids = items.compactMap { ExerciseCatalog.findByName($0.name)?.id }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = cleanName.isEmpty ? "Workout" : cleanName

        if let template {
            template.name = finalName
            template.exerciseIDs = ids
            template.plannedExercises = items
        } else {
            context.insert(
                WorkoutTemplate(
                    name: finalName,
                    exerciseIDs: ids,
                    plan: items
                )
            )
        }

        try? context.save()
        dismiss()
    }

    private func addPickedExercises() {
        let existing = Set(items.map(\.name))
        for id in pickerIDs {
            guard let exercise = ExerciseCatalog.find(id),
                  !existing.contains(exercise.name) else { continue }
            items.append(
                ProgramExercise(
                    exercise.name,
                    exercise.movement == "cardio" ? 1 : 3,
                    exercise.movement == "cardio" ? "cardio" : "8–12"
                )
            )
        }
        pickerIDs = []
    }
}

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIDs: [String]
    @State private var search = ""
    @State private var muscle = "All"
    @State private var equipment = "All"
    @AppStorage("exerciseShortcutRevision") private var shortcutRevision = 0

    private var filtered: [ExerciseDefinition] {
        _ = shortcutRevision
        return ExerciseCatalog.all.filter { ex in
            ExerciseSearch.matches(ex, query: search) &&
            (muscle == "All" || ex.muscle == muscle) &&
            GymEquipmentFilter.matches(ex, selected: equipment)
        }
    }

    private var favorites: [ExerciseDefinition] {
        ExerciseShortcutStore.favorites.compactMap(ExerciseCatalog.find)
    }

    private var recent: [ExerciseDefinition] {
        ExerciseShortcutStore.recent
            .filter { !ExerciseShortcutStore.favorites.contains($0) }
            .compactMap(ExerciseCatalog.find)
    }

    private var showShortcuts: Bool {
        search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            muscle == "All" && equipment == "All"
    }

    var body: some View {
        NavigationStack {
            List {
                if showShortcuts, !favorites.isEmpty {
                    Section(L10n.text("Favorites", "Favorieten")) {
                        ForEach(favorites) { ex in
                            exerciseRow(ex)
                        }
                    }
                }

                if showShortcuts, !recent.isEmpty {
                    Section(L10n.text("Recent", "Recent")) {
                        ForEach(Array(recent.prefix(10))) { ex in
                            exerciseRow(ex)
                        }
                    }
                }

                Section(showShortcuts ? L10n.text("All exercises", "Alle oefeningen") : L10n.exercises) {
                    ForEach(filtered) { ex in
                        exerciseRow(ex)
                    }
                }
            }
            .searchable(text: $search, prompt: L10n.text("Search exercises, aliases or equipment", "Zoek oefeningen, aliassen of apparatuur"))
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(RFTheme.bg)
            .navigationTitle(L10n.exercises)
            .safeAreaInset(edge: .top) {
                HStack(spacing: 10) {
                    Menu {
                        Button(L10n.text("All muscles", "Alle spiergroepen")) { muscle = "All" }
                        ForEach(ExerciseCatalog.muscles, id: \.self) { option in
                            Button(option) { muscle = option }
                        }
                    } label: {
                        Label(muscle == "All" ? L10n.text("Muscles", "Spieren") : muscle,
                              systemImage: "figure.strengthtraining.traditional")
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                    }

                    Spacer()

                    Menu {
                        ForEach(GymEquipmentFilter.options, id: \.self) { option in
                            Button(GymEquipmentFilter.label(option)) { equipment = option }
                        }
                    } label: {
                        Label(GymEquipmentFilter.label(equipment), systemImage: "slider.horizontal.3")
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedIDs.isEmpty
                             ? L10n.text("No exercises selected", "Geen oefeningen geselecteerd")
                             : "\(selectedIDs.count) \(L10n.text("selected", "geselecteerd"))")
                            .font(.caption.bold())
                        Text(L10n.text("Tap an exercise to add or remove it", "Tik op een oefening om deze toe te voegen of te verwijderen"))
                            .font(.caption2)
                            .foregroundStyle(RFTheme.muted)
                    }

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Text(selectedIDs.isEmpty
                             ? L10n.done
                             : "\(L10n.text("Add", "Voeg toe")) \(selectedIDs.count)")
                            .font(.headline)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(RFTheme.accent)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("Close", "Sluiten")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) { dismiss() }.bold()
                }
            }
        }
    }

    @ViewBuilder
    private func exerciseRow(_ ex: ExerciseDefinition) -> some View {
        HStack(spacing: 10) {
            Button {
                if selectedIDs.contains(ex.id) {
                    selectedIDs.removeAll { $0 == ex.id }
                } else {
                    selectedIDs.append(ex.id)
                    ExerciseShortcutStore.recordRecent(ex.id)
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(ex.name)
                            .foregroundStyle(.primary)
                            .font(.headline)
                        Text("\(ex.muscle) • \(ex.equipment)")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }

                    Spacer()

                    Image(systemName: selectedIDs.contains(ex.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedIDs.contains(ex.id) ? RFTheme.accent : RFTheme.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                ExerciseShortcutStore.toggleFavorite(ex.id)
            } label: {
                Image(systemName: ExerciseShortcutStore.isFavorite(ex.id) ? "star.fill" : "star")
                    .foregroundStyle(ExerciseShortcutStore.isFavorite(ex.id) ? .yellow : RFTheme.muted)
                    .frame(width: 28, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.text("Toggle favorite", "Favoriet wisselen"))
        }
    }
}

// MARK: - Active workout

struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var session: WorkoutSession
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var allSessions: [WorkoutSession]

    @State private var showExercisePicker = false
    @State private var pickerIDs: [String] = []
    @State private var showFinishConfirm = false
    @State private var showSummary = false
    @State private var restRemaining = 0
    @State private var restOriginal = 0
    @State private var restCollapsed = false
    @State private var restExerciseName = ""
    @State private var restEndDate: Date?
    @State private var showWorkoutNote = false
    @State private var draggingExerciseID: UUID?
    @State private var hiddenExerciseIDs: Set<UUID> = []
    @State private var focusMode = false
    @ObservedObject private var heartRateMonitor = HeartRateMonitor.shared

    @AppStorage("keepScreenAwake") private var keepScreenAwake = true
    @AppStorage("autoRestTimer") private var autoRestTimer = true
    @AppStorage("defaultRestSeconds") private var defaultRestSeconds = 90
    @AppStorage("compactWorkoutMode") private var compactWorkoutMode = false
    @AppStorage("countdownHaptics") private var countdownHaptics = true

    private let restTicker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var orderedExercises: [ExerciseLog] {
        session.exercises
            .filter { !hiddenExerciseIDs.contains($0.id) }
            .sorted(by: { $0.order < $1.order })
    }

    private var totalEntries: Int {
        session.exercises.reduce(0) { $0 + $1.sets.count }
    }

    private var completedEntries: Int {
        session.exercises.reduce(0) { $0 + $1.sets.filter(\.completed).count }
    }

    private var workoutProgress: Double {
        totalEntries == 0 ? 0 : Double(completedEntries) / Double(totalEntries)
    }

    private var visibleExercises: [ExerciseLog] {
        guard focusMode else { return orderedExercises }
        if let next = orderedExercises.first(where: { !$0.sets.allSatisfy(\.completed) }) {
            return [next]
        }
        return orderedExercises.last.map { [$0] } ?? []
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: compactWorkoutMode ? 10 : 18) {
                    workoutHero

                    if !compactWorkoutMode && completedEntries > 0 {
                        LiveWorkoutHeatmap(session: session)
                    }

                    if showWorkoutNote {
                        TextField(
                            L10n.text("How did the workout feel?", "Hoe voelde de training?"),
                            text: Binding(
                                get: { session.note ?? "" },
                                set: {
                                    session.note = $0
                                    try? context.save()
                                }
                            ),
                            axis: .vertical
                        )
                        .lineLimit(2...5)
                        .padding(14)
                        .background(RFTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(RFTheme.cardBorder)
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    if session.exercises.isEmpty {
                        EmptyCard(
                            icon: "dumbbell",
                            title: L10n.text("No exercises yet", "Nog geen oefeningen"),
                            text: L10n.text(
                                "Add an exercise to begin logging your workout.",
                                "Voeg een oefening toe om je training te registreren."
                            )
                        )
                    }

                    exerciseCards

                    Button {
                        pickerIDs = []
                        showExercisePicker = true
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(RFTheme.accent.opacity(0.16))
                                Image(systemName: "plus")
                                    .font(.headline.bold())
                                    .foregroundStyle(RFTheme.accent)
                            }
                            .frame(width: 34, height: 34)

                            Text(L10n.addExercise)
                                .font(.headline)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(RFTheme.muted)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .background(RFTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(RFTheme.cardBorder)
                    )
                }
                .padding(RFLayout.pagePadding)
                .padding(.bottom, restRemaining > 0 ? 14 : 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(
                LinearGradient(
                    colors: [RFTheme.bg, RFTheme.bg, RFTheme.accent.opacity(0.035)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.headline.bold())
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if restRemaining > 0, let endDate = restEndDate {
                    RestTimerDock(
                        endDate: endDate,
                        exerciseName: restExerciseName,
                        totalSeconds: max(restOriginal, 1),
                        onAdjust: { adjustRest(by: $0) },
                        onReset: { resetRest() },
                        onSkip: { stopRest() }
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 5)
                }
            }
            .onReceive(restTicker) { _ in
                guard let end = restEndDate else { return }
                let remaining = max(0, Int(ceil(end.timeIntervalSinceNow)))
                // Updating @State once per second used to invalidate the entire
                // exercise list. TimelineView now owns the visible countdown.
                if countdownHaptics && (1...3).contains(remaining) {
                    Haptics.light()
                }

                if remaining == 0 {
                    restRemaining = 0
                    restEndDate = nil
                    RestTimerLiveActivityManager.end()
                    Haptics.success()
                }
            }
            .confirmationDialog(
                L10n.text("Finish this workout?", "Deze training afronden?"),
                isPresented: $showFinishConfirm
            ) {
                Button(L10n.text("Finish Workout", "Training afronden")) {
                    finishWorkout()
                }
                Button(L10n.text("Cancel", "Annuleren"), role: .cancel) {}
            } message: {
                Text(L10n.text(
                    "Completed strength sets and cardio intervals will be saved to history.",
                    "Voltooide krachtsets en cardio-intervallen worden in je geschiedenis opgeslagen."
                ))
            }
            .sheet(isPresented: $showExercisePicker, onDismiss: addPickedExercises) {
                ExercisePickerView(selectedIDs: $pickerIDs)
            }
            .sheet(isPresented: $showSummary) {
                WorkoutSummaryView(
                    session: session,
                    sessions: allSessions,
                    onDone: {
                        showSummary = false
                        dismiss()
                    }
                )
                .interactiveDismissDisabled()
            }
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = keepScreenAwake
            }
            .onChange(of: keepScreenAwake) { _, enabled in
                UIApplication.shared.isIdleTimerDisabled = enabled
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }

    @ViewBuilder
    private var exerciseCards: some View {
        ForEach(visibleExercises) { log in
            exerciseCard(log)
        }
    }

    @ViewBuilder
    private func exerciseCard(_ log: ExerciseLog) -> some View {
        WorkoutExerciseBlock(
            log: log,
            sessions: allSessions,
            gymID: GymProfileStore.sessionGymID(session),
            supersetPosition: supersetPosition(for: log),
            onSetCompleted: {
                startRestTimer(for: log)
            },
            onMoveUp: { moveExercise(log, delta: -1) },
            onMoveDown: { moveExercise(log, delta: 1) },
            onDuplicate: { duplicateExercise(log) },
            onRemoveExercise: { removeExercise(log) }
        )
    }

    private func handleExerciseDrop(_ items: [String], targetID: UUID) -> Bool {
        guard let raw = items.first,
              let sourceID = UUID(uuidString: raw) else { return false }
        reorderExercise(sourceID: sourceID, targetID: targetID)
        return true
    }

    private func updateDropTarget(_ id: UUID, targeted: Bool) {
        if targeted {
            draggingExerciseID = id
        } else if draggingExerciseID == id {
            draggingExerciseID = nil
        }
    }

    private var workoutHero: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(RFTheme.accent.opacity(0.14))
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.title2.bold())
                        .foregroundStyle(RFTheme.accent)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title)
                        .font(.title2.bold())
                        .lineLimit(2)

                    Label(
                        GymProfileStore.profile(id: session.gymID).name,
                        systemImage: "mappin.and.ellipse"
                    )
                    .font(.caption)
                    .foregroundStyle(RFTheme.muted)
                }

                Spacer()

                Button(L10n.finish) {
                    showFinishConfirm = true
                }
                .buttonStyle(.borderedProminent)
                .tint(RFTheme.success)
                .font(.subheadline.bold())
            }

            HStack(spacing: 8) {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    WorkoutMetricPill(
                        icon: "clock.fill",
                        text: durationString(session.duration)
                    )
                }

                WorkoutMetricPill(
                    icon: "checkmark.circle.fill",
                    text: "\(completedEntries)/\(totalEntries)"
                )

                if let bpm = heartRateMonitor.bpm {
                    WorkoutMetricPill(
                        icon: "heart.fill",
                        text: "\(bpm) bpm"
                    )
                }

                if session.totalCardioDistanceKm > 0 {
                    WorkoutMetricPill(
                        icon: "figure.run",
                        text: "\(AppPreferences.displayDistance(session.totalCardioDistanceKm).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.distanceLabel)"
                    )
                }

                Spacer()

                Button {
                    withAnimation(.snappy) {
                        focusMode.toggle()
                    }
                } label: {
                    Image(systemName: focusMode ? "scope" : "rectangle.stack.fill")
                        .font(.caption.bold())
                        .padding(8)
                        .background(focusMode ? RFTheme.accent.opacity(0.18) : RFTheme.field.opacity(0.75))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    focusMode
                        ? L10n.text("Show all exercises", "Toon alle oefeningen")
                        : L10n.text("Focus on next exercise", "Focus op volgende oefening")
                )
            }

            VStack(spacing: 7) {
                HStack {
                    Text(L10n.text("Workout progress", "Trainingsvoortgang"))
                        .font(.caption.bold())
                        .foregroundStyle(RFTheme.muted)
                    Spacer()
                    Text("\(Int(workoutProgress * 100))%")
                        .font(.caption.bold())
                        .foregroundStyle(RFTheme.accent)
                }

                ProgressView(value: workoutProgress)
                    .tint(RFTheme.accent)
                    .scaleEffect(x: 1, y: 1.5)
            }

            Button {
                withAnimation(.snappy) {
                    showWorkoutNote.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "note.text")
                    Text(
                        (session.note ?? "").isEmpty
                            ? L10n.text("Add workout note", "Trainingsnotitie toevoegen")
                            : L10n.text("Workout note added", "Trainingsnotitie toegevoegd")
                    )
                        .font(.caption.bold())
                    Spacer()
                    Image(systemName: showWorkoutNote ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .foregroundStyle(RFTheme.muted)
            }
            .buttonStyle(.plain)
        }
        .padding(15)
        .background(RFTheme.surface, in: RoundedRectangle(cornerRadius: 19))
        .overlay(
            RoundedRectangle(cornerRadius: 19).stroke(RFTheme.cardBorder)
        )
    }

    private func finishWorkout() {
        session.endedAt = .now
        stopRest()
        try? context.save()
        Haptics.success()
        showSummary = true
    }

    private func startRestTimer(for log: ExerciseLog) {
        guard autoRestTimer else { return }
        let seconds = log.restSeconds ?? defaultRestSeconds
        guard seconds > 0 else { return }

        let exerciseName = ExerciseCatalog.find(log.exerciseID)?.name ?? session.title
        restRemaining = seconds
        restOriginal = seconds
        restCollapsed = false
        restExerciseName = exerciseName
        let endDate = Date().addingTimeInterval(TimeInterval(seconds))
        restEndDate = endDate
        RestNotificationManager.shared.schedule(seconds: seconds, exerciseName: exerciseName)
        RestTimerLiveActivityManager.startOrUpdate(
            workoutTitle: session.title,
            exerciseName: exerciseName,
            endDate: endDate,
            totalSeconds: seconds
        )
    }

    private func adjustRest(by seconds: Int) {
        let currentEnd = restEndDate ?? Date().addingTimeInterval(TimeInterval(restRemaining))
        let newEnd = currentEnd.addingTimeInterval(TimeInterval(seconds))
        restEndDate = newEnd
        restRemaining = max(0, Int(ceil(newEnd.timeIntervalSinceNow)))
        restOriginal = max(restOriginal, restRemaining)
        RestNotificationManager.shared.schedule(seconds: restRemaining, exerciseName: restExerciseName)
        if restRemaining > 0 {
            RestTimerLiveActivityManager.startOrUpdate(
                workoutTitle: session.title,
                exerciseName: restExerciseName,
                endDate: newEnd,
                totalSeconds: max(restOriginal, restRemaining)
            )
        } else {
            RestTimerLiveActivityManager.end()
        }
        Haptics.light()
    }

    private func resetRest() {
        guard defaultRestSeconds > 0 else { return }
        restOriginal = defaultRestSeconds
        restRemaining = defaultRestSeconds
        let endDate = Date().addingTimeInterval(TimeInterval(defaultRestSeconds))
        restEndDate = endDate
        RestNotificationManager.shared.schedule(seconds: defaultRestSeconds, exerciseName: restExerciseName)
        RestTimerLiveActivityManager.startOrUpdate(
            workoutTitle: session.title,
            exerciseName: restExerciseName,
            endDate: endDate,
            totalSeconds: defaultRestSeconds
        )
        Haptics.light()
    }

    private func stopRest() {
        restRemaining = 0
        restOriginal = 0
        restEndDate = nil
        restExerciseName = ""
        RestNotificationManager.shared.cancel()
        RestTimerLiveActivityManager.end()
        Haptics.light()
    }

    private func addPickedExercises() {
        guard !pickerIDs.isEmpty else { return }
        let existing = Set(session.exercises.map(\.exerciseID))
        var nextOrder = (session.exercises.map(\.order).max() ?? -1) + 1

        for id in pickerIDs where !existing.contains(id) {
            let exercise = ExerciseCatalog.find(id)
            let initialCount = exercise?.movement == "cardio" ? 1 : AppPreferences.defaultSets

            session.exercises.append(
                ExerciseLog(
                    exerciseID: id,
                    order: nextOrder,
                    restSeconds: defaultRestSeconds,
                    sets: (0..<initialCount).map { WorkoutSet(order: $0) }
                )
            )
            nextOrder += 1
        }

        pickerIDs = []
        try? context.save()
    }

    private func supersetPosition(for log: ExerciseLog) -> String? {
        guard let group = log.supersetGroup?.trimmingCharacters(in: .whitespacesAndNewlines),
              !group.isEmpty else { return nil }

        let members = orderedExercises.filter {
            $0.supersetGroup?.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(group) == .orderedSame
        }

        guard members.count > 1,
              let index = members.firstIndex(where: { $0.id == log.id }) else { return nil }

        return "\(group.uppercased())\(index + 1)"
    }

    private func reorderExercise(sourceID: UUID, targetID: UUID) {
        var ordered = orderedExercises
        guard let source = ordered.firstIndex(where: { $0.id == sourceID }),
              let target = ordered.firstIndex(where: { $0.id == targetID }),
              source != target else { return }

        let moved = ordered.remove(at: source)
        ordered.insert(moved, at: target)

        for (index, exercise) in ordered.enumerated() {
            exercise.order = index
        }

        draggingExerciseID = nil
        Haptics.light()
        try? context.save()
    }

    private func moveExercise(_ log: ExerciseLog, delta: Int) {
        var ordered = orderedExercises
        guard let current = ordered.firstIndex(where: { $0.id == log.id }) else { return }
        let destination = current + delta
        guard ordered.indices.contains(destination) else { return }

        ordered.swapAt(current, destination)
        for (index, item) in ordered.enumerated() {
            item.order = index
        }

        Haptics.light()
        try? context.save()
    }

    private func duplicateExercise(_ log: ExerciseLog) {
        let copySets = log.sets.sorted(by: { $0.order < $1.order }).map {
            WorkoutSet(
                order: $0.order,
                weightKg: $0.weightKg,
                reps: $0.reps,
                setTypeRaw: $0.setTypeRaw,
                rpe: $0.rpe,
                rir: $0.rir,
                note: $0.note,
                durationSeconds: $0.durationSeconds,
                distanceKm: $0.distanceKm,
                inclinePercent: $0.inclinePercent,
                calories: $0.calories,
                averageHeartRate: $0.averageHeartRate
            )
        }

        let next = (session.exercises.map(\.order).max() ?? -1) + 1
        session.exercises.append(
            ExerciseLog(
                exerciseID: log.exerciseID,
                order: next,
                targetReps: log.targetReps,
                coachingNote: log.coachingNote,
                supersetGroup: log.supersetGroup,
                sessionNote: log.sessionNote,
                restSeconds: log.restSeconds,
                sets: copySets
            )
        )

        Haptics.light()
        try? context.save()
    }

    private func removeExercise(_ log: ExerciseLog) {
        let logID = log.id
        let exerciseName = ExerciseCatalog.find(log.exerciseID)?.name
        guard !hiddenExerciseIDs.contains(logID) else { return }

        // Cardio rows hold several live Bindings to their WorkoutSet models.
        // Deleting the ExerciseLog in the same interaction can invalidate
        // those bindings. Detach from the workout and save that relationship
        // change only; stale detached logs are cleaned up on a later launch.
        withAnimation(.snappy) {
            hiddenExerciseIDs.insert(logID)
        }

        if restExerciseName == exerciseName {
            stopRest()
        }

        DispatchQueue.main.async {
            guard let index = session.exercises.firstIndex(where: { $0.id == logID }) else {
                hiddenExerciseIDs.remove(logID)
                return
            }

            session.exercises.remove(at: index)

            let remaining = session.exercises.sorted(by: { $0.order < $1.order })
            for (newIndex, exercise) in remaining.enumerated() {
                exercise.order = newIndex
            }

            do {
                try context.save()
                hiddenExerciseIDs.remove(logID)
                Haptics.light()
            } catch {
                if !session.exercises.contains(where: { $0.id == logID }) {
                    session.exercises.append(log)
                    for (newIndex, exercise) in session.exercises
                        .sorted(by: { $0.order < $1.order })
                        .enumerated() {
                        exercise.order = newIndex
                    }
                }
                hiddenExerciseIDs.remove(logID)
            }
        }
    }
}

struct WorkoutMetricPill: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption.bold())
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RFTheme.field.opacity(0.75))
            .clipShape(Capsule())
    }
}

struct RestTimerBanner: View {
    let remaining: Int
    let original: Int
    let exerciseName: String
    let onAdjust: (Int) -> Void
    let onReset: () -> Void
    let onMinimize: () -> Void
    let onSkip: () -> Void

    private var progress: Double {
        min(1, max(0, Double(remaining) / Double(max(original, 1))))
    }

    var body: some View {
        VStack(spacing: 11) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(RFTheme.field, lineWidth: 6)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            RFTheme.accent,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    Text(durationString(TimeInterval(remaining)))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.text("Rest", "Rust"))
                        .font(.headline.bold())

                    Text(exerciseName)
                        .font(.caption)
                        .foregroundStyle(RFTheme.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button(action: onMinimize) {
                    Image(systemName: "chevron.down")
                        .font(.subheadline.bold())
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.plain)
                .background(RFTheme.field)
                .clipShape(Circle())
                .accessibilityLabel(L10n.text("Minimize timer", "Timer minimaliseren"))

                Button(action: onSkip) {
                    Image(systemName: "forward.end.fill")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(RFTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 13))
                .accessibilityLabel(L10n.text("Skip rest", "Rust overslaan"))
            }

            HStack(spacing: 8) {
                RestAdjustmentButton(
                    title: "−15",
                    systemImage: "minus",
                    action: { onAdjust(-15) }
                )

                Button(action: onReset) {
                    Label(
                        L10n.text("Reset", "Reset"),
                        systemImage: "arrow.counterclockwise"
                    )
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .foregroundStyle(RFTheme.muted)
                .background(RFTheme.field)
                .clipShape(RoundedRectangle(cornerRadius: 11))

                RestAdjustmentButton(
                    title: "+15",
                    systemImage: "plus",
                    action: { onAdjust(15) }
                )
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(RFTheme.cardBorder)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 12, y: 5)
    }
}

struct RestAdjustmentButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .foregroundStyle(RFTheme.accent)
        .background(RFTheme.accent.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }
}

struct RestTimerCompactChip: View {
    let remaining: Int
    let onExpand: () -> Void
    let onSubtract15: () -> Void
    let onAdd15: () -> Void
    let onSkip: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onExpand) {
                HStack(spacing: 8) {
                    Image(systemName: "timer")
                    Text(durationString(TimeInterval(remaining)))
                        .font(.headline.monospacedDigit())
                    Image(systemName: "chevron.up")
                        .font(.caption.bold())
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(RFTheme.accent)
            .clipShape(Capsule())

            Button("−15", action: onSubtract15)
                .font(.caption.bold())
                .buttonStyle(.bordered)

            Button("+15", action: onAdd15)
                .font(.caption.bold())
                .buttonStyle(.bordered)

            Spacer(minLength: 0)

            Button(action: onSkip) {
                Image(systemName: "forward.end.fill")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(L10n.text("Skip rest", "Rust overslaan"))
        }
        .padding(7)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(RFTheme.cardBorder)
        )
        .shadow(color: Color.black.opacity(0.14), radius: 9, y: 3)
    }
}

struct WorkoutExerciseBlock: View {
    @Environment(\.modelContext) private var context
    @Bindable var log: ExerciseLog
    let sessions: [WorkoutSession]
    let gymID: String
    let supersetPosition: String?
    let onSetCompleted: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDuplicate: () -> Void
    let onRemoveExercise: () -> Void

    @State private var showRemoveExerciseConfirm = false
    @State private var showOptions = false
    @State private var isCollapsed = false
    @AppStorage("autoCollapseCompleted") private var autoCollapseCompleted = true
    @AppStorage("compactWorkoutMode") private var compactWorkoutMode = false

    private var exercise: ExerciseDefinition? { ExerciseCatalog.find(log.exerciseID) }
    private var isCardio: Bool { exercise?.movement == "cardio" }
    private var orderedSets: [WorkoutSet] { log.sets.sorted(by: { $0.order < $1.order }) }
    private var completedCount: Int { log.sets.filter(\.completed).count }
    private var allCompleted: Bool { !log.sets.isEmpty && completedCount == log.sets.count }

    @State private var priorLog: ExerciseLog?
    @State private var priorSets: [(Double, Int)] = []
    @State private var priorBest: Double = 0
    @State private var historyLoaded = false

    private var previousLog: ExerciseLog? { priorLog }
    private var previous: [(Double, Int)] { priorSets }
    private var best: Double { priorBest }

    // History snapshots are loaded once per exercise instead of scanning the
    // entire workout database on every keystroke or view invalidation.
    private func refreshHistorySnapshot() {
        let past = Metrics.scopedSessions(sessions, gymID: gymID)
        priorLog = past
            .filter { session in session.exercises.contains(where: { $0.exerciseID == log.exerciseID }) }
            .max(by: { ($0.endedAt ?? $0.startedAt) < ($1.endedAt ?? $1.startedAt) })?
            .exercises.first(where: { $0.exerciseID == log.exerciseID })
        priorSets = priorLog?.sets
            .filter(\.countsForPR)
            .sorted(by: { $0.order < $1.order })
            .map { ($0.weightKg, $0.reps) } ?? []
        priorBest = Metrics.personalBest(
            exerciseID: log.exerciseID, sessions: sessions,
            gymID: gymID, startDate: AppPreferences.prStartDate
        )
        historyLoaded = true
    }

    private var canCopyPrevious: Bool {
        isCardio ? !(previousLog?.sets.isEmpty ?? true) : !previous.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            exerciseHeader

            if isCollapsed {
                collapsedSummary
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    if let note = log.coachingNote, !note.isEmpty {
                        Label(note, systemImage: "quote.bubble")
                            .font(.caption)
                            .foregroundStyle(RFTheme.muted)
                            .padding(.horizontal, 4)
                    }

                    if let sessionNote = log.sessionNote, !sessionNote.isEmpty {
                        Label(sessionNote, systemImage: "note.text")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }

                    if isCardio {
                        cardioContent
                    } else {
                        strengthContent
                    }

                    Button {
                        addSet()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text(isCardio
                                 ? L10n.text("Add Interval", "Interval toevoegen")
                                 : L10n.text("Add Set", "Set toevoegen"))
                                .font(.subheadline.bold())
                            Spacer()
                        }
                        .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(RFTheme.accent)
                }
                .padding(.horizontal, compactWorkoutMode ? 10 : 16)
                .padding(.bottom, compactWorkoutMode ? 10 : 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(RFTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 19))
        .overlay(
            RoundedRectangle(cornerRadius: 19)
                .stroke(
                    supersetPosition != nil
                        ? RFTheme.accent.opacity(0.55)
                        : (allCompleted ? RFTheme.success.opacity(0.32) : RFTheme.cardBorder),
                    lineWidth: supersetPosition != nil ? 1.5 : 1
                )
        )
        .overlay(alignment: .leading) {
            if supersetPosition != nil {
                Capsule()
                    .fill(RFTheme.accent)
                    .frame(width: 4)
                    .padding(.vertical, 14)
            }
        }
        .shadow(color: Color.black.opacity(0.035), radius: 5, y: 2)
        .sheet(isPresented: $showOptions) {
            ExerciseLogOptionsView(log: log)
        }
        .confirmationDialog(
            L10n.text("Remove \(exercise?.name ?? "exercise")?", "\(exercise?.name ?? "oefening") verwijderen?"),
            isPresented: $showRemoveExerciseConfirm,
            titleVisibility: .visible
        ) {
            Button(L10n.text("Remove Exercise", "Oefening verwijderen"), role: .destructive) {
                onRemoveExercise()
            }
            Button(L10n.text("Cancel", "Annuleren"), role: .cancel) {}
        } message: {
            Text(L10n.text(
                "This removes the exercise and all of its entries from the current workout.",
                "Dit verwijdert de oefening en alle invoer uit de huidige training."
            ))
        }
        .onAppear {
            if !historyLoaded { refreshHistorySnapshot() }
            if autoCollapseCompleted && allCompleted { isCollapsed = true }
        }
        .onChange(of: log.exerciseID) { _, _ in
            refreshHistorySnapshot()
        }
        .onChange(of: completedCount) { _, _ in
            if autoCollapseCompleted && allCompleted {
                withAnimation(.snappy) {
                    isCollapsed = true
                }
            }
        }
    }

    private var exerciseHeader: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.snappy) {
                    isCollapsed.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(RFTheme.accent.opacity(0.12))
                        Image(systemName: exerciseIcon)
                            .font(.title3.bold())
                            .foregroundStyle(RFTheme.accent)
                    }
                    .frame(width: 46, height: 46)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 7) {
                            Text(exercise?.name ?? "Exercise")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)

                            if let supersetPosition {
                                Text(supersetPosition)
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 4)
                                    .background(RFTheme.accent)
                                    .clipShape(Capsule())
                            }
                        }

                        HStack(spacing: 7) {
                            Text("\(completedCount)/\(log.sets.count) \(isCardio ? L10n.text("intervals", "intervallen") : L10n.text("sets", "sets"))")
                                .foregroundStyle(allCompleted ? RFTheme.success : RFTheme.muted)

                            if isCardio {
                                if let summary = cardioSummary, !summary.isEmpty {
                                    Text("• \(summary)")
                                        .foregroundStyle(RFTheme.muted)
                                }
                            } else if best > 0 {
                                Text("• \(L10n.text("Best", "Beste")) \(AppPreferences.displayWeight(best).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.weightLabel)")
                                    .foregroundStyle(RFTheme.muted)
                            }
                        }
                        .font(.caption)
                        .lineLimit(1)
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .stroke(RFTheme.field, lineWidth: 4)
                        Circle()
                            .trim(
                                from: 0,
                                to: log.sets.isEmpty ? 0 : Double(completedCount) / Double(log.sets.count)
                            )
                            .stroke(
                                allCompleted ? RFTheme.success : RFTheme.accent,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))

                        if allCompleted {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(RFTheme.success)
                        } else {
                            Text("\(completedCount)")
                                .font(.caption2.bold())
                                .foregroundStyle(RFTheme.muted)
                        }
                    }
                    .frame(width: 34, height: 34)

                    Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                        .font(.caption.bold())
                        .foregroundStyle(RFTheme.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                if let ex = exercise {
                    NavigationLink {
                        ExerciseDetailView(exercise: ex)
                    } label: {
                        Label(L10n.text("Exercise Guide", "Oefening uitleg"), systemImage: "info.circle")
                    }
                }

                Button {
                    copyPreviousEntries()
                } label: {
                    Label(
                        isCardio
                            ? L10n.text("Copy Previous Cardio", "Vorige cardio kopiëren")
                            : L10n.text("Copy Previous Sets", "Vorige sets kopiëren"),
                        systemImage: "doc.on.doc"
                    )
                }
                .disabled(!canCopyPrevious)

                Button {
                    withAnimation(.snappy) {
                        isCollapsed.toggle()
                    }
                } label: {
                    Label(
                        isCollapsed
                            ? L10n.text("Expand", "Uitklappen")
                            : L10n.text("Collapse", "Inklappen"),
                        systemImage: isCollapsed ? "chevron.down" : "chevron.up"
                    )
                }

                Button(action: onMoveUp) {
                    Label(L10n.text("Move Up", "Omhoog"), systemImage: "arrow.up")
                }

                Button(action: onMoveDown) {
                    Label(L10n.text("Move Down", "Omlaag"), systemImage: "arrow.down")
                }

                Button(action: onDuplicate) {
                    Label(L10n.text("Duplicate Exercise", "Oefening dupliceren"), systemImage: "plus.square.on.square")
                }

                Button {
                    showOptions = true
                } label: {
                    Label(L10n.text("Exercise Options", "Oefening opties"), systemImage: "slider.horizontal.3")
                }

                Divider()

                Button(role: .destructive) {
                    showRemoveExerciseConfirm = true
                } label: {
                    Label(L10n.text("Remove Exercise", "Oefening verwijderen"), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline)
                    .foregroundStyle(RFTheme.muted)
                    .frame(width: 36, height: 36)
                    .background(RFTheme.field)
                    .clipShape(Circle())
            }
        }
        .padding(compactWorkoutMode ? 10 : 14)
    }

    private var strengthContent: some View {
        VStack(spacing: 10) {
            ForEach(orderedSets) { set in
                WorkoutSetRow(
                    set: set,
                    previous: previous.indices.contains(set.order) ? previous[set.order] : nil,
                    canDelete: log.sets.count > 1,
                    onCompleted: { completed in
                        if completed { onSetCompleted() }
                    },
                    onDelete: { removeSet(set) }
                )
            }
        }
    }

    private var cardioContent: some View {
        VStack(spacing: 10) {
            HStack {
                Label(
                    L10n.text(
                        "Cardio uses time, distance and intensity — not kg/reps.",
                        "Cardio gebruikt tijd, afstand en intensiteit — geen kg/reps."
                    ),
                    systemImage: "waveform.path.ecg"
                )
                .font(.caption)
                .foregroundStyle(RFTheme.muted)
                Spacer()
            }
            .padding(.horizontal, 2)

            ForEach(orderedSets) { set in
                CardioIntervalRow(
                    set: set,
                    canDelete: log.sets.count > 1,
                    onCompleted: { completed in
                        if completed { onSetCompleted() }
                    },
                    onDelete: {
                        removeSet(set)
                    }
                )
            }
        }
    }

    private var collapsedSummary: some View {
        HStack(spacing: 10) {
            Image(systemName: allCompleted ? "checkmark.seal.fill" : "rectangle.compress.vertical")
                .foregroundStyle(allCompleted ? RFTheme.success : RFTheme.accent)

            Text(
                isCardio
                    ? (cardioSummary ?? L10n.text("Cardio ready to log", "Cardio klaar om te loggen"))
                    : strengthCollapsedSummary
            )
            .font(.caption.bold())
            .foregroundStyle(RFTheme.muted)
            .lineLimit(1)

            Spacer()

            Text(allCompleted ? L10n.text("Complete", "Voltooid") : "\(completedCount)/\(log.sets.count)")
                .font(.caption.bold())
                .foregroundStyle(allCompleted ? RFTheme.success : RFTheme.accent)
        }
        .padding(11)
        .background(RFTheme.field.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var strengthCollapsedSummary: String {
        guard let last = orderedSets.last(where: { $0.completed }) else {
            return L10n.text("Tap to expand sets", "Tik om sets uit te klappen")
        }

        return "\(AppPreferences.displayWeight(last.weightKg).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.weightLabel) × \(last.reps)"
    }

    private var cardioSummary: String? {
        let completed = orderedSets.filter(\.completed)
        let source = completed.isEmpty ? orderedSets : completed
        let totalSeconds = source.reduce(0.0) { $0 + ($1.durationSeconds ?? 0) }
        let distanceKm = source.reduce(0.0) { $0 + ($1.distanceKm ?? 0) }

        var parts: [String] = []
        if totalSeconds > 0 {
            parts.append(cardioDurationText(totalSeconds))
        }
        if distanceKm > 0 {
            parts.append(
                "\(AppPreferences.displayDistance(distanceKm).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.distanceLabel)"
            )
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private var exerciseIcon: String {
        guard let exercise else { return "dumbbell.fill" }
        switch exercise.movement {
        case "cardio": return "figure.run"
        case "press": return "arrow.up.forward.circle.fill"
        case "pull": return "arrow.down.backward.circle.fill"
        case "squat": return "figure.strengthtraining.traditional"
        case "hinge": return "figure.flexibility"
        case "core": return "figure.core.training"
        case "curl": return "dumbbell.fill"
        default: return "dumbbell.fill"
        }
    }

    private func copyPreviousEntries() {
        if isCardio {
            guard let previousLog else { return }
            let previousSets = previousLog.sets.sorted(by: { $0.order < $1.order })

            while log.sets.count < previousSets.count {
                log.sets.append(WorkoutSet(order: log.sets.count))
            }

            for (index, old) in previousSets.enumerated() {
                guard log.sets.indices.contains(index) else { continue }
                let set = log.sets[index]
                set.durationSeconds = old.durationSeconds
                set.distanceKm = old.distanceKm
                set.inclinePercent = old.inclinePercent
                set.calories = old.calories
                set.averageHeartRate = old.averageHeartRate
                set.rpe = old.rpe
                set.completed = false
                set.completedAt = nil
            }
        } else {
            guard !previous.isEmpty else { return }

            while log.sets.count < previous.count {
                log.sets.append(WorkoutSet(order: log.sets.count))
            }

            for (index, values) in previous.enumerated() {
                guard log.sets.indices.contains(index) else { continue }
                log.sets[index].weightKg = values.0
                log.sets[index].reps = values.1
                log.sets[index].completed = false
                log.sets[index].completedAt = nil
            }
        }

        Haptics.light()
        try? context.save()
    }

    private func addSet() {
        Haptics.light()
        let next = (log.sets.map(\.order).max() ?? -1) + 1
        log.sets.append(WorkoutSet(order: next))
        try? context.save()
    }

    private func removeSet(_ set: WorkoutSet) {
        guard log.sets.count > 1 else { return }
        log.sets.removeAll { $0.id == set.id }
        context.delete(set)
        renumberSets()
        try? context.save()
    }

    private func renumberSets() {
        for (index, set) in log.sets.sorted(by: { $0.order < $1.order }).enumerated() {
            set.order = index
        }
    }
}

private func cardioDurationText(_ seconds: Double) -> String {
    let total = max(0, Int(seconds.rounded()))
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let secs = total % 60

    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, secs)
    }
    return String(format: "%d:%02d", minutes, secs)
}

struct CardioIntervalRow: View {
    @Environment(\.modelContext) private var context
    @ObservedObject private var heartRateMonitor = HeartRateMonitor.shared
    @Bindable var set: WorkoutSet
    let canDelete: Bool
    let onCompleted: (Bool) -> Void
    let onDelete: () -> Void

    var body: some View {
        SwipeDeleteContainer(canDelete: canDelete, onDelete: onDelete) {
            VStack(spacing: 10) {
                HStack {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(set.completed ? RFTheme.success.opacity(0.16) : RFTheme.accent.opacity(0.12))
                            Text("\(set.order + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(set.completed ? RFTheme.success : RFTheme.accent)
                        }
                        .frame(width: 30, height: 30)

                        Text(L10n.text("Interval", "Interval"))
                            .font(.subheadline.bold())
                    }

                    Spacer()

                    if let pace = paceText {
                        Label(pace, systemImage: "speedometer")
                            .font(.caption.bold())
                            .foregroundStyle(RFTheme.muted)
                    }

                    if let bpm = heartRateMonitor.bpm {
                        Button {
                            set.averageHeartRate = bpm
                            try? context.save()
                            Haptics.light()
                        } label: {
                            Label("\(bpm)", systemImage: "heart.fill")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .accessibilityLabel(L10n.text("Use current heart rate", "Gebruik huidige hartslag"))
                    }

                    Button {
                        set.completed.toggle()
                        set.completedAt = set.completed ? .now : nil
                        if set.completed { Haptics.success() } else { Haptics.light() }
                        try? context.save()
                        onCompleted(set.completed)
                    } label: {
                        Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(set.completed ? RFTheme.success : RFTheme.muted)
                    }
                }

                HStack(spacing: 8) {
                    CardioMetricInput(
                        title: L10n.text("TIME", "TIJD"),
                        unit: "min",
                        icon: "clock",
                        value: Binding(
                            get: { (set.durationSeconds ?? 0) / 60.0 },
                            set: { set.durationSeconds = $0 > 0 ? $0 * 60.0 : nil }
                        )
                    )

                    CardioMetricInput(
                        title: L10n.text("DISTANCE", "AFSTAND"),
                        unit: AppPreferences.distanceLabel,
                        icon: "point.topleft.down.to.point.bottomright.curvepath",
                        value: Binding(
                            get: { AppPreferences.displayDistance(set.distanceKm ?? 0) },
                            set: {
                                let km = AppPreferences.storedDistanceKm($0)
                                set.distanceKm = km > 0 ? km : nil
                            }
                        )
                    )

                    CardioMetricInput(
                        title: L10n.text("INCLINE", "HELLING"),
                        unit: "%",
                        icon: "mountain.2",
                        value: Binding(
                            get: { set.inclinePercent ?? 0 },
                            set: { set.inclinePercent = $0 > 0 ? $0 : nil }
                        )
                    )
                }

                HStack(spacing: 8) {
                    CardioMetricInput(
                        title: L10n.text("CALORIES", "CALORIEËN"),
                        unit: "kcal",
                        icon: "flame.fill",
                        integerOnly: true,
                        value: Binding(
                            get: { set.calories ?? 0 },
                            set: { set.calories = $0 > 0 ? $0 : nil }
                        )
                    )

                    CardioMetricInput(
                        title: L10n.text("AVG HR", "GEM. HF"),
                        unit: "bpm",
                        icon: "heart.fill",
                        integerOnly: true,
                        value: Binding(
                            get: { Double(set.averageHeartRate ?? 0) },
                            set: {
                                let bpm = Int($0.rounded())
                                set.averageHeartRate = bpm > 0 ? bpm : nil
                            }
                        )
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Label(L10n.text("SPEED", "SNELHEID"), systemImage: "gauge.with.dots.needle.50percent")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(RFTheme.muted)
                            .lineLimit(1)

                        Text(speedText)
                            .font(.subheadline.bold())
                            .lineLimit(1)

                        Text(AppPreferences.speedLabel)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(RFTheme.muted)
                    }
                    .padding(9)
                    .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
                    .background(RFTheme.field)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                }
            }
            .padding(11)
            .background(set.completed ? RFTheme.success.opacity(0.055) : RFTheme.raised.opacity(0.52))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(set.completed ? RFTheme.success.opacity(0.26) : RFTheme.cardBorder)
            )
        }
    }

    private var speedText: String {
        guard let duration = set.durationSeconds,
              let distance = set.distanceKm,
              duration > 0,
              distance > 0 else { return "—" }

        let displayedDistance = AppPreferences.displayDistance(distance)
        let hours = duration / 3600.0
        return (displayedDistance / hours)
            .formatted(.number.precision(.fractionLength(0...1)))
    }

    private var paceText: String? {
        guard let duration = set.durationSeconds,
              let distance = set.distanceKm,
              duration > 0,
              distance > 0 else { return nil }

        let displayedDistance = AppPreferences.displayDistance(distance)
        guard displayedDistance > 0 else { return nil }

        let secondsPerUnit = duration / displayedDistance
        let minutes = Int(secondsPerUnit) / 60
        let seconds = Int(secondsPerUnit) % 60
        return "\(minutes):\(String(format: "%02d", seconds))/\(AppPreferences.distanceLabel)"
    }
}

struct CardioMetricInput: View {
    let title: String
    let unit: String
    let icon: String
    var integerOnly: Bool = false
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(RFTheme.muted)
                .lineLimit(1)

            DoneNumberField(
                value: $value,
                integerOnly: integerOnly,
                placeholder: "0"
            )
            .font(.subheadline.bold())
            .frame(height: 24)

            Text(unit)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(RFTheme.muted)
        }
        .padding(9)
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
        .background(RFTheme.field)
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }
}

struct SwipeDeleteContainer<Content: View>: View {
    let canDelete: Bool
    let onDelete: () -> Void
    let content: Content

    init(
        canDelete: Bool,
        onDelete: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.canDelete = canDelete
        self.onDelete = onDelete
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if canDelete {
                Menu {
                    Button(role: .destructive) {
                        Haptics.light()
                        onDelete()
                    } label: {
                        Label(L10n.text("Delete interval", "Interval verwijderen"), systemImage: "trash")
                    }
                } label: {
                    Label(L10n.text("More actions", "Meer acties"), systemImage: "ellipsis")
                        .font(.caption)
                        .foregroundStyle(RFTheme.muted)
                        .frame(minHeight: 36)
                }
            }
            content
        }
        .frame(maxWidth: .infinity)
    }
}

struct ExerciseLogOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var log: ExerciseLog

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.text("Rest timer", "Rusttimer")) {
                    Stepper(
                        "\(L10n.text("Rest", "Rust")): \(log.restSeconds ?? AppPreferences.defaultRestSeconds)s",
                        value: Binding(
                            get: { log.restSeconds ?? AppPreferences.defaultRestSeconds },
                            set: { log.restSeconds = $0 }
                        ),
                        in: 15...600,
                        step: 15
                    )

                    Button(L10n.text("Use app default", "Gebruik app-standaard")) {
                        log.restSeconds = nil
                    }
                }

                Section(L10n.text("Workout note", "Trainingsnotitie")) {
                    TextField(
                        L10n.text("Note for this exercise", "Notitie voor deze oefening"),
                        text: Binding(
                            get: { log.sessionNote ?? "" },
                            set: { log.sessionNote = $0 }
                        ),
                        axis: .vertical
                    )
                    .lineLimit(2...5)
                }
            }
            .navigationTitle(L10n.text("Exercise Options", "Oefening opties"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) {
                        try? context.save()
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}


struct WorkoutSetRow: View {
    @Environment(\.modelContext) private var context
    @Bindable var set: WorkoutSet
    let previous: (Double, Int)?
    let canDelete: Bool
    let onCompleted: (Bool) -> Void
    let onDelete: () -> Void
    @State private var showSetOptions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            entryRow
            previousValues
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            set.completed ? RFTheme.success.opacity(0.075) : RFTheme.raised.opacity(0.65),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(set.completed ? RFTheme.success.opacity(0.25) : RFTheme.cardBorder)
        )
        .sheet(isPresented: $showSetOptions) {
            SetOptionsView(set: set)
        }
    }

    private var entryRow: some View {
        HStack(spacing: 7) {
            Button {
                showSetOptions = true
            } label: {
                VStack(spacing: 2) {
                    Text("\(set.order + 1)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.primary)
                    if set.setType != "working" {
                        Text("•")
                            .font(.system(size: 7, weight: .black))
                            .foregroundStyle(RFTheme.accent)
                    }
                }
                .frame(width: 34, height: 49)
                .background(RFTheme.field, in: RoundedRectangle(cornerRadius: 11))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.text("Set", "Set") + " \(set.order + 1)")

            inputs
            completeButton
            moreActions
        }
    }

    private var moreActions: some View {
        Menu {
            Button {
                showSetOptions = true
            } label: {
                Label(L10n.text("Set options", "Setopties"), systemImage: "slider.horizontal.3")
            }
            if canDelete {
                Button(role: .destructive, action: onDelete) {
                    Label(L10n.text("Delete set", "Set verwijderen"), systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.headline)
                .foregroundStyle(RFTheme.muted)
                .frame(width: 29, height: 49)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(L10n.text("More set actions", "Meer setacties"))
    }

    private var completeButton: some View {
        Button(action: toggleCompleted) {
            Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(set.completed ? RFTheme.success : RFTheme.accent)
                .frame(width: 44, height: 49)
                .background(
                    set.completed ? RFTheme.success.opacity(0.12) : RFTheme.accent.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 11)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(set.completed
            ? L10n.text("Unmark completed set", "Voltooide set terugdraaien")
            : L10n.text("Complete set", "Set voltooien"))
    }

    private var inputs: some View {
        HStack(spacing: 7) {
            entryField(
                title: AppPreferences.weightLabel.uppercased(),
                value: Binding(
                    get: { AppPreferences.displayWeight(set.weightKg) },
                    set: { set.weightKg = AppPreferences.storedWeightKg($0) }
                ),
                integerOnly: false
            )
            entryField(
                title: L10n.text("REPS", "REPS"),
                value: Binding(
                    get: { Double(set.reps) },
                    set: { set.reps = max(0, Int($0.rounded())) }
                ),
                integerOnly: true
            )
        }
    }

    @ViewBuilder
    private var previousValues: some View {
        if AppPreferences.showPreviousSets, let previous {
            HStack(spacing: 6) {
                Label(
                    previousLabel(weight: previous.0, reps: previous.1),
                    systemImage: "clock.arrow.circlepath"
                )
                .font(.caption2)
                .foregroundStyle(RFTheme.muted)

                Spacer(minLength: 0)

                if !set.completed {
                    Button {
                        set.weightKg = previous.0
                        set.reps = previous.1
                        try? context.save()
                        Haptics.light()
                    } label: {
                        Label(L10n.text("Reuse", "Herhaal"), systemImage: "arrow.down.to.line")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(RFTheme.accent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.text(
                        "Copy previous weight and repetitions",
                        "Vorig gewicht en herhalingen kopiëren"
                    ))
                }
            }
        }
    }

    private func previousLabel(weight: Double, reps: Int) -> String {
        let display = AppPreferences.displayWeight(weight)
            .formatted(.number.precision(.fractionLength(0...2)))
        return L10n.text("Previous", "Vorig") + ": " +
            display + " " + AppPreferences.weightLabel + " × \(reps)"
    }

    private func toggleCompleted() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
        set.completed.toggle()
        set.completedAt = set.completed ? .now : nil
        if set.completed { Haptics.success() } else { Haptics.light() }
        try? context.save()
        onCompleted(set.completed)
    }

    private func entryField(
        title: String, value: Binding<Double>, integerOnly: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .tracking(0.7)
                .foregroundStyle(RFTheme.muted)
            DoneNumberField(value: value, integerOnly: integerOnly, placeholder: "0")
                .frame(height: 31)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 49)
        .background(RFTheme.field, in: RoundedRectangle(cornerRadius: 11))
    }
}

struct SetOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var set: WorkoutSet

    @State private var useRPE: Bool
    @State private var useRIR: Bool

    init(set: WorkoutSet) {
        self.set = set
        _useRPE = State(initialValue: set.rpe != nil)
        _useRIR = State(initialValue: set.rir != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.text("Set type", "Settype")) {
                    Picker(
                        L10n.text("Type", "Type"),
                        selection: Binding(
                            get: { set.setType },
                            set: { set.setType = $0 }
                        )
                    ) {
                        Text(L10n.text("Working", "Werkset")).tag("working")
                        Text(L10n.text("Warm-up", "Warming-up")).tag("warmup")
                        Text(L10n.text("Drop set", "Dropset")).tag("drop")
                        Text(L10n.text("To failure", "Tot falen")).tag("failure")
                    }
                    .pickerStyle(.segmented)

                    if set.setType == "warmup" {
                        Text(L10n.text(
                            "Warm-up sets are excluded from personal-record calculations.",
                            "Warming-upsets tellen niet mee voor persoonlijke records."
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Section("RPE / RIR") {
                    Toggle("RPE", isOn: $useRPE)
                        .onChange(of: useRPE) { _, enabled in
                            set.rpe = enabled ? (set.rpe ?? 8) : nil
                        }

                    if useRPE {
                        Stepper(
                            "RPE \(set.rpe?.formatted(.number.precision(.fractionLength(0...1))) ?? "8")",
                            value: Binding(
                                get: { set.rpe ?? 8 },
                                set: { set.rpe = $0 }
                            ),
                            in: 5...10,
                            step: 0.5
                        )
                    }

                    Toggle("RIR", isOn: $useRIR)
                        .onChange(of: useRIR) { _, enabled in
                            set.rir = enabled ? (set.rir ?? 2) : nil
                        }

                    if useRIR {
                        Stepper(
                            "RIR \(set.rir ?? 2)",
                            value: Binding(
                                get: { set.rir ?? 2 },
                                set: { set.rir = $0 }
                            ),
                            in: 0...6
                        )
                    }
                }

                Section(L10n.text("Set note", "Setnotitie")) {
                    TextField(
                        L10n.text("Optional note", "Optionele notitie"),
                        text: Binding(
                            get: { set.note ?? "" },
                            set: { set.note = $0 }
                        ),
                        axis: .vertical
                    )
                    .lineLimit(2...5)
                }
            }
            .navigationTitle(L10n.text("Set \(set.order + 1)", "Set \(set.order + 1)"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) {
                        try? context.save()
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}

struct DoneNumberField: UIViewRepresentable {
    @Binding var value: Double
    let integerOnly: Bool
    let placeholder: String

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.keyboardType = integerOnly ? .numberPad : .decimalPad
        field.textAlignment = .center
        field.textColor = .label
        field.tintColor = UIColor(RFTheme.accent)
        field.placeholder = placeholder
        field.adjustsFontSizeToFitWidth = true
        field.minimumFontSize = 13
        field.font = .systemFont(ofSize: 18, weight: .semibold)
        // Keep partial numeric edits in UIKit until editing ends; SwiftData writes
        // on every keypress used to invalidate the entire active workout.

        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.items = [
            UIBarButtonItem(systemItem: .flexibleSpace),
            UIBarButtonItem(
                title: L10n.done,
                style: .done,
                target: context.coordinator,
                action: #selector(Coordinator.doneTapped)
            )
        ]
        field.inputAccessoryView = toolbar
        context.coordinator.field = field
        field.text = formatted(value)
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.parent = self
        guard !uiView.isFirstResponder else { return }
        let expected = formatted(value)
        if uiView.text != expected {
            uiView.text = expected
        }

        if let toolbar = uiView.inputAccessoryView as? UIToolbar,
           let done = toolbar.items?.last {
            done.title = L10n.done
        }
    }

    private func formatted(_ value: Double) -> String {
        guard value != 0 else { return "" }
        if integerOnly { return String(Int(value.rounded())) }
        return value.formatted(.number.precision(.fractionLength(0...2)))
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: DoneNumberField
        weak var field: UITextField?

        init(parent: DoneNumberField) {
            self.parent = parent
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            let raw = (textField.text ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ",", with: ".")
            if raw.isEmpty {
                parent.value = 0
            } else if parent.integerOnly {
                if let parsed = Int(raw), parsed >= 0 {
                    parent.value = Double(parsed)
                }
            } else if let parsed = Double(raw), parsed.isFinite, parsed >= 0 {
                parent.value = parsed
            }
        }

        @objc func doneTapped() {
            field?.resignFirstResponder()
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}


struct WorkoutSummaryView: View {
    let session: WorkoutSession
    let sessions: [WorkoutSession]
    let onDone: () -> Void

    private var completedSets: [WorkoutSet] {
        session.exercises.flatMap(\.sets).filter(\.completed)
    }

    private var prs: [(String, Double, Double)] {
        let previousSessions = sessions.filter { $0.id != session.id && $0.endedAt != nil }

        return session.exercises.compactMap { log in
            let current = log.sets.filter(\.countsForPR).map(\.weightKg).max() ?? 0
            guard current > 0 else { return nil }
            let previous = Metrics.personalBest(
                exerciseID: log.exerciseID,
                sessions: previousSessions,
                gymID: GymProfileStore.sessionGymID(session),
                startDate: AppPreferences.prStartDate
            )
            guard current > previous else { return nil }
            let name = ExerciseCatalog.find(log.exerciseID)?.name ?? "Exercise"
            return (name, current, previous)
        }
    }

    private var progressionSuggestions: [(name: String, current: Double, next: Double, reason: String)] {
        guard AppPreferences.progressionRule != "off" else { return [] }

        return session.exercises.compactMap { log in
            guard ExerciseCatalog.find(log.exerciseID)?.movement != "cardio" else { return nil }

            let workingSets = log.sets.filter { $0.countsForPR && $0.setType == "working" }
            guard !workingSets.isEmpty,
                  let current = workingSets.map(\.weightKg).max(),
                  current > 0 else { return nil }

            let name = ExerciseCatalog.find(log.exerciseID)?.name ?? "Exercise"
            let next = current + AppPreferences.progressionStepKg

            if AppPreferences.progressionRule == "fixed" {
                guard workingSets.allSatisfy({ $0.reps > 0 }) else { return nil }
                let completedText = workingSets
                    .map { "\($0.reps)" }
                    .joined(separator: "/")
                let reason = L10n.text(
                    "Fixed increment: completed working-set reps \(completedText) at \(AppPreferences.displayWeight(current).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.weightLabel).",
                    "Vaste verhoging: werkset-herhalingen \(completedText) voltooid op \(AppPreferences.displayWeight(current).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.weightLabel)."
                )
                return (name, current, next, reason)
            }

            guard let target = log.targetReps,
                  let upper = highestRepTarget(target),
                  workingSets.allSatisfy({ $0.reps >= upper }) else { return nil }

            let repsText = workingSets
                .map { "\($0.reps)" }
                .joined(separator: "/")
            let reason = L10n.text(
                "Target was \(target). You reached the top of the range on every working set (\(repsText)) at \(AppPreferences.displayWeight(current).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.weightLabel).",
                "Doel was \(target). Je haalde de bovenkant van de range op elke werkset (\(repsText)) met \(AppPreferences.displayWeight(current).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.weightLabel)."
            )
            return (name, current, next, reason)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(spacing: 8) {
                        Image(systemName: prs.isEmpty ? "checkmark.circle.fill" : "trophy.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(prs.isEmpty ? RFTheme.success : RFTheme.accent)
                        Text(L10n.text("Workout Complete", "Training voltooid"))
                            .font(.largeTitle.bold())
                        Text(session.title)
                            .foregroundStyle(RFTheme.muted)
                    }
                    .frame(maxWidth: .infinity)

                    ForgeSessionRewards(session: session, sessions: sessions)

                    HStack {
                        StatCard(
                            title: L10n.text("Duration", "Duur"),
                            value: durationString(session.duration),
                            icon: "clock.fill"
                        )

                        if session.totalVolume > 0 {
                            StatCard(
                                title: L10n.text("Volume", "Volume"),
                                value: "\(Int(AppPreferences.displayVolume(session.totalVolume))) \(AppPreferences.weightLabel)",
                                icon: "chart.bar.fill"
                            )
                        } else if session.totalCardioDistanceKm > 0 {
                            StatCard(
                                title: L10n.text("Distance", "Afstand"),
                                value: "\(AppPreferences.displayDistance(session.totalCardioDistanceKm).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.distanceLabel)",
                                icon: "figure.run"
                            )
                        } else {
                            StatCard(
                                title: L10n.text("Entries", "Invoer"),
                                value: "\(completedSets.count)",
                                icon: "checkmark.circle.fill"
                            )
                        }
                    }

                    HStack {
                        StatCard(title: L10n.text("Completed entries", "Voltooide invoer"), value: "\(completedSets.count)", icon: "checkmark.circle.fill")
                        StatCard(title: L10n.text("PRs", "PR's"), value: "\(prs.count)", icon: "trophy.fill")
                    }

                    if session.totalCardioDistanceKm > 0 || session.totalCardioDurationSeconds > 0 {
                        HStack {
                            StatCard(
                                title: L10n.text("Cardio distance", "Cardioafstand"),
                                value: session.totalCardioDistanceKm > 0
                                    ? "\(AppPreferences.displayDistance(session.totalCardioDistanceKm).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.distanceLabel)"
                                    : "—",
                                icon: "figure.run"
                            )
                            StatCard(
                                title: L10n.text("Cardio time", "Cardiotijd"),
                                value: session.totalCardioDurationSeconds > 0
                                    ? cardioDurationText(session.totalCardioDurationSeconds)
                                    : "—",
                                icon: "timer"
                            )
                        }
                    }

                    MuscleHeatMapView(
                        entries: MuscleAnalytics.sessionVolume(session),
                        title: L10n.text("Muscles trained", "Getrainde spieren")
                    )

                    if !prs.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n.text("New personal records", "Nieuwe persoonlijke records"))
                                .font(.title3.bold())

                            ForEach(Array(prs.enumerated()), id: \.offset) { _, pr in
                                HStack {
                                    Image(systemName: "trophy.fill")
                                        .foregroundStyle(RFTheme.accent)
                                    VStack(alignment: .leading) {
                                        Text(pr.0).bold()
                                        Text(
                                            pr.2 > 0
                                            ? "\(AppPreferences.displayWeight(pr.2).formatted(.number.precision(.fractionLength(0...2)))) → \(AppPreferences.displayWeight(pr.1).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.weightLabel)"
                                            : "\(AppPreferences.displayWeight(pr.1).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.weightLabel)"
                                        )
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(12)
                                .background(RFTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }

                    if !progressionSuggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n.text("Next workout suggestions", "Suggesties voor volgende training"))
                                .font(.title3.bold())

                            ForEach(Array(progressionSuggestions.enumerated()), id: \.offset) { _, suggestion in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "arrow.up.right.circle.fill")
                                            .foregroundStyle(RFTheme.success)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(suggestion.name).bold()
                                            Text(
                                                "\(AppPreferences.displayWeight(suggestion.current).formatted(.number.precision(.fractionLength(0...2)))) → \(AppPreferences.displayWeight(suggestion.next).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.weightLabel)"
                                            )
                                            .font(.headline)
                                            .foregroundStyle(RFTheme.success)
                                        }

                                        Spacer()
                                    }

                                    Text(suggestion.reason)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Label(
                                        L10n.text("Suggestion only — you stay in control.", "Alleen een suggestie — jij beslist."),
                                        systemImage: "info.circle"
                                    )
                                    .font(.caption2)
                                    .foregroundStyle(RFTheme.muted)
                                }
                                .padding(12)
                                .background(RFTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(RFTheme.cardBorder)
                                )
                            }
                        }
                    }

                    if let note = session.note, !note.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(L10n.text("Workout note", "Trainingsnotitie"), systemImage: "note.text")
                                .font(.headline)
                            Text(note)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(RFTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button(L10n.done, action: onDone)
                        .buttonStyle(.borderedProminent)
                        .tint(RFTheme.accent)
                        .frame(maxWidth: .infinity)
                        .controlSize(.large)
                }
                .padding()
            }
            .background(RFTheme.bg)
            .navigationTitle(L10n.text("Summary", "Samenvatting"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func highestRepTarget(_ text: String) -> Int? {
        let numbers = text
            .split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }
        return numbers.max()
    }
}

// MARK: - History

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

    @State private var deleteCandidate: WorkoutSession?
    @State private var mode = 0
    @State private var search = ""
    @State private var gymFilter = "all"
    @State private var muscleFilter = "All"
    @State private var periodFilter = "all"
    @State private var onlyPRs = false

    @AppStorage("scheduleRevision") private var scheduleRevision = 0
    @AppStorage("gymRevision") private var gymRevision = 0

    private var completed: [WorkoutSession] {
        sessions.filter { $0.endedAt != nil }
    }

    private var filtered: [WorkoutSession] {
        _ = scheduleRevision
        _ = gymRevision

        return completed.filter { session in
            if gymFilter != "all",
               GymProfileStore.sessionGymID(session) != gymFilter {
                return false
            }

            if muscleFilter != "All" {
                let matchesMuscle = session.exercises.contains { log in
                    guard let exercise = ExerciseCatalog.find(log.exerciseID) else { return false }
                    return exercise.muscle == muscleFilter ||
                        exercise.detailedMuscles.contains(where: { $0.muscle == muscleFilter })
                }
                if !matchesMuscle { return false }
            }

            let calendar = Calendar.current
            switch periodFilter {
            case "7":
                if session.startedAt < (calendar.date(byAdding: .day, value: -7, to: .now) ?? .distantPast) { return false }
            case "30":
                if session.startedAt < (calendar.date(byAdding: .day, value: -30, to: .now) ?? .distantPast) { return false }
            case "year":
                if let start = calendar.dateInterval(of: .year, for: .now)?.start,
                   session.startedAt < start { return false }
            default:
                break
            }

            if onlyPRs && !sessionHasPR(session) {
                return false
            }

            let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return true }

            let haystack = [
                session.title,
                session.note ?? "",
                GymProfileStore.profile(id: session.gymID).name,
                session.startedAt.formatted(date: .long, time: .omitted)
            ] + session.exercises.compactMap { log in
                guard let exercise = ExerciseCatalog.find(log.exerciseID) else { return nil }
                return "\(exercise.name) \(exercise.muscle) \(exercise.equipment)"
            }

            return haystack.contains { $0.localizedCaseInsensitiveContains(trimmed) }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker(L10n.history, selection: $mode) {
                    Text(L10n.text("List", "Lijst")).tag(0)
                    Text(L10n.text("Calendar", "Kalender")).tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                if mode == 0 {
                    WorkoutActivityHeatmap(sessions: completed, condensed: true)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    filterBar

                    if filtered.isEmpty {
                        EmptyCard(
                            icon: "line.3.horizontal.decrease.circle",
                            title: L10n.text("No matching workouts", "Geen overeenkomende trainingen"),
                            text: L10n.text("Change the search or filters.", "Pas de zoekopdracht of filters aan.")
                        )
                        .padding()
                        Spacer()
                    } else {
                        List(filtered) { session in
                            NavigationLink {
                                SessionDetailView(session: session)
                            } label: {
                                historyRow(session)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteCandidate = session
                                } label: {
                                    Label(L10n.text("Delete", "Verwijder"), systemImage: "trash")
                                }
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                } else {
                    WorkoutCalendarView(sessions: completed)
                }
            }
            .background(RFTheme.bg)
            .navigationTitle(L10n.history)
            .searchable(
                text: $search,
                prompt: L10n.text("Search workouts, exercises, gyms…", "Zoek trainingen, oefeningen, gyms…")
            )
            .confirmationDialog(
                L10n.text("Delete workout history?", "Trainingsgeschiedenis verwijderen?"),
                isPresented: Binding(
                    get: { deleteCandidate != nil },
                    set: { if !$0 { deleteCandidate = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(L10n.text("Delete workout", "Training verwijderen"), role: .destructive) {
                    if let session = deleteCandidate {
                        context.delete(session)
                        try? context.save()
                        deleteCandidate = nil
                    }
                }
                Button(L10n.text("Cancel", "Annuleren"), role: .cancel) {
                    deleteCandidate = nil
                }
            } message: {
                Text(L10n.text(
                    "This permanently removes this workout and all of its logged sets.",
                    "Hiermee worden deze training en alle opgeslagen sets permanent verwijderd."
                ))
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    Button(L10n.text("All gyms", "Alle gyms")) { gymFilter = "all" }
                    ForEach(GymProfileStore.load()) { gym in
                        Button {
                            gymFilter = gym.id
                        } label: {
                            if gymFilter == gym.id {
                                Label(gym.name, systemImage: "checkmark")
                            } else {
                                Text(gym.name)
                            }
                        }
                    }
                } label: {
                    Label(
                        gymFilter == "all"
                            ? L10n.text("All gyms", "Alle gyms")
                            : GymProfileStore.profile(id: gymFilter).name,
                        systemImage: "mappin.and.ellipse"
                    )
                }
                .buttonStyle(.bordered)

                Menu {
                    Button(L10n.text("All muscles", "Alle spieren")) { muscleFilter = "All" }
                    ForEach(ExerciseCatalog.muscles, id: \.self) { muscle in
                        Button(muscle) { muscleFilter = muscle }
                    }
                    Divider()
                    ForEach(MuscleMap.trackedMuscles, id: \.self) { muscle in
                        Button(muscle) { muscleFilter = muscle }
                    }
                } label: {
                    Label(
                        muscleFilter == "All" ? L10n.text("Muscle", "Spier") : muscleFilter,
                        systemImage: "figure.strengthtraining.traditional"
                    )
                }
                .buttonStyle(.bordered)

                Menu {
                    Button(L10n.text("All time", "Altijd")) { periodFilter = "all" }
                    Button(L10n.text("Last 7 days", "Laatste 7 dagen")) { periodFilter = "7" }
                    Button(L10n.text("Last 30 days", "Laatste 30 dagen")) { periodFilter = "30" }
                    Button(L10n.text("This year", "Dit jaar")) { periodFilter = "year" }
                } label: {
                    Label(periodLabel, systemImage: "calendar")
                }
                .buttonStyle(.bordered)

                Button {
                    onlyPRs.toggle()
                } label: {
                    Label("PR", systemImage: onlyPRs ? "trophy.fill" : "trophy")
                }
                .buttonStyle(.bordered)
                .tint(onlyPRs ? RFTheme.accent : .gray)

                if gymFilter != "all" || muscleFilter != "All" || periodFilter != "all" || onlyPRs {
                    Button {
                        gymFilter = "all"
                        muscleFilter = "All"
                        periodFilter = "all"
                        onlyPRs = false
                    } label: {
                        Label(L10n.text("Clear", "Wis"), systemImage: "xmark")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func historyRow(_ session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(session.title).font(.headline)
                if sessionHasPR(session) {
                    Image(systemName: "trophy.fill")
                        .font(.caption)
                        .foregroundStyle(RFTheme.accent)
                }
                Spacer()
                Text(session.startedAt, format: .dateTime.day().month(.abbreviated))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                Label(GymProfileStore.profile(id: session.gymID).name, systemImage: "mappin.and.ellipse")
                Text("•")
                Text("\(session.exercises.count) \(L10n.text("exercises", "oefeningen"))")
                Text("•")
                Text(historyPrimaryMetric(session))
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(durationString(session.duration))
                .font(.caption2)
                .foregroundStyle(RFTheme.muted)
        }
        .padding(.vertical, 6)
    }

    private func historyPrimaryMetric(_ session: WorkoutSession) -> String {
        if session.totalVolume > 0 {
            return "\(Int(AppPreferences.displayVolume(session.totalVolume))) \(AppPreferences.weightLabel)"
        }

        if session.totalCardioDistanceKm > 0 {
            return "\(AppPreferences.displayDistance(session.totalCardioDistanceKm).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.distanceLabel)"
        }

        if session.totalCardioDurationSeconds > 0 {
            return cardioDurationText(session.totalCardioDurationSeconds)
        }

        return "—"
    }

    private var periodLabel: String {
        switch periodFilter {
        case "7": return "7d"
        case "30": return "30d"
        case "year": return L10n.text("Year", "Jaar")
        default: return L10n.text("All time", "Altijd")
        }
    }

    private func sessionHasPR(_ session: WorkoutSession) -> Bool {
        let earlier = completed.filter { $0.startedAt < session.startedAt }

        return session.exercises.contains { log in
            let current = log.sets.filter(\.countsForPR).map(\.weightKg).max() ?? 0
            guard current > 0 else { return false }

            let previous = Metrics.personalBest(
                exerciseID: log.exerciseID,
                sessions: earlier,
                gymID: GymProfileStore.sessionGymID(session)
            )

            return current > previous
        }
    }
}

struct WorkoutCalendarView: View {
    let sessions: [WorkoutSession]

    @State private var month = Calendar.current.date(
        from: Calendar.current.dateComponents([.year, .month], from: .now)
    ) ?? .now
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var editingSchedule: ScheduledWorkoutRecord?

    @AppStorage("scheduleRevision") private var scheduleRevision = 0

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private var monthDays: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else {
            return []
        }

        let weekday = calendar.component(.weekday, from: first)
        let prefix = (weekday - calendar.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: prefix)

        for day in range {
            days.append(calendar.date(byAdding: .day, value: day - 1, to: first))
        }

        while days.count % 7 != 0 {
            days.append(nil)
        }
        return days
    }

    private var planned: [ScheduledWorkoutRecord] {
        _ = scheduleRevision
        return WorkoutScheduleStore.load()
    }

    private var selectedSessions: [WorkoutSession] {
        sessions.filter { calendar.isDate($0.startedAt, inSameDayAs: selectedDate) }
    }

    private var selectedPlans: [ScheduledWorkoutRecord] {
        planned.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    Button {
                        shiftMonth(-1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }

                    Spacer()

                    Text(month.formatted(.dateTime.month(.wide).year()))
                        .font(.title3.bold())

                    Spacer()

                    Button {
                        shiftMonth(1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                }
                .padding(.horizontal)

                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.caption2.bold())
                            .foregroundStyle(RFTheme.muted)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                        if let date {
                            CalendarDayCell(
                                date: date,
                                selected: calendar.isDate(date, inSameDayAs: selectedDate),
                                workoutCount: sessions.filter { calendar.isDate($0.startedAt, inSameDayAs: date) }.count,
                                plannedCount: planned.filter {
                                    calendar.isDate($0.date, inSameDayAs: date) && !$0.skipped
                                }.count,
                                skippedCount: planned.filter {
                                    calendar.isDate($0.date, inSameDayAs: date) && $0.skipped
                                }.count
                            ) {
                                selectedDate = calendar.startOfDay(for: date)
                            }
                        } else {
                            Color.clear.frame(height: 48)
                        }
                    }
                }
                .padding(.horizontal)

                Divider()
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 10) {
                    Text(selectedDate.formatted(date: .complete, time: .omitted))
                        .font(.headline)

                    if selectedSessions.isEmpty && selectedPlans.isEmpty {
                        Text(L10n.text("Nothing scheduled or completed.", "Niets gepland of voltooid."))
                            .foregroundStyle(RFTheme.muted)
                            .padding(.vertical, 12)
                    }

                    ForEach(selectedPlans) { item in
                        HStack(spacing: 10) {
                            Image(systemName: item.skipped ? "forward.end.fill" : "calendar.badge.clock")
                                .foregroundStyle(item.skipped ? .orange : RFTheme.accent)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.subheadline.bold())
                                    .strikethrough(item.skipped)
                                Text(
                                    "\(item.date.formatted(date: .omitted, time: .shortened)) • \(GymProfileStore.profile(id: item.gymID).name)"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Menu {
                                Button {
                                    editingSchedule = item
                                } label: {
                                    Label(L10n.text("Reschedule", "Verplaatsen"), systemImage: "calendar")
                                }
                                Button {
                                    WorkoutScheduleStore.toggleSkipped(id: item.id)
                                } label: {
                                    Label(
                                        item.skipped
                                            ? L10n.text("Unskip", "Niet overslaan")
                                            : L10n.text("Skip", "Overslaan"),
                                        systemImage: "forward.end"
                                    )
                                }
                                Button(role: .destructive) {
                                    WorkoutScheduleStore.remove(id: item.id)
                                } label: {
                                    Label(L10n.text("Delete", "Verwijder"), systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .frame(width: 32, height: 32)
                            }
                        }
                        .padding(12)
                        .background(RFTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    ForEach(selectedSessions) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(RFTheme.success)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(session.title)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                    Text(
                                        "\(Int(AppPreferences.displayVolume(session.totalVolume))) \(AppPreferences.weightLabel) • \(durationString(session.duration))"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(RFTheme.muted)
                            }
                            .padding(12)
                            .background(RFTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .padding(.top, 10)
        }
        .sheet(item: $editingSchedule) { item in
            ScheduleWorkoutSheet(seed: item) { updated in
                WorkoutScheduleStore.update(updated)
            }
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    private func shiftMonth(_ delta: Int) {
        if let next = calendar.date(byAdding: .month, value: delta, to: month) {
            month = next
            selectedDate = calendar.startOfDay(for: next)
        }
    }
}

struct CalendarDayCell: View {
    let date: Date
    let selected: Bool
    let workoutCount: Int
    let plannedCount: Int
    let skippedCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.subheadline.bold())
                    .foregroundStyle(selected ? Color.white : Color.primary)

                HStack(spacing: 3) {
                    if workoutCount > 0 {
                        Circle().fill(RFTheme.success).frame(width: 5, height: 5)
                    }
                    if plannedCount > 0 {
                        Circle().fill(RFTheme.accent).frame(width: 5, height: 5)
                    }
                    if skippedCount > 0 {
                        Circle().fill(Color.orange).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(selected ? RFTheme.accent : RFTheme.surface.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

struct SessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let session: WorkoutSession
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var allSessions: [WorkoutSession]
    @State private var showDeleteConfirmation = false

    private var previousComparable: WorkoutSession? {
        let earlier = allSessions.filter {
            $0.endedAt != nil &&
            $0.startedAt < session.startedAt &&
            GymProfileStore.sessionGymID($0) == GymProfileStore.sessionGymID(session)
        }

        if let exact = earlier.first(where: { $0.title == session.title }) {
            return exact
        }

        let currentIDs = Set(session.exercises.map(\.exerciseID))
        guard !currentIDs.isEmpty else { return nil }

        return earlier
            .map { candidate -> (WorkoutSession, Double) in
                let ids = Set(candidate.exercises.map(\.exerciseID))
                let overlap = Double(currentIDs.intersection(ids).count)
                let union = Double(currentIDs.union(ids).count)
                return (candidate, union > 0 ? overlap / union : 0)
            }
            .filter { $0.1 >= 0.45 }
            .sorted { $0.1 > $1.1 }
            .first?.0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.startedAt.formatted(date: .complete, time: .shortened))
                                .font(.caption.bold())
                                .foregroundStyle(RFTheme.muted)

                            Label(
                                GymProfileStore.profile(id: session.gymID).name,
                                systemImage: "mappin.and.ellipse"
                            )
                            .font(.caption.bold())
                            .foregroundStyle(RFTheme.accent)
                        }

                        Spacer()

                        Image(systemName: "checkmark.seal.fill")
                            .font(.title)
                            .foregroundStyle(RFTheme.success)
                    }

                    HStack {
                        StatCard(
                            title: L10n.text("Duration", "Duur"),
                            value: durationString(session.duration),
                            icon: "clock.fill"
                        )

                        if session.totalVolume > 0 {
                            StatCard(
                                title: L10n.text("Volume", "Volume"),
                                value: "\(Int(AppPreferences.displayVolume(session.totalVolume))) \(AppPreferences.weightLabel)",
                                icon: "chart.bar.fill"
                            )
                        } else {
                            StatCard(
                                title: L10n.text("Entries", "Invoer"),
                                value: "\(session.exercises.flatMap(\.sets).filter(\.completed).count)",
                                icon: "checkmark.circle.fill"
                            )
                        }
                    }

                    if session.totalCardioDistanceKm > 0 || session.totalCardioDurationSeconds > 0 {
                        HStack {
                            StatCard(
                                title: L10n.text("Cardio distance", "Cardioafstand"),
                                value: session.totalCardioDistanceKm > 0
                                    ? "\(AppPreferences.displayDistance(session.totalCardioDistanceKm).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.distanceLabel)"
                                    : "—",
                                icon: "figure.run"
                            )
                            StatCard(
                                title: L10n.text("Cardio time", "Cardiotijd"),
                                value: session.totalCardioDurationSeconds > 0
                                    ? cardioDurationText(session.totalCardioDurationSeconds)
                                    : "—",
                                icon: "timer"
                            )
                        }
                    }
                }
                .padding()
                .background(RFTheme.heroGradient)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(RFTheme.cardBorder)
                )

                if let note = session.note, !note.isEmpty {
                    Label(note, systemImage: "note.text")
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RFTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(RFTheme.cardBorder)
                        )
                }

                if let previousComparable {
                    WorkoutComparisonCard(current: session, previous: previousComparable)
                }

                ForEach(session.exercises.sorted(by: { $0.order < $1.order })) { log in
                    let ex = ExerciseCatalog.find(log.exerciseID)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 11)
                                    .fill(RFTheme.accent.opacity(0.12))
                                Image(systemName: ex?.movement == "cardio" ? "figure.run" : "dumbbell.fill")
                                    .foregroundStyle(RFTheme.accent)
                            }
                            .frame(width: 38, height: 38)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(ex?.name ?? "Exercise")
                                    .font(.headline)
                                Text(ex?.movement == "cardio"
                                     ? L10n.text("Cardio", "Cardio")
                                     : "\(log.sets.filter(\.completed).count) \(L10n.text("completed sets", "voltooide sets"))")
                                    .font(.caption)
                                    .foregroundStyle(RFTheme.muted)
                            }

                            Spacer()
                        }

                        if ex?.movement == "cardio" {
                            ForEach(log.sets.filter(\.completed).sorted(by: { $0.order < $1.order })) { set in
                                CardioHistoryEntry(set: set)
                            }
                        } else {
                            ForEach(log.sets.filter(\.completed).sorted(by: { $0.order < $1.order })) { set in
                                HStack {
                                    Text("\(L10n.text("Set", "Set")) \(set.order + 1)")
                                        .foregroundStyle(RFTheme.muted)

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(AppPreferences.displayWeight(set.weightKg).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.weightLabel) × \(set.reps)")
                                            .bold()

                                        HStack(spacing: 6) {
                                            if set.setType != "working" {
                                                Text(set.setType.capitalized)
                                            }
                                            if let rpe = set.rpe {
                                                Text("RPE \(rpe.formatted(.number.precision(.fractionLength(0...1))))")
                                            }
                                            if let rir = set.rir {
                                                Text("RIR \(rir)")
                                            }
                                        }
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    }
                                }
                                .font(.subheadline)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding()
                    .background(RFTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(RFTheme.cardBorder)
                    )
                }
            }
            .padding()
        }
        .background(RFTheme.bg)
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel(L10n.text("Delete workout", "Training verwijderen"))
            }
        }
        .confirmationDialog(
            L10n.text("Delete workout history?", "Trainingsgeschiedenis verwijderen?"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.text("Delete workout", "Training verwijderen"), role: .destructive) {
                context.delete(session)
                try? context.save()
                dismiss()
            }
            Button(L10n.text("Cancel", "Annuleren"), role: .cancel) {}
        } message: {
            Text(L10n.text(
                "This permanently removes this workout and all of its logged sets.",
                "Hiermee worden deze training en alle opgeslagen sets permanent verwijderd."
            ))
        }
    }
}

struct CardioHistoryEntry: View {
    let set: WorkoutSet

    var body: some View {
        VStack(spacing: 7) {
            HStack {
                Text("\(L10n.text("Interval", "Interval")) \(set.order + 1)")
                    .font(.caption.bold())
                    .foregroundStyle(RFTheme.muted)
                Spacer()
                if let paceText {
                    Label(paceText, systemImage: "speedometer")
                        .font(.caption.bold())
                        .foregroundStyle(RFTheme.accent)
                }
            }

            HStack(spacing: 12) {
                if let duration = set.durationSeconds, duration > 0 {
                    historyMetric(
                        icon: "clock",
                        value: cardioDurationText(duration),
                        label: L10n.text("Time", "Tijd")
                    )
                }

                if let distance = set.distanceKm, distance > 0 {
                    historyMetric(
                        icon: "figure.run",
                        value: "\(AppPreferences.displayDistance(distance).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.distanceLabel)",
                        label: L10n.text("Distance", "Afstand")
                    )
                }

                if let calories = set.calories, calories > 0 {
                    historyMetric(
                        icon: "flame.fill",
                        value: "\(Int(calories.rounded()))",
                        label: "kcal"
                    )
                }

                if let hr = set.averageHeartRate, hr > 0 {
                    historyMetric(
                        icon: "heart.fill",
                        value: "\(hr)",
                        label: "bpm"
                    )
                }
            }

            if let incline = set.inclinePercent, incline > 0 {
                HStack {
                    Label(
                        "\(L10n.text("Incline", "Helling")) \(incline.formatted(.number.precision(.fractionLength(0...1))))%",
                        systemImage: "mountain.2"
                    )
                    .font(.caption)
                    .foregroundStyle(RFTheme.muted)
                    Spacer()
                }
            }
        }
        .padding(10)
        .background(RFTheme.field.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var paceText: String? {
        guard let duration = set.durationSeconds,
              let distanceKm = set.distanceKm,
              duration > 0,
              distanceKm > 0 else { return nil }

        let distance = AppPreferences.displayDistance(distanceKm)
        let secondsPerUnit = duration / distance
        let minutes = Int(secondsPerUnit) / 60
        let seconds = Int(secondsPerUnit) % 60
        return "\(minutes):\(String(format: "%02d", seconds))/\(AppPreferences.distanceLabel)"
    }

    private func historyMetric(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(RFTheme.accent)
            Text(value)
                .font(.caption.bold())
                .lineLimit(1)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(RFTheme.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

struct WorkoutComparisonCard: View {
    let current: WorkoutSession
    let previous: WorkoutSession

    private var currentSets: Int {
        current.exercises.flatMap(\.sets).filter(\.completed).count
    }

    private var previousSets: Int {
        previous.exercises.flatMap(\.sets).filter(\.completed).count
    }

    private var volumeDelta: Double {
        current.totalVolume - previous.totalVolume
    }

    private var durationDelta: TimeInterval {
        current.duration - previous.duration
    }

    private var setDelta: Int {
        currentSets - previousSets
    }

    private var exerciseChanges: [(String, Double)] {
        current.exercises.compactMap { log in
            guard let previousLog = previous.exercises.first(where: { $0.exerciseID == log.exerciseID }),
                  let exercise = ExerciseCatalog.find(log.exerciseID) else {
                return nil
            }

            let currentBest = log.sets.filter(\.countsForPR).map(\.weightKg).max() ?? 0
            let previousBest = previousLog.sets.filter(\.countsForPR).map(\.weightKg).max() ?? 0
            guard currentBest > 0 || previousBest > 0 else { return nil }
            return (exercise.name, currentBest - previousBest)
        }
        .sorted { abs($0.1) > abs($1.1) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.text("Compared with previous", "Vergeleken met vorige"))
                        .font(.title3.bold())
                    Text(previous.startedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(RFTheme.muted)
                }
                Spacer()
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundStyle(RFTheme.accent)
            }

            HStack {
                if current.totalVolume > 0 || previous.totalVolume > 0 {
                    comparisonMetric(
                        title: L10n.text("Volume", "Volume"),
                        value: signedWeight(volumeDelta),
                        positive: volumeDelta >= 0
                    )
                } else {
                    comparisonMetric(
                        title: L10n.text("Distance", "Afstand"),
                        value: signedDistance(current.totalCardioDistanceKm - previous.totalCardioDistanceKm),
                        positive: current.totalCardioDistanceKm >= previous.totalCardioDistanceKm
                    )
                }

                comparisonMetric(
                    title: L10n.text("Entries", "Invoer"),
                    value: signedInt(setDelta),
                    positive: setDelta >= 0
                )

                comparisonMetric(
                    title: L10n.text("Time", "Tijd"),
                    value: signedDuration(durationDelta),
                    positive: durationDelta <= 0
                )
            }

            if !exerciseChanges.isEmpty {
                Divider()
                ForEach(Array(exerciseChanges.prefix(5).enumerated()), id: \.offset) { _, item in
                    HStack {
                        Text(item.0)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text(signedWeight(item.1))
                            .font(.caption.bold())
                            .foregroundStyle(item.1 > 0 ? RFTheme.success : item.1 < 0 ? Color.orange : RFTheme.muted)
                    }
                }
            }
        }
        .padding()
        .background(RFTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func comparisonMetric(title: String, value: String, positive: Bool) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundStyle(positive ? RFTheme.success : Color.orange)
            Text(title)
                .font(.caption2)
                .foregroundStyle(RFTheme.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private func signedWeight(_ kg: Double) -> String {
        let displayed = AppPreferences.displayWeight(abs(kg))
        let sign = kg > 0 ? "+" : kg < 0 ? "−" : "±"
        return "\(sign)\(displayed.formatted(.number.precision(.fractionLength(0...1)))) \(AppPreferences.weightLabel)"
    }

    private func signedDistance(_ km: Double) -> String {
        let displayed = AppPreferences.displayDistance(abs(km))
        let sign = km > 0 ? "+" : km < 0 ? "−" : "±"
        return "\(sign)\(displayed.formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.distanceLabel)"
    }

    private func signedInt(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    private func signedDuration(_ value: TimeInterval) -> String {
        let minutes = Int(abs(value) / 60)
        let sign = value > 0 ? "+" : value < 0 ? "−" : "±"
        return "\(sign)\(minutes)m"
    }
}

// MARK: - Exercise library & detail

struct ExerciseLibraryView: View {
    @State private var search = ""
    @State private var muscle = "All"
    @State private var equipment = "All"
    @State private var showCustomEditor = false
    @State private var refreshToken = UUID()
    @State private var deleteCandidate: ExerciseDefinition?

    private var filtered: [ExerciseDefinition] {
        _ = refreshToken
        return ExerciseCatalog.all.filter { ex in
            ExerciseSearch.matches(ex, query: search) &&
            (muscle == "All" || ex.muscle == muscle) &&
            GymEquipmentFilter.matches(ex, selected: equipment)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterPanel

                HStack {
                    Text("\(filtered.count) " + L10n.text("exercises", "oefeningen"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RFTheme.muted)
                    Spacer()
                    if muscle != "All" || equipment != "All" || !search.isEmpty {
                        Button(L10n.text("Clear filters", "Filters wissen")) {
                            search = ""
                            muscle = "All"
                            equipment = "All"
                        }
                        .font(.caption.weight(.semibold))
                    }
                }
                .padding(.horizontal, RFLayout.pagePadding)
                .padding(.vertical, 8)

                if filtered.isEmpty {
                    ContentUnavailableView.search(text: search)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filtered) { ex in
                        NavigationLink {
                            ExerciseDetailView(exercise: ex)
                        } label: {
                            ExerciseLibraryRow(exercise: ex)
                        }
                        .listRowBackground(RFLayout.style == "focused" ? RFTheme.surface : Color.clear)
                        .listRowSeparator(RFLayout.style == "focused" ? .hidden : .visible)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                ExerciseShortcutStore.toggleFavorite(ex.id)
                                refreshToken = UUID()
                            } label: {
                                Label(
                                    ExerciseShortcutStore.isFavorite(ex.id)
                                        ? L10n.text("Unfavorite", "Verwijder favoriet")
                                        : L10n.text("Favorite", "Favoriet"),
                                    systemImage: ExerciseShortcutStore.isFavorite(ex.id) ? "star.slash" : "star.fill"
                                )
                            }
                            .tint(.yellow)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if CustomExerciseStore.isCustom(ex.id) {
                                Button(role: .destructive) {
                                    deleteCandidate = ex
                                } label: {
                                    Label(L10n.text("Delete", "Verwijder"), systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .id(refreshToken)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(RFTheme.bg)
            .searchable(
                text: $search,
                prompt: L10n.text("Exercise or machine name", "Oefening of apparaat")
            )
            .navigationTitle(L10n.exercises)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showCustomEditor = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(L10n.text("Create custom exercise", "Eigen oefening maken"))
                }
            }
            .sheet(isPresented: $showCustomEditor, onDismiss: {
                refreshToken = UUID()
            }) {
                CustomExerciseEditorView()
            }
            .confirmationDialog(
                L10n.text("Delete custom exercise?", "Eigen oefening verwijderen?"),
                isPresented: Binding(
                    get: { deleteCandidate != nil },
                    set: { if !$0 { deleteCandidate = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(L10n.text("Delete", "Verwijder"), role: .destructive) {
                    if let candidate = deleteCandidate {
                        CustomExerciseStore.delete(id: candidate.id)
                        deleteCandidate = nil
                        refreshToken = UUID()
                    }
                }
                Button(L10n.text("Cancel", "Annuleren"), role: .cancel) {
                    deleteCandidate = nil
                }
            } message: {
                Text(L10n.text(
                    "Existing workout history will keep its saved exercise ID, but the exercise will no longer appear in the library.",
                    "Bestaande trainingsgeschiedenis behoudt de opgeslagen oefening-ID, maar de oefening verschijnt niet meer in de bibliotheek."
                ))
            }
        }
    }

    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: RFLayout.style == "compact" ? 8 : 12) {
            HStack {
                Text(L10n.text("Explore equipment", "Verken apparaten"))
                    .font(RFLayout.style == "focused" ? .title3.bold() : .headline)
                Spacer()
                Menu {
                    Button(L10n.text("All muscles", "Alle spiergroepen")) { muscle = "All" }
                    ForEach(ExerciseCatalog.muscles, id: \.self) { option in
                        Button(option) { muscle = option }
                    }
                } label: {
                    Label(
                        muscle == "All" ? L10n.text("Muscles", "Spieren") : muscle,
                        systemImage: "line.3.horizontal.decrease"
                    )
                    .font(.subheadline.weight(.medium))
                }
            }
            .padding(.horizontal, RFLayout.pagePadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(GymEquipmentFilter.options, id: \.self) { option in
                        Button {
                            equipment = option
                        } label: {
                            Text(GymEquipmentFilter.label(option))
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 13)
                                .padding(.vertical, RFLayout.style == "compact" ? 7 : 10)
                                .foregroundStyle(equipment == option ? RFTheme.accent : .primary)
                                .background(
                                    equipment == option ? RFTheme.accent.opacity(0.16) : RFTheme.surface,
                                    in: Capsule()
                                )
                                .overlay(Capsule().stroke(
                                    equipment == option ? RFTheme.accent.opacity(0.65) : RFTheme.cardBorder
                                ))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(equipment == option ? .isSelected : [])
                    }
                }
                .padding(.horizontal, RFLayout.pagePadding)
            }

            if equipment == "Machines" && search.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(GymEquipmentFilter.machineShortcuts, id: \.label) { shortcut in
                            Button {
                                search = shortcut.term
                                muscle = "All"
                            } label: {
                                Label(shortcut.label, systemImage: "magnifyingglass")
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.horizontal, RFLayout.pagePadding)
                }
            }
        }
        .padding(.vertical, RFLayout.style == "compact" ? 8 : 12)
        .background(.ultraThinMaterial)
    }
}

struct ExerciseLibraryRow: View {
    let exercise: ExerciseDefinition

    var body: some View {
        HStack(spacing: RFLayout.style == "compact" ? 10 : 14) {
            ZStack {
                RoundedRectangle(cornerRadius: RFLayout.style == "compact" ? 9 : 15)
                    .fill(RFTheme.accent.opacity(0.12))
                Image(systemName: symbol)
                    .font(RFLayout.style == "compact" ? .body : .title3)
                    .foregroundStyle(RFTheme.accent)
            }
            .frame(width: RFLayout.style == "compact" ? 38 : 54,
                   height: RFLayout.style == "compact" ? 38 : 54)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(exercise.name)
                    .font(RFLayout.style == "compact" ? .subheadline.weight(.semibold) : .headline)
                    .foregroundStyle(.primary)
                HStack(spacing: 5) {
                    Text(exercise.muscle)
                    Text("•")
                    Text(exercise.equipment)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 4)

            if CustomExerciseStore.isCustom(exercise.id) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .foregroundStyle(RFTheme.muted)
                    .accessibilityLabel(L10n.text("Custom exercise", "Eigen oefening"))
            } else if exercise.sourceID != nil {
                Image(systemName: "play.rectangle")
                    .foregroundStyle(RFTheme.muted)
                    .accessibilityLabel(L10n.text("Video available", "Video beschikbaar"))
            }
        }
        .padding(.vertical, RFLayout.style == "compact" ? 0 : 5)
    }

    private var symbol: String {
        switch exercise.movement {
        case "press": return "arrow.up.right"
        case "pull": return "arrow.down.left"
        case "squat": return "figure.strengthtraining.traditional"
        case "hinge": return "figure.flexibility"
        case "cardio": return "figure.run"
        case "core": return "figure.core.training"
        default: return "dumbbell.fill"
        }
    }
}

struct CustomExerciseEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var muscle = "Chest"
    @State private var equipment = "Dumbbell"
    @State private var movement = "press"

    private let muscles = [
        "Chest", "Back", "Shoulders", "Biceps", "Triceps", "Forearms",
        "Quadriceps", "Hamstrings", "Glutes", "Calves", "Core", "Full Body", "Cardio", "Other"
    ]

    private let equipmentOptions = [
        "Barbell", "Dumbbell", "Cable", "Machine", "Bodyweight",
        "Kettlebell", "EZ-Bar", "Trap Bar", "Cardio", "Other"
    ]

    private let movementOptions: [(String, String)] = [
        ("press", "Press"),
        ("pull", "Pull"),
        ("squat", "Squat"),
        ("hinge", "Hinge"),
        ("curl", "Curl"),
        ("extension", "Extension"),
        ("raise", "Raise"),
        ("core", "Core"),
        ("carry", "Carry"),
        ("cardio", "Cardio"),
        ("other", "Other")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.text("Exercise", "Oefening")) {
                    TextField(L10n.text("Exercise name", "Naam oefening"), text: $name)

                    Picker(L10n.text("Muscle", "Spiergroep"), selection: $muscle) {
                        ForEach(muscles, id: \.self) { Text($0).tag($0) }
                    }

                    Picker(L10n.text("Equipment", "Apparatuur"), selection: $equipment) {
                        ForEach(equipmentOptions, id: \.self) { Text($0).tag($0) }
                    }

                    Picker(L10n.text("Movement", "Beweging"), selection: $movement) {
                        ForEach(movementOptions, id: \.0) { option in
                            Text(option.1).tag(option.0)
                        }
                    }
                }

                Section {
                    Text(L10n.text(
                        "Custom exercises are stored locally and automatically appear in workout and template exercise pickers.",
                        "Eigen oefeningen worden lokaal opgeslagen en verschijnen automatisch in de oefeningkiezers voor trainingen en templates."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(L10n.text("New Exercise", "Nieuwe oefening"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("Cancel", "Annuleren")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("Save", "Opslaan")) {
                        CustomExerciseStore.add(
                            name: name,
                            muscle: muscle,
                            equipment: equipment,
                            movement: movement
                        )
                        Haptics.success()
                        dismiss()
                    }
                    .bold()
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}


struct ExerciseDetailView: View {
    let exercise: ExerciseDefinition
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @State private var tab = 0

    private var performances: [(date: Date, weight: Double, oneRM: Double, volume: Double)] {
        guard exercise.movement != "cardio" else { return [] }
        return Metrics.performances(
            exerciseID: exercise.id,
            sessions: sessions,
            gymID: AppPreferences.activeGymID,
            startDate: AppPreferences.prStartDate
        )
    }

    private var cardioPerformances: [(date: Date, distanceKm: Double, duration: Double, calories: Double, avgHR: Double?)] {
        guard exercise.movement == "cardio" else { return [] }

        return Metrics.scopedSessions(
            sessions,
            gymID: AppPreferences.activeGymID,
            startDate: AppPreferences.prStartDate
        )
        .compactMap { session in
            guard let log = session.exercises.first(where: { $0.exerciseID == exercise.id }) else { return nil }
            let completed = log.sets.filter(\.completed)
            guard !completed.isEmpty else { return nil }

            let distance = completed.reduce(0.0) { $0 + ($1.distanceKm ?? 0) }
            let duration = completed.reduce(0.0) { $0 + ($1.durationSeconds ?? 0) }
            let calories = completed.reduce(0.0) { $0 + ($1.calories ?? 0) }
            let heartRates = completed.compactMap(\.averageHeartRate)
            let avgHR = heartRates.isEmpty
                ? nil
                : Double(heartRates.reduce(0, +)) / Double(heartRates.count)

            return (
                session.endedAt ?? session.startedAt,
                distance,
                duration,
                calories,
                avgHR
            )
        }
        .sorted { $0.date < $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("Section", selection: $tab) {
                    Text("Guide").tag(0)
                    Text("History").tag(1)
                    Text("Charts").tag(2)
                    Text("Records").tag(3)
                }
                .pickerStyle(.segmented)

                if tab == 0 { guide }
                if tab == 1 { history }
                if tab == 2 { charts }
                if tab == 3 { records }
            }
            .padding()
        }
        .background(RFTheme.bg)
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var guide: some View {
        ExerciseDemoView(exercise: exercise)

        ExerciseTargetHeatmap(exercise: exercise)

        HStack {
            Label(exercise.muscle, systemImage: "figure.strengthtraining.traditional")
            Spacer()
            Text(exercise.equipment).foregroundStyle(RFTheme.muted)
        }

        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text("Muscles trained", "Getrainde spieren"))
                .font(.title3.bold())

            FlowMuscleTags(contributions: exercise.detailedMuscles)
        }

        Text("How to perform").font(.title3.bold())
        ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { index, step in
            HStack(alignment: .top, spacing: 12) {
                Text("\(index + 1)")
                    .font(.caption.bold())
                    .frame(width: 28, height: 28)
                    .background(RFTheme.accent)
                    .clipShape(Circle())
                Text(step)
            }
        }

        Text("Technique cues").font(.title3.bold()).padding(.top, 4)
        ForEach(exercise.cues, id: \.self) {
            Label($0, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.secondary)
        }

        Text("Training guidance is general information, not medical advice. Stop an exercise if it causes pain and seek qualified help when appropriate.")
            .font(.caption)
            .foregroundStyle(RFTheme.muted)
            .padding(.top, 4)
    }

    @ViewBuilder
    private var history: some View {
        if exercise.movement == "cardio" {
            if cardioPerformances.isEmpty {
                EmptyCard(
                    icon: "clock",
                    title: L10n.text("No cardio history yet", "Nog geen cardiogeschiedenis"),
                    text: L10n.text("Complete this cardio exercise to populate its history.", "Voltooi deze cardio-oefening om geschiedenis op te bouwen.")
                )
            } else {
                ForEach(Array(cardioPerformances.reversed().enumerated()), id: \.offset) { _, p in
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(RFTheme.accent.opacity(0.12))
                            Image(systemName: "figure.run")
                                .foregroundStyle(RFTheme.accent)
                        }
                        .frame(width: 42, height: 42)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(p.date.formatted(date: .abbreviated, time: .omitted))
                                .bold()

                            HStack(spacing: 7) {
                                if p.duration > 0 {
                                    Text(cardioDurationText(p.duration))
                                }
                                if p.distanceKm > 0 {
                                    Text("• \(AppPreferences.displayDistance(p.distanceKm).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.distanceLabel)")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if let pace = cardioPaceText(duration: p.duration, distanceKm: p.distanceKm) {
                            Text(pace)
                                .font(.headline)
                                .foregroundStyle(RFTheme.accent)
                        }
                    }
                    .padding()
                    .background(RFTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(RFTheme.cardBorder)
                    )
                }
            }
        } else if performances.isEmpty {
            EmptyCard(
                icon: "clock",
                title: "No history yet",
                text: "Complete this exercise in a workout to populate its history."
            )
        } else {
            ForEach(Array(performances.reversed().enumerated()), id: \.offset) { _, p in
                HStack {
                    VStack(alignment: .leading) {
                        Text(p.date.formatted(date: .abbreviated, time: .omitted)).bold()
                        Text("\(L10n.text("Volume", "Volume")) \(Int(AppPreferences.displayVolume(p.volume))) \(AppPreferences.weightLabel)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(AppPreferences.displayWeight(p.weight).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.weightLabel)")
                        .font(.headline)
                        .foregroundStyle(RFTheme.accent)
                }
                .padding()
                .background(RFTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    @ViewBuilder
    private var charts: some View {
        if exercise.movement == "cardio" {
            if cardioPerformances.isEmpty {
                EmptyCard(
                    icon: "chart.xyaxis.line",
                    title: L10n.text("No cardio chart data", "Geen cardiografiekdata"),
                    text: L10n.text("Distance and duration trends appear after completed cardio sessions.", "Afstand- en duurtrends verschijnen na voltooide cardiosessies.")
                )
            } else {
                Text(L10n.text("Distance", "Afstand"))
                    .font(.title3.bold())

                Chart {
                    ForEach(Array(cardioPerformances.enumerated()), id: \.offset) { _, p in
                        LineMark(
                            x: .value("Date", p.date),
                            y: .value("Distance", AppPreferences.displayDistance(p.distanceKm))
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(RFTheme.accent)

                        PointMark(
                            x: .value("Date", p.date),
                            y: .value("Distance", AppPreferences.displayDistance(p.distanceKm))
                        )
                        .foregroundStyle(RFTheme.accent)
                    }
                }
                .frame(height: 220)

                Text(L10n.text("Duration", "Duur"))
                    .font(.title3.bold())
                    .padding(.top, 8)

                Chart {
                    ForEach(Array(cardioPerformances.enumerated()), id: \.offset) { _, p in
                        BarMark(
                            x: .value("Date", p.date),
                            y: .value("Minutes", p.duration / 60.0)
                        )
                        .foregroundStyle(RFTheme.accent.gradient)
                    }
                }
                .frame(height: 220)
            }
        } else if performances.isEmpty {
            EmptyCard(
                icon: "chart.xyaxis.line",
                title: "No chart data",
                text: "Your weight progression will appear after completed sessions."
            )
        } else {
            Text("Best weight").font(.title3.bold())
            Chart {
                ForEach(Array(performances.enumerated()), id: \.offset) { _, p in
                    LineMark(
                        x: .value("Date", p.date),
                        y: .value("Weight", AppPreferences.displayWeight(p.weight))
                    )
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", p.date),
                        y: .value("Weight", AppPreferences.displayWeight(p.weight))
                    )
                }
            }
            .frame(height: 220)

            Text("Estimated 1RM").font(.title3.bold()).padding(.top, 8)
            Chart {
                ForEach(Array(performances.enumerated()), id: \.offset) { _, p in
                    AreaMark(
                        x: .value("Date", p.date),
                        y: .value("1RM", AppPreferences.displayWeight(p.oneRM))
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(RFTheme.accent.opacity(0.22))

                    LineMark(
                        x: .value("Date", p.date),
                        y: .value("1RM", AppPreferences.displayWeight(p.oneRM))
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(RFTheme.accent)
                }
            }
            .frame(height: 220)
        }
    }

    @ViewBuilder
    private var records: some View {
        VStack(spacing: 12) {
            HStack {
                Label(recordScopeLabel, systemImage: "scope")
                    .font(.caption.bold())
                    .foregroundStyle(RFTheme.muted)
                Spacer()
            }

            if exercise.movement == "cardio" {
                let longestDistance = cardioPerformances.map(\.distanceKm).max() ?? 0
                let longestDuration = cardioPerformances.map(\.duration).max() ?? 0
                let mostCalories = cardioPerformances.map(\.calories).max() ?? 0
                let fastestPace = cardioPerformances
                    .compactMap { performance -> Double? in
                        guard performance.distanceKm > 0, performance.duration > 0 else { return nil }
                        let displayedDistance = AppPreferences.displayDistance(performance.distanceKm)
                        guard displayedDistance > 0 else { return nil }
                        return performance.duration / displayedDistance
                    }
                    .min()

                RecordRow(
                    name: L10n.text("Longest distance", "Langste afstand"),
                    value: longestDistance > 0
                        ? "\(AppPreferences.displayDistance(longestDistance).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.distanceLabel)"
                        : "—"
                )

                RecordRow(
                    name: L10n.text("Longest duration", "Langste duur"),
                    value: longestDuration > 0 ? cardioDurationText(longestDuration) : "—"
                )

                RecordRow(
                    name: L10n.text("Fastest pace", "Snelste tempo"),
                    value: fastestPace.map { paceText(secondsPerUnit: $0) } ?? "—"
                )

                RecordRow(
                    name: L10n.text("Most calories", "Meeste calorieën"),
                    value: mostCalories > 0 ? "\(Int(mostCalories.rounded())) kcal" : "—"
                )
            } else {
                let bestWeight = performances.map(\.weight).max() ?? 0
                let bestRM = performances.map(\.oneRM).max() ?? 0
                let maxVolume = performances.map(\.volume).max() ?? 0

                RecordRow(
                    name: L10n.text("Best weight", "Beste gewicht"),
                    value: bestWeight > 0
                        ? "\(AppPreferences.displayWeight(bestWeight).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.weightLabel)"
                        : "—"
                )

                RecordRow(
                    name: "Estimated 1RM",
                    value: bestRM > 0
                        ? "\(AppPreferences.displayWeight(bestRM).formatted(.number.precision(.fractionLength(0...1)))) \(AppPreferences.weightLabel)"
                        : "—"
                )

                RecordRow(
                    name: L10n.text("Max session volume", "Max sessievolume"),
                    value: maxVolume > 0
                        ? "\(Int(AppPreferences.displayVolume(maxVolume))) \(AppPreferences.weightLabel)"
                        : "—"
                )
            }
        }
    }

    private func cardioPaceText(duration: Double, distanceKm: Double) -> String? {
        guard duration > 0, distanceKm > 0 else { return nil }
        let distance = AppPreferences.displayDistance(distanceKm)
        guard distance > 0 else { return nil }
        return paceText(secondsPerUnit: duration / distance)
    }

    private func paceText(secondsPerUnit: Double) -> String {
        let minutes = Int(secondsPerUnit) / 60
        let seconds = Int(secondsPerUnit) % 60
        return "\(minutes):\(String(format: "%02d", seconds))/\(AppPreferences.distanceLabel)"
    }

    private var recordScopeLabel: String {
        let period: String
        switch AppPreferences.prScope {
        case "year": period = L10n.text("This year", "Dit jaar")
        case "season": period = L10n.text("Current season", "Huidig seizoen")
        default: period = L10n.text("Lifetime", "Altijd")
        }

        if AppPreferences.separateRecordsByGym {
            return "\(period) • \(GymProfileStore.profile(id: AppPreferences.activeGymID).name)"
        }
        return period
    }
}

struct ExerciseDemoView: View {
    let exercise: ExerciseDefinition
    @StateObject private var model = ExerciseMediaModel()
    @State private var gender = "Male"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Group {
                if model.isLoading {
                    ZStack {
                        Color.black
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(RFTheme.accent)
                            Text("Loading HD exercise demo…")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.65))
                        }
                    }
                } else if let media = model.media,
                          let videoURL = selectedVideoURL(media) {
                    LoopingExerciseVideo(url: videoURL)
                } else if let media = model.media,
                          let imageURL = selectedThumbnailURL(media) {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            ZStack {
                                Color.black
                                image
                                    .resizable()
                                    .scaledToFit()
                            }
                        case .failure:
                            mediaFallback
                        default:
                            ZStack {
                                Color.black
                                ProgressView().tint(RFTheme.accent)
                            }
                        }
                    }
                } else {
                    mediaFallback
                }
            }
            .frame(height: 255)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.10)))

            if let media = model.media {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(media.matchedName)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                        if let sourceURL = media.sourceURL {
                            Link("Demo source: \(media.sourceName)", destination: sourceURL)
                                .font(.caption2)
                                .foregroundStyle(RFTheme.muted)
                        } else {
                            Text("Demo source: \(media.sourceName)")
                                .font(.caption2)
                                .foregroundStyle(RFTheme.muted)
                        }
                    }

                    Spacer()

                    if media.hasBothGenders {
                        Picker("Model", selection: $gender) {
                            Text("M").tag("Male")
                            Text("F").tag("Female")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 88)
                    }
                }
            }
        }
        .task(id: exercise.id) {
            await model.load(exercise: exercise)
        }
    }

    private func selectedVideoURL(_ media: ExerciseMedia) -> URL? {
        if gender == "Female" {
            return media.femaleVideoURL ?? media.maleVideoURL
        }
        return media.maleVideoURL ?? media.femaleVideoURL
    }

    private func selectedThumbnailURL(_ media: ExerciseMedia) -> URL? {
        if gender == "Female" {
            return media.femaleThumbnailURL ?? media.maleThumbnailURL
        }
        return media.maleThumbnailURL ?? media.femaleThumbnailURL
    }

    private var mediaFallback: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, RFTheme.surface],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 10) {
                Image(systemName: "play.slash.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(RFTheme.muted)
                Text("No HD demo found for this exercise")
                    .font(.headline)
                Text("Form instructions are available below.")
                    .font(.caption)
                    .foregroundStyle(RFTheme.muted)
            }
        }
    }
}

final class PlayerLayerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}

struct AVPlayerLayerContainer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.backgroundColor = .black
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        uiView.playerLayer.player = player
        uiView.playerLayer.videoGravity = .resizeAspect
    }
}

struct LoopingExerciseVideo: View {
    let url: URL
    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?
    @State private var isPlaying = true

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.black

            if let player {
                AVPlayerLayerContainer(player: player)
                    .ignoresSafeArea()
            } else {
                ProgressView()
                    .tint(RFTheme.accent)
            }

            Button {
                guard let player else { return }
                isPlaying.toggle()
                if isPlaying {
                    player.play()
                } else {
                    player.pause()
                }
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(.black.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(12)
        }
        .task(id: url) {
            player?.pause()
            player = nil
            looper = nil

            // Play the downloaded local MP4 on subsequent visits, including offline.
            // Streaming remains a fallback when storage is full or downloads fail.
            let playbackURL = (try? await ExerciseVideoCache.shared.localURL(for: url)) ?? url
            guard !Task.isCancelled else { return }

            let item = AVPlayerItem(url: playbackURL)
            let queue = AVQueuePlayer()
            queue.isMuted = true
            queue.actionAtItemEnd = .none

            let loop = AVPlayerLooper(player: queue, templateItem: item)
            player = queue
            looper = loop
            isPlaying = true
            queue.play()
        }
        .onDisappear {
            player?.pause()
        }
    }
}

struct FlowMuscleTags: View {
    let contributions: [MuscleContribution]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 8)], spacing: 8) {
            ForEach(contributions.sorted(by: { $0.weight > $1.weight })) { contribution in
                HStack(spacing: 5) {
                    Circle()
                        .fill(contribution.weight >= 0.8 ? RFTheme.accent : RFTheme.accent.opacity(0.45))
                        .frame(width: 7, height: 7)
                    Text(contribution.muscle)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(RFTheme.raised)
                .clipShape(Capsule())
            }
        }
    }
}

struct MuscleVolumeDashboard: View {
    let entries: [MuscleVolumeEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.text("Weekly muscle volume", "Wekelijks spiervolume"))
                    .font(.title3.bold())
                Spacer()
                Text(L10n.text("effective sets", "effectieve sets"))
                    .font(.caption)
                    .foregroundStyle(RFTheme.muted)
            }

            if entries.isEmpty {
                Text(L10n.text(
                    "Complete working sets this week to build the dashboard.",
                    "Voltooi deze week werksets om het dashboard op te bouwen."
                ))
                .font(.caption)
                .foregroundStyle(RFTheme.muted)
            } else {
                Chart(Array(entries.prefix(10))) { entry in
                    BarMark(
                        x: .value("Sets", entry.sets),
                        y: .value("Muscle", entry.muscle)
                    )
                    .foregroundStyle(RFTheme.accent)
                    .cornerRadius(4)
                    .annotation(position: .trailing) {
                        Text(entry.sets.formatted(.number.precision(.fractionLength(0...1))))
                            .font(.caption2.bold())
                            .foregroundStyle(RFTheme.muted)
                    }
                }
                .frame(height: CGFloat(max(190, min(360, entries.prefix(10).count * 31))))
                .chartXAxis {
                    AxisMarks(position: .bottom)
                }
            }

            Text(L10n.text(
                "Primary muscles count as 1 set; meaningful secondary involvement counts fractionally.",
                "Primaire spieren tellen als 1 set; relevante secundaire belasting telt gedeeltelijk mee."
            ))
            .font(.caption2)
            .foregroundStyle(RFTheme.muted)
        }
        .padding()
        .background(RFTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct MuscleRecoveryDashboard: View {
    let entries: [MuscleRecoveryEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.text("Muscle recovery", "Spierherstel"))
                    .font(.title3.bold())
                Spacer()
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(RFTheme.accent)
            }

            if entries.isEmpty {
                Text(L10n.text(
                    "Recovery estimates appear after completed workouts.",
                    "Herstelschattingen verschijnen na voltooide trainingen."
                ))
                .font(.caption)
                .foregroundStyle(RFTheme.muted)
            } else {
                ForEach(Array(entries.prefix(10))) { entry in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(entry.muscle)
                                .font(.subheadline.bold())
                            Spacer()
                            Text("\(Int(entry.recovery * 100))% • \(entry.status)")
                                .font(.caption.bold())
                                .foregroundStyle(recoveryColor(entry.recovery))
                        }

                        ProgressView(value: entry.recovery)
                            .tint(recoveryColor(entry.recovery))

                        if let last = entry.lastTrained {
                            Text(
                                "\(L10n.text("Last trained", "Laatst getraind")) \(last.formatted(.relative(presentation: .named))) • \(entry.recentSets.formatted(.number.precision(.fractionLength(0...1)))) \(L10n.text("recent sets", "recente sets"))"
                            )
                            .font(.caption2)
                            .foregroundStyle(RFTheme.muted)
                        }
                    }
                }
            }

            Text(L10n.text(
                "Recovery is a training-load estimate based on recent sets and time since training, not a medical measurement.",
                "Herstel is een trainingsbelastingsschatting op basis van recente sets en tijd sinds training, geen medische meting."
            ))
            .font(.caption2)
            .foregroundStyle(RFTheme.muted)
        }
        .padding()
        .background(RFTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func recoveryColor(_ recovery: Double) -> Color {
        if recovery >= 0.85 { return RFTheme.success }
        if recovery >= 0.55 { return RFTheme.accent }
        return .orange
    }
}

struct MuscleHeatMapView: View {
    let entries: [MuscleVolumeEntry]
    let title: String

    private var intensity: [String: Double] {
        let maxValue = max(entries.map(\.sets).max() ?? 1, 1)
        return Dictionary(uniqueKeysWithValues: entries.map {
            ($0.muscle, min(1, $0.sets / maxValue))
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())

            if entries.isEmpty {
                Text(L10n.text("No muscle data yet.", "Nog geen spierdata."))
                    .foregroundStyle(RFTheme.muted)
            } else {
                VStack(spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        BodyMuscleFigure(side: .front, intensity: intensity)
                        BodyMuscleFigure(side: .back, intensity: intensity)
                    }
                    .frame(maxWidth: 420)

                    MuscleHeatLegend()
                        .frame(maxWidth: 220)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 115), spacing: 8)], spacing: 8) {
                    ForEach(Array(entries.prefix(8))) { entry in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(heatColor(intensity[entry.muscle] ?? 0))
                                .frame(width: 8, height: 8)
                            Text(entry.muscle)
                                .font(.caption2)
                                .lineLimit(1)
                            Spacer()
                            Text(entry.sets.formatted(.number.precision(.fractionLength(0...1))))
                                .font(.caption2.bold())
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(RFTheme.raised)
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding()
        .background(RFTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func heatColor(_ value: Double) -> Color {
        MuscleHeatPalette.color(for: value)
    }
}


// MARK: - Profile

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]
    @State private var editing = false
    @State private var showMeasurementEditor = false
    @AppStorage("activeGymID") private var activeGymID = GymProfileStore.defaultID
    @AppStorage("gymRevision") private var gymRevision = 0
    @AppStorage("separateRecordsByGym") private var separateRecordsByGym = true

    private var profile: UserProfile? { profiles.first }
    private var completed: [WorkoutSession] { sessions.filter { $0.endedAt != nil } }

    private var analyticsSessions: [WorkoutSession] {
        guard separateRecordsByGym else { return completed }
        return completed.filter { GymProfileStore.sessionGymID($0) == activeGymID }
    }

    private var weeklyMuscleVolume: [MuscleVolumeEntry] {
        MuscleAnalytics.weeklyVolume(
            sessions: sessions,
            gymID: separateRecordsByGym ? activeGymID : nil
        )
    }

    private var recoveryData: [MuscleRecoveryEntry] {
        MuscleAnalytics.recovery(
            sessions: sessions,
            gymID: separateRecordsByGym ? activeGymID : nil
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let profile {
                    profileDashboard(profile)
                        .padding()
                }
            }
            .background(RFTheme.bg)
            .navigationTitle(L10n.profile)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(L10n.settings)
                }
            }
            .sheet(isPresented: $editing) {
                if let profile {
                    EditProfileView(profile: profile)
                }
            }
            .sheet(isPresented: $showMeasurementEditor) {
                if let profile {
                    BodyMeasurementEditorView(profile: profile)
                }
            }
        }
    }

    @ViewBuilder
    private func profileDashboard(_ profile: UserProfile) -> some View {
        VStack(spacing: 18) {
            ProfileIdentityHeader(
                profile: profile,
                gymName: separateRecordsByGym
                    ? GymProfileStore.profile(id: activeGymID).name
                    : L10n.text("All gyms", "Alle gyms"),
                revision: gymRevision
            )

            ForgeMomentumCard(sessions: analyticsSessions)

            WorkoutActivityHeatmap(sessions: analyticsSessions)

            MuscleIntelligencePanel(sessions: sessions)

            ProfileStatsGrid(
                workoutCount: completed.count,
                totalVolume: completed.reduce(0) { $0 + $1.totalVolume },
                workoutsThisWeek: workoutsThisWeek,
                streak: currentStreak,
                completedSets: totalCompletedSets,
                averageDuration: averageDuration
            )

            ProfileActivityCard(activityData: activityData)

            BodyMeasurementsCard(
                measurements: measurements,
                onAdd: { showMeasurementEditor = true }
            )

            MuscleVolumeDashboard(entries: weeklyMuscleVolume)
            MuscleRecoveryDashboard(entries: recoveryData)

            Button {
                editing = true
            } label: {
                Label(L10n.text("Edit Local Profile", "Lokaal profiel bewerken"), systemImage: "pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var workoutsThisWeek: Int {
        let calendar = Calendar.current
        guard let start = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return 0 }
        return analyticsSessions.filter { $0.startedAt >= start }.count
    }

    private var totalCompletedSets: Int {
        analyticsSessions.reduce(0) { partial, session in
            partial + session.exercises.flatMap(\.sets).filter(\.completed).count
        }
    }

    private var averageDuration: String {
        guard !analyticsSessions.isEmpty else { return "00:00" }
        let average = analyticsSessions.reduce(0.0) { $0 + $1.duration } / Double(analyticsSessions.count)
        return durationString(average)
    }

    private var currentStreak: Int {
        let calendar = Calendar.current
        let weeks = Set(analyticsSessions.compactMap {
            calendar.dateInterval(of: .weekOfYear, for: $0.startedAt)?.start
        })

        guard let currentWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return 0 }

        var count = 0
        var cursor = currentWeek
        while weeks.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    private var activityData: [(date: Date, count: Int)] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: cal.date(byAdding: .day, value: -27, to: .now)!)
        return (0..<28).map { i in
            let date = cal.date(byAdding: .day, value: i, to: start)!
            let count = completed.filter { cal.isDate($0.startedAt, inSameDayAs: date) }.count
            return (date, count)
        }
    }
}

struct BodyMeasurementsCard: View {
    let measurements: [BodyMeasurement]
    let onAdd: () -> Void

    private var chartData: [BodyMeasurement] {
        Array(measurements.prefix(12).reversed())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.text("Body measurements", "Lichaamsmetingen"))
                        .font(.title3.bold())
                    Text(L10n.text("Track trends over time", "Volg trends door de tijd"))
                        .font(.caption)
                        .foregroundStyle(RFTheme.muted)
                }

                Spacer()

                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.headline.bold())
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.borderedProminent)
                .tint(RFTheme.accent)
            }

            if let latest = measurements.first {
                HStack(spacing: 8) {
                    measurementPill(
                        title: L10n.text("Weight", "Gewicht"),
                        value: latest.bodyWeightKg > 0
                            ? "\(AppPreferences.displayWeight(latest.bodyWeightKg).formatted(.number.precision(.fractionLength(0...1)))) \(AppPreferences.weightLabel)"
                            : "—"
                    )

                    measurementPill(
                        title: L10n.text("Body fat", "Vetpercentage"),
                        value: latest.bodyFatPercent.map {
                            "\($0.formatted(.number.precision(.fractionLength(0...1))))%"
                        } ?? "—"
                    )

                    measurementPill(
                        title: L10n.text("Waist", "Taille"),
                        value: lengthText(latest.waistCm)
                    )
                }

                if chartData.count > 1 {
                    Chart(chartData) { item in
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("Weight", AppPreferences.displayWeight(item.bodyWeightKg))
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(RFTheme.accent)

                        PointMark(
                            x: .value("Date", item.date),
                            y: .value("Weight", AppPreferences.displayWeight(item.bodyWeightKg))
                        )
                        .foregroundStyle(RFTheme.accent)
                    }
                    .frame(height: 150)
                }

                if let chest = latest.chestCm,
                   let arm = latest.armCm,
                   let thigh = latest.thighCm {
                    HStack(spacing: 10) {
                        Label("\(L10n.text("Chest", "Borst")) \(lengthText(chest))", systemImage: "figure.arms.open")
                        Label("\(L10n.text("Arm", "Arm")) \(lengthText(arm))", systemImage: "dumbbell.fill")
                        Label("\(L10n.text("Thigh", "Bovenbeen")) \(lengthText(thigh))", systemImage: "figure.walk")
                    }
                    .font(.caption2.bold())
                    .foregroundStyle(RFTheme.muted)
                }
            } else {
                Text(L10n.text(
                    "Add your first measurement to track weight, body fat and circumferences.",
                    "Voeg je eerste meting toe om gewicht, vetpercentage en omtrekken te volgen."
                ))
                .font(.caption)
                .foregroundStyle(RFTheme.muted)
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(RFTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(RFTheme.cardBorder)
        )
    }

    private func measurementPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(RFTheme.muted)
            Text(value)
                .font(.subheadline.bold())
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(RFTheme.field)
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }

    private func lengthText(_ cm: Double?) -> String {
        guard let cm, cm > 0 else { return "—" }
        return "\(AppPreferences.displayHeight(cm).formatted(.number.precision(.fractionLength(0...1)))) \(AppPreferences.heightLabel)"
    }

    private func lengthText(_ cm: Double) -> String {
        "\(AppPreferences.displayHeight(cm).formatted(.number.precision(.fractionLength(0...1)))) \(AppPreferences.heightLabel)"
    }
}

struct BodyMeasurementEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var profile: UserProfile

    @State private var date = Date.now
    @State private var weight: Double
    @State private var bodyFat: Double = 0
    @State private var waist: Double = 0
    @State private var chest: Double = 0
    @State private var arm: Double = 0
    @State private var thigh: Double = 0
    @State private var hip: Double = 0

    init(profile: UserProfile) {
        self.profile = profile
        _weight = State(initialValue: AppPreferences.displayWeight(profile.bodyWeightKg))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.text("Measurement", "Meting")) {
                    DatePicker(
                        L10n.text("Date", "Datum"),
                        selection: $date,
                        displayedComponents: .date
                    )

                    measurementField(
                        L10n.text("Body weight", "Lichaamsgewicht"),
                        unit: AppPreferences.weightLabel,
                        value: $weight
                    )

                    measurementField(
                        L10n.text("Body fat", "Vetpercentage"),
                        unit: "%",
                        value: $bodyFat
                    )
                }

                Section(L10n.text("Circumferences", "Omtrekken")) {
                    measurementField(L10n.text("Waist", "Taille"), unit: AppPreferences.heightLabel, value: $waist)
                    measurementField(L10n.text("Chest", "Borst"), unit: AppPreferences.heightLabel, value: $chest)
                    measurementField(L10n.text("Arm", "Arm"), unit: AppPreferences.heightLabel, value: $arm)
                    measurementField(L10n.text("Thigh", "Bovenbeen"), unit: AppPreferences.heightLabel, value: $thigh)
                    measurementField(L10n.text("Hips", "Heupen"), unit: AppPreferences.heightLabel, value: $hip)
                }
            }
            .navigationTitle(L10n.text("Add Measurement", "Meting toevoegen"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("Cancel", "Annuleren")) { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("Save", "Opslaan")) {
                        save()
                    }
                    .bold()
                }
            }
        }
    }

    @ViewBuilder
    private func measurementField(_ title: String, unit: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            DoneNumberField(
                value: value,
                integerOnly: false,
                placeholder: "0"
            )
            .frame(width: 95, height: 38)

            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)
        }
    }

    private func save() {
        let storedWeight = AppPreferences.storedWeightKg(weight)
        let record = BodyMeasurement(
            date: date,
            bodyWeightKg: storedWeight,
            bodyFatPercent: bodyFat > 0 ? bodyFat : nil,
            waistCm: storedLength(waist),
            chestCm: storedLength(chest),
            armCm: storedLength(arm),
            thighCm: storedLength(thigh),
            hipCm: storedLength(hip)
        )

        context.insert(record)

        if storedWeight > 0 {
            profile.bodyWeightKg = storedWeight
        }

        try? context.save()
        Haptics.success()
        dismiss()
    }

    private func storedLength(_ displayed: Double) -> Double? {
        guard displayed > 0 else { return nil }
        return AppPreferences.storedHeightCm(displayed)
    }
}

struct ProfileIdentityHeader: View {
    let profile: UserProfile
    let gymName: String
    let revision: Int

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [RFTheme.accent.opacity(0.28), RFTheme.accent.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)

                Text(String(profile.displayName.prefix(1)).uppercased())
                    .font(.largeTitle.bold())
                    .foregroundStyle(RFTheme.accent)
            }

            Text(profile.displayName)
                .font(.title.bold())

            Text(profile.bio)
                .foregroundStyle(RFTheme.muted)

            Label(gymName, systemImage: "mappin.and.ellipse")
                .font(.caption.bold())
                .foregroundStyle(RFTheme.accent)
                .id(revision)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RFTheme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(RFTheme.cardBorder)
        )
    }
}

struct ProfileStatsGrid: View {
    let workoutCount: Int
    let totalVolume: Double
    let workoutsThisWeek: Int
    let streak: Int
    let completedSets: Int
    let averageDuration: String

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                StatCard(
                    title: L10n.text("Workouts", "Trainingen"),
                    value: "\(workoutCount)",
                    icon: "dumbbell.fill"
                )
                StatCard(
                    title: L10n.text("Total Volume", "Totaal volume"),
                    value: "\(Int(AppPreferences.displayVolume(totalVolume))) \(AppPreferences.weightLabel)",
                    icon: "chart.bar.fill"
                )
            }

            HStack {
                StatCard(
                    title: L10n.text("This week", "Deze week"),
                    value: "\(workoutsThisWeek)",
                    icon: "calendar"
                )
                StatCard(
                    title: L10n.text("Current streak", "Huidige reeks"),
                    value: "\(streak) \(L10n.text("wk", "wk"))",
                    icon: "flame.fill"
                )
            }

            HStack {
                StatCard(
                    title: L10n.text("Completed sets", "Voltooide sets"),
                    value: "\(completedSets)",
                    icon: "checkmark.circle.fill"
                )
                StatCard(
                    title: L10n.text("Avg duration", "Gem. duur"),
                    value: averageDuration,
                    icon: "timer"
                )
            }
        }
    }
}

struct ProfileActivityCard: View {
    let activityData: [(date: Date, count: Int)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("Training activity", "Trainingsactiviteit"))
                .font(.title3.bold())

            Chart(activityData, id: \.date) { item in
                BarMark(
                    x: .value("Day", item.date, unit: .day),
                    y: .value("Workouts", item.count)
                )
                .foregroundStyle(RFTheme.accent.gradient)
                .cornerRadius(4)
            }
            .frame(height: 190)
            .chartYAxis(.hidden)
        }
        .padding()
        .background(RFTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(RFTheme.cardBorder)
        )
    }
}

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var profile: UserProfile

    var body: some View {
        NavigationStack {
            Form {
                TextField(L10n.text("Display name", "Weergavenaam"), text: $profile.displayName)
                TextField(L10n.text("Bio", "Bio"), text: $profile.bio, axis: .vertical)

                DoneNumberField(
                    value: Binding(
                        get: { AppPreferences.displayWeight(profile.bodyWeightKg) },
                        set: { profile.bodyWeightKg = AppPreferences.storedWeightKg($0) }
                    ),
                    integerOnly: false,
                    placeholder: L10n.text("Body weight", "Lichaamsgewicht")
                )
                .frame(height: 44)
                .overlay(alignment: .trailing) {
                    Text(AppPreferences.weightLabel)
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 10)
                }

                DoneNumberField(
                    value: Binding(
                        get: { AppPreferences.displayHeight(profile.heightCm) },
                        set: { profile.heightCm = AppPreferences.storedHeightCm($0) }
                    ),
                    integerOnly: false,
                    placeholder: L10n.text("Height", "Lengte")
                )
                .frame(height: 44)
                .overlay(alignment: .trailing) {
                    Text(AppPreferences.heightLabel)
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 10)
                }
            }
            .navigationTitle(L10n.profile)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("Save", "Opslaan")) {
                        try? context.save()
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}

// MARK: - Settings

struct ThemeSelector: View {
    @Binding var selection: String

    private let themes: [(id: String, name: String, bg: Color, card: Color, accent: Color)] = [
        ("forge", "Forge Blue", Color(red: 0.055, green: 0.070, blue: 0.078), Color(red: 0.105, green: 0.135, blue: 0.150), Color(red: 0.18, green: 0.63, blue: 1.0)),
        ("oled", "OLED", .black, Color(red: 0.055, green: 0.055, blue: 0.060), Color(red: 0.18, green: 0.63, blue: 1.0)),
        ("graphite", "Graphite", Color(red: 0.075, green: 0.075, blue: 0.082), Color(red: 0.125, green: 0.125, blue: 0.135), Color(red: 0.18, green: 0.63, blue: 1.0)),
        ("navy", "Navy", Color(red: 0.025, green: 0.055, blue: 0.095), Color(red: 0.070, green: 0.105, blue: 0.155), Color(red: 0.18, green: 0.63, blue: 1.0)),
        ("emerald", "Emerald", Color(red: 0.025, green: 0.080, blue: 0.065), Color(red: 0.055, green: 0.145, blue: 0.110), Color(red: 0.10, green: 0.78, blue: 0.48)),
        ("orange", "Orange", Color(red: 0.105, green: 0.055, blue: 0.025), Color(red: 0.175, green: 0.095, blue: 0.045), Color(red: 1.0, green: 0.48, blue: 0.12)),
        ("purple", "Purple", Color(red: 0.070, green: 0.040, blue: 0.105), Color(red: 0.125, green: 0.075, blue: 0.180), Color(red: 0.63, green: 0.43, blue: 1.0)),
        ("midnight", "Midnight", Color(red: 0.012, green: 0.020, blue: 0.055), Color(red: 0.038, green: 0.055, blue: 0.115), Color(red: 0.40, green: 0.56, blue: 1.0)),
        ("cyan", "Arctic Cyan", Color(red: 0.018, green: 0.070, blue: 0.082), Color(red: 0.040, green: 0.130, blue: 0.148), Color(red: 0.08, green: 0.82, blue: 0.94)),
        ("teal", "Deep Teal", Color(red: 0.018, green: 0.065, blue: 0.060), Color(red: 0.038, green: 0.125, blue: 0.110), Color(red: 0.08, green: 0.80, blue: 0.68)),
        ("crimson", "Crimson", Color(red: 0.085, green: 0.022, blue: 0.032), Color(red: 0.155, green: 0.050, blue: 0.065), Color(red: 1.0, green: 0.24, blue: 0.36)),
        ("rose", "Rose", Color(red: 0.082, green: 0.030, blue: 0.064), Color(red: 0.150, green: 0.060, blue: 0.120), Color(red: 1.0, green: 0.36, blue: 0.68)),
        ("gold", "Gold", Color(red: 0.095, green: 0.070, blue: 0.020), Color(red: 0.160, green: 0.115, blue: 0.035), Color(red: 1.0, green: 0.72, blue: 0.18)),
        ("forest", "Forest", Color(red: 0.030, green: 0.060, blue: 0.035), Color(red: 0.060, green: 0.120, blue: 0.070), Color(red: 0.32, green: 0.78, blue: 0.38)),
        ("slate", "Slate", Color(red: 0.045, green: 0.052, blue: 0.065), Color(red: 0.095, green: 0.110, blue: 0.135), Color(red: 0.64, green: 0.72, blue: 0.84)),
        ("neon", "Neon", Color(red: 0.018, green: 0.028, blue: 0.024), Color(red: 0.035, green: 0.085, blue: 0.060), Color(red: 0.30, green: 1.0, blue: 0.54))
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.text("Theme", "Thema"))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(themes, id: \.id) { theme in
                        Button {
                            selection = theme.id
                            Haptics.light()
                        } label: {
                            VStack(spacing: 7) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(theme.bg)
                                        .frame(width: 72, height: 48)

                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(theme.card)
                                        .frame(width: 48, height: 28)

                                    Circle()
                                        .fill(theme.accent)
                                        .frame(width: 13, height: 13)
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(selection == theme.id ? theme.accent : Color.secondary.opacity(0.25), lineWidth: selection == theme.id ? 2.5 : 1)
                                )

                                Text(theme.name)
                                    .font(.caption2)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct PlateCalculatorView: View {
    @State private var targetWeight: Double = AppPreferences.isImperial ? 225 : 100
    @State private var barWeight: Double = AppPreferences.isImperial ? 45 : 20

    private var plates: [Double] {
        AppPreferences.isImperial
            ? [45, 35, 25, 10, 5, 2.5]
            : [25, 20, 15, 10, 5, 2.5, 1.25]
    }

    private var calculation: [(Double, Int)] {
        var remaining = max(0, (targetWeight - barWeight) / 2)
        var result: [(Double, Int)] = []

        for plate in plates {
            let count = Int((remaining + 0.0001) / plate)
            if count > 0 {
                result.append((plate, count))
                remaining -= Double(count) * plate
            }
        }
        return result
    }

    private var actualWeight: Double {
        barWeight + calculation.reduce(0) { $0 + ($1.0 * Double($1.1) * 2) }
    }

    var body: some View {
        Form {
            Section(L10n.text("Target", "Doel")) {
                HStack {
                    Text(L10n.text("Target weight", "Doelgewicht"))
                    Spacer()
                    DoneNumberField(value: $targetWeight, integerOnly: false, placeholder: "0")
                        .frame(width: 100, height: 40)
                    Text(AppPreferences.weightLabel)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text(L10n.text("Bar weight", "Stanggewicht"))
                    Spacer()
                    DoneNumberField(value: $barWeight, integerOnly: false, placeholder: "0")
                        .frame(width: 100, height: 40)
                    Text(AppPreferences.weightLabel)
                        .foregroundStyle(.secondary)
                }
            }

            Section(L10n.text("Load each side", "Belading per kant")) {
                if targetWeight <= barWeight {
                    Text(L10n.text("No plates required.", "Geen schijven nodig."))
                        .foregroundStyle(.secondary)
                } else if calculation.isEmpty {
                    Text(L10n.text("Target cannot be matched with the standard plate set.", "Doel kan niet met de standaard schijven worden gemaakt."))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(calculation.enumerated()), id: \.offset) { _, item in
                        HStack {
                            Image(systemName: "circle.fill")
                                .foregroundStyle(RFTheme.accent)
                            Text("\(item.0.formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.weightLabel)")
                            Spacer()
                            Text("× \(item.1)")
                                .bold()
                        }
                    }

                    LabeledContent(
                        L10n.text("Actual loaded weight", "Werkelijk geladen gewicht"),
                        value: "\(actualWeight.formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.weightLabel)"
                    )
                }
            }

            Section {
                Text(L10n.text(
                    "The calculator assumes the same plates are loaded on both sides of the bar.",
                    "De calculator gaat uit van dezelfde schijven aan beide kanten van de stang."
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(L10n.text("Plate Calculator", "Schijvencalculator"))
    }
}

struct GymManagerView: View {
    @Binding var activeGymID: String
    @State private var gyms = GymProfileStore.load()
    @State private var editingGym: GymProfile?
    @State private var showAdd = false

    var body: some View {
        List {
            Section {
                ForEach(gyms) { gym in
                    Button {
                        activeGymID = gym.id
                        Haptics.light()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: gym.id == activeGymID ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(gym.id == activeGymID ? RFTheme.accent : RFTheme.muted)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(gym.name)
                                    .foregroundStyle(.primary)
                                    .font(.headline)
                                if !gym.note.isEmpty {
                                    Text(gym.note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Button {
                                editingGym = gym
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .swipeActions {
                        if gym.id != GymProfileStore.defaultID {
                            Button(role: .destructive) {
                                GymProfileStore.delete(id: gym.id)
                                gyms = GymProfileStore.load()
                                if activeGymID == gym.id {
                                    activeGymID = GymProfileStore.defaultID
                                }
                            } label: {
                                Label(L10n.text("Delete", "Verwijder"), systemImage: "trash")
                            }
                        }
                    }
                }
            } footer: {
                Text(L10n.text(
                    "The gym attached to a workout determines which previous weights and PRs are shown when gym-specific records are enabled.",
                    "De gym van een training bepaalt welke vorige gewichten en PR's worden getoond wanneer records per gym zijn ingeschakeld."
                ))
            }
        }
        .navigationTitle(L10n.text("Gym Profiles", "Gymprofielen"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $editingGym, onDismiss: reload) { gym in
            GymEditView(gym: gym) { updated in
                GymProfileStore.update(updated)
                reload()
            }
        }
        .sheet(isPresented: $showAdd, onDismiss: reload) {
            GymEditView(
                gym: GymProfile(id: "", name: "", note: ""),
                isNew: true
            ) { newGym in
                let created = GymProfileStore.add(name: newGym.name, note: newGym.note)
                activeGymID = created.id
                reload()
            }
        }
    }

    private func reload() {
        gyms = GymProfileStore.load()
    }
}

struct GymEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var gym: GymProfile
    let isNew: Bool
    let onSave: (GymProfile) -> Void

    init(gym: GymProfile, isNew: Bool = false, onSave: @escaping (GymProfile) -> Void) {
        _gym = State(initialValue: gym)
        self.isNew = isNew
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.text("Gym", "Gym")) {
                    TextField(L10n.text("Gym name", "Naam gym"), text: $gym.name)
                    TextField(
                        L10n.text("Optional note / equipment", "Optionele notitie / apparatuur"),
                        text: $gym.note,
                        axis: .vertical
                    )
                    .lineLimit(2...5)
                }
            }
            .navigationTitle(isNew ? L10n.text("New Gym", "Nieuwe gym") : L10n.text("Edit Gym", "Gym bewerken"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("Cancel", "Annuleren")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("Save", "Opslaan")) {
                        onSave(gym)
                        dismiss()
                    }
                    .bold()
                    .disabled(gym.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct StrongCSVDocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let csvType = UTType(filenameExtension: "csv") ?? .commaSeparatedText
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [csvType, .commaSeparatedText, .plainText, .data],
            asCopy: true
        )
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                onCancel()
                return
            }
            onPick(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var exportSessions: [WorkoutSession]
    @Query(sort: \WorkoutTemplate.createdAt, order: .reverse) private var exportTemplates: [WorkoutTemplate]
    @Query private var exportProfiles: [UserProfile]
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var exportBodyMeasurements: [BodyMeasurement]
    @ObservedObject private var heartRateMonitor = HeartRateMonitor.shared

    @AppStorage("appLanguage") private var appLanguage = "en"
    @AppStorage("measurementSystem") private var measurementSystem = "metric"
    @AppStorage("appearance") private var appearance = "dark"
    @AppStorage("themePreset") private var themePreset = "forge"
    @AppStorage("textSize") private var textSize = "standard"
    @AppStorage("layoutStyle") private var layoutStyle = "balanced"
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("showPreviousSets") private var showPreviousSets = true
    @AppStorage("keepScreenAwake") private var keepScreenAwake = true
    @AppStorage("defaultSets") private var defaultSets = 3
    @AppStorage("defaultRestSeconds") private var defaultRestSeconds = 90
    @AppStorage("autoRestTimer") private var autoRestTimer = true
    @AppStorage("autoCollapseCompleted") private var autoCollapseCompleted = true
    @AppStorage("restNotifications") private var restNotifications = true
    @AppStorage("countdownHaptics") private var countdownHaptics = true
    @AppStorage("compactWorkoutMode") private var compactWorkoutMode = false
    @AppStorage("highContrastWorkout") private var highContrastWorkout = false
    @AppStorage("progressionRule") private var progressionRule = "double"
    @AppStorage("progressionStepKg") private var progressionStepKg = 2.5
    @AppStorage("activeGymID") private var activeGymID = GymProfileStore.defaultID
    @AppStorage("separateRecordsByGym") private var separateRecordsByGym = true
    @AppStorage("prScope") private var prScope = "lifetime"
    @AppStorage("seasonStartDate") private var seasonStartDate = 0.0
    @AppStorage("gymRevision") private var gymRevision = 0

    @State private var showBackupExporter = false
    @State private var showBackupImporter = false
    @State private var showStrongImporter = false
    @State private var backupDocument = RepForgeBackupDocument()
    @State private var backupMessage: String?
    @State private var strongImportMessage: String?

    private var appVersionDisplay: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2.9"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "18"
        return "\(version) (\(build))"
    }

    private var workoutCSV: String {
        var rows: [String] = [
            "date,workout,exercise,set,type,weight_kg,reps,duration_seconds,distance_km,incline_percent,calories,avg_hr,rpe,rir,note"
        ]

        for session in exportSessions where session.endedAt != nil {
            let dateValue = csv(session.startedAt.ISO8601Format())
            let workoutValue = csv(session.title)

            for log in session.exercises.sorted(by: { $0.order < $1.order }) {
                let exerciseName = ExerciseCatalog.find(log.exerciseID)?.name ?? log.exerciseID
                let exerciseValue = csv(exerciseName)

                for set in log.sets.sorted(by: { $0.order < $1.order }) where set.completed {
                    var fields: [String] = []
                    fields.append(dateValue)
                    fields.append(workoutValue)
                    fields.append(exerciseValue)
                    fields.append(String(set.order + 1))
                    fields.append(csv(set.setType))
                    fields.append(csvNumber(set.weightKg))
                    fields.append(String(set.reps))
                    fields.append(optionalCSVNumber(set.durationSeconds))
                    fields.append(optionalCSVNumber(set.distanceKm))
                    fields.append(optionalCSVNumber(set.inclinePercent))
                    fields.append(optionalCSVNumber(set.calories))
                    fields.append(set.averageHeartRate.map(String.init) ?? "")
                    fields.append(optionalCSVNumber(set.rpe))
                    fields.append(set.rir.map(String.init) ?? "")
                    fields.append(csv(set.note ?? ""))
                    rows.append(fields.joined(separator: ","))
                }
            }
        }

        return rows.joined(separator: "\n")
    }

    private func csvNumber(_ value: Double) -> String {
        value.formatted(
            .number
                .locale(Locale(identifier: "en_US_POSIX"))
                .precision(.fractionLength(0...3))
        )
    }

    private func optionalCSVNumber(_ value: Double?) -> String {
        guard let value else { return "" }
        return value.formatted(
            .number
                .locale(Locale(identifier: "en_US_POSIX"))
                .precision(.fractionLength(0...3))
        )
    }

    private var templateBackupText: String {
        exportTemplates.map { template in
            let exercises = template.plannedExercises?.map {
                "\($0.name) | \($0.sets) × \($0.reps)\($0.note.map { " | \($0)" } ?? "")"
            } ?? template.exerciseIDs.compactMap { ExerciseCatalog.find($0)?.name }
            return "# \(template.name)\n" + exercises.joined(separator: "\n")
        }
        .joined(separator: "\n\n")
    }

    private func csv(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.text("Units & region", "Eenheden & regio")) {
                    Picker(L10n.text("Language", "Taal"), selection: $appLanguage) {
                        Text("English").tag("en")
                        Text("Nederlands").tag("nl")
                        Text("Español").tag("es")
                        Text("Deutsch").tag("de")
                        Text("Français").tag("fr")
                    }

                    Picker(L10n.text("Measurement system", "Meetsysteem"), selection: $measurementSystem) {
                        Text(L10n.text("Metric (kg, cm, km)", "Metrisch (kg, cm, km)")).tag("metric")
                        Text(L10n.text("Imperial (lb, in, mi)", "Imperiaal (lb, in, mi)")).tag("imperial")
                    }

                    LabeledContent(L10n.text("Weight", "Gewicht"), value: AppPreferences.weightLabel)
                    LabeledContent(L10n.text("Height", "Lengte"), value: AppPreferences.heightLabel)
                    LabeledContent(L10n.text("Distance", "Afstand"), value: AppPreferences.distanceLabel)
                }

                Section(L10n.text("Appearance", "Weergave")) {
                    Picker(L10n.text("Mode", "Modus"), selection: $appearance) {
                        Text(L10n.text("System", "Systeem")).tag("system")
                        Text(L10n.text("Dark", "Donker")).tag("dark")
                        Text(L10n.text("Light", "Licht")).tag("light")
                    }

                    ThemeSelector(selection: $themePreset)

                    Picker(L10n.text("Layout", "Indeling"), selection: $layoutStyle) {
                        Text(L10n.text("Balanced cards", "Gebalanceerde kaarten")).tag("balanced")
                        Text(L10n.text("Compact lists", "Compacte lijsten")).tag("compact")
                        Text(L10n.text("Focused sections", "Focus op secties")).tag("focused")
                    }
                    Text(L10n.text(
                        "Changes spacing, card shapes, template layout and visual hierarchy—not just colors.",
                        "Verandert afstanden, kaartvormen, template-indeling en visuele hiërarchie, niet alleen kleuren."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Picker(L10n.text("Text size", "Tekstgrootte"), selection: $textSize) {
                        Text(L10n.text("Compact", "Compact")).tag("compact")
                        Text(L10n.text("Standard", "Standaard")).tag("standard")
                        Text(L10n.text("Large", "Groot")).tag("large")
                        Text(L10n.text("Extra large", "Extra groot")).tag("xlarge")
                    }
                }

                Section(L10n.text("Gym & records", "Gym & records")) {
                    NavigationLink {
                        GymManagerView(activeGymID: $activeGymID)
                    } label: {
                        HStack {
                            Label(L10n.text("Gym profiles", "Gymprofielen"), systemImage: "building.2.fill")
                            Spacer()
                            Text(GymProfileStore.profile(id: activeGymID).name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .id(gymRevision)
                    }

                    Toggle(
                        L10n.text("Separate records by gym", "Records per gym scheiden"),
                        isOn: $separateRecordsByGym
                    )

                    Picker(L10n.text("Personal-record period", "Periode persoonlijke records"), selection: $prScope) {
                        Text(L10n.text("Lifetime", "Altijd")).tag("lifetime")
                        Text(L10n.text("This year", "Dit jaar")).tag("year")
                        Text(L10n.text("Current season", "Huidig seizoen")).tag("season")
                    }

                    if prScope == "season" {
                        DatePicker(
                            L10n.text("Season starts", "Seizoen start"),
                            selection: Binding(
                                get: {
                                    seasonStartDate > 0
                                        ? Date(timeIntervalSince1970: seasonStartDate)
                                        : AppPreferences.seasonStartDate
                                },
                                set: { seasonStartDate = $0.timeIntervalSince1970 }
                            ),
                            in: ...Date.now,
                            displayedComponents: .date
                        )
                    }

                    Text(L10n.text(
                        "Previous weights and personal records can be kept separate for each gym. Existing workouts are assigned to Main Gym.",
                        "Vorige gewichten en persoonlijke records kunnen per gym worden bijgehouden. Bestaande trainingen worden aan Hoofdgym toegewezen."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Section(L10n.text("Workout", "Training")) {
                    Stepper(
                        "\(L10n.text("Default sets for new exercises", "Standaard sets voor nieuwe oefeningen")): \(defaultSets)",
                        value: $defaultSets,
                        in: 1...6
                    )

                    Toggle(L10n.text("Show previous sets", "Vorige sets tonen"), isOn: $showPreviousSets)
                    Toggle(L10n.text("Auto-collapse completed exercises", "Voltooide oefeningen automatisch inklappen"), isOn: $autoCollapseCompleted)
                    Toggle(L10n.text("Compact workout layout", "Compacte trainingsweergave"), isOn: $compactWorkoutMode)
                    Toggle(L10n.text("High-contrast workout cards", "Trainingskaarten met hoog contrast"), isOn: $highContrastWorkout)
                    Toggle(L10n.text("Automatic rest timer", "Automatische rusttimer"), isOn: $autoRestTimer)

                    if autoRestTimer {
                        Stepper(
                            "\(L10n.text("Default rest", "Standaard rust")): \(defaultRestSeconds)s",
                            value: $defaultRestSeconds,
                            in: 15...600,
                            step: 15
                        )

                        Toggle(
                            L10n.text("Rest-finished notification + sound", "Melding + geluid wanneer rust voorbij is"),
                            isOn: $restNotifications
                        )
                        .onChange(of: restNotifications) { _, enabled in
                            if enabled {
                                RestNotificationManager.shared.requestAuthorization()
                            } else {
                                RestNotificationManager.shared.cancel()
                            }
                        }

                        Toggle(
                            L10n.text("3-second countdown haptics", "Haptische aftelling van 3 seconden"),
                            isOn: $countdownHaptics
                        )
                    }

                    Picker(
                        L10n.text("Progression rule", "Progressieregel"),
                        selection: $progressionRule
                    ) {
                        Text(L10n.text("Double progression", "Dubbele progressie")).tag("double")
                        Text(L10n.text("Fixed increment", "Vaste verhoging")).tag("fixed")
                        Text(L10n.text("Suggestions off", "Suggesties uit")).tag("off")
                    }

                    if progressionRule != "off" {
                        Stepper(
                            "\(L10n.text("Progression step", "Progressiestap")): \(AppPreferences.displayWeight(progressionStepKg).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.weightLabel)",
                            value: $progressionStepKg,
                            in: 0.25...20,
                            step: 0.25
                        )
                    }

                    Toggle(L10n.text("Keep screen awake during workout", "Scherm aanhouden tijdens training"), isOn: $keepScreenAwake)
                    Toggle(L10n.text("Haptic feedback", "Haptische feedback"), isOn: $hapticsEnabled)
                }

                Section(L10n.text("Heart rate", "Hartslag")) {
                    HStack {
                        Label(
                            heartRateMonitor.isConnected
                                ? (heartRateMonitor.sensorName ?? L10n.text("Connected sensor", "Verbonden sensor"))
                                : L10n.text("Bluetooth HR sensor", "Bluetooth-hartslagsensor"),
                            systemImage: heartRateMonitor.isConnected ? "heart.circle.fill" : "heart.circle"
                        )
                        .foregroundStyle(heartRateMonitor.isConnected ? RFTheme.success : .primary)

                        Spacer()

                        if let bpm = heartRateMonitor.bpm {
                            Text("\(bpm) bpm")
                                .font(.headline)
                                .foregroundStyle(.red)
                        }
                    }

                    if heartRateMonitor.isConnected {
                        Button(role: .destructive) {
                            heartRateMonitor.disconnect()
                        } label: {
                            Label(L10n.text("Disconnect sensor", "Sensor loskoppelen"), systemImage: "xmark.circle")
                        }
                    } else {
                        Button {
                            heartRateMonitor.startScanning()
                        } label: {
                            Label(
                                heartRateMonitor.isScanning
                                    ? L10n.text("Scanning…", "Zoeken…")
                                    : L10n.text("Find heart-rate sensor", "Zoek hartslagsensor"),
                                systemImage: "dot.radiowaves.left.and.right"
                            )
                        }
                        .disabled(heartRateMonitor.isScanning)
                    }

                    Text(L10n.text(
                        "Supports standard Bluetooth Heart Rate Service sensors. When connected, live BPM appears in the workout and can be copied into cardio intervals.",
                        "Ondersteunt standaard Bluetooth Heart Rate Service-sensoren. Na verbinden verschijnt live BPM in de training en kan deze naar cardio-intervallen worden gekopieerd."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Section(L10n.text("Tools", "Hulpmiddelen")) {
                    NavigationLink {
                        PlateCalculatorView()
                    } label: {
                        Label(L10n.text("Plate Calculator", "Schijvencalculator"), systemImage: "circle.grid.2x2.fill")
                    }
                }

                Section(L10n.text("About", "Over")) {
                    LabeledContent(
                        L10n.text("RepForge version", "RepForge-versie"),
                        value: appVersionDisplay
                    )
                    Label(
                        L10n.text(
                            "0.2.9 adds in-app project support and a completely refreshed README.",
                            "0.2.9 voegt ondersteuning voor het project in de app toe en een volledig vernieuwde README."
                        ),
                        systemImage: "sparkles"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    LabeledContent(
                        L10n.text("Exercise media", "Oefenmedia"),
                        value: "Free Exercise DB"
                    )
                }

                Section(L10n.text("Support RepForge", "Steun RepForge")) {
                    Link(destination: URL(string: "https://ko-fi.com/flippyy")!) {
                        HStack(spacing: 12) {
                            Image(systemName: "heart.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.pink)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(L10n.text("Support on Ko-fi", "Steun via Ko-fi"))
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(L10n.text(
                                    "RepForge is free. If you enjoy using it, you can support continued development with an optional donation.",
                                    "RepForge is gratis. Als je de app graag gebruikt, kun je de verdere ontwikkeling steunen met een vrijwillige donatie."
                                ))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(RFTheme.accent)
                        }
                    }
                }

                Section(L10n.text("Storage & export", "Opslag & export")) {
                    LabeledContent(L10n.text("Workout data", "Trainingsdata"), value: L10n.text("Stored locally", "Lokaal opgeslagen"))

                    ShareLink(item: workoutCSV) {
                        Label(L10n.text("Export workout history", "Trainingsgeschiedenis exporteren"), systemImage: "square.and.arrow.up")
                    }

                    ShareLink(item: templateBackupText) {
                        Label(L10n.text("Export templates", "Templates exporteren"), systemImage: "doc.on.doc")
                    }

                    Divider()

                    Button {
                        showStrongImporter = true
                    } label: {
                        Label(
                            L10n.text("Import from Strong CSV", "Importeer vanuit Strong CSV"),
                            systemImage: "arrow.down.doc.fill"
                        )
                    }

                    Text(L10n.text(
                        "Migrates Strong workout history, completed sets, weights, reps, RPE, notes and rest timers. Missing exercises are created automatically. Re-importing the same workout date and name is skipped.",
                        "Migreert Strong-trainingsgeschiedenis, voltooide sets, gewichten, herhalingen, RPE, notities en rusttijden. Ontbrekende oefeningen worden automatisch aangemaakt. Dezelfde trainingsdatum en naam worden bij opnieuw importeren overgeslagen."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Divider()

                    Button {
                        backupDocument = RepForgeBackupDocument(text: makeBackupText())
                        showBackupExporter = true
                    } label: {
                        Label(L10n.text("Full RepForge Backup", "Volledige RepForge-back-up"), systemImage: "externaldrive.fill.badge.plus")
                    }

                    Button {
                        showBackupImporter = true
                    } label: {
                        Label(L10n.text("Restore Full Backup", "Volledige back-up herstellen"), systemImage: "arrow.counterclockwise.circle.fill")
                    }

                    Text(L10n.text(
                        "Full backup includes workout history, templates, profile, custom exercises, gym profiles, planned workouts, program edits, favorites and app settings.",
                        "De volledige back-up bevat trainingsgeschiedenis, templates, profiel, eigen oefeningen, gymprofielen, geplande trainingen, programma-aanpassingen, favorieten en app-instellingen."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

            }
            .scrollContentBackground(.hidden)
            .background(RFTheme.bg)
            .navigationTitle(L10n.settings)
            .fileExporter(
                isPresented: $showBackupExporter,
                document: backupDocument,
                contentType: .json,
                defaultFilename: "RepForge-Backup-\(Date.now.formatted(.dateTime.year().month().day()))"
            ) { result in
                if case .failure(let error) = result {
                    backupMessage = error.localizedDescription
                }
            }
            .fileImporter(
                isPresented: $showBackupImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                restoreBackup(result)
            }
            .sheet(isPresented: $showStrongImporter) {
                StrongCSVDocumentPicker(
                    onPick: { url in
                        showStrongImporter = false
                        importStrongCSV(url)
                    },
                    onCancel: {
                        showStrongImporter = false
                    }
                )
            }
            .alert(
                L10n.text("Strong Import", "Strong-import"),
                isPresented: Binding(
                    get: { strongImportMessage != nil },
                    set: { if !$0 { strongImportMessage = nil } }
                )
            ) {
                Button(L10n.done) { strongImportMessage = nil }
            } message: {
                Text(strongImportMessage ?? "")
            }
            .alert(
                L10n.text("Backup", "Back-up"),
                isPresented: Binding(
                    get: { backupMessage != nil },
                    set: { if !$0 { backupMessage = nil } }
                )
            ) {
                Button(L10n.done) { backupMessage = nil }
            } message: {
                Text(backupMessage ?? "")
            }
        }
    }

    private func importStrongCSV(_ url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let summary = try StrongCSVImporter.importCSV(
                data: data,
                into: context,
                gymID: activeGymID,
                usesImperialUnits: measurementSystem == "imperial"
            )

            var message = L10n.text(
                "Imported \(summary.workoutsImported) workouts and \(summary.setsImported) completed sets from Strong.",
                "\(summary.workoutsImported) trainingen en \(summary.setsImported) voltooide sets uit Strong geïmporteerd."
            )

            if summary.duplicateWorkoutsSkipped > 0 {
                message += "\n" + L10n.text(
                    "Skipped \(summary.duplicateWorkoutsSkipped) workouts that were already in RepForge.",
                    "\(summary.duplicateWorkoutsSkipped) trainingen overgeslagen die al in RepForge stonden."
                )
            }

            if !summary.customExercisesCreated.isEmpty {
                message += "\n" + L10n.text(
                    "Created \(summary.customExercisesCreated.count) missing exercises: \(summary.customExercisesCreated.joined(separator: ", ")).",
                    "\(summary.customExercisesCreated.count) ontbrekende oefeningen aangemaakt: \(summary.customExercisesCreated.joined(separator: ", "))."
                )
            }

            if summary.rowsSkipped > 0 {
                message += "\n" + L10n.text(
                    "Skipped \(summary.rowsSkipped) rows that could not be imported.",
                    "\(summary.rowsSkipped) rijen overgeslagen die niet konden worden geïmporteerd."
                )
            }

            strongImportMessage = message
            Haptics.success()
        } catch {
            strongImportMessage = L10n.text(
                "Could not import Strong CSV: \(error.localizedDescription)",
                "Strong CSV kon niet worden geïmporteerd: \(error.localizedDescription)"
            )
        }
    }

    private func makeBackupText() -> String {
        let templates = exportTemplates.map {
            BackupTemplate(
                id: $0.id,
                name: $0.name,
                exerciseIDs: $0.exerciseIDs,
                plan: $0.plannedExercises,
                createdAt: $0.createdAt
            )
        }

        let sessions = exportSessions.map { session in
            BackupSession(
                id: session.id,
                title: session.title,
                startedAt: session.startedAt,
                endedAt: session.endedAt,
                note: session.note,
                gymID: session.gymID,
                exercises: session.exercises.map { log in
                    BackupExerciseLog(
                        id: log.id,
                        exerciseID: log.exerciseID,
                        order: log.order,
                        targetReps: log.targetReps,
                        coachingNote: log.coachingNote,
                        supersetGroup: log.supersetGroup,
                        sessionNote: log.sessionNote,
                        restSeconds: log.restSeconds,
                        sets: log.sets.map { set in
                            BackupSet(
                                id: set.id,
                                order: set.order,
                                weightKg: set.weightKg,
                                reps: set.reps,
                                completed: set.completed,
                                completedAt: set.completedAt,
                                setTypeRaw: set.setTypeRaw,
                                rpe: set.rpe,
                                rir: set.rir,
                                note: set.note,
                                durationSeconds: set.durationSeconds,
                                distanceKm: set.distanceKm,
                                inclinePercent: set.inclinePercent,
                                calories: set.calories,
                                averageHeartRate: set.averageHeartRate
                            )
                        }
                    )
                }
            )
        }

        let profiles = exportProfiles.map {
            BackupProfile(
                id: $0.id,
                displayName: $0.displayName,
                bio: $0.bio,
                bodyWeightKg: $0.bodyWeightKg,
                heightCm: $0.heightCm,
                createdAt: $0.createdAt
            )
        }

        let bodyMeasurements = exportBodyMeasurements.map {
            BackupBodyMeasurement(
                id: $0.id,
                date: $0.date,
                bodyWeightKg: $0.bodyWeightKg,
                bodyFatPercent: $0.bodyFatPercent,
                waistCm: $0.waistCm,
                chestCm: $0.chestCm,
                armCm: $0.armCm,
                thighCm: $0.thighCm,
                hipCm: $0.hipCm
            )
        }

        let programDays = SwiftDataUserStore.programDays()

        let settings = BackupSettings(
            appLanguage: appLanguage,
            measurementSystem: measurementSystem,
            appearance: appearance,
            themePreset: themePreset,
            textSize: textSize,
            hapticsEnabled: hapticsEnabled,
            showPreviousSets: showPreviousSets,
            keepScreenAwake: keepScreenAwake,
            defaultSets: defaultSets,
            defaultRestSeconds: defaultRestSeconds,
            autoRestTimer: autoRestTimer,
            autoCollapseCompleted: autoCollapseCompleted,
            restNotifications: restNotifications,
            countdownHaptics: countdownHaptics,
            compactWorkoutMode: compactWorkoutMode,
            highContrastWorkout: highContrastWorkout,
            progressionRule: progressionRule,
            progressionStepKg: progressionStepKg,
            activeGymID: activeGymID,
            separateRecordsByGym: separateRecordsByGym,
            prScope: prScope,
            seasonStartDate: seasonStartDate
        )

        let payload = RepForgeBackupPayload(
            version: 1,
            exportedAt: .now,
            templates: templates,
            sessions: sessions,
            profiles: profiles,
            bodyMeasurements: bodyMeasurements,
            customExercises: CustomExerciseStore.load(),
            gyms: GymProfileStore.load(),
            scheduledWorkouts: WorkoutScheduleStore.load(),
            programDays: programDays,
            favorites: ExerciseShortcutStore.favorites,
            recents: ExerciseShortcutStore.recent,
            settings: settings
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(payload) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    private func restoreBackup(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing { url.stopAccessingSecurityScopedResource() }
            }

            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let payload = try decoder.decode(RepForgeBackupPayload.self, from: data)
            try restore(payload)
            backupMessage = L10n.text(
                "Backup restored successfully.",
                "Back-up succesvol hersteld."
            )
        } catch {
            backupMessage = L10n.text(
                "Could not restore backup: \(error.localizedDescription)",
                "Back-up kon niet worden hersteld: \(error.localizedDescription)"
            )
        }
    }

    private func restore(_ payload: RepForgeBackupPayload) throws {
        for session in exportSessions { context.delete(session) }
        for template in exportTemplates { context.delete(template) }
        for profile in exportProfiles { context.delete(profile) }
        for measurement in exportBodyMeasurements { context.delete(measurement) }

        for dto in payload.templates {
            let template = WorkoutTemplate(
                name: dto.name,
                exerciseIDs: dto.exerciseIDs,
                plan: dto.plan
            )
            template.id = dto.id
            template.createdAt = dto.createdAt
            context.insert(template)
        }

        for dto in payload.sessions {
            let logs = dto.exercises.map { logDTO -> ExerciseLog in
                let sets = logDTO.sets.map { setDTO -> WorkoutSet in
                    let set = WorkoutSet(
                        order: setDTO.order,
                        weightKg: setDTO.weightKg,
                        reps: setDTO.reps,
                        completed: setDTO.completed,
                        setTypeRaw: setDTO.setTypeRaw,
                        rpe: setDTO.rpe,
                        rir: setDTO.rir,
                        note: setDTO.note,
                        durationSeconds: setDTO.durationSeconds,
                        distanceKm: setDTO.distanceKm,
                        inclinePercent: setDTO.inclinePercent,
                        calories: setDTO.calories,
                        averageHeartRate: setDTO.averageHeartRate
                    )
                    set.id = setDTO.id
                    set.completedAt = setDTO.completedAt
                    return set
                }

                let log = ExerciseLog(
                    exerciseID: logDTO.exerciseID,
                    order: logDTO.order,
                    targetReps: logDTO.targetReps,
                    coachingNote: logDTO.coachingNote,
                    supersetGroup: logDTO.supersetGroup,
                    sessionNote: logDTO.sessionNote,
                    restSeconds: logDTO.restSeconds,
                    sets: sets
                )
                log.id = logDTO.id
                return log
            }

            let session = WorkoutSession(
                title: dto.title,
                startedAt: dto.startedAt,
                exercises: logs,
                note: dto.note,
                gymID: dto.gymID
            )
            session.id = dto.id
            session.endedAt = dto.endedAt
            context.insert(session)
        }

        for dto in payload.profiles {
            let profile = UserProfile(displayName: dto.displayName)
            profile.id = dto.id
            profile.bio = dto.bio
            profile.bodyWeightKg = dto.bodyWeightKg
            profile.heightCm = dto.heightCm
            profile.createdAt = dto.createdAt
            context.insert(profile)
        }

        for dto in payload.bodyMeasurements ?? [] {
            let measurement = BodyMeasurement(
                date: dto.date,
                bodyWeightKg: dto.bodyWeightKg,
                bodyFatPercent: dto.bodyFatPercent,
                waistCm: dto.waistCm,
                chestCm: dto.chestCm,
                armCm: dto.armCm,
                thighCm: dto.thighCm,
                hipCm: dto.hipCm
            )
            measurement.id = dto.id
            context.insert(measurement)
        }

        CustomExerciseStore.save(payload.customExercises)
        GymProfileStore.save(payload.gyms)
        WorkoutScheduleStore.restore(payload.scheduledWorkouts)
        ExerciseShortcutStore.restore(favorites: payload.favorites, recent: payload.recents)

        SwiftDataUserStore.saveProgramDays(payload.programDays)

        appLanguage = payload.settings.appLanguage
        measurementSystem = payload.settings.measurementSystem
        appearance = payload.settings.appearance
        themePreset = payload.settings.themePreset
        textSize = payload.settings.textSize
        hapticsEnabled = payload.settings.hapticsEnabled
        showPreviousSets = payload.settings.showPreviousSets
        keepScreenAwake = payload.settings.keepScreenAwake
        defaultSets = payload.settings.defaultSets
        defaultRestSeconds = payload.settings.defaultRestSeconds
        autoRestTimer = payload.settings.autoRestTimer
        autoCollapseCompleted = payload.settings.autoCollapseCompleted
        restNotifications = payload.settings.restNotifications ?? true
        countdownHaptics = payload.settings.countdownHaptics ?? true
        compactWorkoutMode = payload.settings.compactWorkoutMode ?? false
        highContrastWorkout = payload.settings.highContrastWorkout ?? false
        progressionRule = payload.settings.progressionRule ?? "double"
        progressionStepKg = payload.settings.progressionStepKg
        activeGymID = payload.settings.activeGymID
        separateRecordsByGym = payload.settings.separateRecordsByGym
        prScope = payload.settings.prScope
        seasonStartDate = payload.settings.seasonStartDate

        try context.save()
    }
}

// MARK: - Shared UI

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(RFTheme.accent)
            Text(value).font(.headline)
            Text(title).font(.caption).foregroundStyle(RFTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RFTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct EmptyCard: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.largeTitle).foregroundStyle(RFTheme.accent)
            Text(title).font(.headline)
            Text(text).multilineTextAlignment(.center).foregroundStyle(RFTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(RFTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct RecordRow: View {
    let name: String
    let value: String

    var body: some View {
        HStack {
            Text(name).font(.headline)
            Spacer()
            Text(value).font(.headline).foregroundStyle(RFTheme.accent)
        }
        .padding()
        .background(RFTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

func durationString(_ interval: TimeInterval) -> String {
    let total = max(0, Int(interval))
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
}
