import SwiftUI
import SwiftData

struct V3ExerciseStage: View {
    @Environment(\.modelContext) private var context
    @Bindable var log: ExerciseLog
    let history: [WorkoutSession]
    let gymID: String
    let onCompleted: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDuplicate: () -> Void
    let onRemove: () -> Void

    @State private var prior: [(Double, Int)] = []
    @State private var showAdvanced = false
    @State private var confirmRemoval = false
    @State private var noteDraft = ""
    @State private var showNote = false
    private var exercise: ExerciseDefinition? { ExerciseCatalog.find(log.exerciseID) }
    private var cardio: Bool { exercise?.movement == "cardio" }
    private var sets: [WorkoutSet] { log.sets.sorted { $0.order < $1.order } }
    private var completed: Int { sets.filter(\.completed).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            heading
            if let reps = log.targetReps, !reps.isEmpty {
                Label(L10n.text("Target", "Doel") + ": " + reps, systemImage: "scope")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(V3.faint)
            }
            if let note = log.coachingNote, !note.isEmpty {
                Text(note).font(.subheadline).foregroundStyle(V3.faint)
            }
            if let note = log.sessionNote, !note.isEmpty {
                Label(note, systemImage: "note.text").font(.caption).foregroundStyle(V3.faint)
            }
            ForEach(sets) { set in
                if cardio {
                    V3CardioSet(
                        set: set, canDelete: sets.count > 1,
                        onCompleted: { if $0 { onCompleted() } },
                        onDelete: { deleteSet(set) }
                    )
                } else {
                    V3StrengthSet(
                        set: set,
                        previous: prior.indices.contains(set.order) ? prior[set.order] : nil,
                        canDelete: sets.count > 1,
                        onCompleted: { if $0 { onCompleted() } },
                        onDelete: { deleteSet(set) }
                    )
                }
            }
            Button {
                log.sets.append(WorkoutSet(order: sets.count))
                try? context.save()
                Haptics.light()
            } label: {
                Label(cardio ? L10n.text("Add interval", "Interval toevoegen") : L10n.text("Add a set", "Set toevoegen"),
                      systemImage: "plus.circle.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(V3.accent)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(V3.inset, in: RoundedRectangle(cornerRadius: 15))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(V3.card, in: RoundedRectangle(cornerRadius: 23))
        .overlay(RoundedRectangle(cornerRadius: 23).stroke(V3.border))
        .onAppear {
            prior = Metrics.previousSets(
                exerciseID: log.exerciseID, sessions: history, gymID: gymID
            )
        }
        .sheet(isPresented: $showAdvanced) {
            ExerciseLogOptionsView(log: log)
        }
        .sheet(isPresented: $showNote) {
            NavigationStack {
                Form {
                    TextField(L10n.text("Exercise note", "Notitie bij oefening"),
                              text: $noteDraft, axis: .vertical)
                        .lineLimit(3...8)
                }
                .navigationTitle(L10n.text("Exercise note", "Oefeningnotitie"))
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.done) {
                            log.sessionNote = noteDraft
                            try? context.save()
                            showNote = false
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            L10n.text("Remove exercise and all of its sets?", "Oefening en alle sets verwijderen?"),
            isPresented: $confirmRemoval
        ) {
            Button(L10n.text("Remove", "Verwijderen"), role: .destructive, action: onRemove)
            Button(L10n.text("Cancel", "Annuleren"), role: .cancel) {}
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 5) {
                    V3Tag(text: cardio ? "CARDIO" : "STRENGTH")
                    Text(exercise?.name ?? log.exerciseID)
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(exercise?.equipment ?? "")
                        .font(.caption).foregroundStyle(V3.faint)
                }
                Spacer(minLength: 3)
                Menu {
                    Button(L10n.text("Exercise settings", "Oefeninginstellingen"), systemImage: "slider.horizontal.3") {
                        showAdvanced = true
                    }
                    Button(L10n.text("Exercise note", "Oefeningnotitie"), systemImage: "square.and.pencil") {
                        noteDraft = log.sessionNote ?? ""
                        showNote = true
                    }
                    Button(L10n.text("Move up", "Omhoog"), systemImage: "arrow.up", action: onMoveUp)
                    Button(L10n.text("Move down", "Omlaag"), systemImage: "arrow.down", action: onMoveDown)
                    Button(L10n.text("Duplicate", "Dupliceren"), systemImage: "plus.square.on.square", action: onDuplicate)
                    Button(L10n.text("Remove", "Verwijderen"), systemImage: "trash", role: .destructive) {
                        confirmRemoval = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title3.bold())
                        .foregroundStyle(V3.accent)
                        .frame(width: 44, height: 44)
                        .background(V3.inset, in: Circle())
                }
                .accessibilityLabel(L10n.text("Exercise actions", "Oefeningacties"))
            }

            HStack(spacing: 9) {
                Label("\(completed)/\(sets.count) " + L10n.text("sets", "sets"), systemImage: "checkmark.circle")
                    .font(.caption.bold())
                    .foregroundStyle(V3.accent)
                Spacer()
                if let exercise {
                    NavigationLink {
                        ExerciseDetailView(exercise: exercise)
                    } label: {
                        Label(L10n.text("Technique", "Techniek"),
                              systemImage: "play.rectangle")
                            .font(.caption.weight(.semibold))
                            .frame(minHeight: 43)
                    }
                }
            }
        }
    }

    private func deleteSet(_ set: WorkoutSet) {
        guard log.sets.count > 1 else { return }
        log.sets.removeAll { $0.id == set.id }
        // Delete orphan at a safe time to avoid invalidating an editing field.
        for (i, row) in sets.enumerated() { row.order = i }
        try? context.save()
    }
}

struct V3MetricField: View {
    let label: String
    @Binding var value: Double
    var integerOnly = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased())
                .font(.caption2.weight(.heavy))
                .foregroundStyle(V3.faint)
                .lineLimit(1)
            DoneNumberField(value: $value, integerOnly: integerOnly, placeholder: "0")
                .frame(height: 42)
                .background(V3.isLight ? Color.white : V3.card,
                            in: RoundedRectangle(cornerRadius: 11))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(V3.inset, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct V3StrengthSet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Bindable var set: WorkoutSet
    let previous: (Double, Int)?
    let canDelete: Bool
    let onCompleted: (Bool) -> Void
    let onDelete: () -> Void
    @State private var showSetOptions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            entryContent
            previousContent
        }
        .padding(10)
        .background(
            set.completed ? V3.positive.opacity(0.09) : V3.background.opacity(0.68),
            in: RoundedRectangle(cornerRadius: 17)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 17).stroke(
                set.completed ? V3.positive.opacity(0.5) : V3.border
            )
        )
        .sheet(isPresented: $showSetOptions) {
            SetOptionsView(set: set)
        }
    }

    @ViewBuilder
    private var entryContent: some View {
        if dynamicType.isAccessibilitySize {
            VStack(spacing: 8) {
                HStack {
                    setNumber
                    Spacer()
                    actions
                    complete
                }
                inputs
            }
        } else {
            HStack(spacing: 7) {
                setNumber
                inputs
                complete
                actions
            }
        }
    }

    @ViewBuilder
    private var previousContent: some View {
        if let previous {
            HStack(spacing: 7) {
                Text(previousDescription(weight: previous.0, reps: previous.1))
                    .font(.caption)
                    .foregroundStyle(V3.faint)
                Spacer(minLength: 2)
                if !set.completed {
                    Button {
                        set.weightKg = previous.0
                        set.reps = previous.1
                        try? context.save()
                    } label: {
                        Label(L10n.text("Copy", "Kopieer"), systemImage: "arrow.down.to.line")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(V3.accent)
                            .frame(minHeight: 40)
                    }
                }
            }
        }
    }

    private func previousDescription(weight: Double, reps: Int) -> String {
        let value = AppPreferences.displayWeight(weight).formatted(
            .number.precision(.fractionLength(0...2))
        )
        return L10n.text("Last", "Vorig") + ": " +
            value + " " + AppPreferences.weightLabel + " × \(reps)"
    }

    private var setNumber: some View {
        VStack(spacing: 3) {
            Text("\(set.order + 1)").font(.system(.headline, design: .rounded, weight: .heavy))
            if set.setType != "working" {
                Circle().fill(V3.energy).frame(width: 6, height: 6)
            }
        }
        .frame(width: 28, height: 48)
        .accessibilityLabel(L10n.text("Set", "Set") + " \(set.order + 1)")
    }

    private var inputs: some View {
        HStack(spacing: 6) {
            V3MetricField(
                label: AppPreferences.weightLabel,
                value: Binding(
                    get: { AppPreferences.displayWeight(set.weightKg) },
                    set: { set.weightKg = AppPreferences.storedWeightKg($0) }
                )
            )
            V3MetricField(
                label: L10n.text("Reps", "Reps"),
                value: Binding(
                    get: { Double(set.reps) },
                    set: { set.reps = max(0, Int($0.rounded())) }
                ),
                integerOnly: true
            )
        }
    }

    private var complete: some View {
        Button {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                             to: nil, from: nil, for: nil)
            set.completed.toggle()
            set.completedAt = set.completed ? .now : nil
            try? context.save()
            if set.completed { Haptics.success() } else { Haptics.light() }
            onCompleted(set.completed)
        } label: {
            Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                .font(.title2.weight(.semibold))
                .foregroundStyle(set.completed ? V3.positive : V3.accent)
                .frame(width: 46, height: 62)
                .background(V3.inset, in: RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(set.completed
            ? L10n.text("Unmark completed", "Voltooide set ongedaan maken")
            : L10n.text("Complete set", "Set voltooien"))
    }

    private var actions: some View {
        Menu {
            Button(L10n.text("Set details", "Setdetails"), systemImage: "slider.horizontal.3") {
                showSetOptions = true
            }
            if canDelete {
                Button(L10n.text("Delete set", "Set verwijderen"),
                       systemImage: "trash", role: .destructive, action: onDelete)
            }
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: 30, height: 50)
                .foregroundStyle(V3.faint)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(L10n.text("More set options", "Meer setopties"))
    }
}

