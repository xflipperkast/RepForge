import SwiftUI

struct NextWorkoutBlueprintView: View {
    let workout: CoachWorkout
    let onStart: () -> Void
    let onSave: () -> Void
    let onSchedule: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 13) {
                    NextEyebrow(text: workout.category + " / " + workout.level)
                    Text(workout.name)
                        .font(.system(.largeTitle, design: .rounded, weight: .black))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(workout.focus)
                        .font(.subheadline)
                        .foregroundStyle(NextStyle.muted)
                    HStack(spacing: 10) {
                        NextStat(symbol: "clock",
                                 value: "~\(workout.estimatedMinutes)m",
                                 title: L10n.text("Estimated", "Geschat"))
                        NextStat(symbol: "figure.strengthtraining.traditional",
                                 value: "\(workout.exercises.count)",
                                 title: L10n.text("Exercises", "Oefeningen"))
                        NextStat(symbol: "checkmark.circle",
                                 value: "\(workout.totalSets)",
                                 title: L10n.text("Sets", "Sets"))
                    }
                }
                .nextSurface(prominent: true, radius: 27)

                NextHeading(
                    title: L10n.text("Session blueprint", "Trainingsopbouw"),
                    subtitle: L10n.text("A plan you can actually follow", "Een schema om te volgen")
                )

                ForEach(Array(workout.exercises.enumerated()), id: \.offset) { index, item in
                    blueprintRow(index, item)
                }

                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(NextStyle.electric)
                    Text(L10n.text(
                        "Time includes warm-up, working sets, rest and equipment transitions. Adjust rest and load to your capacity.",
                        "Tijdsduur omvat warming-up, sets, rust en wisselen van apparatuur. Pas je rust en gewicht aan je niveau aan."
                    ))
                    .font(.caption)
                    .foregroundStyle(NextStyle.muted)
                }
                .nextSurface()
            }
            .padding(18)
            .padding(.bottom, 25)
        }
        .nextCanvas()
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionDock
        }
    }

    private func blueprintRow(_ index: Int, _ item: ProgramExercise) -> some View {
        HStack(alignment: .center, spacing: 13) {
            VStack {
                Text(String(format: "%02d", index + 1))
                    .font(.system(.title3, design: .rounded, weight: .black))
                    .monospacedDigit()
                    .foregroundStyle(NextStyle.electric)
            }
            .frame(width: 42, height: 46)
            .background(NextStyle.electric.opacity(0.11),
                        in: RoundedRectangle(cornerRadius: 13))

            VStack(alignment: .leading, spacing: 6) {
                Text(item.name)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(item.sets) × \(item.reps)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(NextStyle.electric)
                if let note = item.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(NextStyle.muted)
                }
            }

            Spacer(minLength: 2)

            if let exercise = ExerciseCatalog.findByName(item.name) {
                NavigationLink {
                    ExerciseDetailView(exercise: exercise)
                } label: {
                    Image(systemName: "play.rectangle.on.rectangle")
                        .font(.headline)
                        .foregroundStyle(NextStyle.electric)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(L10n.text("Show exercise technique", "Bekijk oefeninguitleg"))
            }
        }
        .nextSurface(radius: 18)
        .accessibilityElement(children: .contain)
    }

    private var actionDock: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    NextPrimaryButton(
                        title: L10n.text("Start this session", "Start deze training"),
                        symbol: "play.fill", action: onStart
                    )
                    HStack {
                        accessoryAction(L10n.text("Save", "Bewaren"),
                                        symbol: "bookmark", action: onSave)
                        accessoryAction(L10n.text("Schedule", "Plannen"),
                                        symbol: "calendar.badge.plus", action: onSchedule)
                    }
                }
            } else {
                HStack(spacing: 9) {
                    Button(action: onStart) {
                        Label(L10n.text("Start workout", "Start training"), systemImage: "play.fill")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(NextStyle.electric,
                                        in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(NextPressStyle())
                    accessoryAction(L10n.text("Save", "Bewaren"),
                                    symbol: "bookmark", action: onSave)
                    accessoryAction(L10n.text("Schedule", "Plannen"),
                                    symbol: "calendar.badge.plus", action: onSchedule)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(NextStyle.ink.opacity(0.97))
    }

    private func accessoryAction(_ text: String, symbol: String,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(NextStyle.electric)
                .frame(minWidth: 49, minHeight: 54)
                .background(NextStyle.panel, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(NextPressStyle())
        .accessibilityLabel(text)
    }
}
