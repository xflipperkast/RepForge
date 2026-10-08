import SwiftUI

struct NextExploreView: View {
    @State private var search = ""
    @State private var equipment = "All"
    @State private var muscle = "All"
    @State private var favoritesOnly = false
    @State private var showCreate = false
    @State private var revision = 0

    private var filtered: [ExerciseDefinition] {
        ExerciseCatalog.all.filter { exercise in
            ExerciseSearch.matches(exercise, query: search) &&
            GymEquipmentFilter.matches(exercise, selected: equipment) &&
            (muscle == "All" || exercise.muscle == muscle) &&
            (!favoritesOnly || ExerciseShortcutStore.isFavorite(exercise.id))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 15) {
                    NextScreenHeader(
                        eyebrow: L10n.text("MOVEMENT LIBRARY", "OEFENBIBLIOTHEEK"),
                        title: L10n.text("Know the move.\nOwn the rep.", "Ken je oefening.\nBeheers je rep."),
                        detail: L10n.text(
                            "Machines, cables, free weights and expert-style exercise instructions.",
                            "Machines, kabels, losse gewichten en oefeninstructies."
                        )
                    )

                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.headline)
                            .foregroundStyle(NextStyle.electric)
                            .accessibilityHidden(true)
                        TextField(
                            L10n.text("Search exercises or machines", "Zoek oefeningen of apparaten"),
                            text: $search
                        )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .font(.subheadline)
                        .accessibilityLabel(L10n.text("Search exercises", "Zoek oefeningen"))
                        if !search.isEmpty {
                            Button {
                                search = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(NextStyle.muted)
                            }
                            .accessibilityLabel(L10n.text("Clear search", "Zoekveld wissen"))
                        }
                    }
                    .padding(15)
                    .background(NextStyle.panel, in: RoundedRectangle(cornerRadius: 17))
                    .overlay(RoundedRectangle(cornerRadius: 17).stroke(RFTheme.cardBorder))

                    equipmentPicker

                    HStack(spacing: 8) {
                        Menu {
                            Button(L10n.text("All muscles", "Alle spiergroepen")) {
                                muscle = "All"
                            }
                            ForEach(ExerciseCatalog.muscles, id: \.self) { group in
                                Button(group) { muscle = group }
                            }
                        } label: {
                            Label(muscle == "All"
                                  ? L10n.text("Every muscle", "Alle spieren") : muscle,
                                  systemImage: "line.3.horizontal.decrease")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 13)
                                .frame(minHeight: 44)
                                .background(NextStyle.panel, in: Capsule())
                        }
                        .foregroundStyle(.primary)

                        Button {
                            favoritesOnly.toggle()
                            Haptics.light()
                        } label: {
                            Label(L10n.text("Saved", "Bewaard"),
                                  systemImage: favoritesOnly ? "star.fill" : "star")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(favoritesOnly ? Color.black : Color.primary)
                                .padding(.horizontal, 13)
                                .frame(minHeight: 44)
                                .background(favoritesOnly ? NextStyle.electric : NextStyle.panel,
                                            in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(favoritesOnly ? .isSelected : [])
                        Spacer(minLength: 0)
                    }

                    HStack {
                        NextHeading(
                            title: L10n.text("Find your movement", "Vind je oefening"),
                            trailing: "\(filtered.count)"
                        )
                        Spacer()
                        Button {
                            showCreate = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Color.black)
                                .frame(width: 44, height: 44)
                                .background(NextStyle.electric, in: Circle())
                        }
                        .accessibilityLabel(L10n.text("Create custom exercise", "Eigen oefening maken"))
                    }

                    if filtered.isEmpty {
                        ContentUnavailableView.search(text: search)
                            .padding(.vertical, 35)
                    } else {
                        ForEach(filtered) { exercise in
                            HStack(spacing: 8) {
                                NavigationLink {
                                    ExerciseDetailView(exercise: exercise)
                                } label: {
                                    NextExerciseRow(exercise: exercise)
                                }
                                .buttonStyle(NextPressStyle())

                                Button {
                                    ExerciseShortcutStore.toggleFavorite(exercise.id)
                                    revision += 1
                                    Haptics.light()
                                } label: {
                                    Image(systemName:
                                          ExerciseShortcutStore.isFavorite(exercise.id)
                                          ? "star.fill" : "star")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(NextStyle.electric)
                                        .frame(width: 44, height: 52)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(
                                    ExerciseShortcutStore.isFavorite(exercise.id)
                                    ? L10n.text("Remove favorite", "Favoriet verwijderen")
                                    : L10n.text("Add favorite", "Favoriet toevoegen")
                                )
                            }
                            .nextSurface(radius: 18)
                            .id("\(exercise.id)-\(revision)")
                        }
                    }

                    NavigationLink {
                        ExerciseLibraryView()
                    } label: {
                        NextLinkRow(
                            symbol: "square.and.pencil",
                            title: L10n.text("Manage exercise library", "Oefeningen beheren"),
                            description: L10n.text(
                                "Edit custom exercises and advanced library actions",
                                "Eigen oefeningen en uitgebreide bibliotheekacties"
                            )
                        )
                    }
                    .buttonStyle(NextPressStyle())
                }
                .padding(.horizontal, 18)
                .padding(.top, 22)
                .padding(.bottom, 35)
            }
            .nextCanvas()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showCreate, onDismiss: {
                revision += 1
            }) {
                CustomExerciseEditorView()
            }
        }
    }

    private var equipmentPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(GymEquipmentFilter.options, id: \.self) { kind in
                    let active = equipment == kind
                    Button {
                        equipment = kind
                    } label: {
                        Text(GymEquipmentFilter.label(kind))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(active ? Color.black : Color.primary)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 43)
                            .background(active ? NextStyle.electric : NextStyle.panel, in: Capsule())
                    }
                    .buttonStyle(NextPressStyle())
                    .accessibilityAddTraits(active ? .isSelected : [])
                }
            }
        }
    }
}

struct NextExerciseRow: View {
    let exercise: ExerciseDefinition

    private var symbol: String {
        switch exercise.movement {
        case "press": return "arrow.up.forward"
        case "pull": return "arrow.down.backward"
        case "squat": return "figure.strengthtraining.traditional"
        case "cardio": return "figure.run"
        case "core": return "figure.core.training"
        default: return "dumbbell.fill"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(NextStyle.electric)
                .frame(width: 46, height: 52)
                .background(NextStyle.electric.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 13))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(exercise.name)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(exercise.muscle + "  •  " + exercise.equipment)
                    .font(.caption)
                    .foregroundStyle(NextStyle.muted)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
