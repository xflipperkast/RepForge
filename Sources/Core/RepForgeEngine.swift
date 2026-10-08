import SwiftUI
import SwiftData
import Charts
import AVKit
import UIKit
import UniformTypeIdentifiers
import UserNotifications
import CoreBluetooth

// MARK: - Theme

enum AppPreferences {
    static var language: String {
        UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
    }

    static var measurementSystem: String {
        UserDefaults.standard.string(forKey: "measurementSystem") ?? "metric"
    }

    static var appearance: String {
        UserDefaults.standard.string(forKey: "appearance") ?? "dark"
    }

    static var themePreset: String {
        UserDefaults.standard.string(forKey: "themePreset") ?? "forge"
    }

    static var hapticsEnabled: Bool {
        if UserDefaults.standard.object(forKey: "hapticsEnabled") == nil { return true }
        return UserDefaults.standard.bool(forKey: "hapticsEnabled")
    }

    static var showPreviousSets: Bool {
        if UserDefaults.standard.object(forKey: "showPreviousSets") == nil { return true }
        return UserDefaults.standard.bool(forKey: "showPreviousSets")
    }

    static var defaultSets: Int {
        let value = UserDefaults.standard.integer(forKey: "defaultSets")
        return value == 0 ? 3 : max(1, min(6, value))
    }

    static var defaultRestSeconds: Int {
        let value = UserDefaults.standard.integer(forKey: "defaultRestSeconds")
        return value == 0 ? 90 : max(15, min(600, value))
    }

    static var autoRestTimer: Bool {
        if UserDefaults.standard.object(forKey: "autoRestTimer") == nil { return true }
        return UserDefaults.standard.bool(forKey: "autoRestTimer")
    }

    static var autoCollapseCompleted: Bool {
        if UserDefaults.standard.object(forKey: "autoCollapseCompleted") == nil { return true }
        return UserDefaults.standard.bool(forKey: "autoCollapseCompleted")
    }

    static var restNotifications: Bool {
        if UserDefaults.standard.object(forKey: "restNotifications") == nil { return true }
        return UserDefaults.standard.bool(forKey: "restNotifications")
    }

    static var countdownHaptics: Bool {
        if UserDefaults.standard.object(forKey: "countdownHaptics") == nil { return true }
        return UserDefaults.standard.bool(forKey: "countdownHaptics")
    }

    static var compactWorkoutMode: Bool {
        UserDefaults.standard.bool(forKey: "compactWorkoutMode")
    }

    static var highContrastWorkout: Bool {
        UserDefaults.standard.bool(forKey: "highContrastWorkout")
    }

    static var progressionRule: String {
        UserDefaults.standard.string(forKey: "progressionRule") ?? "double"
    }

    static var progressionStepKg: Double {
        let value = UserDefaults.standard.double(forKey: "progressionStepKg")
        return value == 0 ? 2.5 : max(0.25, min(20, value))
    }

    static var activeGymID: String {
        UserDefaults.standard.string(forKey: "activeGymID") ?? GymProfileStore.defaultID
    }

    static var separateRecordsByGym: Bool {
        if UserDefaults.standard.object(forKey: "separateRecordsByGym") == nil { return true }
        return UserDefaults.standard.bool(forKey: "separateRecordsByGym")
    }

    static var prScope: String {
        UserDefaults.standard.string(forKey: "prScope") ?? "lifetime"
    }

    static var seasonStartDate: Date {
        let value = UserDefaults.standard.double(forKey: "seasonStartDate")
        if value > 0 { return Date(timeIntervalSince1970: value) }
        return Calendar.current.date(byAdding: .month, value: -3, to: .now) ?? .now
    }

    static var prStartDate: Date? {
        switch prScope {
        case "year":
            return Calendar.current.dateInterval(of: .year, for: .now)?.start
        case "season":
            return seasonStartDate
        default:
            return nil
        }
    }

    static var isImperial: Bool { measurementSystem == "imperial" }
    static var weightLabel: String { isImperial ? "lb" : "kg" }
    static var heightLabel: String { isImperial ? "in" : "cm" }
    static var distanceLabel: String { isImperial ? "mi" : "km" }

    static func displayWeight(_ kg: Double) -> Double {
        isImperial ? kg * 2.2046226218 : kg
    }

    static func storedWeightKg(_ displayed: Double) -> Double {
        isImperial ? displayed / 2.2046226218 : displayed
    }

    static func displayVolume(_ kgVolume: Double) -> Double {
        displayWeight(kgVolume)
    }

    static func displayHeight(_ cm: Double) -> Double {
        isImperial ? cm / 2.54 : cm
    }

    static func storedHeightCm(_ displayed: Double) -> Double {
        isImperial ? displayed * 2.54 : displayed
    }

    static func displayDistance(_ km: Double) -> Double {
        isImperial ? km * 0.6213711922 : km
    }

    static func storedDistanceKm(_ displayed: Double) -> Double {
        isImperial ? displayed / 0.6213711922 : displayed
    }

    static var speedLabel: String { isImperial ? "mph" : "km/h" }
}

enum L10n {
    static func text(_ english: String, _ dutch: String) -> String {
        switch AppPreferences.language {
        case "nl":
            return dutch
        case "es", "de", "fr":
            return LocalizationCatalog.translate(english, language: AppPreferences.language)
        default:
            return english
        }
    }

    static var profile: String { text("Profile", "Profiel") }
    static var history: String { text("History", "Geschiedenis") }
    static var workout: String { text("Workout", "Training") }
    static var exercises: String { text("Exercises", "Oefeningen") }
    static var settings: String { text("Settings", "Instellingen") }
    static var done: String { text("Done", "Gereed") }
    static var startWorkout: String { text("Start Workout", "Start training") }
    static var addExercise: String { text("Add Exercise", "Oefening toevoegen") }
    static var finish: String { text("Finish", "Afronden") }
}

/// Three distinct information-density and composition systems, independent of color theme.
enum RFLayout {
    static var style: String {
        UserDefaults.standard.string(forKey: "layoutStyle") ?? "balanced"
    }

    static var pagePadding: CGFloat { style == "compact" ? 12 : 18 }
    static var sectionSpacing: CGFloat { style == "compact" ? 14 : 24 }
    static var cardPadding: CGFloat { style == "compact" ? 12 : (style == "focused" ? 24 : 17) }
    static var cornerRadius: CGFloat { style == "compact" ? 12 : (style == "focused" ? 28 : 20) }
    static var heroFont: Font {
        style == "focused" ? .system(size: 35, weight: .black, design: .rounded)
            : .system(size: style == "compact" ? 25 : 30, weight: .bold, design: .rounded)
    }
    static var templateColumns: [GridItem] {
        if style == "focused" { return [GridItem(.flexible())] }
        return [GridItem(.adaptive(minimum: style == "compact" ? 145 : 165), spacing: 12)]
    }
}

enum RFTheme {
    private static var explicitLight: Bool { AppPreferences.appearance == "light" }
    private static var systemMode: Bool { AppPreferences.appearance == "system" }

    static var bg: Color {
        if systemMode { return Color(uiColor: .systemBackground) }
        if explicitLight { return Color(red: 0.955, green: 0.965, blue: 0.975) }

        switch AppPreferences.themePreset {
        case "oled": return .black
        case "graphite": return Color(red: 0.075, green: 0.075, blue: 0.082)
        case "navy": return Color(red: 0.025, green: 0.055, blue: 0.095)
        case "emerald": return Color(red: 0.025, green: 0.080, blue: 0.065)
        case "orange": return Color(red: 0.105, green: 0.055, blue: 0.025)
        case "purple": return Color(red: 0.070, green: 0.040, blue: 0.105)
        case "midnight": return Color(red: 0.012, green: 0.020, blue: 0.055)
        case "cyan": return Color(red: 0.018, green: 0.070, blue: 0.082)
        case "teal": return Color(red: 0.018, green: 0.065, blue: 0.060)
        case "crimson": return Color(red: 0.085, green: 0.022, blue: 0.032)
        case "rose": return Color(red: 0.082, green: 0.030, blue: 0.064)
        case "gold": return Color(red: 0.095, green: 0.070, blue: 0.020)
        case "forest": return Color(red: 0.030, green: 0.060, blue: 0.035)
        case "slate": return Color(red: 0.045, green: 0.052, blue: 0.065)
        case "neon": return Color(red: 0.018, green: 0.028, blue: 0.024)
        default: return Color(red: 0.035, green: 0.044, blue: 0.057)
        }
    }

    static var surface: Color {
        if systemMode { return Color(uiColor: .secondarySystemBackground) }
        if explicitLight { return .white }

        switch AppPreferences.themePreset {
        case "oled": return Color(red: 0.055, green: 0.055, blue: 0.060)
        case "graphite": return Color(red: 0.125, green: 0.125, blue: 0.135)
        case "navy": return Color(red: 0.070, green: 0.105, blue: 0.155)
        case "emerald": return Color(red: 0.055, green: 0.145, blue: 0.110)
        case "orange": return Color(red: 0.175, green: 0.095, blue: 0.045)
        case "purple": return Color(red: 0.125, green: 0.075, blue: 0.180)
        case "midnight": return Color(red: 0.038, green: 0.055, blue: 0.115)
        case "cyan": return Color(red: 0.040, green: 0.130, blue: 0.148)
        case "teal": return Color(red: 0.038, green: 0.125, blue: 0.110)
        case "crimson": return Color(red: 0.155, green: 0.050, blue: 0.065)
        case "rose": return Color(red: 0.150, green: 0.060, blue: 0.120)
        case "gold": return Color(red: 0.160, green: 0.115, blue: 0.035)
        case "forest": return Color(red: 0.060, green: 0.120, blue: 0.070)
        case "slate": return Color(red: 0.095, green: 0.110, blue: 0.135)
        case "neon": return Color(red: 0.035, green: 0.085, blue: 0.060)
        default: return Color(red: 0.085, green: 0.100, blue: 0.125)
        }
    }

    static var raised: Color {
        if systemMode { return Color(uiColor: .tertiarySystemBackground) }
        if explicitLight { return Color(red: 0.90, green: 0.92, blue: 0.94) }

        switch AppPreferences.themePreset {
        case "oled": return Color(red: 0.095, green: 0.095, blue: 0.105)
        case "graphite": return Color(red: 0.165, green: 0.165, blue: 0.180)
        case "navy": return Color(red: 0.105, green: 0.145, blue: 0.205)
        case "emerald": return Color(red: 0.080, green: 0.190, blue: 0.145)
        case "orange": return Color(red: 0.220, green: 0.125, blue: 0.060)
        case "purple": return Color(red: 0.175, green: 0.105, blue: 0.245)
        case "midnight": return Color(red: 0.060, green: 0.082, blue: 0.165)
        case "cyan": return Color(red: 0.060, green: 0.175, blue: 0.195)
        case "teal": return Color(red: 0.055, green: 0.170, blue: 0.145)
        case "crimson": return Color(red: 0.210, green: 0.070, blue: 0.090)
        case "rose": return Color(red: 0.205, green: 0.085, blue: 0.160)
        case "gold": return Color(red: 0.215, green: 0.155, blue: 0.050)
        case "forest": return Color(red: 0.085, green: 0.165, blue: 0.095)
        case "slate": return Color(red: 0.135, green: 0.155, blue: 0.185)
        case "neon": return Color(red: 0.050, green: 0.130, blue: 0.085)
        default: return Color(red: 0.120, green: 0.143, blue: 0.170)
        }
    }

    static var field: Color {
        if systemMode { return Color(uiColor: .tertiarySystemFill) }
        if explicitLight { return Color.black.opacity(0.06) }
        return Color.black.opacity(AppPreferences.themePreset == "oled" ? 0.62 : 0.28)
    }

