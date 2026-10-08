import Foundation

/// Reusable equipment taxonomy shared by the exercise library and workout picker.
/// Groups work with the bundled free-exercise catalog and user-defined exercises.
enum GymEquipmentFilter {
    static let options = ["All", "Machines", "Cables", "Free weights", "Bodyweight", "Cardio"]

    static func label(_ option: String) -> String {
        switch option {
        case "Machines": return L10n.text("Machines", "Apparaten")
        case "Cables": return L10n.text("Cables", "Kabels")
        case "Free weights": return L10n.text("Free weights", "Losse gewichten")
        case "Bodyweight": return L10n.text("Bodyweight", "Lichaamsgewicht")
        case "Cardio": return "Cardio"
        default: return L10n.text("All equipment", "Alle apparatuur")
        }
    }

    static func matches(_ exercise: ExerciseDefinition, selected: String) -> Bool {
        let type = exercise.equipment.lowercased()

        switch selected {
        case "Machines":
            return ["machine", "lever", "sled", "smith", "assisted"]
                .contains(where: type.contains)
        case "Cables":
            return type.contains("cable") || type.contains("rope")
        case "Free weights":
            return ["barbell", "dumbbell", "ez-bar", "kettlebell", "trap bar", "weight plate"]
                .contains(where: type.contains)
        case "Bodyweight":
            return type.contains("bodyweight") || type.contains("body weight")
        case "Cardio":
            return exercise.movement == "cardio" || type.contains("cardio")
        default:
            return true
        }
    }

    static let machineShortcuts: [(label: String, term: String)] = [
        ("Chest press", "chest press"),
        ("Leg press", "leg press"),
        ("Lat pulldown", "lat pulldown"),
        ("Leg curl", "leg curl"),
        ("Leg extension", "leg extension"),
        ("Hack squat", "hack squat"),
        ("Pec deck", "pec deck"),
        ("Calf raise", "calf raise"),
        ("Hip machine", "hip")
    ]
}
