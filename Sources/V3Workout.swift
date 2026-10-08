import SwiftUI
import SwiftData
import UIKit
import Combine

// New session surface: one exercise at a time, no nested swipe gestures, no
// per-second whole-screen invalidation. All writes use existing SwiftData IDs.
struct V3WorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var session: WorkoutSession
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var history: [WorkoutSession]

    @State private var selection = 0
    @State private var showQueue = false
    @State private var showPicker = false
    @State private var selectedIDs: [String] = []
    @State private var showFinish = false
    @State private var showSummary = false
    @State private var showNote = false
    @State private var restEnd: Date?
    @State private var restTotal = 90
    @State private var restExercise = ""
    @State private var pendingNote = ""
    @AppStorage("keepScreenAwake") private var keepScreenAwake = true
    @AppStorage("autoRestTimer") private var autoRestTimer = true
    @AppStorage("defaultRestSeconds") private var defaultRestSeconds = 90
    @AppStorage("countdownHaptics") private var countdownHaptics = true

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var logs: [ExerciseLog] { session.exercises.sorted { $0.order < $1.order } }
    private var current: ExerciseLog? { logs.indices.contains(selection) ? logs[selection] : nil }
    private var setsTotal: Int { logs.reduce(0) { $0 + $1.sets.count } }
    private var setsDone: Int { logs.reduce(0) { $0 + $1.sets.filter(\.completed).count } }
    private var completion: Double { setsTotal == 0 ? 0 : Double(setsDone) / Double(setsTotal) }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 17) {
                    header
                    exerciseNavigator
                    if let current {
                        V3ExerciseStage(
                            log: current,
                            history: history,
                            gymID: GymProfileStore.sessionGymID(session),
                            onCompleted: { startRest(for: current) },
                            onMoveUp: { move(current, delta: -1) },
                            onMoveDown: { move(current, delta: 1) },
                            onDuplicate: { duplicate(current) },
                            onRemove: { remove(current) }
                        )
                        .id(current.id)
                    } else {
                        V3Panel {
                            VStack(alignment: .leading, spacing: 13) {
                                Image(systemName: "dumbbell.fill")
                                    .font(.largeTitle).foregroundStyle(V3.accent)
                                Text(L10n.text("Your session is a blank canvas.",
                                               "Je training is nog leeg."))
                                    .font(.title2.bold())
                                Text(L10n.text("Add an exercise to begin logging.",
                                               "Voeg een oefening toe om te beginnen."))
                                    .foregroundStyle(V3.faint)
                            }
                        }
                    }
                    V3PrimaryAction(title: L10n.addExercise, symbol: "plus") {
                        selectedIDs = []
                        showPicker = true
                    }
                    if setsDone > 0 {
                        V3Panel {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(L10n.text("Work visualized", "Je spieractivatie"))
                                        .font(.headline)
                                    Text(L10n.text("Today, by completed sets",
                                                   "Vandaag, per voltooide set"))
                                        .font(.caption).foregroundStyle(V3.faint)
                                }
                                Spacer()
                                V3ProgressArc(value: completion,
                                    title: L10n.text("Workout progress", "Trainingsvoortgang"), diameter: 66)
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 15)
            }
            .background(V3Backdrop())
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(L10n.text("Leave workout open", "Training open laten"))
                }
                ToolbarItem(placement: .principal) {
                    Text("FORGE / LIVE").font(.caption.weight(.heavy))
                        .tracking(2).foregroundStyle(V3.accent)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(L10n.finish) { showFinish = true }
                        .font(.subheadline.bold())
                        .disabled(session.endedAt != nil)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                workoutDock
            }
            .sheet(isPresented: $showQueue) {
                V3ExerciseQueue(session: session, onChoose: { index in
                    selection = index
                    showQueue = false
                })
            }
            .sheet(isPresented: $showPicker, onDismiss: applyPicker) {
                V3ExerciseSelector(selectedIDs: $selectedIDs)
            }
            .sheet(isPresented: $showNote) {
                NavigationStack {
                    Form {
                        TextField(L10n.text("Workout notes", "Trainingsnotities"),
                                  text: $pendingNote, axis: .vertical)
                        .lineLimit(3...10)
                    }
                    .navigationTitle(L10n.text("Workout note", "Trainingsnotitie"))
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(L10n.done) {
                                session.note = pendingNote
                                try? context.save()
                                showNote = false
                            }
                        }
                    }
                }
            }
            .confirmationDialog(
                L10n.text("Finish this workout?", "Training afronden?"),
                isPresented: $showFinish
            ) {
                Button(L10n.text("Finish and save", "Afronden en bewaren")) { finish() }
                Button(L10n.text("Keep training", "Verder trainen"), role: .cancel) {}
            }
            .sheet(isPresented: $showSummary, onDismiss: {
                dismiss()
            }) {
                V3WorkoutCompletion(session: session, history: history)
            }
            .onReceive(tick) { _ in
                guard let end = restEnd else { return }
                let remaining = Int(ceil(end.timeIntervalSinceNow))
                if countdownHaptics && (1...3).contains(remaining) { Haptics.light() }
                if remaining <= 0 {
                    restEnd = nil
                    RestTimerLiveActivityManager.end()
                    Haptics.success()
                }
            }
            .onAppear { UIApplication.shared.isIdleTimerDisabled = keepScreenAwake }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        }
        .tint(V3.accent)
    }

    private var header: some View {
        V3Panel(highlighted: true) {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    V3Tag(text: "SESSION IN PROGRESS")
                    Spacer()
                    Button {
                        pendingNote = session.note ?? ""
                        showNote = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(L10n.text("Workout note", "Trainingsnotitie"))
                }
                Text(session.title)
                    .font(.system(.title, design: .rounded, weight: .heavy))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                HStack {
                    Label("\(setsDone)/\(setsTotal)", systemImage: "checkmark.circle")
                    Spacer()
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Label(durationString(session.duration), systemImage: "clock")
                            .monospacedDigit()
                    }
                }
                .font(.caption.weight(.bold)).foregroundStyle(V3.faint)
                ProgressView(value: completion).tint(V3.accent)
                    .accessibilityLabel(L10n.text("Workout completion", "Trainingsvoortgang"))
            }
        }
    }

    private var exerciseNavigator: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                V3SectionTitle(title: L10n.text("Your movements", "Jouw oefeningen"),
                               action: "\(logs.count)")
                Spacer()
                Button {
                    showQueue = true
                } label: {
                    Label(L10n.text("All", "Alles"), systemImage: "list.bullet")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(logs.enumerated()), id: \.element.id) { index, log in
                        let selected = selection == index
                        let finished = log.sets.allSatisfy(\.completed) && !log.sets.isEmpty
                        Button {
                            UIApplication.shared.sendAction(
                                #selector(UIResponder.resignFirstResponder),
                                to: nil, from: nil, for: nil
                            )
                            selection = index
                        } label: {
                            HStack(spacing: 7) {
                                Text("\(index + 1)")
                                Image(systemName: finished ? "checkmark.circle.fill" : "circle")
                            }
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(selected ? (V3.isLight ? Color.white : V3.background) : V3.faint)
                            .frame(minWidth: 67, minHeight: 45)
                            .background(selected ? V3.accent : V3.card, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(ExerciseCatalog.find(log.exerciseID)?.name ??
                                            L10n.text("Exercise", "Oefening"))
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }
            HStack {
                Button {
                    selection = max(0, selection - 1)
                } label: { Label(L10n.text("Previous", "Vorige"), systemImage: "chevron.left") }
                    .disabled(selection == 0)
                Spacer()
                if !logs.isEmpty {
                    Text("\(selection + 1) / \(logs.count)")
                        .font(.caption.bold()).foregroundStyle(V3.faint)
                }
                Spacer()
                Button {
                    selection = min(max(0, logs.count - 1), selection + 1)
                } label: {
                    Label(L10n.text("Next", "Volgende"), systemImage: "chevron.right")
                }
                .disabled(logs.isEmpty || selection >= logs.count - 1)
            }
            .font(.subheadline.weight(.semibold))
            .frame(minHeight: 44)
        }
    }

    @ViewBuilder
    private var workoutDock: some View {
        if let end = restEnd {
            RestTimerDock(
                endDate: end,
                exerciseName: restExercise,
                totalSeconds: restTotal,
                onAdjust: { seconds in
                    restEnd = end.addingTimeInterval(TimeInterval(seconds))
                    restTotal = max(1, restTotal + seconds)
                    updateActivity()
                },
                onReset: {
                    restEnd = .now.addingTimeInterval(TimeInterval(restTotal))
                    updateActivity()
                },
                onSkip: { endRest() }
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 5)
            .background(.ultraThinMaterial)
        }
    }

    private func startRest(for log: ExerciseLog) {
        guard autoRestTimer else { return }
        let seconds = max(1, log.restSeconds ?? defaultRestSeconds)
        restTotal = seconds
        restExercise = ExerciseCatalog.find(log.exerciseID)?.name ?? ""
        restEnd = .now.addingTimeInterval(TimeInterval(seconds))
        RestNotificationManager.shared.schedule(seconds: seconds, exerciseName: restExercise)
        updateActivity()
    }

    private func updateActivity() {
        guard let end = restEnd else { return }
        RestTimerLiveActivityManager.startOrUpdate(
            workoutTitle: session.title,
            exerciseName: restExercise,
            endDate: end,
            totalSeconds: restTotal
        )
    }

    private func endRest() {
        restEnd = nil
        RestTimerLiveActivityManager.end()
        RestNotificationManager.shared.cancel()
    }

    private func applyPicker() {
        let existing = Set(session.exercises.map(\.exerciseID))
        var next = (logs.map(\.order).max() ?? -1) + 1
        let first = next
        for id in selectedIDs where !existing.contains(id) {
            let cardinal = ExerciseCatalog.find(id)?.movement == "cardio" ? 1 : AppPreferences.defaultSets
            session.exercises.append(
                ExerciseLog(exerciseID: id, order: next,
                            sets: (0..<max(1, cardinal)).map { WorkoutSet(order: $0) })
            )
            next += 1
        }
        if next > first { selection = first }
        selectedIDs = []
        try? context.save()
    }

    private func move(_ log: ExerciseLog, delta: Int) {
        var list = logs
        guard let index = list.firstIndex(where: { $0.id == log.id }),
              list.indices.contains(index + delta) else { return }
        list.swapAt(index, index + delta)
        for (i, item) in list.enumerated() { item.order = i }
        selection = index + delta
        try? context.save()
        Haptics.light()
    }

    private func duplicate(_ log: ExerciseLog) {
        let sets = log.sets.sorted { $0.order < $1.order }.map {
            WorkoutSet(order: $0.order, weightKg: $0.weightKg,
                       reps: $0.reps, setTypeRaw: $0.setTypeRaw,
                       rpe: $0.rpe, rir: $0.rir, note: $0.note,
                       durationSeconds: $0.durationSeconds, distanceKm: $0.distanceKm,
                       inclinePercent: $0.inclinePercent, calories: $0.calories,
                       averageHeartRate: $0.averageHeartRate)
        }
        session.exercises.append(ExerciseLog(
            exerciseID: log.exerciseID, order: logs.count,
            targetReps: log.targetReps, coachingNote: log.coachingNote,
            supersetGroup: log.supersetGroup, sessionNote: log.sessionNote,
            restSeconds: log.restSeconds, sets: sets
        ))
        selection = logs.count - 1
        try? context.save()
    }

    private func remove(_ log: ExerciseLog) {
        // Detach first: deleting a SwiftData model while its fields are bound to
        // the active editor may invalidate a live UITextField. Orphan maintenance
        // handles cleanup when no active view can reference the old model.
        session.exercises.removeAll { $0.id == log.id }
        for (index, item) in logs.enumerated() { item.order = index }
        selection = max(0, min(selection, logs.count - 1))
        try? context.save()
    }

    private func finish() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                         to: nil, from: nil, for: nil)
        session.endedAt = .now
        endRest()
        try? context.save()
        Haptics.success()
        showSummary = true
    }
}