    static var accent: Color {
        switch AppPreferences.themePreset {
        case "emerald": return Color(red: 0.10, green: 0.78, blue: 0.48)
        case "orange": return Color(red: 1.0, green: 0.48, blue: 0.12)
        case "purple": return Color(red: 0.63, green: 0.43, blue: 1.0)
        case "midnight": return Color(red: 0.40, green: 0.56, blue: 1.0)
        case "cyan": return Color(red: 0.08, green: 0.82, blue: 0.94)
        case "teal": return Color(red: 0.08, green: 0.80, blue: 0.68)
        case "crimson": return Color(red: 1.0, green: 0.24, blue: 0.36)
        case "rose": return Color(red: 1.0, green: 0.36, blue: 0.68)
        case "gold": return Color(red: 1.0, green: 0.72, blue: 0.18)
        case "forest": return Color(red: 0.32, green: 0.78, blue: 0.38)
        case "slate": return Color(red: 0.64, green: 0.72, blue: 0.84)
        case "neon": return Color(red: 0.30, green: 1.0, blue: 0.54)
        default: return Color(red: 0.81, green: 0.97, blue: 0.34)
        }
    }

    static let success = Color(red: 0.16, green: 0.78, blue: 0.43)

    static var muted: Color {
        if systemMode { return Color.secondary }
        return explicitLight ? Color.black.opacity(0.50) : Color.white.opacity(0.52)
    }

