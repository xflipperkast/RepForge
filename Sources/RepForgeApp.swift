import SwiftUI
import SwiftData
import UIKit

// MARK: - App

@main
struct RepForgeApp: App {
    private let container = RepForgePersistence.container

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @State private var tab = 0
    @State private var keyboardVisible = false
    @State private var importMessage: String?

    @AppStorage("appLanguage") private var appLanguage = "en"
    @AppStorage("appearance") private var appearance = "dark"
    @AppStorage("themePreset") private var themePreset = "forge"
    @AppStorage("textSize") private var textSize = "standard"
    @AppStorage("layoutStyle") private var layoutStyle = "balanced"
    @AppStorage("measurementSystem") private var measurementSystem = "metric"

    var body: some View {
        V3Shell(selectedTab: $tab)
        .tint(V3.accent)
        .preferredColorScheme(preferredColorScheme)
        .dynamicTypeSize(preferredTextSize)
        .id("\(appLanguage)-\(appearance)-\(themePreset)-\(textSize)-\(measurementSystem)-\(layoutStyle)")
        .task {
            if profiles.isEmpty {
                context.insert(UserProfile())
                try? context.save()
            }

            // Detached exercise logs are removed only when no active workout
            // row can still hold a SwiftData binding to them.
            PersistenceMaintenance.cleanupOrphanExerciseLogs(context: context)
        }
        .onOpenURL { url in
            if url.scheme == "repforge", url.host == "workout" {
                tab = 0
            } else {
                importShareLink(url)
            }
        }
        .alert(
            L10n.text("RepForge Import", "RepForge Import"),
            isPresented: Binding(
                get: { importMessage != nil },
                set: { if !$0 { importMessage = nil } }
            )
        ) {
            Button(L10n.done) { importMessage = nil }
        } message: {
            Text(importMessage ?? "")
        }
    }

    private func importShareLink(_ url: URL) {
        guard let payload = RepForgeShareCodec.decode(url) else {
            importMessage = L10n.text("This RepForge link could not be read.", "Deze RepForge-link kon niet worden gelezen.")
            return
        }

        switch payload.kind {
        case "template":
            guard let exercises = payload.exercises, !exercises.isEmpty else {
                importMessage = L10n.text("The shared template is empty.", "De gedeelde template is leeg.")
                return
            }

            let ids = exercises.compactMap { ExerciseCatalog.findByName($0.name)?.id }
            context.insert(
                WorkoutTemplate(
                    name: payload.name,
                    exerciseIDs: ids,
                    plan: exercises
                )
            )
            try? context.save()
            importMessage = L10n.text(
                "Imported template “\(payload.name)”.",
                "Template “\(payload.name)” geïmporteerd."
            )

        case "program":
            let days = payload.days ?? []
            guard !days.isEmpty else {
                importMessage = L10n.text("The shared program is empty.", "Het gedeelde programma is leeg.")
                return
            }

            for day in days {
                let ids = day.exercises.compactMap { ExerciseCatalog.findByName($0.name)?.id }
                context.insert(
                    WorkoutTemplate(
                        name: "\(payload.name) • \(day.title) — \(day.focus)",
                        exerciseIDs: ids,
                        plan: day.exercises
                    )
                )
            }
            try? context.save()
            importMessage = L10n.text(
                "Imported \(days.count) workouts from “\(payload.name)”.",
                "\(days.count) trainingen uit “\(payload.name)” geïmporteerd."
            )

        default:
            importMessage = L10n.text("Unsupported RepForge share link.", "Niet-ondersteunde RepForge-deellink.")
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private var preferredTextSize: DynamicTypeSize {
        switch textSize {
        case "compact": return .small
        case "large": return .xLarge
        case "xlarge": return .xxLarge
        default: return .medium
        }
    }
}

// MARK: - Workout home

