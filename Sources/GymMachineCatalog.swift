import Foundation

/// Additional common gym machine configurations. Source IDs are used only when the
/// bundled exercise database contains a technique demonstration for that exact movement.
/// Unmatched variants remain loggable but intentionally do not display a guessed video.
enum GymMachineCatalog {
    static let variants: [ExerciseDefinition] = {
        let rows = """
Incline Chest Press (Machine)|Chest|Machine|press|1299|incline machine chest press,incline hammer press
Pec Deck Chest Fly|Chest|Machine|press|drv-lever-pec-deck-fly|seated chest fly,pec fly machine
Single-Arm Chest Press (Machine)|Chest|Machine|press||unilateral chest press
Reverse-Grip Lat Pulldown (Cable)|Back|Cable|pull|0207|supinated lat pulldown,underhand pulldown
Single-Arm Lat Pulldown (Cable)|Back|Cable|pull|2616|unilateral lat pulldown
Seated Row (Machine, Neutral Grip)|Back|Machine|pull||neutral grip machine row
High Row (Machine)|Back|Machine|pull||plate loaded high row
Wide-Stance Leg Press (45 Degree)|Quadriceps|Sled Machine|squat|0740|wide feet leg press
Single-Leg Leg Press (Machine)|Quadriceps|Machine|squat||unilateral leg press
High-Foot Leg Press (Machine)|Glutes|Machine|squat||high foot placement leg press
Single-Leg Extension (Machine)|Quadriceps|Machine|extension||unilateral leg extension
Single-Leg Seated Leg Curl (Machine)|Hamstrings|Machine|curl||unilateral leg curl
Smith Machine Squat|Quadriceps|Smith Machine|squat||smith squat
Smith Incline Bench Press|Chest|Smith Machine|press||incline smith press
Smith Romanian Deadlift|Hamstrings|Smith Machine|hinge||smith rdl
Cable Fly (High to Low)|Chest|Cable|press||high to low crossover,decline cable fly
Cable Fly (Low to High)|Chest|Cable|press||low to high crossover,incline cable fly
Rope Hammer Curl (Cable)|Biceps|Cable|curl||cable rope curl
Pallof Press (Cable)|Core|Cable|core||anti rotation cable press
Assisted Pull-Up (Machine)|Back|Machine|pull||assisted chin up machine
Hip Thrust (Machine)|Glutes|Machine|hinge||glute drive machine
Glute Kickback (Machine)|Glutes|Machine|extension||standing glute machine
Torso Rotation (Machine)|Core|Machine|core||rotary torso machine
"""
        return rows.split(separator: "\n").compactMap { row -> ExerciseDefinition? in
            let fields = row.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard fields.count == 6 else { return nil }

            let slug = fields[0].lowercased()
                .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
                .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

            return ExerciseDefinition(
                id: "gym-\(slug)",
                name: fields[0],
                muscle: fields[1],
                equipment: fields[2],
                movement: fields[3],
                aliases: fields[5].split(separator: ",").map(String.init),
                sourceID: fields[4].isEmpty ? nil : fields[4]
            )
        }
    }()
}
