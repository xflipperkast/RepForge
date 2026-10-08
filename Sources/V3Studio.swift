import SwiftUI
import SwiftData

struct V3Studio: View {
    let onStart: (WorkoutSession) -> Void
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutTemplate.createdAt, order: .reverse) private var templates: [WorkoutTemplate]
    @StateObject private var personal = ProgramPlanStore()
    @State private var section = 0
    @State private var category = "All"
    @State private var query = ""
    @State private var equipment = "All"
    @State private var week = 1
    @State private var editingTemplate: WorkoutTemplate?
    @State private var deleteTemplate: WorkoutTemplate?
    @State private var editDay: ProgramDay?
    @State private var pendingSchedule: ScheduledWorkoutRecord?
    @State private var showCreateTemplate = false
    @State private var showCreateExercise = false
    @State private var showAdvanced = false
    @State private var revision = 0
    @AppStorage("activeGymID") private var gymID = GymProfileStore.defaultID

    private var workouts: [CoachWorkout] {
        CoachWorkoutLibrary.all.filter {
            (category == "All" || $0.category == category) &&
            (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) ||
                $0.focus.localizedCaseInsensitiveContains(query))
        }
    }
    private var exercises: [ExerciseDefinition] {
        _ = revision
        return ExerciseCatalog.all.filter {
            GymEquipmentFilter.matches($0, selected: equipment) &&
            (query.isEmpty || ExerciseSearch.matches($0, query: query))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 19) {
                    header
                    sectionPicker
                    if section == 0 {
                        plans
                    } else if section == 1 {
                        routines
                    } else if section == 2 {
                        exerciseLibrary
                    } else {
                        threeWeeks
                    }
                    advancedAccess
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 30)
            }
            .background(V3Backdrop())
            .scrollIndicators(.hidden)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $editingTemplate) { item in
                TemplateEditorView(template: item)
            }
            .sheet(item: $editDay) { day in
                ProgramDayEditorView(day: day) { updated in personal.save(updated) }
            }
            .sheet(item: $pendingSchedule) { record in
                ScheduleWorkoutSheet(seed: record) { updated in
                    WorkoutScheduleStore.update(updated)
                }
            }
            .sheet(isPresented: $showCreateTemplate) { TemplateEditorView() }
            .sheet(isPresented: $showCreateExercise, onDismiss: { revision += 1 }) {
                CustomExerciseEditorView()
            }
            .sheet(isPresented: $showAdvanced) { StartWorkoutView() }
            .confirmationDialog(
                L10n.text("Delete routine?", "Schema verwijderen?"),
                isPresented: Binding(get: { deleteTemplate != nil },
                                     set: { if !$0 { deleteTemplate = nil } })
            ) {
                Button(L10n.text("Delete", "Verwijderen"), role: .destructive) {
                    if let template = deleteTemplate {
                        context.delete(template)
                        try? context.save()
                    }
                    deleteTemplate = nil
                }
                Button(L10n.text("Cancel", "Annuleren"), role: .cancel) {}
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            V3Tag(text: "TRAINING / STUDIO")
            Text(L10n.text("Build the work.", "Bouw je training."))
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                .accessibilityAddTraits(.isHeader)
            Text(L10n.text("A program for your goals. A movement for every machine.",
                           "Een schema voor elk doel. Een oefening voor elk apparaat."))
                .font(.subheadline).foregroundStyle(V3.faint)
        }
    }

    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                let sections: [(String,String)] = [
                    ("Workouts", "Workouts"), ("My routines", "Mijn schema's"),
                    ("Exercises", "Oefeningen"), ("3-week plan", "3-wekenplan")
                ]
                ForEach(sections.indices, id: \.self) { index in
                    Button {
                        section = index
                        query = ""
                    } label: {
                        Text(L10n.text(sections[index].0, sections[index].1))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(section == index ? (V3.isLight ? Color.white : V3.background) : .primary)
                            .padding(.horizontal, 18)
                            .frame(minHeight: 44)
                            .background(section == index ? V3.accent : V3.card, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(section == index ? .isSelected : [])
                }
            }
        }
    }

    private var plans: some View {
        VStack(alignment: .leading, spacing: 13) {
            V3SectionTitle(title: L10n.text("Training blueprints", "Trainingsschema's"),
                           detail: L10n.text("Browse by goal and time", "Kies op doel en tijd"),
                           action: "\(workouts.count)")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(CoachWorkoutLibrary.categories, id: \.self) { value in
                        V3CapsuleButton(
                            title: value, symbol: category == value ? "checkmark" : "circle",
                            filled: category == value, action: { category = value }
                        )
                    }
                }
            }
            searchField
            ForEach(workouts) { workout in
                NavigationLink {
                    V3Blueprint(workout: workout, onStart: onStart)
                } label: {
                    HStack(spacing: 13) {
                        VStack(alignment: .leading, spacing: 5) {
                            V3Tag(text: workout.category)
                            Text(workout.name).font(.headline.weight(.bold))
                                .foregroundStyle(.primary)
                            Text(workout.focus).font(.caption).foregroundStyle(V3.faint)
                                .lineLimit(2)
                            HStack(spacing: 10) {
                                Label("~\(workout.estimatedMinutes)m", systemImage: "clock")
                                Label("\(workout.exercises.count)", systemImage: "list.number")
                                Text(workout.level)
                            }
                            .font(.caption2).foregroundStyle(V3.faint)
                        }
                        Spacer(minLength: 2)
                        Image(systemName: "arrow.up.right").foregroundStyle(V3.accent)
                    }
                    .padding(16)
                    .background(V3.card, in: RoundedRectangle(cornerRadius: 20))
                }
                .buttonStyle(V3TapStyle())
            }
            V3SectionTitle(title: L10n.text("Training splits", "Meerdaagse programma's"))
            ForEach(CoachWorkoutLibrary.splits) { split in
                NavigationLink {
                    V3SplitDetail(split: split, onStart: onStart)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar").font(.title3).foregroundStyle(V3.accent)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(split.title).font(.headline).foregroundStyle(.primary)
                            Text("~\(split.weeklyMinutes) " + L10n.text("minutes per cycle", "minuten per cyclus"))
                                .font(.caption).foregroundStyle(V3.faint)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(V3.faint)
                    }
                    .padding(15)
                    .background(V3.card, in: RoundedRectangle(cornerRadius: 19))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var routines: some View {
        VStack(alignment: .leading, spacing: 14) {
            V3SectionTitle(title: L10n.text("Your routines", "Jouw schema's"),
                           detail: L10n.text("Reusable plans you control", "Altijd aanpasbaar"))
            V3PrimaryAction(title: L10n.text("Create a routine", "Nieuw schema"),
                            symbol: "plus") { showCreateTemplate = true }
            if templates.isEmpty {
                Text(L10n.text("No routines saved yet. Make your first or save one from the workout library.",
                               "Nog geen eigen schema's. Maak een schema of bewaar er een uit de bibliotheek."))
                    .font(.subheadline).foregroundStyle(V3.faint).padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(V3.card, in: RoundedRectangle(cornerRadius: 18))
            }
            ForEach(templates) { template in
                V3Panel {
                    VStack(alignment: .leading, spacing: 11) {
                        HStack {
                            Text(template.name).font(.headline.weight(.bold))
                            Spacer()
                            Menu {
                                Button(L10n.text("Edit", "Bewerken"), systemImage: "square.and.pencil") {
                                    editingTemplate = template
                                }
                                Button(L10n.text("Duplicate", "Dupliceren"), systemImage: "plus.square.on.square") {
                                    context.insert(WorkoutTemplate(
                                        name: template.name + " Copy",
                                        exerciseIDs: template.exerciseIDs,
                                        plan: template.plannedExercises
                                    ))
                                    try? context.save()
                                }
                                Button(L10n.text("Delete", "Verwijderen"), systemImage: "trash",
                                       role: .destructive) {
                                    deleteTemplate = template
                                }
                            } label: {
                                Image(systemName: "ellipsis").font(.headline)
                                    .frame(width: 44, height: 44)
                            }
                        }
                        Text("\(template.exerciseIDs.count) " + L10n.text("exercises", "oefeningen"))
                            .font(.caption).foregroundStyle(V3.faint)
                        V3PrimaryAction(title: L10n.text("Train this routine", "Start dit schema"),
                                        symbol: "play.fill") {
                            startRoutine(template)
                        }
                    }
                }
            }
        }
    }

    private var exerciseLibrary: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                V3SectionTitle(title: L10n.exercises,
                               detail: "\(exercises.count) " + L10n.text("movements", "oefeningen"))
                Spacer(minLength: 2)
                Button { showCreateExercise = true } label: {
                    Image(systemName: "plus").font(.headline)
                        .foregroundStyle(V3.accent)
                        .frame(width: 46, height: 46)
                        .background(V3.card, in: Circle())
                }
                .accessibilityLabel(L10n.text("Add custom exercise", "Eigen oefening toevoegen"))
            }
            searchField
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(GymEquipmentFilter.options, id: \.self) { option in
                        V3CapsuleButton(
                            title: GymEquipmentFilter.label(option),
                            symbol: equipment == option ? "checkmark" : "circle",
                            filled: equipment == option,
                            action: { equipment = option }
                        )
                    }
                }
            }
            ForEach(exercises) { item in
                NavigationLink {
                    ExerciseDetailView(exercise: item)
                } label: {
                    HStack(spacing: 13) {
                        Image(systemName: item.movement == "cardio" ? "figure.run" : "dumbbell.fill")
                            .font(.title3).foregroundStyle(V3.accent)
                            .frame(width: 49, height: 49)
                            .background(V3.inset, in: RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.name).font(.subheadline.weight(.bold)).foregroundStyle(.primary)
                            Text(item.muscle + "  •  " + item.equipment)
                                .font(.caption).foregroundStyle(V3.faint).lineLimit(2)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right").foregroundStyle(V3.accent)
                    }
                    .padding(11)
                    .background(V3.card, in: RoundedRectangle(cornerRadius: 17))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var threeWeeks: some View {
        VStack(alignment: .leading, spacing: 13) {
            V3SectionTitle(title: L10n.text("Your original plan", "Jouw bestaande schema"),
                           detail: L10n.text("Three editable weeks, independent of the new library",
                                             "Drie bewerkbare weken, los van de trainingsbibliotheek"))
            ShareLink(item: RepForgeShareCodec.programURL(
                name: "RepForge 3-Week Program",
                days: BuiltInProgram.days.map { personal.day(for: $0) }
            )) {
                Label(L10n.text("Share program", "Deel programma"),
                      systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(V3.accent)
                    .frame(minHeight: 44)
            }

            Picker("Week", selection: $week) {
                ForEach(1...3, id: \.self) { i in Text("W\(i)").tag(i) }
            }
            .pickerStyle(.segmented)
            ForEach(personal.days(for: week)) { day in
                V3Panel {
                    VStack(alignment: .leading, spacing: 12) {
                        V3Tag(text: day.day.uppercased())
                        Text(day.focus).font(.title3.weight(.bold))
                        Label("~\(TrainingTimeEstimator.minutes(for: day.exercises)) min", systemImage: "clock")
                            .font(.caption).foregroundStyle(V3.faint)
                        ForEach(day.exercises.prefix(5), id: \.self) { exercise in
                            Text("• " + exercise.name).font(.subheadline)
                        }
                        HStack(spacing: 9) {
                            V3CapsuleButton(title: L10n.text("Edit", "Bewerk"), symbol: "pencil") {
                                editDay = day
                            }
                            V3CapsuleButton(title: L10n.text("Start", "Start"), symbol: "play.fill", filled: true) {
                                let session = CoachWorkoutActions.start(
                                    name: day.title + " — " + day.focus,
                                    plan: day.exercises, gymID: gymID, in: context
                                )
                                if let session { onStart(session) }
                            }
                        }
                        HStack {
                            Button {
                                pendingSchedule = ScheduledWorkoutRecord(
                                    date: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now,
                                    title: day.title + " — " + day.focus,
                                    exerciseIDs: day.exercises.compactMap { ExerciseCatalog.findByName($0.name)?.id },
                                    plan: day.exercises,
                                    gymID: gymID,
                                    sourceLabel: "3-week plan"
                                )
                            } label: {
                                Label(L10n.text("Schedule", "Plannen"), systemImage: "calendar.badge.plus")
                                    .frame(minHeight: 44)
                            }
                            Spacer()
                            if personal.isCustomized(day) {
                                Button(role: .destructive) {
                                    personal.reset(day)
                                } label: {
                                    Label(L10n.text("Reset changes", "Herstel wijzigingen"),
                                          systemImage: "arrow.uturn.backward")
                                        .frame(minHeight: 44)
                                }
                            }
                        }
                        .font(.caption.weight(.semibold))
                    }
                }
            }
        }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(V3.accent)
            TextField(L10n.text("Search", "Zoeken"), text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
            }
        }
        .padding(14)
        .background(V3.card, in: RoundedRectangle(cornerRadius: 15))
    }

    private var advancedAccess: some View {
        VStack(alignment: .leading, spacing: 9) {
            Divider()
            Button { showAdvanced = true } label: {
                Label(L10n.text("Advanced routine tools and scheduling",
                                "Geavanceerde schema's en planning"),
                      systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(V3.accent)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            }
        }
    }

    private func startRoutine(_ template: WorkoutTemplate) {
        let plan = template.plannedExercises
            ?? template.exerciseIDs.compactMap { id -> ProgramExercise? in
                guard let exercise = ExerciseCatalog.find(id) else { return nil }
                return ProgramExercise(exercise.name, AppPreferences.defaultSets, "8–12")
            }
        if let session = CoachWorkoutActions.start(name: template.name, plan: plan,
                                                    gymID: gymID, in: context) {
            onStart(session)
        }
    }
}

struct V3Blueprint: View {
    let workout: CoachWorkout
    let onStart: (WorkoutSession) -> Void
    @Environment(\.modelContext) private var context
    @AppStorage("activeGymID") private var gymID = GymProfileStore.defaultID
    @State private var showSchedule = false
    @State private var scheduled: ScheduledWorkoutRecord?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                V3Tag(text: workout.category.uppercased())
                Text(workout.name)
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .accessibilityAddTraits(.isHeader)
                Text(workout.focus).foregroundStyle(V3.faint)
                HStack(spacing: 9) {
                    V3BigNumber(amount: "~\(workout.estimatedMinutes)m", caption: "TIME", symbol: "clock")
                    V3BigNumber(amount: "\(workout.totalSets)", caption: "SETS", symbol: "checkmark.circle")
                }
                V3SectionTitle(title: L10n.text("Your session", "Jouw training"))
                ForEach(Array(workout.exercises.enumerated()), id: \.offset) { index, exercise in
                    V3Panel {
                        HStack {
                            Text(String(format: "%02d", index + 1)).font(.title2.bold())
                                .foregroundStyle(V3.accent).frame(width: 42)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(exercise.name).font(.headline)
                                Text("\(exercise.sets) × \(exercise.reps)")
                                    .foregroundStyle(V3.accent).font(.subheadline.bold())
                                if let note = exercise.note {
                                    Text(note).font(.caption).foregroundStyle(V3.faint)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                V3PrimaryAction(title: L10n.text("Start workout", "Start training"),
                                symbol: "play.fill") { start() }
                HStack {
                    V3CapsuleButton(title: L10n.text("Save routine", "Bewaar schema"), symbol: "bookmark") {
                        CoachWorkoutActions.saveTemplate(workout, in: context)
                        Haptics.success()
                    }
                    V3CapsuleButton(title: L10n.text("Schedule", "Plannen"), symbol: "calendar") {
                        scheduled = ScheduledWorkoutRecord(
                            date: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now,
                            title: workout.name,
                            exerciseIDs: workout.exercises.compactMap { ExerciseCatalog.findByName($0.name)?.id },
                            plan: workout.exercises,
                            gymID: gymID,
                            sourceLabel: "Training library")
                    }
                }
                Text(L10n.text("Estimated time includes warm-up, work and rest.",
                               "Tijdsduur is inclusief warming-up, sets en rust."))
                    .font(.caption).foregroundStyle(V3.faint)
            }
            .padding(18)
        }
        .background(V3Backdrop())
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .sheet(item: $scheduled) { item in
            ScheduleWorkoutSheet(seed: item) { updated in
                WorkoutScheduleStore.update(updated)
            }
        }
    }

    private func start() {
        if let session = CoachWorkoutActions.start(
            name: workout.name, plan: workout.exercises, gymID: gymID, in: context
        ) {
            onStart(session)
        }
    }
}

struct V3SplitDetail: View {
    let split: CoachTrainingSplit
    let onStart: (WorkoutSession) -> Void
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 15) {
                V3Tag(text: split.level)
                Text(split.title).font(.largeTitle.bold())
                Text(split.description).foregroundStyle(V3.faint)
                ForEach(split.workouts) { workout in
                    NavigationLink {
                        V3Blueprint(workout: workout, onStart: onStart)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(workout.name).font(.headline).foregroundStyle(.primary)
                                Text("~\(workout.estimatedMinutes) min")
                                    .font(.caption).foregroundStyle(V3.faint)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(V3.accent)
                        }
                        .padding(17)
                        .background(V3.card, in: RoundedRectangle(cornerRadius: 19))
                    }
                }
            }
            .padding(18)
        }
        .background(V3Backdrop())
        .navigationTitle(split.title)
        .toolbar(.visible, for: .navigationBar)
    }
}
