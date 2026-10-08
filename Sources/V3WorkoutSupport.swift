import SwiftUI
import SwiftData

struct V3ExerciseSelector: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIDs: [String]
    @State private var query = ""
    @State private var muscle = "All"
    @State private var equipment = "All"
    @State private var revision = 0

    private var matching: [ExerciseDefinition] {
        _ = revision
        return ExerciseCatalog.all.filter {
            ExerciseSearch.matches($0, query: query) &&
            (muscle == "All" || $0.muscle == muscle) &&
            GymEquipmentFilter.matches($0, selected: equipment)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 11) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(V3.accent)
                        TextField(L10n.text("Exercise or machine", "Oefening of apparaat"),
                                  text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(14)
                    .background(V3.card, in: RoundedRectangle(cornerRadius: 14))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(GymEquipmentFilter.options, id: \.self) { option in
                                V3CapsuleButton(title: GymEquipmentFilter.label(option),
                                    symbol: equipment == option ? "checkmark" : "circle",
                                    filled: equipment == option) { equipment = option }
                            }
                        }
                    }
                    Menu {
                        Button(L10n.text("All muscle groups", "Alle spiergroepen")) {
                            muscle = "All"
                        }
                        ForEach(ExerciseCatalog.muscles, id: \.self) { option in
                            Button(option) { muscle = option }
                        }
                    } label: {
                        Label(muscle == "All" ? L10n.text("All muscles", "Alle spieren") : muscle,
                              systemImage: "line.3.horizontal.decrease")
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: 44)
                    }

                    Text("\(matching.count) " + L10n.text("movements", "oefeningen"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(V3.faint)

                    ForEach(matching) { item in
                        let chosen = selectedIDs.contains(item.id)
                        Button {
                            if chosen { selectedIDs.removeAll { $0 == item.id } }
                            else {
                                selectedIDs.append(item.id)
                                ExerciseShortcutStore.recordRecent(item.id)
                            }
                            revision += 1
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: chosen ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundStyle(V3.accent)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(item.name)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.primary)
                                    Text(item.muscle + " • " + item.equipment)
                                        .font(.caption).foregroundStyle(V3.faint)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(14)
                            .background(chosen ? V3.accent.opacity(0.12) : V3.card,
                                        in: RoundedRectangle(cornerRadius: 17))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(chosen ? .isSelected : [])
                    }
                }
                .padding(16)
            }
            .background(V3Backdrop())
            .navigationTitle(L10n.addExercise)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("Close", "Sluiten")) { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                V3PrimaryAction(
                    title: selectedIDs.isEmpty ? L10n.done :
                        L10n.text("Add", "Voeg toe") + " \(selectedIDs.count)",
                    symbol: "checkmark"
                ) { dismiss() }
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
            }
        }
    }
}

struct V3ExerciseQueue: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: WorkoutSession
    let onChoose: (Int) -> Void
    private var ordered: [ExerciseLog] { session.exercises.sorted { $0.order < $1.order } }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 11) {
                    V3SectionTitle(
                        title: L10n.text("Today's queue", "Oefeningen van vandaag"),
                        detail: L10n.text("Jump to any movement", "Ga direct naar een oefening")
                    )
                    ForEach(Array(ordered.enumerated()), id: \.element.id) { index, log in
                        Button {
                            onChoose(index)
                        } label: {
                            HStack(spacing: 13) {
                                Text(String(format: "%02d", index + 1))
                                    .font(.title3.bold()).foregroundStyle(V3.accent)
                                    .frame(width: 36)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(ExerciseCatalog.find(log.exerciseID)?.name ?? log.exerciseID)
                                        .font(.headline).foregroundStyle(.primary)
                                    Text("\(log.sets.filter(\.completed).count)/\(log.sets.count) " +
                                         L10n.text("sets", "sets"))
                                        .font(.caption).foregroundStyle(V3.faint)
                                }
                                Spacer()
                                Image(systemName: log.sets.allSatisfy(\.completed) && !log.sets.isEmpty ?
                                      "checkmark.circle.fill" : "arrow.right")
                                    .foregroundStyle(V3.accent)
                            }
                            .padding(15)
                            .background(V3.card, in: RoundedRectangle(cornerRadius: 18))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(18)
            }
            .background(V3Backdrop())
            .navigationTitle(L10n.text("Exercise queue", "Oefeningenlijst"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) { dismiss() }
                }
            }
        }
    }
}

struct V3WorkoutCompletion: View {
    @Environment(\.dismiss) private var dismiss
    let session: WorkoutSession
    let history: [WorkoutSession]
    @State private var showFullReport = false
    @State private var reveal = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var setCount: Int { session.exercises.flatMap(\.sets).filter(\.completed).count }
    private var progress: ForgeProgress { ForgeProgress(sessions: history) }
    private var intensity: [String: Double] {
        Dictionary(uniqueKeysWithValues: MuscleAnalytics.sessionVolume(session).map {
            ($0.muscle, min(1, $0.sets / 8.0))
        })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    V3Panel(highlighted: true) {
                        VStack(alignment: .leading, spacing: 13) {
                            HStack {
                                V3Tag(text: "MISSION COMPLETE", tint: V3.energy)
                                Spacer()
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 37))
                                    .foregroundStyle(V3.energy)
                                    .scaleEffect(reveal ? 1 : 0.8)
                                    .animation(reduceMotion ? nil : .spring(response: 0.45),
                                               value: reveal)
                            }
                            Text(L10n.text("You showed up.\nYou did the work.",
                                           "Je kwam opdagen.\nJe deed het werk."))
                                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                            Text(session.title).font(.subheadline).foregroundStyle(V3.faint)
                            Text("+\(25 + setCount * 5) XP")
                                .font(.system(size: 42, weight: .black, design: .rounded))
                                .foregroundStyle(V3.energy)
                                .monospacedDigit()
                        }
                    }
                    HStack(spacing: 9) {
                        V3BigNumber(amount: durationString(session.duration),
                                    caption: L10n.text("TIME", "TIJD"), symbol: "clock")
                        V3BigNumber(amount: "\(setCount)",
                                    caption: L10n.text("SETS", "SETS"), symbol: "checkmark.circle")
                        V3BigNumber(amount: "\(progress.level)",
                                    caption: "LEVEL", symbol: "trophy")
                    }
                    if !intensity.isEmpty {
                        V3Panel {
                            V3SectionTitle(title: L10n.text("Your muscle imprint", "Je spierafdruk"))
                            HStack(alignment: .top, spacing: 10) {
                                BodyMuscleFigure(side: .front, intensity: intensity)
                                BodyMuscleFigure(side: .back, intensity: intensity)
                            }
                            .frame(maxWidth: 330)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    ForgeSessionRewards(session: session, sessions: history)
                    V3PrimaryAction(title: L10n.text("Done", "Klaar"),
                                    symbol: "checkmark", action: { dismiss() })
                    Button {
                        showFullReport = true
                    } label: {
                        Label(L10n.text("Detailed report and personal records",
                                        "Uitgebreid verslag en persoonlijke records"),
                              systemImage: "chart.xyaxis.line")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(18)
            }
            .background(V3Backdrop())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showFullReport) {
                WorkoutSummaryView(session: session, sessions: history) {
                    showFullReport = false
                }
            }
            .onAppear { reveal = true }
        }
    }
}