    static var cardBorder: Color {
        if AppPreferences.highContrastWorkout {
            return explicitLight ? Color.black.opacity(0.24) : Color.white.opacity(0.30)
        }
        return explicitLight ? Color.black.opacity(0.08) : Color.white.opacity(0.10)
    }

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [surface, raised.opacity(0.90), accent.opacity(explicitLight ? 0.10 : 0.16)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

enum Haptics {
    static func light() {
        guard AppPreferences.hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func success() {
        guard AppPreferences.hapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

final class RestNotificationManager {
    static let shared = RestNotificationManager()
    private let identifier = "repforge.rest.timer"

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func schedule(seconds: Int, exerciseName: String) {
        guard AppPreferences.restNotifications, seconds > 0 else { return }

        requestAuthorization()
        cancel()

        let content = UNMutableNotificationContent()
        content.title = L10n.text("Rest complete", "Rust voorbij")
        content.body = exerciseName.isEmpty
            ? L10n.text("Time for your next set.", "Tijd voor je volgende set.")
            : "\(exerciseName) • \(L10n.text("next set is ready", "volgende set is klaar"))"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(max(1, seconds)),
            repeats: false
        )

        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        )
    }

    func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}

final class HeartRateMonitor: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    static let shared = HeartRateMonitor()

    @Published private(set) var bpm: Int?
    @Published private(set) var sensorName: String?
    @Published private(set) var isScanning = false
    @Published private(set) var isConnected = false

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?

    private let heartRateService = CBUUID(string: "180D")
    private let heartRateMeasurement = CBUUID(string: "2A37")

    override private init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    func startScanning() {
        guard central.state == .poweredOn else { return }
        isScanning = true
        central.scanForPeripherals(
            withServices: [heartRateService],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func stopScanning() {
        central.stopScan()
        isScanning = false
    }

    func disconnect() {
        if let peripheral {
            central.cancelPeripheralConnection(peripheral)
        }
        self.peripheral = nil
        bpm = nil
        sensorName = nil
        isConnected = false
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn {
            isScanning = false
            isConnected = false
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber
    ) {
        stopScanning()
        self.peripheral = peripheral
        peripheral.delegate = self
        sensorName = peripheral.name ?? L10n.text("Heart-rate sensor", "Hartslagsensor")
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        peripheral.discoverServices([heartRateService])
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        isConnected = false
        bpm = nil
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else { return }
        peripheral.services?.forEach { service in
            if service.uuid == heartRateService {
                peripheral.discoverCharacteristics([heartRateMeasurement], for: service)
            }
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil else { return }
        service.characteristics?.forEach { characteristic in
            if characteristic.uuid == heartRateMeasurement {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil,
              characteristic.uuid == heartRateMeasurement,
              let data = characteristic.value,
              data.count >= 2 else { return }

        let bytes = [UInt8](data)
        let flags = bytes[0]
        let isUInt16 = (flags & 0x01) != 0

        let value: Int
        if isUInt16, bytes.count >= 3 {
            value = Int(UInt16(bytes[1]) | (UInt16(bytes[2]) << 8))
        } else {
            value = Int(bytes[1])
        }

        bpm = value
    }
}

// MARK: - Gym profiles

struct GymProfile: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var note: String
}

enum GymProfileStore {
    static let defaultID = "gym-default"

    static func load() -> [GymProfile] {
        SwiftDataUserStore.gyms()
    }

    static func save(_ gyms: [GymProfile]) {
        SwiftDataUserStore.saveGyms(gyms)
        bumpRevision()
    }

    static func profile(id: String?) -> GymProfile {
        let resolved = id ?? defaultID
        return load().first(where: { $0.id == resolved })
            ?? load().first
            ?? GymProfile(id: defaultID, name: L10n.text("Main Gym", "Hoofdgym"), note: "")
    }

    static func add(name: String, note: String = "") -> GymProfile {
        var gyms = load()
        let gym = GymProfile(
            id: "gym-\(UUID().uuidString)",
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? L10n.text("New Gym", "Nieuwe gym")
                : name.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note
        )
        gyms.append(gym)
        save(gyms)
        return gym
    }

    static func update(_ gym: GymProfile) {
        var gyms = load()
        if let index = gyms.firstIndex(where: { $0.id == gym.id }) {
            gyms[index] = gym
        } else {
            gyms.append(gym)
        }
        save(gyms)
    }

    static func delete(id: String) {
        guard id != defaultID else { return }
        var gyms = load()
        gyms.removeAll { $0.id == id }
        save(gyms)
        if AppPreferences.activeGymID == id {
            UserDefaults.standard.set(defaultID, forKey: "activeGymID")
        }
    }

    static func sessionGymID(_ session: WorkoutSession) -> String {
        session.gymID ?? defaultID
    }

    private static func bumpRevision() {
        let revision = UserDefaults.standard.integer(forKey: "gymRevision")
        UserDefaults.standard.set(revision + 1, forKey: "gymRevision")
    }
}

// MARK: - Exercise catalog

struct ExerciseDefinition: Identifiable, Hashable {
    let id: String
    let name: String
    let muscle: String
    let equipment: String
    let movement: String
    let aliases: [String]
    let sourceID: String?
    let sourceTarget: String?
    let sourceSecondaryMuscles: [String]
    let sourceBodyPart: String?
    let sourceSteps: [String]
    let sourceFormCues: [String]

    init(
        id: String,
        name: String,
        muscle: String,
        equipment: String,
        movement: String,
        aliases: [String] = [],
        sourceID: String? = nil,
        sourceTarget: String? = nil,
        sourceSecondaryMuscles: [String] = [],
        sourceBodyPart: String? = nil,
        sourceSteps: [String] = [],
        sourceFormCues: [String] = []
    ) {
        self.id = id
        self.name = name
        self.muscle = muscle
        self.equipment = equipment
        self.movement = movement
        self.aliases = aliases
        self.sourceID = sourceID
        self.sourceTarget = sourceTarget
        self.sourceSecondaryMuscles = sourceSecondaryMuscles
        self.sourceBodyPart = sourceBodyPart
        self.sourceSteps = sourceSteps
        self.sourceFormCues = sourceFormCues
    }

    var instructions: [String] {
        if !sourceSteps.isEmpty { return sourceSteps }

        switch movement {
        case "press":
            return ["Set a stable base and brace your trunk.", "Lower under control while keeping the working joints stacked.", "Press smoothly through the intended range without bouncing."]
        case "pull":
            return ["Set the shoulder blades before initiating the pull.", "Pull with the target muscles instead of jerking with momentum.", "Return slowly and keep tension through the full range."]
        case "squat":
            return ["Brace before each rep and keep your whole foot planted.", "Track the knees in line with the toes.", "Drive up while keeping the torso controlled."]
        case "hinge":
            return ["Push the hips back while keeping the spine neutral.", "Keep the load close to your body.", "Finish by extending the hips, not by leaning backward."]
        case "curl":
            return ["Keep the upper arm controlled.", "Curl without swinging the torso.", "Lower slowly until the elbow is fully extended."]
        case "extension":
            return ["Keep the working joint stable.", "Extend without using body momentum.", "Control the return and avoid snapping into lockout."]
        case "raise":
            return ["Use a controlled range with relaxed traps.", "Lead with the intended limb path.", "Lower more slowly than you lift."]
        case "core":
            return ["Brace as if preparing for impact.", "Move without losing rib-to-pelvis control.", "Stop the set when position starts to break down."]
        case "cardio":
            return ["Start at a sustainable pace.", "Use smooth, repeatable mechanics.", "Increase intensity gradually rather than sprinting immediately."]
        default:
            return ["Set up in a stable position.", "Use a controlled range of motion.", "Prioritize consistent technique over load."]
        }
    }

    var cues: [String] {
        sourceFormCues.isEmpty
            ? ["Controlled tempo", "Stable setup", "Pain-free range", "Progress load gradually"]
            : sourceFormCues
    }

    var detailedMuscles: [MuscleContribution] {
        MuscleMap.contributions(for: self)
    }
}

struct MuscleContribution: Hashable, Identifiable {
    var id: String { muscle }
    let muscle: String
    let weight: Double
    let side: BodySide

    enum BodySide: String, Hashable {
        case front, back
    }
}

enum MuscleMap {
    static let trackedMuscles = [
        "Upper Chest", "Mid Chest", "Lower Chest",
        "Front Delts", "Side Delts", "Rear Delts",
        "Lats", "Upper Back", "Traps", "Spinal Erectors",
        "Biceps", "Brachialis", "Triceps", "Forearms",
        "Quadriceps", "Hamstrings", "Glutes", "Adductors", "Abductors",
        "Calves", "Shins", "Abs", "Obliques", "Hip Flexors", "Neck"
    ]

    static func contributions(for exercise: ExerciseDefinition) -> [MuscleContribution] {
        let name = exercise.name.lowercased()
        var result: [MuscleContribution] = []

        func add(_ muscle: String, _ weight: Double = 1, _ side: MuscleContribution.BodySide) {
            if let index = result.firstIndex(where: { $0.muscle == muscle }) {
                let existing = result[index]
                result[index] = MuscleContribution(
                    muscle: muscle,
                    weight: max(existing.weight, weight),
                    side: existing.side
                )
            } else {
                result.append(MuscleContribution(muscle: muscle, weight: weight, side: side))
            }
        }

        if let sourceTarget = exercise.sourceTarget {
            if let mapped = sourceMuscle(sourceTarget, exerciseName: name) {
                add(mapped.muscle, 1.0, mapped.side)
            }

            for secondary in exercise.sourceSecondaryMuscles {
                if let mapped = sourceMuscle(secondary, exerciseName: name) {
                    add(mapped.muscle, 0.38, mapped.side)
                }
            }

            if result.isEmpty {
                if exercise.movement == "cardio" {
                    add("Quadriceps", 0.35, .front)
                    add("Glutes", 0.25, .back)
                    add("Calves", 0.25, .back)
                } else if exercise.muscle == "Full Body" {
                    add("Quadriceps", 0.55, .front)
                    add("Glutes", 0.55, .back)
                    add("Upper Back", 0.35, .back)
                    add("Abs", 0.35, .front)
                }
            }

            return result
        }

        switch exercise.muscle {
        case "Chest":
            if name.contains("incline") {
                add("Upper Chest", 1, .front)
            } else if name.contains("decline") || name.contains("dip") {
                add("Lower Chest", 1, .front)
            } else {
                add("Mid Chest", 1, .front)
            }
            if exercise.movement == "press" {
                add("Triceps", 0.5, .back)
                add("Front Delts", 0.35, .front)
            }

        case "Back":
            if name.contains("pulldown") || name.contains("pull up") || name.contains("chin up") || name.contains("straight arm") {
                add("Lats", 1, .back)
                add("Biceps", 0.4, .front)
            } else if name.contains("row") {
                add("Upper Back", 1, .back)
                add("Lats", 0.55, .back)
                add("Rear Delts", 0.35, .back)
                add("Biceps", 0.35, .front)
            } else if name.contains("shrug") {
                add("Traps", 1, .back)
            } else {
                add("Spinal Erectors", 0.8, .back)
                add("Upper Back", 0.5, .back)
            }

        case "Shoulders":
            if name.contains("lateral") {
                add("Side Delts", 1, .front)
            } else if name.contains("rear") || name.contains("reverse pec") || name.contains("face pull") {
                add("Rear Delts", 1, .back)
                add("Upper Back", 0.45, .back)
            } else if name.contains("front raise") {
                add("Front Delts", 1, .front)
            } else if name.contains("shrug") {
                add("Traps", 1, .back)
            } else {
                add("Front Delts", 1, .front)
                add("Side Delts", 0.6, .front)
                add("Triceps", 0.45, .back)
            }

        case "Biceps":
            if name.contains("hammer") {
                add("Brachialis", 1, .front)
                add("Biceps", 0.7, .front)
                add("Forearms", 0.4, .front)
            } else if name.contains("reverse") {
                add("Forearms", 1, .front)
                add("Brachialis", 0.7, .front)
            } else {
                add("Biceps", 1, .front)
                add("Brachialis", 0.25, .front)
            }

        case "Triceps":
            add("Triceps", 1, .back)
            if exercise.movement == "press" { add("Mid Chest", 0.35, .front) }

        case "Forearms":
            add("Forearms", 1, .front)
            add("Brachialis", 0.45, .front)

        case "Quadriceps":
            add("Quadriceps", 1, .front)
            if name.contains("squat") || name.contains("lunge") || name.contains("press") || name.contains("step") {
                add("Glutes", 0.45, .back)
            }
            if name.contains("lunge") || name.contains("split") {
                add("Adductors", 0.25, .front)
            }

        case "Hamstrings":
            add("Hamstrings", 1, .back)
            if exercise.movement == "hinge" {
                add("Glutes", 0.65, .back)
                add("Spinal Erectors", 0.35, .back)
            }

        case "Glutes":
            add("Glutes", 1, .back)
            if name.contains("thrust") || name.contains("bridge") { add("Hamstrings", 0.3, .back) }

        case "Adductors":
            add("Adductors", 1, .front)

        case "Calves":
            add("Calves", 1, .back)

        case "Core":
            if name.contains("side") || name.contains("russian") || name.contains("bicycle") {
                add("Obliques", 1, .front)
                add("Abs", 0.6, .front)
            } else if name.contains("leg raise") || name.contains("captain") {
                add("Abs", 1, .front)
                add("Hip Flexors", 0.55, .front)
            } else {
                add("Abs", 1, .front)
            }

        case "Full Body":
            if name.contains("deadlift") || name.contains("swing") {
                add("Glutes", 1, .back)
                add("Hamstrings", 0.8, .back)
                add("Spinal Erectors", 0.6, .back)
                add("Traps", 0.35, .back)
            } else {
                add("Quadriceps", 0.7, .front)
                add("Glutes", 0.7, .back)
                add("Front Delts", 0.55, .front)
                add("Triceps", 0.4, .back)
            }

        default:
            if exercise.movement == "cardio" {
                add("Quadriceps", 0.35, .front)
                add("Glutes", 0.25, .back)
                add("Calves", 0.25, .back)
            }
        }

        return result
    }

    private static func sourceMuscle(
        _ raw: String,
        exerciseName: String
    ) -> (muscle: String, side: MuscleContribution.BodySide)? {
        let value = raw
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        switch value {
        case "pectorals", "pectoralis major", "chest":
            if exerciseName.contains("incline") { return ("Upper Chest", .front) }
            if exerciseName.contains("decline") || exerciseName.contains("dip") { return ("Lower Chest", .front) }
            return ("Mid Chest", .front)
        case "upper pectorals", "upper chest":
            return ("Upper Chest", .front)
        case "anterior deltoid", "anterior deltoids":
            return ("Front Delts", .front)
        case "posterior deltoid", "posterior deltoids", "rear deltoids":
            return ("Rear Delts", .back)
        case "deltoids", "delts", "shoulders":
            if exerciseName.contains("rear") || exerciseName.contains("reverse") { return ("Rear Delts", .back) }
            if exerciseName.contains("front") { return ("Front Delts", .front) }
            return ("Side Delts", .front)
        case "lats", "latissimus dorsi":
            return ("Lats", .back)
        case "middle back", "upper back", "rhomboids", "rhoboids", "teres major":
            return ("Upper Back", .back)
        case "traps", "trapezius", "upper trapezius", "middle trapezius", "lower trapezius":
            return ("Traps", .back)
        case "erector spinae", "erectors", "spinal erectors", "lower back", "spine", "thoracic spine", "quadratus lumborum":
            return ("Spinal Erectors", .back)
        case "biceps", "biceps brachii":
            return ("Biceps", .front)
        case "brachialis", "brachioradialis":
            return ("Brachialis", .front)
        case "triceps", "triceps brachii", "anconeus":
            return ("Triceps", .back)
        case "forearms", "forearm extensors", "flexor carpi radialis", "flexor carpi ulnaris":
            return ("Forearms", .front)
        case "quadriceps", "quads", "rectus femoris", "vastus medialis":
            return ("Quadriceps", .front)
        case "hamstrings":
            return ("Hamstrings", .back)
        case "glutes", "gluteus maximus", "gluteus medius", "gluteus minimus", "piriformis":
            return ("Glutes", .back)
        case "adductors", "groin":
            return ("Adductors", .front)
        case "abductors", "hip abductors", "tensor fasciae latae":
            return ("Abductors", .front)
        case "calves", "gastrocnemius", "soleus", "achilles tendon", "ankle stabilizers", "ankles":
            return ("Calves", .back)
        case "peroneals", "tibialis anterior", "tibialis posterior":
            return ("Shins", .front)
        case "abdominals", "abs", "rectus abdominis", "lower abdominals", "lower abs", "transverse abdominis", "core", "core stabilizers":
            return ("Abs", .front)
        case "obliques", "intercostals", "serratus anterior":
            return ("Obliques", .front)
        case "hip flexors", "iliopsoas":
            return ("Hip Flexors", .front)
        case "neck flexors", "sternocleidomastoid", "scalenes":
            return ("Neck", .front)
        case "rotator cuff", "infraspinatus":
            return ("Rear Delts", .back)
        default:
            return nil
        }
    }
}

enum ExerciseCatalog {
    // Kept only for resolving existing ex-N history/templates from older RepForge builds.
    // New pickers use the complete bundled Free Exercise DB catalog below.
    private static let legacyBuiltIn: [ExerciseDefinition] = {
        let rows = """
Bench Press (Barbell)|Chest|Barbell|press
Bench Press (Dumbbell)|Chest|Dumbbell|press
Incline Bench Press (Barbell)|Chest|Barbell|press
Incline Bench Press (Dumbbell)|Chest|Dumbbell|press
Decline Bench Press|Chest|Barbell|press
Chest Press (Machine)|Chest|Machine|press
Chest Fly (Machine)|Chest|Machine|press
Cable Fly|Chest|Cable|press
Push Up|Chest|Bodyweight|press
Dip (Chest)|Chest|Bodyweight|press
Around the World|Chest|Dumbbell|raise
Pullover (Dumbbell)|Chest|Dumbbell|pull
Deadlift (Barbell)|Back|Barbell|hinge
Romanian Deadlift (Barbell)|Hamstrings|Barbell|hinge
Bent Over Row (Barbell)|Back|Barbell|pull
Bent Over Row (Dumbbell)|Back|Dumbbell|pull
One Arm Dumbbell Row|Back|Dumbbell|pull
Seated Cable Row|Back|Cable|pull
T-Bar Row|Back|Machine|pull
Chest Supported Row|Back|Machine|pull
Lat Pulldown|Back|Cable|pull
Lat Pulldown - Wide Grip|Back|Cable|pull
Pull Up|Back|Bodyweight|pull
Chin Up|Back|Bodyweight|pull
Straight Arm Pulldown|Back|Cable|pull
Back Extension|Back|Bodyweight|hinge
Back Extension (Machine)|Back|Machine|hinge
Good Morning|Back|Barbell|hinge
Overhead Press (Barbell)|Shoulders|Barbell|press
Shoulder Press (Dumbbell)|Shoulders|Dumbbell|press
Arnold Press (Dumbbell)|Shoulders|Dumbbell|press
Shoulder Press (Machine)|Shoulders|Machine|press
Lateral Raise (Dumbbell)|Shoulders|Dumbbell|raise
Lateral Raise (Cable)|Shoulders|Cable|raise
Front Raise|Shoulders|Dumbbell|raise
Rear Delt Fly|Shoulders|Dumbbell|raise
Reverse Pec Deck|Shoulders|Machine|raise
Face Pull|Shoulders|Cable|pull
Upright Row|Shoulders|Barbell|pull
Shrug (Barbell)|Shoulders|Barbell|pull
Shrug (Dumbbell)|Shoulders|Dumbbell|pull
Biceps Curl (Barbell)|Biceps|Barbell|curl
Biceps Curl (Dumbbell)|Biceps|Dumbbell|curl
Hammer Curl|Biceps|Dumbbell|curl
Incline Dumbbell Curl|Biceps|Dumbbell|curl
Preacher Curl|Biceps|Machine|curl
Cable Curl|Biceps|Cable|curl
Concentration Curl|Biceps|Dumbbell|curl
EZ-Bar Curl|Biceps|Barbell|curl
Triceps Pushdown|Triceps|Cable|extension
Overhead Triceps Extension|Triceps|Cable|extension
Skull Crusher|Triceps|Barbell|extension
Close Grip Bench Press|Triceps|Barbell|press
Triceps Dip|Triceps|Bodyweight|extension
Triceps Extension (Dumbbell)|Triceps|Dumbbell|extension
Squat (Barbell)|Quadriceps|Barbell|squat
Front Squat|Quadriceps|Barbell|squat
Goblet Squat|Quadriceps|Dumbbell|squat
Hack Squat|Quadriceps|Machine|squat
Leg Press|Quadriceps|Machine|squat
Leg Extension (Machine)|Quadriceps|Machine|extension
Bulgarian Split Squat|Quadriceps|Dumbbell|squat
Walking Lunge|Quadriceps|Dumbbell|squat
Reverse Lunge|Quadriceps|Dumbbell|squat
Step Up|Quadriceps|Dumbbell|squat
Leg Curl (Lying)|Hamstrings|Machine|curl
Leg Curl (Seated)|Hamstrings|Machine|curl
Nordic Hamstring Curl|Hamstrings|Bodyweight|curl
Stiff Leg Deadlift|Hamstrings|Barbell|hinge
Hip Thrust (Barbell)|Glutes|Barbell|hinge
Glute Bridge|Glutes|Bodyweight|hinge
Cable Kickback|Glutes|Cable|extension
Hip Abduction (Machine)|Glutes|Machine|raise
Hip Adduction (Machine)|Adductors|Machine|raise
Standing Calf Raise|Calves|Machine|raise
Seated Calf Raise|Calves|Machine|raise
Standing Calf Raise (Dumbbell)|Calves|Dumbbell|raise
Crunch|Core|Bodyweight|core
Cable Crunch|Core|Cable|core
Hanging Leg Raise|Core|Bodyweight|core
Flat Leg Raise|Core|Bodyweight|core
Plank|Core|Bodyweight|core
Side Plank|Core|Bodyweight|core
Ab Wheel|Core|Other|core
Russian Twist|Core|Bodyweight|core
Bicycle Crunch|Core|Bodyweight|core
Mountain Climber|Core|Bodyweight|core
Farmer Carry|Full Body|Dumbbell|carry
Kettlebell Swing|Full Body|Kettlebell|hinge
Clean and Press|Full Body|Barbell|press
Thruster|Full Body|Barbell|squat
Battle Ropes|Full Body|Other|cardio
Ball Slams|Full Body|Other|cardio
Burpee|Full Body|Bodyweight|cardio
Aerobics|Cardio|Cardio|cardio
Running|Cardio|Cardio|cardio
Cycling|Cardio|Cardio|cardio
Rowing|Cardio|Cardio|cardio
Stair Climber|Cardio|Cardio|cardio
Elliptical|Cardio|Cardio|cardio
Jump Rope|Cardio|Other|cardio
Barbell Flat Bench Press|Chest|Barbell|press
Chest Supported Machine Row|Back|Machine|pull
Lying Leg Curl|Hamstrings|Machine|curl
Cable Triceps Rope Pushdown|Triceps|Cable|extension
Dumbbell Shoulder Press (Seated)|Shoulders|Dumbbell|press
Dumbbell Romanian Deadlift|Hamstrings|Dumbbell|hinge
Wide Grip Lat Pulldown|Back|Cable|pull
Standing Dumbbell Biceps Curl|Biceps|Dumbbell|curl
Cable Face Pull|Shoulders|Cable|pull
Seated Cable Row (V-Bar)|Back|Cable|pull
Incline Dumbbell Bench Press|Chest|Dumbbell|press
Standing Dumbbell Lateral Raise|Shoulders|Dumbbell|raise
Cable Overhead Triceps Rope Extension|Triceps|Cable|extension
Reverse Pec Deck Machine|Shoulders|Machine|raise
Captain's Chair Leg Raise|Core|Bodyweight|core
Hack Squat Machine|Quadriceps|Machine|squat
Single-Arm Dumbbell Row|Back|Dumbbell|pull
Seated Leg Curl Machine|Hamstrings|Machine|curl
Cable Triceps Straight Bar Pushdown|Triceps|Cable|extension
Standing Barbell Overhead Press (Military Press)|Shoulders|Barbell|press
Trap Bar Deadlift|Full Body|Trap Bar|hinge
Neutral Grip Lat Pulldown|Back|Cable|pull
Dumbbell Walking Lunges|Quadriceps|Dumbbell|squat
Cable Biceps Curl|Biceps|Cable|curl
Chest Supported Dumbbell Row|Back|Dumbbell|pull
Assisted Dip Machine|Chest|Machine|press
Bench Dips|Triceps|Bodyweight|extension
Seated Calf Raise Machine|Calves|Machine|raise
Lean-Away Cable Lateral Raise|Shoulders|Cable|raise
EZ-Bar Biceps Curl|Biceps|EZ-Bar|curl
Kneeling Cable Crunch|Core|Cable|core
Abdominal Crunch Machine|Core|Machine|core
EZ-Bar Reverse Curl|Forearms|EZ-Bar|curl
Arnold Dumbbell Press|Shoulders|Dumbbell|press
Flat Dumbbell Bench Press|Chest|Dumbbell|press
Close-Grip Barbell Bench Press|Triceps|Barbell|press
Dumbbell Preacher Curl|Biceps|Dumbbell|curl
Incline Bench Spider Curl|Biceps|Dumbbell|curl
Lying Dumbbell Skull Crushers|Triceps|Dumbbell|extension
Lying Floor Leg Raises|Core|Bodyweight|core
Bench Press (Smith Machine)|Chest|Machine|press
Close Feet Leg Press|Quadriceps|Machine|squat
Lever Horizontal Leg Press|Quadriceps|Machine|squat
Sled 45 Degree Wide Leg Press|Quadriceps|Machine|squat
Smith Machine Leg Press|Quadriceps|Machine|squat
"""
        return rows.split(separator: "\n").enumerated().compactMap { index, raw in
            let p = raw.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard p.count == 4 else { return nil }
            return ExerciseDefinition(
                id: "ex-\(index)",
                name: p[0],
                muscle: p[1],
                equipment: p[2],
                movement: p[3]
            )
        }
    }()

    private static let databaseBuiltIn: [ExerciseDefinition] = {
        guard let url = Bundle.main.url(forResource: "ExerciseDatabase", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([ExerciseDBItem].self, from: data),
              !items.isEmpty else {
            return []
        }

        return items.map { item in
            ExerciseDefinition(
                id: "db-\(item.id)",
                name: item.name,
                muscle: broadMuscle(for: item),
                equipment: displayEquipment(item.equipment),
                movement: movement(for: item),
                aliases: item.aliases ?? [],
                sourceID: item.id,
                sourceTarget: item.target,
                sourceSecondaryMuscles: item.secondaryMuscles ?? [],
                sourceBodyPart: item.bodyPart,
                sourceSteps: item.steps ?? [],
                sourceFormCues: item.formCues ?? []
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }()

    // Preserve the legacy movements in the picker as well as in older workout history.
    // The bundled video catalog is not a complete exercise catalog by itself.
    private static let additionalMachineBuiltIn: [ExerciseDefinition] = GymMachineCatalog.variants.map { exercise in
        guard let sourceID = exercise.sourceID,
              let item = bundledSourceItems[sourceID] else {
            return exercise
        }
        return ExerciseDefinition(
            id: exercise.id,
            name: exercise.name,
            muscle: exercise.muscle,
            equipment: exercise.equipment,
            movement: exercise.movement,
            aliases: exercise.aliases + (item.aliases ?? []),
            sourceID: sourceID,
            sourceTarget: item.target,
            sourceSecondaryMuscles: item.secondaryMuscles ?? [],
            sourceBodyPart: item.bodyPart,
            sourceSteps: item.steps ?? [],
            sourceFormCues: item.formCues ?? []
        )
    }

    private static let bundledSourceItems: [String: ExerciseDBItem] = {
        guard let url = Bundle.main.url(forResource: "ExerciseDatabase", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([ExerciseDBItem].self, from: data) else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    }()

    private static let combinedBuiltIn: [ExerciseDefinition] = {
        let primary = databaseBuiltIn.isEmpty ? legacyBuiltIn : databaseBuiltIn
        var names = Set(primary.map { $0.name.lowercased() })
        let additional = (additionalMachineBuiltIn + legacyBuiltIn).filter { item in
            names.insert(item.name.lowercased()).inserted
        }
        return primary + additional
    }()

    static var all: [ExerciseDefinition] {
        combinedBuiltIn + CustomExerciseStore.load().map { $0.definition }
    }

    private static let builtInLookup: [String: ExerciseDefinition] = {
        var index = Dictionary(uniqueKeysWithValues: combinedBuiltIn.map { ($0.id, $0) })
        for exercise in legacyBuiltIn where index[exercise.id] == nil {
            index[exercise.id] = exercise
        }
        return index
    }()

    static func find(_ id: String) -> ExerciseDefinition? {
        if let builtIn = builtInLookup[id] { return builtIn }
        return CustomExerciseStore.load().first(where: { $0.id == id })?.definition
    }

    static func findByName(_ name: String) -> ExerciseDefinition? {
        if let exact = all.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return exact
        }

        if let alias = databaseBuiltIn.first(where: { exercise in
            exercise.aliases.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame })
        }) {
            return alias
        }

        return legacyBuiltIn.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    static var muscles: [String] {
        Array(Set(all.map(\.muscle))).sorted()
    }

    private static func broadMuscle(for item: ExerciseDBItem) -> String {
        let target = normalized(item.target)
        let bodyPart = normalized(item.bodyPart)

        switch target {
        case "pectorals", "upper pectorals": return "Chest"
        case "deltoids", "delts", "anterior deltoid", "posterior deltoid", "rear deltoids": return "Shoulders"
        case "biceps": return "Biceps"
        case "triceps": return "Triceps"
        case "forearms", "forearm extensors": return "Forearms"
        case "quadriceps", "quads": return "Quadriceps"
        case "hamstrings": return "Hamstrings"
        case "glutes", "gluteus medius", "abductors": return "Glutes"
        case "adductors": return "Adductors"
        case "calves", "peroneals": return "Calves"
        case "abdominals", "abs", "rectus abdominis", "obliques", "hip flexors": return "Core"
        case "lats", "middle back", "upper back", "rhomboids", "traps", "erector spinae", "erectors", "spinal erectors", "spine", "thoracic spine": return "Back"
        case "neck flexors", "sternocleidomastoid": return "Neck"
        case "cardiovascular system": return "Cardio"
        case "full body": return "Full Body"
        default:
            switch bodyPart {
            case "chest": return "Chest"
            case "shoulders": return "Shoulders"
            case "upper arms": return "Arms"
            case "lower arms": return "Forearms"
            case "upper legs": return "Legs"
            case "lower legs": return "Calves"
            case "waist": return "Core"
            case "back": return "Back"
            case "hips": return "Glutes"
            case "cardio": return "Cardio"
            default: return "Full Body"
            }
        }
    }

    private static func movement(for item: ExerciseDBItem) -> String {
        let name = normalized(item.name)
        let target = normalized(item.target)
        let bodyPart = normalized(item.bodyPart)

        if bodyPart == "cardio" || target == "cardiovascular system" { return "cardio" }
        if ["abdominals", "abs", "rectus abdominis", "obliques", "hip flexors"].contains(target) { return "core" }
        if name.contains("curl") { return "curl" }
        if name.contains("pushdown") || name.contains("extension") || name.contains("kickback") { return "extension" }
        if name.contains("raise") || name.contains("fly") || name.contains("abduction") || name.contains("adduction") { return "raise" }
        if name.contains("squat") || name.contains("lunge") || name.contains("leg press") || name.contains("step up") { return "squat" }
        if name.contains("deadlift") || name.contains("hip thrust") || name.contains("bridge") || name.contains("swing") || name.contains("hyperextension") || name.contains("back extension") || name.contains("good morning") { return "hinge" }
        if name.contains("row") || name.contains("pulldown") || name.contains("pull up") || name.contains("pull-up") || name.contains("chin up") || name.contains("chin-up") || name.contains("pullover") { return "pull" }
        if name.contains("press") || name.contains("push up") || name.contains("push-up") || name.contains("dip") { return "press" }
        if ["biceps", "lats", "middle back", "upper back", "rhomboids"].contains(target) { return "pull" }
        if ["pectorals", "upper pectorals", "deltoids", "delts", "anterior deltoid", "triceps"].contains(target) { return "press" }
        if ["quadriceps", "quads"].contains(target) { return "squat" }
        if ["hamstrings", "glutes", "erector spinae", "erectors", "spinal erectors"].contains(target) { return "hinge" }
        if ["calves", "peroneals"].contains(target) { return "raise" }
        return "other"
    }

    private static func displayEquipment(_ value: String?) -> String {
        switch normalized(value) {
        case "body weight": return "Bodyweight"
        case "ez barbell": return "EZ-Bar"
        case "leverage machine": return "Leverage Machine"
        case "sled machine": return "Sled Machine"
        case "smith machine": return "Smith Machine"
        case "stability ball": return "Stability Ball"
        case "barbell": return "Barbell"
        case "dumbbell": return "Dumbbell"
        case "cable": return "Cable"
        case "band": return "Band"
        case "kettlebell": return "Kettlebell"
        case "rope": return "Rope"
        case "weighted": return "Weighted"
        default:
            guard let value, !value.isEmpty else { return "Other" }
            return value.capitalized
        }
    }

    private static func normalized(_ value: String?) -> String {
        (value ?? "")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct CustomExerciseRecord: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var muscle: String
    var equipment: String
    var movement: String

    var definition: ExerciseDefinition {
        ExerciseDefinition(
            id: id,
            name: name,
            muscle: muscle,
            equipment: equipment,
            movement: movement
        )
    }
}

enum CustomExerciseStore {
    static func load() -> [CustomExerciseRecord] {
        SwiftDataUserStore.customExercises()
    }

    static func save(_ records: [CustomExerciseRecord]) {
        SwiftDataUserStore.saveCustomExercises(records)
    }

    static func add(name: String, muscle: String, equipment: String, movement: String) {
        var records = load()
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty,
              !records.contains(where: { $0.name.caseInsensitiveCompare(cleanName) == .orderedSame }),
              ExerciseCatalog.findByName(cleanName) == nil else { return }

        records.append(
            CustomExerciseRecord(
                id: "custom-\(UUID().uuidString)",
                name: cleanName,
                muscle: muscle,
                equipment: equipment,
                movement: movement
            )
        )
        save(records)
    }

    static func delete(id: String) {
        var records = load()
        records.removeAll { $0.id == id }
        save(records)
    }

    static func isCustom(_ id: String) -> Bool {
        id.hasPrefix("custom-")
    }
}

// MARK: - Exercise search & shortcuts

enum ExerciseSearch {
    private static let aliases: [String: [String]] = [
        "Bench Press (Barbell)": ["bench", "barbell bench", "bb bench", "flat bench"],
        "Barbell Flat Bench Press": ["bench", "barbell bench", "bb bench", "flat bench"],
        "Bench Press (Dumbbell)": ["db bench", "dumbbell bench", "flat dumbbell press"],
        "Flat Dumbbell Bench Press": ["db bench", "dumbbell bench", "flat dumbbell press"],
        "Incline Bench Press (Dumbbell)": ["incline db bench", "incline dumbbell press", "incline press"],
        "Incline Dumbbell Bench Press": ["incline db bench", "incline dumbbell press", "incline press"],
        "Overhead Press (Barbell)": ["ohp", "military press", "barbell shoulder press"],
        "Standing Barbell Overhead Press (Military Press)": ["ohp", "military press", "barbell shoulder press"],
        "Shoulder Press (Dumbbell)": ["db shoulder press", "dumbbell press"],
        "Dumbbell Shoulder Press (Seated)": ["db shoulder press", "seated dumbbell press"],
        "Romanian Deadlift (Barbell)": ["rdl", "barbell rdl", "romanian"],
        "Dumbbell Romanian Deadlift": ["db rdl", "dumbbell rdl", "romanian"],
        "Stiff Leg Deadlift": ["sldl", "stiff leg"],
        "Lat Pulldown": ["lat pull down", "pulldown"],
        "Lat Pulldown - Wide Grip": ["wide pulldown", "wide grip pulldown", "lat pull down"],
        "Wide Grip Lat Pulldown": ["wide pulldown", "wide grip pulldown", "lat pull down"],
        "Neutral Grip Lat Pulldown": ["neutral pulldown", "close grip pulldown"],
        "Lateral Raise (Dumbbell)": ["lat raise", "side raise", "db lateral"],
        "Standing Dumbbell Lateral Raise": ["lat raise", "side raise", "db lateral"],
        "Lateral Raise (Cable)": ["cable lat raise", "cable lateral", "side delt cable"],
        "Lean-Away Cable Lateral Raise": ["lean away lateral", "cable lat raise"],
        "Face Pull": ["facepull", "rear delt cable"],
        "Cable Face Pull": ["facepull", "rear delt cable"],
        "Bent Over Row (Barbell)": ["barbell row", "bb row"],
        "Bent Over Row (Dumbbell)": ["db row", "dumbbell row"],
        "One Arm Dumbbell Row": ["one arm row", "single arm row", "db row"],
        "Single-Arm Dumbbell Row": ["one arm row", "single arm row", "db row"],
        "Seated Cable Row": ["cable row", "seated row"],
        "Seated Cable Row (V-Bar)": ["v bar row", "cable row", "close grip row"],
        "Chest Supported Machine Row": ["chest supported row", "machine row"],
        "Chest Supported Dumbbell Row": ["chest supported row", "db row"],
        "Leg Press": ["legpress"],
        "Close Feet Leg Press": ["close stance leg press", "narrow stance leg press", "platform narrow press"],
        "Lever Horizontal Leg Press": ["horizontal leg press", "machine leg press", "horizontal plate loaded leg press"],
        "Sled 45 Degree Wide Leg Press": ["45 degree leg press", "wide stance leg press", "plate loaded leg press"],
        "Smith Machine Leg Press": ["smith leg press", "smith lying leg press", "smith platform press"],
        "Leg Extension (Machine)": ["leg ext", "quad extension"],
        "Leg Curl (Lying)": ["lying ham curl", "hamstring curl"],
        "Lying Leg Curl": ["lying ham curl", "hamstring curl"],
        "Leg Curl (Seated)": ["seated ham curl", "hamstring curl"],
        "Seated Leg Curl Machine": ["seated ham curl", "hamstring curl"],
        "Hack Squat": ["hack"],
        "Hack Squat Machine": ["hack"],
        "Hip Thrust (Barbell)": ["hip thrust", "barbell thrust"],
        "Triceps Pushdown": ["pushdown", "tricep pressdown"],
        "Cable Triceps Rope Pushdown": ["rope pushdown", "rope pressdown"],
        "Cable Triceps Straight Bar Pushdown": ["bar pushdown", "pressdown"],
        "EZ-Bar Biceps Curl": ["ez curl", "ez bar curl"],
        "EZ-Bar Curl": ["ez curl", "ez bar curl"],
        "Hammer Curl": ["hammer"],
        "Kneeling Cable Crunch": ["cable crunch", "kneeling crunch"],
        "Abdominal Crunch Machine": ["ab crunch machine", "machine crunch", "ab machine"],
        "Captain's Chair Leg Raise": ["captains chair", "vertical knee raise"],
        "Pull Up": ["pullup", "pull-up"],
        "Chin Up": ["chinup", "chin-up"],
        "Push Up": ["pushup", "push-up"]
    ]

    static func matches(_ exercise: ExerciseDefinition, query: String) -> Bool {
        let q = normalize(query)
        guard !q.isEmpty else { return true }

        let haystacks = [
            exercise.name,
            exercise.muscle,
            exercise.equipment,
            exercise.movement
        ] + exercise.aliases + (aliases[exercise.name] ?? [])

        if haystacks.contains(where: { normalize($0).contains(q) }) { return true }

        let queryTokens = q.split(separator: " ").map(String.init)
        let combined = normalize(haystacks.joined(separator: " "))
        return queryTokens.allSatisfy { token in
            combined.contains(expand(token))
        }
    }

    private static func expand(_ token: String) -> String {
        switch token {
        case "db": return "dumbbell"
        case "bb": return "barbell"
        case "ohp": return "overhead press"
        case "rdl": return "romanian deadlift"
        case "sldl": return "stiff leg deadlift"
        case "lat": return "lateral"
        case "tri": return "triceps"
        case "bi": return "biceps"
        default: return token
        }
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "&", with: " and ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: #"[^a-z0-9 ]+"#, with: " ", options: .regularExpression)
            .split(separator: " ")
            .joined(separator: " ")
    }
}

enum ExerciseShortcutStore {
    static var favorites: [String] {
        SwiftDataUserStore.exerciseFavorites()
    }

    static var recent: [String] {
        SwiftDataUserStore.exerciseRecents()
    }

    static func isFavorite(_ id: String) -> Bool {
        favorites.contains(id)
    }

    static func toggleFavorite(_ id: String) {
        var items = favorites
        if items.contains(id) {
            items.removeAll { $0 == id }
        } else {
            items.insert(id, at: 0)
        }
        SwiftDataUserStore.saveExerciseFavorites(items)
        bumpRevision()
    }

    static func recordRecent(_ id: String) {
        var items = recent.filter { $0 != id }
        items.insert(id, at: 0)
        SwiftDataUserStore.saveExerciseRecents(Array(items.prefix(20)))
        bumpRevision()
    }

    static func restore(favorites: [String], recent: [String]) {
        SwiftDataUserStore.saveExerciseFavorites(favorites)
        SwiftDataUserStore.saveExerciseRecents(recent)
        bumpRevision()
    }

    private static func bumpRevision() {
        let revision = UserDefaults.standard.integer(forKey: "exerciseShortcutRevision")
        UserDefaults.standard.set(revision + 1, forKey: "exerciseShortcutRevision")
    }
}

// MARK: - Scheduling

struct ScheduledWorkoutRecord: Codable, Identifiable, Hashable {
    var id: String
    var date: Date
    var title: String
    var exerciseIDs: [String]
    var plan: [ProgramExercise]?
    var gymID: String
    var skipped: Bool
    var sourceLabel: String?

    init(
        id: String = UUID().uuidString,
        date: Date,
        title: String,
        exerciseIDs: [String],
        plan: [ProgramExercise]? = nil,
        gymID: String,
        skipped: Bool = false,
        sourceLabel: String? = nil
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.exerciseIDs = exerciseIDs
        self.plan = plan
        self.gymID = gymID
        self.skipped = skipped
        self.sourceLabel = sourceLabel
    }
}

enum WorkoutScheduleStore {
    static func load() -> [ScheduledWorkoutRecord] {
        SwiftDataUserStore.scheduledWorkouts()
    }

    static func save(_ items: [ScheduledWorkoutRecord]) {
        SwiftDataUserStore.saveScheduledWorkouts(items)
        bumpRevision()
    }

    static func add(_ item: ScheduledWorkoutRecord) {
        var items = load()
        items.append(item)
        save(items)
    }

    static func update(_ item: ScheduledWorkoutRecord) {
        var items = load()
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
        save(items)
    }

    static func remove(id: String) {
        save(load().filter { $0.id != id })
    }

    static func toggleSkipped(id: String) {
        var items = load()
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].skipped.toggle()
        save(items)
    }

    static func restore(_ items: [ScheduledWorkoutRecord]) {
        save(items)
    }

    private static func bumpRevision() {
        let revision = UserDefaults.standard.integer(forKey: "scheduleRevision")
        UserDefaults.standard.set(revision + 1, forKey: "scheduleRevision")
    }
}

// MARK: - Sharing

struct RepForgeSharePayload: Codable {
    var version: Int
    var kind: String
    var name: String
    var exercises: [ProgramExercise]?
    var days: [ProgramDay]?
}

enum RepForgeShareCodec {
    static func templateURL(name: String, exercises: [ProgramExercise]) -> URL {
        makeURL(
            RepForgeSharePayload(
                version: 1,
                kind: "template",
                name: name,
                exercises: exercises,
                days: nil
            )
        )
    }

    static func programURL(name: String, days: [ProgramDay]) -> URL {
        makeURL(
            RepForgeSharePayload(
                version: 1,
                kind: "program",
                name: name,
                exercises: nil,
                days: days
            )
        )
    }

    static func decode(_ url: URL) -> RepForgeSharePayload? {
        guard url.scheme?.lowercased() == "repforge",
              url.host?.lowercased() == "import",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let encoded = components.queryItems?.first(where: { $0.name == "payload" })?.value,
              let data = Data(base64URLEncoded: encoded) else {
            return nil
        }
        return try? JSONDecoder().decode(RepForgeSharePayload.self, from: data)
    }

    private static func makeURL(_ payload: RepForgeSharePayload) -> URL {
        let data = (try? JSONEncoder().encode(payload)) ?? Data()
        let encoded = data.base64URLEncodedString()
        var components = URLComponents()
        components.scheme = "repforge"
        components.host = "import"
        components.queryItems = [URLQueryItem(name: "payload", value: encoded)]
        return components.url ?? URL(string: "repforge://import")!
    }
}

extension Data {
    fileprivate func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    fileprivate init?(base64URLEncoded value: String) {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        self.init(base64Encoded: base64)
    }
}

// MARK: - Full backup

struct RepForgeBackupPayload: Codable {
    var version: Int
    var exportedAt: Date
    var templates: [BackupTemplate]
    var sessions: [BackupSession]
    var profiles: [BackupProfile]
    var bodyMeasurements: [BackupBodyMeasurement]?
    var customExercises: [CustomExerciseRecord]
    var gyms: [GymProfile]
    var scheduledWorkouts: [ScheduledWorkoutRecord]
    var programDays: [String: ProgramDay]
    var favorites: [String]
    var recents: [String]
    var settings: BackupSettings
}

struct BackupTemplate: Codable {
    var id: UUID
    var name: String
    var exerciseIDs: [String]
    var plan: [ProgramExercise]?
    var createdAt: Date
}

struct BackupSession: Codable {
    var id: UUID
    var title: String
    var startedAt: Date
    var endedAt: Date?
    var note: String?
    var gymID: String?
    var exercises: [BackupExerciseLog]
}

struct BackupExerciseLog: Codable {
    var id: UUID
    var exerciseID: String
    var order: Int
    var targetReps: String?
    var coachingNote: String?
    var supersetGroup: String?
    var sessionNote: String?
    var restSeconds: Int?
    var sets: [BackupSet]
}

struct BackupSet: Codable {
    var id: UUID
    var order: Int
    var weightKg: Double
    var reps: Int
    var completed: Bool
    var completedAt: Date?
    var setTypeRaw: String?
    var rpe: Double?
    var rir: Int?
    var note: String?
    var durationSeconds: Double?
    var distanceKm: Double?
    var inclinePercent: Double?
    var calories: Double?
    var averageHeartRate: Int?
}

struct BackupProfile: Codable {
    var id: UUID
    var displayName: String
    var bio: String
    var bodyWeightKg: Double
    var heightCm: Double
    var createdAt: Date
}

struct BackupBodyMeasurement: Codable {
    var id: UUID
    var date: Date
    var bodyWeightKg: Double
    var bodyFatPercent: Double?
    var waistCm: Double?
    var chestCm: Double?
    var armCm: Double?
    var thighCm: Double?
    var hipCm: Double?
}

struct BackupSettings: Codable {
    var appLanguage: String
    var measurementSystem: String
    var appearance: String
    var themePreset: String
    var textSize: String
    var hapticsEnabled: Bool
    var showPreviousSets: Bool
    var keepScreenAwake: Bool
    var defaultSets: Int
    var defaultRestSeconds: Int
    var autoRestTimer: Bool
    var autoCollapseCompleted: Bool
    var restNotifications: Bool?
    var countdownHaptics: Bool?
    var compactWorkoutMode: Bool?
    var highContrastWorkout: Bool?
    var progressionRule: String?
    var progressionStepKg: Double
    var activeGymID: String
    var separateRecordsByGym: Bool
    var prScope: String
    var seasonStartDate: Double
}

struct RepForgeBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

// MARK: - Built-in 3-week program

struct ProgramExercise: Hashable, Codable {
    var name: String
    var sets: Int
    var reps: String
    var note: String?
    var superset: String?

    init(_ name: String, _ sets: Int, _ reps: String, note: String? = nil, superset: String? = nil) {
        self.name = name
        self.sets = sets
        self.reps = reps
        self.note = note
        self.superset = superset
    }
}

struct ProgramDay: Identifiable, Hashable, Codable {
    let id: String
    let week: Int
    var day: String
    var partner: String
    var focus: String
    var exercises: [ProgramExercise]

    var title: String { "Week \(week) • \(day)" }
}

enum BuiltInProgram {
    static let days: [ProgramDay] = [
        ProgramDay(id: "w1-mon", week: 1, day: "Monday", partner: "with friend", focus: "Chest Strength & Quads", exercises: [
            .init("Barbell Flat Bench Press", 3, "6–8"),
            .init("Leg Press", 3, "8–10", note: "Beginner-friendly quad focus"),
            .init("Chest Supported Machine Row", 3, "8–10"),
            .init("Lying Leg Curl", 3, "10–12"),
            .init("Cable Triceps Rope Pushdown", 3, "12–15", superset: "A"),
            .init("Lateral Raise (Cable)", 3, "12–15", superset: "A")
        ]),
        ProgramDay(id: "w1-wed", week: 1, day: "Wednesday", partner: "with brother", focus: "Shoulders & Hamstrings", exercises: [
            .init("Dumbbell Shoulder Press (Seated)", 3, "8–10"),
            .init("Dumbbell Romanian Deadlift", 3, "8–10"),
            .init("Wide Grip Lat Pulldown", 3, "8–10"),
            .init("Leg Extension (Machine)", 3, "10–12"),
            .init("Standing Dumbbell Biceps Curl", 3, "12–15", superset: "A"),
            .init("Cable Face Pull", 3, "12–15", superset: "A")
        ]),
        ProgramDay(id: "w1-fri", week: 1, day: "Friday", partner: "with friend", focus: "Chest Volume & Upper Back", exercises: [
            .init("Barbell Flat Bench Press", 3, "8–10", note: "Lighter load, controlled reps"),
            .init("Goblet Squat", 3, "10–12"),
            .init("Seated Cable Row (V-Bar)", 3, "8–10"),
            .init("Incline Dumbbell Bench Press", 3, "10–12"),
            .init("Standing Calf Raise", 4, "12–15")
        ]),
        ProgramDay(id: "w1-bonus", week: 1, day: "Bonus Day", partner: "with brother", focus: "Arms & Shoulders", exercises: [
            .init("Standing Dumbbell Lateral Raise", 4, "12–15"),
            .init("Incline Dumbbell Curl", 3, "10–12"),
            .init("Cable Overhead Triceps Rope Extension", 3, "10–12"),
            .init("Reverse Pec Deck Machine", 3, "15"),
            .init("Captain's Chair Leg Raise", 3, "12–15")
        ]),

        ProgramDay(id: "w2-mon", week: 2, day: "Monday", partner: "with friend", focus: "Chest & Hamstrings Focus", exercises: [
            .init("Barbell Flat Bench Press", 3, "6–8"),
            .init("Hack Squat Machine", 3, "8–10"),
            .init("Single-Arm Dumbbell Row", 3, "8–10", note: "Per side"),
            .init("Seated Leg Curl Machine", 3, "10–12"),
            .init("Hammer Curl", 3, "10–12", superset: "A"),
            .init("Cable Triceps Straight Bar Pushdown", 3, "10–12", superset: "A")
        ]),
        ProgramDay(id: "w2-wed", week: 2, day: "Wednesday", partner: "with brother", focus: "Upper Body & Quads", exercises: [
            .init("Standing Barbell Overhead Press (Military Press)", 3, "6–8"),
            .init("Trap Bar Deadlift", 3, "6–8"),
            .init("Neutral Grip Lat Pulldown", 3, "8–10"),
            .init("Dumbbell Walking Lunges", 3, "10/leg"),
            .init("Cable Biceps Curl", 3, "12–15", superset: "A"),
            .init("Lateral Raise (Cable)", 3, "12–15", superset: "A")
        ]),
        ProgramDay(id: "w2-fri", week: 2, day: "Friday", partner: "with friend", focus: "Chest Pump & Back Thickness", exercises: [
            .init("Incline Dumbbell Bench Press", 3, "8–10"),
            .init("Leg Press", 3, "10–12"),
            .init("Chest Supported Dumbbell Row", 3, "10–12"),
            .init("Assisted Dip Machine", 3, "8–10", note: "Bench Dips can be used as an alternative"),
            .init("Seated Calf Raise Machine", 4, "12–15")
        ]),
        ProgramDay(id: "w2-bonus", week: 2, day: "Bonus Day", partner: "with brother", focus: "Pump & Core", exercises: [
            .init("Lean-Away Cable Lateral Raise", 4, "12–15"),
            .init("EZ-Bar Biceps Curl", 3, "10–12"),
            .init("Cable Triceps Rope Pushdown", 3, "10–12"),
            .init("Cable Face Pull", 3, "15"),
            .init("Kneeling Cable Crunch", 3, "12–15")
        ]),

        ProgramDay(id: "w3-mon", week: 3, day: "Monday", partner: "with friend", focus: "Strength & Focus", exercises: [
            .init("Barbell Flat Bench Press", 3, "6"),
            .init("Goblet Squat", 3, "8–10", note: "Use a heavier dumbbell"),
            .init("Seated Cable Row", 3, "8–10", note: "Neutral grip"),
            .init("Dumbbell Romanian Deadlift", 3, "10–12"),
            .init("Triceps Pushdown", 3, "10–12", superset: "A"),
            .init("EZ-Bar Reverse Curl", 3, "10–12", superset: "A")
        ]),
        ProgramDay(id: "w3-wed", week: 3, day: "Wednesday", partner: "with brother", focus: "Shoulders & Back Width", exercises: [
            .init("Arnold Dumbbell Press", 3, "8–10"),
            .init("Romanian Deadlift (Barbell)", 3, "8–10"),
            .init("Wide Grip Lat Pulldown", 3, "8–10"),
            .init("Leg Extension (Machine)", 3, "12–15"),
            .init("Hammer Curl", 3, "12–15", superset: "A"),
            .init("Cable Face Pull", 3, "12–15", superset: "A")
        ]),
        ProgramDay(id: "w3-fri", week: 3, day: "Friday", partner: "with friend", focus: "Chest & Triceps Volume", exercises: [
            .init("Flat Dumbbell Bench Press", 3, "8–10"),
            .init("Close-Grip Barbell Bench Press", 3, "8–10"),
            .init("Chest Supported Machine Row", 3, "10–12"),
            .init("Leg Press", 3, "10–12"),
            .init("Standing Calf Raise", 4, "12–15")
        ]),
        ProgramDay(id: "w3-bonus", week: 3, day: "Bonus Day", partner: "with brother", focus: "Shoulder & Arm Burnout", exercises: [
            .init("Standing Dumbbell Lateral Raise", 4, "12–15"),
            .init("Dumbbell Preacher Curl", 3, "10–12", note: "Incline bench spider curl is an alternative"),
            .init("Lying Dumbbell Skull Crushers", 3, "10–12"),
            .init("Reverse Pec Deck Machine", 3, "15"),
            .init("Lying Floor Leg Raises", 3, "15")
        ])
    ]

    static func week(_ week: Int) -> [ProgramDay] {
        days.filter { $0.week == week }
    }
}

@MainActor
final class ProgramPlanStore: ObservableObject {
    @Published private(set) var customDays: [String: ProgramDay] = [:]

    init() {
        customDays = SwiftDataUserStore.programDays()
    }

    func day(for base: ProgramDay) -> ProgramDay {
        customDays[base.id] ?? base
    }

    func days(for week: Int) -> [ProgramDay] {
        BuiltInProgram.week(week).map(day(for:))
    }

    func isCustomized(_ day: ProgramDay) -> Bool {
        customDays[day.id] != nil
    }

    func save(_ day: ProgramDay) {
        customDays[day.id] = day
        persist()
    }

    func reset(_ day: ProgramDay) {
        customDays.removeValue(forKey: day.id)
        persist()
    }

    private func persist() {
        SwiftDataUserStore.saveProgramDays(customDays)
    }
}

// MARK: - Persistence

@Model
final class WorkoutTemplate {
    var id: UUID
    var name: String
    var exerciseIDsCSV: String
    var planJSON: String?
    var createdAt: Date

    init(name: String, exerciseIDs: [String], plan: [ProgramExercise]? = nil) {
        self.id = UUID()
        self.name = name
        self.exerciseIDsCSV = exerciseIDs.joined(separator: ",")
        self.planJSON = Self.encodePlan(plan)
        self.createdAt = .now
    }

    var exerciseIDs: [String] {
        get { exerciseIDsCSV.split(separator: ",").map(String.init).filter { !$0.isEmpty } }
        set { exerciseIDsCSV = newValue.joined(separator: ",") }
    }

    var plannedExercises: [ProgramExercise]? {
        get {
            guard let planJSON,
                  let data = planJSON.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode([ProgramExercise].self, from: data)
        }
        set {
            planJSON = Self.encodePlan(newValue)
        }
    }

    private static func encodePlan(_ plan: [ProgramExercise]?) -> String? {
        guard let plan,
              let data = try? JSONEncoder().encode(plan) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

@Model
final class WorkoutSession {
    var id: UUID
    var title: String
    var startedAt: Date
    var endedAt: Date?
    var note: String?
    var gymID: String?
    @Relationship(deleteRule: .cascade)
    var exercises: [ExerciseLog]

    init(
        title: String,
        startedAt: Date = .now,
        exercises: [ExerciseLog] = [],
        note: String? = nil,
        gymID: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.startedAt = startedAt
        self.exercises = exercises
        self.note = note
        self.gymID = gymID
    }

    var duration: TimeInterval {
        (endedAt ?? .now).timeIntervalSince(startedAt)
    }

    var totalVolume: Double {
        exercises.flatMap(\.sets).filter(\.completed).reduce(0) { $0 + ($1.weightKg * Double($1.reps)) }
    }

    var totalCardioDistanceKm: Double {
        exercises.flatMap(\.sets).filter(\.completed).reduce(0) { $0 + ($1.distanceKm ?? 0) }
    }

    var totalCardioDurationSeconds: Double {
        exercises.flatMap(\.sets).filter(\.completed).reduce(0) { $0 + ($1.durationSeconds ?? 0) }
    }
}

@Model
final class ExerciseLog {
    var id: UUID
    var exerciseID: String
    var order: Int
    var targetReps: String?
    var coachingNote: String?
    var supersetGroup: String?
    var sessionNote: String?
    var restSeconds: Int?
    @Relationship(deleteRule: .cascade)
    var sets: [WorkoutSet]

    init(
        exerciseID: String,
        order: Int,
        targetReps: String? = nil,
        coachingNote: String? = nil,
        supersetGroup: String? = nil,
        sessionNote: String? = nil,
        restSeconds: Int? = nil,
        sets: [WorkoutSet] = []
    ) {
        self.id = UUID()
        self.exerciseID = exerciseID
        self.order = order
        self.targetReps = targetReps
        self.coachingNote = coachingNote
        self.supersetGroup = supersetGroup
        self.sessionNote = sessionNote
        self.restSeconds = restSeconds
        self.sets = sets
    }
}

@Model
final class WorkoutSet {
    var id: UUID
    var order: Int
    var weightKg: Double
    var reps: Int
    var completed: Bool
    var completedAt: Date?
    var setTypeRaw: String?
    var rpe: Double?
    var rir: Int?
    var note: String?
    var durationSeconds: Double?
    var distanceKm: Double?
    var inclinePercent: Double?
    var calories: Double?
    var averageHeartRate: Int?

    init(
        order: Int,
        weightKg: Double = 0,
        reps: Int = 0,
        completed: Bool = false,
        setTypeRaw: String? = nil,
        rpe: Double? = nil,
        rir: Int? = nil,
        note: String? = nil,
        durationSeconds: Double? = nil,
        distanceKm: Double? = nil,
        inclinePercent: Double? = nil,
        calories: Double? = nil,
        averageHeartRate: Int? = nil
    ) {
        self.id = UUID()
        self.order = order
        self.weightKg = weightKg
        self.reps = reps
        self.completed = completed
        self.setTypeRaw = setTypeRaw
        self.rpe = rpe
        self.rir = rir
        self.note = note
        self.durationSeconds = durationSeconds
        self.distanceKm = distanceKm
        self.inclinePercent = inclinePercent
        self.calories = calories
        self.averageHeartRate = averageHeartRate
    }

    var setType: String {
        get { setTypeRaw ?? "working" }
        set { setTypeRaw = newValue == "working" ? nil : newValue }
    }

    var countsForPR: Bool {
        completed && setType != "warmup"
    }
}

@Model
final class UserProfile {
    var id: UUID
    var displayName: String
    var bio: String
    var bodyWeightKg: Double
    var heightCm: Double
    var createdAt: Date

    init(displayName: String = "Athlete") {
        self.id = UUID()
        self.displayName = displayName
        self.bio = "Consistency compounds."
        self.bodyWeightKg = 0
        self.heightCm = 0
        self.createdAt = .now
    }
}

@Model
final class BodyMeasurement {
    var id: UUID
    var date: Date
    var bodyWeightKg: Double
    var bodyFatPercent: Double?
    var waistCm: Double?
    var chestCm: Double?
    var armCm: Double?
    var thighCm: Double?
    var hipCm: Double?

    init(
        date: Date = .now,
        bodyWeightKg: Double = 0,
        bodyFatPercent: Double? = nil,
        waistCm: Double? = nil,
        chestCm: Double? = nil,
        armCm: Double? = nil,
        thighCm: Double? = nil,
        hipCm: Double? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.bodyWeightKg = bodyWeightKg
        self.bodyFatPercent = bodyFatPercent
        self.waistCm = waistCm
        self.chestCm = chestCm
        self.armCm = armCm
        self.thighCm = thighCm
        self.hipCm = hipCm
    }
}

// MARK: - Metrics

enum Metrics {
    static func completedSessions(_ sessions: [WorkoutSession]) -> [WorkoutSession] {
        sessions.filter { $0.endedAt != nil }
    }

    static func scopedSessions(
        _ sessions: [WorkoutSession],
        gymID: String? = nil,
        startDate: Date? = nil
    ) -> [WorkoutSession] {
        completedSessions(sessions).filter { session in
            let gymMatches: Bool
            if let gymID, AppPreferences.separateRecordsByGym {
                gymMatches = GymProfileStore.sessionGymID(session) == gymID
            } else {
                gymMatches = true
            }

            let dateMatches = startDate.map { session.startedAt >= $0 } ?? true
            return gymMatches && dateMatches
        }
    }

    static func performances(
        exerciseID: String,
        sessions: [WorkoutSession],
        gymID: String? = nil,
        startDate: Date? = nil
    ) -> [(date: Date, weight: Double, oneRM: Double, volume: Double)] {
        scopedSessions(sessions, gymID: gymID, startDate: startDate).compactMap { session in
            let sets = session.exercises
                .filter { $0.exerciseID == exerciseID }
                .flatMap(\.sets)
                .filter(\.countsForPR)
            guard !sets.isEmpty else { return nil }
            let best = sets.map(\.weightKg).max() ?? 0
            let oneRM = sets.map { estimated1RM(weight: $0.weightKg, reps: $0.reps) }.max() ?? 0
            let volume = sets.reduce(0) { $0 + $1.weightKg * Double($1.reps) }
            return (session.endedAt ?? session.startedAt, best, oneRM, volume)
        }
        .sorted { $0.date < $1.date }
    }

    static func previousSets(
        exerciseID: String,
        sessions: [WorkoutSession],
        gymID: String? = nil
    ) -> [(Double, Int)] {
        guard let latest = scopedSessions(sessions, gymID: gymID)
            .filter({ $0.exercises.contains(where: { $0.exerciseID == exerciseID }) })
            .max(by: { ($0.endedAt ?? $0.startedAt) < ($1.endedAt ?? $1.startedAt) }),
              let log = latest.exercises.first(where: { $0.exerciseID == exerciseID })
        else { return [] }

        return log.sets
            .filter(\.countsForPR)
            .sorted { $0.order < $1.order }
            .map { ($0.weightKg, $0.reps) }
    }

    static func personalBest(
        exerciseID: String,
        sessions: [WorkoutSession],
        gymID: String? = nil,
        startDate: Date? = nil
    ) -> Double {
        performances(
            exerciseID: exerciseID,
            sessions: sessions,
            gymID: gymID,
            startDate: startDate
        ).map(\.weight).max() ?? 0
    }

    static func estimated1RM(weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        if reps == 1 { return weight }
        return weight * (1 + Double(reps) / 30.0)
    }
}

struct MuscleVolumeEntry: Identifiable {
    let muscle: String
    let sets: Double
    var id: String { muscle }
}

struct MuscleRecoveryEntry: Identifiable {
    let muscle: String
    let recovery: Double
    let lastTrained: Date?
    let recentSets: Double
    var id: String { muscle }

    var status: String {
        if lastTrained == nil { return L10n.text("No recent data", "Geen recente data") }
        if recovery >= 0.85 { return L10n.text("Ready", "Hersteld") }
        if recovery >= 0.55 { return L10n.text("Mostly recovered", "Grotendeels hersteld") }
        return L10n.text("Recovering", "Herstellend")
    }
}

enum MuscleAnalytics {
    static func sessionVolume(_ session: WorkoutSession) -> [MuscleVolumeEntry] {
        volume(sessions: [session], since: .distantPast)
    }

    static func weeklyVolume(
        sessions: [WorkoutSession],
        gymID: String? = nil,
        weeksBack: Int = 0
    ) -> [MuscleVolumeEntry] {
        let calendar = Calendar.current
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start,
              let start = calendar.date(byAdding: .weekOfYear, value: -weeksBack, to: thisWeek),
              let end = calendar.date(byAdding: .day, value: 7, to: start) else {
            return []
        }

        let scoped = sessions.filter { session in
            session.endedAt != nil &&
            session.startedAt >= start &&
            session.startedAt < end &&
            (!AppPreferences.separateRecordsByGym || gymID == nil || GymProfileStore.sessionGymID(session) == gymID)
        }

        return volume(sessions: scoped, since: start)
    }

    static func volume(sessions: [WorkoutSession], since: Date) -> [MuscleVolumeEntry] {
        var totals: [String: Double] = [:]

        for session in sessions where session.startedAt >= since && session.endedAt != nil {
            for log in session.exercises {
                guard let exercise = ExerciseCatalog.find(log.exerciseID) else { continue }
                let workingSets = Double(log.sets.filter(\.countsForPR).count)
                guard workingSets > 0 else { continue }

                for contribution in exercise.detailedMuscles {
                    totals[contribution.muscle, default: 0] += workingSets * contribution.weight
                }
            }
        }

        return totals
            .map { MuscleVolumeEntry(muscle: $0.key, sets: $0.value) }
            .sorted { $0.sets > $1.sets }
    }

    static func recovery(
        sessions: [WorkoutSession],
        gymID: String? = nil,
        now: Date = .now
    ) -> [MuscleRecoveryEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -10, to: now) ?? .distantPast
        var lastDates: [String: Date] = [:]
        var recentSets: [String: Double] = [:]

        for session in sessions where session.endedAt != nil && session.startedAt >= cutoff {
            if AppPreferences.separateRecordsByGym,
               let gymID,
               GymProfileStore.sessionGymID(session) != gymID {
                continue
            }

            let date = session.endedAt ?? session.startedAt

            for log in session.exercises {
                guard let exercise = ExerciseCatalog.find(log.exerciseID) else { continue }
                let count = Double(log.sets.filter(\.countsForPR).count)
                guard count > 0 else { continue }

                for contribution in exercise.detailedMuscles {
                    let weighted = count * contribution.weight
                    recentSets[contribution.muscle, default: 0] += weighted
                    if date > (lastDates[contribution.muscle] ?? .distantPast) {
                        lastDates[contribution.muscle] = date
                    }
                }
            }
        }

        return MuscleMap.trackedMuscles.compactMap { muscle in
            guard let last = lastDates[muscle] else { return nil }
            let sets = recentSets[muscle, default: 0]
            let hours = max(0, now.timeIntervalSince(last) / 3600)
            let recoveryHours = min(84.0, 36.0 + min(48.0, sets * 2.0))
            let score = min(1, hours / recoveryHours)
            return MuscleRecoveryEntry(
                muscle: muscle,
                recovery: score,
                lastTrained: last,
                recentSets: sets
            )
        }
        .sorted { $0.recovery < $1.recovery }
    }
}

// MARK: - Exercise media

struct ExerciseDBGenderMedia: Decodable {
    let male: String?
    let female: String?
}

struct ExerciseDBItem: Decodable {
    let id: String
    let name: String
    let aliases: [String]?
    let bodyPart: String?
    let target: String?
    let secondaryMuscles: [String]?
    let equipment: String?
    let muscleGroup: String?
    let steps: [String]?
    let formCues: [String]?
    let videos: ExerciseDBGenderMedia?
    let thumbnails: ExerciseDBGenderMedia?
}

struct ExerciseMedia {
    let matchedName: String
    let maleVideoURL: URL?
    let femaleVideoURL: URL?
    let maleThumbnailURL: URL?
    let femaleThumbnailURL: URL?
    let sourceName: String
    let sourceURL: URL?

    var hasBothGenders: Bool {
        maleVideoURL != nil && femaleVideoURL != nil
    }
}

actor ExerciseMediaCatalog {
    static let shared = ExerciseMediaCatalog()

    private var cached: [ExerciseDBItem]?

    func exercises() async throws -> [ExerciseDBItem] {
        if let cached { return cached }

        if let localURL = Bundle.main.url(forResource: "ExerciseDatabase", withExtension: "json"),
           let localData = try? Data(contentsOf: localURL),
           let localItems = try? JSONDecoder().decode([ExerciseDBItem].self, from: localData),
           !localItems.isEmpty {
            cached = localItems
            return localItems
        }

        let url = URL(string: "https://raw.githubusercontent.com/luisaraujoc/free-exercise-db-api/main/data/exercises.json")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .returnCacheDataElseLoad
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode([ExerciseDBItem].self, from: data)
        cached = decoded
        return decoded
    }
}

enum ExerciseMediaService {
    static func media(for exercise: ExerciseDefinition) async throws -> ExerciseMedia? {
        let items = try await ExerciseMediaCatalog.shared.exercises()
        guard !items.isEmpty else { return nil }

        if noExactDemo.contains(exercise.name) ||
            (exercise.id.hasPrefix("gym-") && exercise.sourceID == nil) {
            // Never substitute a similar-but-different movement's tutorial.
            return nil
        }

        let selected: ExerciseDBItem?

        if let sourceID = exercise.sourceID ?? exactSourceIDs[exercise.name] {
            selected = items.first(where: { $0.id == sourceID })
        } else {
            let query = preferredSearchTerm(for: exercise)
            let ranked = items
                .map { ($0, score(item: $0, query: query, exercise: exercise)) }
                .sorted { $0.1 > $1.1 }

            if let (best, bestScore) = ranked.first, bestScore >= 300 {
                selected = best
            } else {
                selected = nil
            }
        }

        guard let best = selected else { return nil }

        let maleVideo = best.videos?.male.flatMap(URL.init(string:))
        let femaleVideo = best.videos?.female.flatMap(URL.init(string:))
        let maleThumb = best.thumbnails?.male.flatMap(URL.init(string:))
        let femaleThumb = best.thumbnails?.female.flatMap(URL.init(string:))

        guard maleVideo != nil || femaleVideo != nil || maleThumb != nil || femaleThumb != nil else {
            return nil
        }

        return ExerciseMedia(
            matchedName: best.name,
            maleVideoURL: maleVideo,
            femaleVideoURL: femaleVideo,
            maleThumbnailURL: maleThumb,
            femaleThumbnailURL: femaleThumb,
            sourceName: "Free Exercise DB",
            sourceURL: URL(string: "https://github.com/luisaraujoc/free-exercise-db-api")
        )
    }

    // These mappings were manually audited against the source catalog so a
    // semantically different exercise can never win only because of aliases.
    private static let exactSourceIDs: [String: String] = [
        "Barbell Flat Bench Press": "0025",
        "Bench Press (Barbell)": "0025",
        "Chest Supported Machine Row": "1349",
        "Lying Leg Curl": "0586",
        "Leg Curl (Lying)": "0586",
        "Cable Triceps Rope Pushdown": "0200",
        "Lateral Raise (Cable)": "0178",
        "Dumbbell Shoulder Press (Seated)": "0289",
        "Shoulder Press (Dumbbell)": "0289",
        "Wide Grip Lat Pulldown": "drv-cable-bar-lateral-pulldown-wide-shoulder-grip",
        "Lat Pulldown - Wide Grip": "drv-cable-bar-lateral-pulldown-wide-shoulder-grip",
        "Leg Extension (Machine)": "0585",
        "Standing Dumbbell Biceps Curl": "0294",
        "Goblet Squat": "1760",
        "Seated Cable Row (V-Bar)": "0208",
        "Seated Cable Row": "0208",
        "Incline Dumbbell Bench Press": "0314",
        "Incline Bench Press (Dumbbell)": "0314",
        "Standing Calf Raise": "0605",
        "Standing Dumbbell Lateral Raise": "0334",
        "Incline Dumbbell Curl": "0318",
        "Cable Overhead Triceps Rope Extension": "0194",
        "Reverse Pec Deck Machine": "0602",
        "Captain's Chair Leg Raise": "0826",
        "Hack Squat Machine": "0743",
        "Seated Leg Curl Machine": "0599",
        "Leg Curl (Seated)": "0599",
        "Cable Triceps Straight Bar Pushdown": "1723",
        "Standing Barbell Overhead Press (Military Press)": "0553",
        "Neutral Grip Lat Pulldown": "0974",
        "Dumbbell Walking Lunges": "0336",
        "Walking Lunge": "0336",
        "Cable Biceps Curl": "0229",
        "Chest Supported Dumbbell Row": "0327",
        "Seated Calf Raise Machine": "0594",
        "EZ-Bar Biceps Curl": "2407",
        "EZ-Bar Curl": "2407",
        "Kneeling Cable Crunch": "0175",
        "Abdominal Crunch Machine": "1452",
        "Triceps Pushdown": "1723",
        "Arnold Dumbbell Press": "2137",
        "Close-Grip Barbell Bench Press": "0030",
        "Dumbbell Preacher Curl": "0402",
        "Lying Dumbbell Skull Crushers": "0351",
        "Lying Floor Leg Raises": "0865",
        "Flat Leg Raise": "0865",
        "Close Feet Leg Press": "drv-close-feet-leg-press",
        "Lever Horizontal Leg Press": "2611",
        "Sled 45 Degree Wide Leg Press": "0740",
        "Smith Machine Leg Press": "0748"
    ]

    // The source database does not contain an exact enough demonstration for
    // these RepForge exercises. Showing no video is preferable to a wrong one.
    private static let noExactDemo: Set<String> = [
        "Leg Press",
        "Cable Face Pull",
        "Face Pull",
        "Dumbbell Romanian Deadlift",
        "Romanian Deadlift (Barbell)",
        "Trap Bar Deadlift",
        "Single-Arm Dumbbell Row",
        "One Arm Dumbbell Row",
        "Hammer Curl",
        "Assisted Dip Machine",
        "Lean-Away Cable Lateral Raise",
        "EZ-Bar Reverse Curl",
        "Flat Dumbbell Bench Press",
        "Bench Press (Dumbbell)"
    ]

    private static func preferredSearchTerm(for exercise: ExerciseDefinition) -> String {
        let explicit: [String: String] = [
            "Bench Press (Smith Machine)": "smith machine bench press",
            "Decline Bench Press": "barbell decline bench press",
            "Chest Press (Machine)": "lever chest press",
            "Cable Fly": "cable fly",
            "Push Up": "push up",
            "Dip (Chest)": "chest dip",
            "Deadlift (Barbell)": "barbell deadlift",
            "Bent Over Row (Barbell)": "barbell bent over row",
            "Bent Over Row (Dumbbell)": "dumbbell bent over row",
            "Lat Pulldown": "cable pulldown",
            "Pull Up": "pull up",
            "Chin Up": "chin up",
            "Back Extension": "back extension",
            "Shoulder Press (Machine)": "lever shoulder press",
            "Front Raise": "dumbbell front raise",
            "Rear Delt Fly": "dumbbell rear delt fly",
            "Biceps Curl (Barbell)": "barbell curl",
            "Biceps Curl (Dumbbell)": "dumbbell biceps curl",
            "Preacher Curl": "lever preacher curl",
            "Squat (Barbell)": "barbell squat",
            "Front Squat": "barbell front squat",
            "Bulgarian Split Squat": "dumbbell bulgarian split squat",
            "Hip Thrust (Barbell)": "barbell hip thrust",
            "Standing Calf Raise (Dumbbell)": "dumbbell standing calf raise",
            "Crunch": "floor crunch",
            "Cable Crunch": "cable kneeling crunch",
            "Hanging Leg Raise": "hanging leg hip raise",
            "Plank": "plank",
            "Russian Twist": "russian twist",
            "Bicycle Crunch": "bicycle crunch"
        ]

        if let explicit = explicit[exercise.name] { return explicit }

        return exercise.name
            .replacingOccurrences(of: #"\s*\([^)]*\)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "&", with: " and ")
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
            .split(separator: " ")
            .map(String.init)
            .filter { !["the", "with", "machine", "exercise"].contains($0) }
            .joined(separator: " ")
    }

    private static func score(item: ExerciseDBItem, query: String, exercise: ExerciseDefinition) -> Int {
        let q = normalize(query)
        let qTokens = Set(q.split(separator: " ").map(String.init))
        let primary = normalize(item.name)

        var best = 0

        if primary == q {
            best = 700
        } else if primary.contains(q) || q.contains(primary) {
            best = 360
        } else {
            let nameTokens = Set(primary.split(separator: " ").map(String.init))
            let intersection = qTokens.intersection(nameTokens).count
            let union = qTokens.union(nameTokens).count
            best = union == 0 ? 0 : Int((Double(intersection) / Double(union)) * 180.0)
        }

        for alias in item.aliases ?? [] {
            let normalizedAlias = normalize(alias)
            if normalizedAlias == q {
                best = max(best, 500)
            } else if normalizedAlias.contains(q) || q.contains(normalizedAlias) {
                best = max(best, 260)
            }
        }

        if let equipment = item.equipment {
            let sourceEquipment = normalize(equipment)
            let appEquipment = normalize(exercise.equipment)
            let compatible =
                sourceEquipment.contains(appEquipment) ||
                appEquipment.contains(sourceEquipment) ||
                (appEquipment == "machine" && (
                    sourceEquipment.contains("leverage") ||
                    sourceEquipment.contains("sled") ||
                    sourceEquipment.contains("smith")
                )) ||
                (appEquipment == "bodyweight" && sourceEquipment.contains("body weight"))

            best += compatible ? 45 : -80
        }

        if item.videos?.male != nil || item.videos?.female != nil {
            best += 20
        }

        return best
    }
}

@MainActor
final class ExerciseMediaModel: ObservableObject {
    @Published var media: ExerciseMedia?
    @Published var isLoading = false
    @Published var loadFailed = false

    func load(exercise: ExerciseDefinition) async {
        isLoading = true
        loadFailed = false
        defer { isLoading = false }

        do {
            media = try await ExerciseMediaService.media(for: exercise)
            loadFailed = media == nil
        } catch {
            media = nil
            loadFailed = true
        }
    }
}

// MARK: - Persistence maintenance

enum PersistenceMaintenance {
    @MainActor
    static func cleanupOrphanExerciseLogs(context: ModelContext) {
        do {
            let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
            let logs = try context.fetch(FetchDescriptor<ExerciseLog>())

            let referencedIDs = Set(
                sessions.flatMap { session in
                    session.exercises.map(\.id)
                }
            )

            let orphans = logs.filter { !referencedIDs.contains($0.id) }
            guard !orphans.isEmpty else { return }

            for log in orphans {
                context.delete(log)
            }

            try context.save()
        } catch {
            // Maintenance should never block startup.
        }
    }
}