struct V3CardioSet: View {
    @Environment(\.modelContext) private var context
    @Bindable var set: WorkoutSet
    let canDelete: Bool
    let onCompleted: (Bool) -> Void
    let onDelete: () -> Void
    @State private var showAdvanced = false

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text(L10n.text("Interval", "Interval") + " \(set.order + 1)")
                    .font(.headline)
                Spacer()
                Menu {
                    Button(L10n.text("Advanced set fields", "Geavanceerde setvelden"),
                           systemImage: "slider.horizontal.3") { showAdvanced = true }
                    if canDelete {
                        Button(L10n.text("Delete interval", "Interval verwijderen"),
                               systemImage: "trash", role: .destructive, action: onDelete)
                    }
                } label: {
                    Image(systemName: "ellipsis").frame(width: 44, height: 44)
                }
            }
            HStack(spacing: 7) {
                V3MetricField(label: L10n.text("Minutes", "Minuten"),
                              value: Binding(
                                get: { (set.durationSeconds ?? 0) / 60 },
                                set: { set.durationSeconds = $0 > 0 ? $0 * 60 : nil }
                              ))
                V3MetricField(label: AppPreferences.distanceLabel,
                              value: Binding(
                                get: { AppPreferences.displayDistance(set.distanceKm ?? 0) },
                                set: {
                                    let km = AppPreferences.storedDistanceKm($0)
                                    set.distanceKm = km > 0 ? km : nil
                                }
                              ))
            }
            HStack(spacing: 7) {
                V3MetricField(label: L10n.text("Incline %", "Helling %"),
                              value: Binding(
                                get: { set.inclinePercent ?? 0 },
                                set: { set.inclinePercent = $0 > 0 ? $0 : nil }
                              ))
                V3MetricField(label: "KCAL",
                              value: Binding(
                                get: { set.calories ?? 0 },
                                set: { set.calories = $0 > 0 ? $0 : nil }
                              ), integerOnly: true)
                V3MetricField(label: "BPM",
                              value: Binding(
                                get: { Double(set.averageHeartRate ?? 0) },
                                set: {
                                    let number = Int($0.rounded())
                                    set.averageHeartRate = number > 0 ? number : nil
                                }
                              ), integerOnly: true)
            }
            Button {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                 to: nil, from: nil, for: nil)
                set.completed.toggle()
                set.completedAt = set.completed ? .now : nil
                try? context.save()
                if set.completed { Haptics.success() }
                onCompleted(set.completed)
            } label: {
                Label(set.completed ? L10n.text("Interval completed", "Interval afgerond")
                                    : L10n.text("Complete interval", "Interval afronden"),
                      systemImage: set.completed ? "checkmark.circle.fill" : "circle")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 49)
                    .foregroundStyle(set.completed ? V3.positive : V3.accent)
                    .background(V3.inset, in: RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(V3.background.opacity(0.68), in: RoundedRectangle(cornerRadius: 17))
        .sheet(isPresented: $showAdvanced) { SetOptionsView(set: set) }
    }
}
