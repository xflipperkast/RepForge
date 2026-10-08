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
        default: return Color(red: 0.055, green: 0.070, blue: 0.078)
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
        default: return Color(red: 0.105, green: 0.135, blue: 0.150)
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
        default: return Color(red: 0.140, green: 0.175, blue: 0.190)
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
        default: return Color(red: 0.18, green: 0.63, blue: 1.0)
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
    @State private var importMessage: String?

    @AppStorage("appLanguage") private var appLanguage = "en"
    @AppStorage("appearance") private var appearance = "dark"
    @AppStorage("themePreset") private var themePreset = "forge"
    @AppStorage("textSize") private var textSize = "standard"
    @AppStorage("layoutStyle") private var layoutStyle = "balanced"
    @AppStorage("measurementSystem") private var measurementSystem = "metric"

    var body: some View {
        TabView(selection: $tab) {
            StartWorkoutView()
                .tabItem { Label(L10n.text("Train", "Trainen"), systemImage: "bolt.fill") }
                .tag(0)
            TrainingHubView()
                .tabItem { Label(L10n.text("Plans", "Schema's"), systemImage: "square.stack.3d.up.fill") }
                .tag(1)
            ExerciseLibraryView()
                .tabItem { Label(L10n.exercises, systemImage: "dumbbell.fill") }
                .tag(2)
            HistoryView()
                .tabItem { Label(L10n.history, systemImage: "clock.arrow.circlepath") }
                .tag(3)
            ProfileView()
                .tabItem { Label(L10n.profile, systemImage: "person.crop.circle.fill") }
                .tag(4)
        }
        .tint(RFTheme.accent)
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

struct GymQuickPicker: View {
    @Binding var activeGymID: String
    @State private var refresh = UUID()
    @AppStorage("gymRevision") private var gymRevision = 0

    var body: some View {
        Menu {
            ForEach(GymProfileStore.load()) { gym in
                Button {
                    activeGymID = gym.id
                    Haptics.light()
                    refresh = UUID()
                } label: {
                    if gym.id == activeGymID {
                        Label(gym.name, systemImage: "checkmark")
                    } else {
                        Text(gym.name)
                    }
                }
            }
        } label: {
            Label(
                GymProfileStore.profile(id: activeGymID).name,
                systemImage: "mappin.and.ellipse"
            )
            .font(.caption.bold())
            .lineLimit(1)
        }
        .id("\(refresh)-\(gymRevision)")
        .buttonStyle(.bordered)
    }
}

struct StartWorkoutView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutTemplate.createdAt, order: .reverse) private var templates: [WorkoutTemplate]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @State private var showTemplateEditor = false
    @State private var showTrainingHub = false
    @State private var templateSeed: ProgramDay?
    @State private var editingTemplate: WorkoutTemplate?
    @State private var activeSession: WorkoutSession?
    @State private var scheduleSeed: ScheduledWorkoutRecord?
    @AppStorage("activeGymID") private var activeGymID = GymProfileStore.defaultID
    @AppStorage("scheduleRevision") private var scheduleRevision = 0

    private var upcomingScheduled: [ScheduledWorkoutRecord] {
        _ = scheduleRevision
        let start = Calendar.current.startOfDay(for: .now)
        return WorkoutScheduleStore.load()
            .filter { !$0.skipped && $0.date >= start }
            .prefix(4)
            .map { $0 }
    }

    private var completedThisWeek: Int {
        sessions.filter {
            $0.endedAt != nil && Calendar.current.isDate(
                $0.startedAt, equalTo: .now, toGranularity: .weekOfYear
            )
        }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RFLayout.sectionSpacing) {
                    VStack(alignment: .leading, spacing: RFLayout.sectionSpacing) {
                        HStack(alignment: .top, spacing: 14) {
                            VStack(alignment: .leading, spacing: 9) {
                                Text(L10n.text("YOUR TRAINING SPACE", "JOUW TRAININGSRUIMTE"))
                                    .font(.caption2.weight(.heavy))
                                    .tracking(1.8)
                                    .foregroundStyle(RFTheme.accent)

                                Text(L10n.text("Make today's sets count.", "Haal meer uit elke set."))
                                    .font(RFLayout.heroFont)
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(L10n.text(
                                    "Start quickly. Log every rep. See your progress.",
                                    "Start direct. Log elke rep. Zie je vooruitgang."
                                ))
                                .font(.subheadline)
                                .foregroundStyle(RFTheme.muted)
                            }

                            Spacer(minLength: 0)

                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: RFLayout.style == "compact" ? 26 : 32, weight: .bold))
                                .foregroundStyle(RFTheme.accent)
                                .frame(width: RFLayout.style == "compact" ? 54 : 68,
                                       height: RFLayout.style == "compact" ? 54 : 68)
                                .background(RFTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 18))
                                .accessibilityHidden(true)
                        }

                        HStack(spacing: 10) {
                            Label("\(completedThisWeek) " + L10n.text("this week", "deze week"), systemImage: "checkmark.circle")
                            Spacer()
                            Label("\(templates.count) " + L10n.text("routines", "schema's"), systemImage: "rectangle.stack")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, RFLayout.style == "compact" ? 0 : 6)
                    }
                    .padding(RFLayout.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RFTheme.heroGradient)
                    .clipShape(RoundedRectangle(cornerRadius: RFLayout.cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: RFLayout.cornerRadius)
                            .stroke(RFTheme.cardBorder)
                    )

                    ForgeMomentumCard(sessions: sessions, condensed: true)

                    WorkoutActivityHeatmap(sessions: sessions, condensed: true)

                    NavigationLink {
                        MuscleIntelligenceScreen()
                    } label: {
                        MuscleIntelligencePanel(sessions: sessions, compact: true)
                    }
                    .buttonStyle(.plain)

                    HStack {
                        Text(L10n.text("Quick Start", "Snel starten"))
                            .font(.title2.bold())
                        Spacer()
                        GymQuickPicker(activeGymID: $activeGymID)
                    }

                    Button {
                        activeSession = createSession(title: "Workout", exerciseIDs: [])
                    } label: {
                        HStack {
                            Image(systemName: "bolt.fill")
                                .font(.title3.bold())
                            Text(L10n.text("Start an empty workout", "Lege training starten"))
                                .font(.headline)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.headline)
                        }
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RFLayout.style == "compact" ? 11 : 17)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(RFTheme.accent)

                    if !upcomingScheduled.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(L10n.text("Upcoming", "Gepland"))
                                    .font(.title2.bold())
                                Spacer()
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundStyle(RFTheme.accent)
                            }

                            ForEach(upcomingScheduled) { item in
                                ScheduledWorkoutCard(
                                    item: item,
                                    onStart: {
                                        activeSession = createSession(schedule: item)
                                    },
                                    onReschedule: {
                                        scheduleSeed = item
                                    },
                                    onSkip: {
                                        WorkoutScheduleStore.toggleSkipped(id: item.id)
                                    },
                                    onDelete: {
                                        WorkoutScheduleStore.remove(id: item.id)
                                    }
                                )
                            }
                        }
                    }

                    HStack {
                        Text(L10n.text("Your templates", "Jouw templates")).font(.title2.bold())
                        Spacer()
                        Button {
                            templateSeed = nil
                            showTemplateEditor = true
                        } label: {
                            Label("Template", systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                    }

                    if templates.isEmpty {
                        EmptyCard(
                            icon: "rectangle.stack.badge.plus",
                            title: "Build your first template",
                            text: "Save a repeatable workout, then launch it with one tap."
                        )
                    } else {
                        LazyVGrid(columns: RFLayout.templateColumns, spacing: RFLayout.style == "compact" ? 8 : 14) {
                            ForEach(templates) { template in
                                TemplateCard(
                                    template: template,
                                    onStart: {
                                        activeSession = createSession(template: template)
                                    },
                                    onEdit: {
                                        editingTemplate = template
                                    },
                                    onDuplicate: {
                                        duplicateTemplate(template)
                                    },
                                    onSchedule: {
                                        scheduleSeed = ScheduledWorkoutRecord(
                                            date: defaultScheduleDate(),
                                            title: template.name,
                                            exerciseIDs: template.exerciseIDs,
                                            plan: template.plannedExercises,
                                            gymID: activeGymID,
                                            sourceLabel: L10n.text("Template", "Template")
                                        )
                                    },
                                    onDelete: {
                                        context.delete(template)
                                        try? context.save()
                                    }
                                )
                            }
                        }
                    }

                    Button {
                        showTrainingHub = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "square.stack.3d.up.fill")
                                .font(.title2)
                                .foregroundStyle(RFTheme.accent)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(L10n.text("Explore training plans", "Bekijk trainingsschema's"))
                                    .font(.headline)
                                Text(L10n.text("Ready-made workouts and your personal 3-week plan",
                                               "Kant-en-klare workouts en jouw 3-wekenplan"))
                                    .font(.caption)
                                    .foregroundStyle(RFTheme.muted)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(RFTheme.accent)
                        }
                        .padding(17)
                        .background(RFTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)

                    if let current = sessions.first(where: { $0.endedAt == nil }) {
                        Button {
                            activeSession = current
                        } label: {
                            Label("Resume \(current.title)", systemImage: "arrowtriangle.right.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(RFLayout.pagePadding)
            }
            .background(RFTheme.bg)
            .navigationTitle(L10n.startWorkout)
            .sheet(isPresented: $showTrainingHub) {
                TrainingHubView()
            }
            .sheet(isPresented: $showTemplateEditor) {
                TemplateEditorView()
            }
            .sheet(item: $templateSeed, onDismiss: {
                templateSeed = nil
            }) { day in
                TemplateEditorView(prefill: day)
            }
            .sheet(item: $editingTemplate) { template in
                TemplateEditorView(template: template)
            }
            .sheet(item: $scheduleSeed) { seed in
                ScheduleWorkoutSheet(seed: seed) { updated in
                    WorkoutScheduleStore.update(updated)
                }
            }
            .fullScreenCover(item: $activeSession) { session in
                ActiveWorkoutView(session: session)
            }
        }
    }

    private func defaultScheduleDate() -> Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: .now) ?? .now
        return calendar.date(bySettingHour: 18, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    private func createSession(schedule: ScheduledWorkoutRecord) -> WorkoutSession {
        let logs: [ExerciseLog]

        if let plan = schedule.plan, !plan.isEmpty {
            logs = plan.enumerated().compactMap { index, item in
                guard let exercise = ExerciseCatalog.findByName(item.name) else { return nil }
                return ExerciseLog(
                    exerciseID: exercise.id,
                    order: index,
                    targetReps: item.reps,
                    coachingNote: item.note,
                    supersetGroup: item.superset,
                    sets: (0..<max(1, item.sets)).map { WorkoutSet(order: $0) }
                )
            }
        } else {
            logs = schedule.exerciseIDs.enumerated().map { index, id in
                ExerciseLog(
                    exerciseID: id,
                    order: index,
                    sets: (0..<AppPreferences.defaultSets).map { WorkoutSet(order: $0) }
                )
            }
        }

        let session = WorkoutSession(
            title: schedule.title,
            exercises: logs,
            gymID: schedule.gymID
        )
        context.insert(session)
        WorkoutScheduleStore.remove(id: schedule.id)
        try? context.save()
        return session
    }

    private func duplicateTemplate(_ template: WorkoutTemplate) {
        let copy = WorkoutTemplate(
            name: "\(template.name) \(L10n.text("Copy", "Kopie"))",
            exerciseIDs: template.exerciseIDs,
            plan: template.plannedExercises
        )
        context.insert(copy)
        try? context.save()
        Haptics.light()
    }

    private func createSession(title: String, exerciseIDs: [String]) -> WorkoutSession {
        let logs = exerciseIDs.enumerated().map { index, id in
            ExerciseLog(
                exerciseID: id,
                order: index,
                sets: (0..<AppPreferences.defaultSets).map { WorkoutSet(order: $0) }
            )
        }
        let session = WorkoutSession(title: title, exercises: logs, gymID: activeGymID)
        context.insert(session)
        try? context.save()
        return session
    }

    private func createSession(template: WorkoutTemplate) -> WorkoutSession {
        if let plan = template.plannedExercises, !plan.isEmpty {
            let logs = plan.enumerated().compactMap { index, item -> ExerciseLog? in
                guard let exercise = ExerciseCatalog.findByName(item.name) else { return nil }
                return ExerciseLog(
                    exerciseID: exercise.id,
                    order: index,
                    targetReps: item.reps,
                    coachingNote: item.note,
                    supersetGroup: item.superset,
                    sets: (0..<max(1, item.sets)).map { WorkoutSet(order: $0) }
                )
            }
            let session = WorkoutSession(title: template.name, exercises: logs, gymID: activeGymID)
            context.insert(session)
            try? context.save()
            return session
        }

        return createSession(title: template.name, exerciseIDs: template.exerciseIDs)
    }

    private func createSession(day: ProgramDay) -> WorkoutSession {
        let logs = day.exercises.enumerated().compactMap { index, item -> ExerciseLog? in
            guard let exercise = ExerciseCatalog.findByName(item.name) else { return nil }
            return ExerciseLog(
                exerciseID: exercise.id,
                order: index,
                targetReps: item.reps,
                coachingNote: item.note,
                supersetGroup: item.superset,
                sets: (0..<item.sets).map { WorkoutSet(order: $0) }
            )
        }
        let session = WorkoutSession(title: "\(day.title) — \(day.focus)", exercises: logs, gymID: activeGymID)
        context.insert(session)
        try? context.save()
        return session
    }
}

struct ScheduleWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var item: ScheduledWorkoutRecord
    let onSave: (ScheduledWorkoutRecord) -> Void

    init(seed: ScheduledWorkoutRecord, onSave: @escaping (ScheduledWorkoutRecord) -> Void) {
        _item = State(initialValue: seed)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.text("Workout", "Training")) {
                    TextField(L10n.text("Title", "Titel"), text: $item.title)

                    DatePicker(
                        L10n.text("Date & time", "Datum & tijd"),
                        selection: $item.date,
                        in: Date.now.addingTimeInterval(-86400)...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                Section(L10n.text("Gym", "Gym")) {
                    Picker(L10n.text("Location", "Locatie"), selection: $item.gymID) {
                        ForEach(GymProfileStore.load()) { gym in
                            Text(gym.name).tag(gym.id)
                        }
                    }
                }

                if let source = item.sourceLabel {
                    Section {
                        LabeledContent(L10n.text("Source", "Bron"), value: source)
                        LabeledContent(
                            L10n.text("Exercises", "Oefeningen"),
                            value: "\(item.plan?.count ?? item.exerciseIDs.count)"
                        )
                    }
                }
            }
            .navigationTitle(L10n.text("Schedule Workout", "Training inplannen"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("Cancel", "Annuleren")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("Save", "Opslaan")) {
                        onSave(item)
                        Haptics.success()
                        dismiss()
                    }
                    .bold()
                    .disabled(item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct ScheduledWorkoutCard: View {
    let item: ScheduledWorkoutRecord
    let onStart: () -> Void
    let onReschedule: () -> Void
    let onSkip: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(item.date.formatted(.dateTime.day()))
                    .font(.title2.bold())
                    .foregroundStyle(RFTheme.accent)
                Text(item.date.formatted(.dateTime.month(.abbreviated)))
                    .font(.caption.bold())
                    .foregroundStyle(RFTheme.muted)
            }
            .frame(width: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(
                    "\(item.date.formatted(date: .omitted, time: .shortened)) • \(GymProfileStore.profile(id: item.gymID).name)"
                )
                .font(.caption)
                .foregroundStyle(RFTheme.muted)
            }

            Spacer()

            Button(action: onStart) {
                Image(systemName: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(RFTheme.accent)

            Menu {
                Button(action: onReschedule) {
                    Label(L10n.text("Reschedule", "Verplaatsen"), systemImage: "calendar")
                }
                Button(action: onSkip) {
                    Label(L10n.text("Skip", "Overslaan"), systemImage: "forward.end")
                }
                Button(role: .destructive, action: onDelete) {
                    Label(L10n.text("Delete", "Verwijder"), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 32, height: 32)
            }
        }
        .padding(12)
        .background(RFTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ProgramDayCard: View {
    let day: ProgramDay
    let isCustomized: Bool
    let onStart: () -> Void
    let onEdit: () -> Void
    let onSaveAsTemplate: () -> Void
    let onSchedule: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 2) {
                    Text(day.day.prefix(3).uppercased())
                        .font(.caption2.bold())
                        .foregroundStyle(RFTheme.accent)
                    Text("\(day.exercises.count)")
                        .font(.title3.bold())
                }
                .frame(width: 46, height: 48)
                .background(RFTheme.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 13))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(day.title)
                            .font(.headline)
                            .lineLimit(1)

                        if isCustomized {
                            Text(L10n.text("Edited", "Bewerkt"))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(RFTheme.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(RFTheme.accent.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }

                    Text(day.focus)
                        .font(.caption.bold())
                        .foregroundStyle(RFTheme.accent)

                    Text(day.partner.capitalized)
                        .font(.caption2)
                        .foregroundStyle(RFTheme.muted)

                    Label("~\(TrainingTimeEstimator.minutes(for: day.exercises)) min", systemImage: "clock")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(RFTheme.muted)
                }

                Spacer()

                Menu {
                    Button(action: onEdit) {
                        Label(L10n.text("Edit Workout", "Training bewerken"), systemImage: "pencil")
                    }
                    Button(action: onSaveAsTemplate) {
                        Label(L10n.text("Add to New Template", "Aan nieuwe template toevoegen"), systemImage: "rectangle.stack.badge.plus")
                    }
                    Button(action: onSchedule) {
                        Label(L10n.text("Schedule", "Inplannen"), systemImage: "calendar.badge.plus")
                    }
                    ShareLink(
                        item: RepForgeShareCodec.templateURL(
                            name: "\(day.title) — \(day.focus)",
                            exercises: day.exercises
                        )
                    ) {
                        Label(L10n.text("Share Workout Link", "Trainingslink delen"), systemImage: "square.and.arrow.up")
                    }
                    if isCustomized {
                        Button(role: .destructive, action: onReset) {
                            Label(L10n.text("Reset to Original", "Herstel origineel"), systemImage: "arrow.counterclockwise")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline)
                        .foregroundStyle(RFTheme.muted)
                        .frame(width: 34, height: 34)
                        .background(RFTheme.field)
                        .clipShape(Circle())
                }
            }

            VStack(spacing: 7) {
                ForEach(Array(day.exercises.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 9) {
                        Text("\(index + 1)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(RFTheme.muted)
                            .frame(width: 20, height: 20)
                            .background(RFTheme.field)
                            .clipShape(Circle())

                        Text(item.name)
                            .font(.caption)
                            .lineLimit(1)

                        Spacer()

                        if let group = item.superset, !group.isEmpty {
                            Text("SS \(group)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(RFTheme.accent)
                        }

                        Text("\(item.sets) × \(item.reps)")
                            .font(.caption2.bold())
                            .foregroundStyle(RFTheme.muted)
                    }
                }
            }

            HStack(spacing: 8) {
                Button(action: onStart) {
                    Label(L10n.text("Start", "Start"), systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(RFTheme.accent)

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.bordered)

                Button(action: onSchedule) {
                    Image(systemName: "calendar.badge.plus")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [RFTheme.surface, RFTheme.raised.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(RFTheme.cardBorder)
        )
    }
}

struct ProgramDayEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ProgramDay
    @State private var showPicker = false
    @State private var pickerIDs: [String] = []
    let onSave: (ProgramDay) -> Void

    init(day: ProgramDay, onSave: @escaping (ProgramDay) -> Void) {
        _draft = State(initialValue: day)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Workout") {
                    TextField("Day", text: $draft.day)
                    TextField("Focus", text: $draft.focus)
                    TextField("Training partner / note", text: $draft.partner)
                }

                Section("Exercises") {
                    ForEach(draft.exercises.indices, id: \.self) { index in
                        ProgramExerciseEditorRow(item: $draft.exercises[index])
                    }
                    .onDelete { offsets in
                        draft.exercises.remove(atOffsets: offsets)
                    }
                    .onMove { source, destination in
                        draft.exercises.move(fromOffsets: source, toOffset: destination)
                    }

                    Button {
                        pickerIDs = []
                        showPicker = true
                    } label: {
                        Label("Add Exercises", systemImage: "plus")
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .background(RFTheme.bg)
            .navigationTitle("Edit \(draft.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .bold()
                    .disabled(draft.exercises.isEmpty)
                }
            }
            .sheet(isPresented: $showPicker, onDismiss: addPickedExercises) {
                ExercisePickerView(selectedIDs: $pickerIDs)
            }
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private func addPickedExercises() {
        let existing = Set(draft.exercises.map(\.name))
        for id in pickerIDs {
            guard let exercise = ExerciseCatalog.find(id),
                  !existing.contains(exercise.name) else { continue }
            draft.exercises.append(ProgramExercise(exercise.name, 3, "8–12"))
        }
        pickerIDs = []
    }
}

struct ProgramExerciseEditorRow: View {
    @Binding var item: ProgramExercise

    private var isCardio: Bool {
        ExerciseCatalog.findByName(item.name)?.movement == "cardio"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(item.name)
                    .font(.headline)

                Spacer()

                if isCardio {
                    Label("Cardio", systemImage: "figure.run")
                        .font(.caption2.bold())
                        .foregroundStyle(RFTheme.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(RFTheme.accent.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 14) {
                Stepper(
                    isCardio
                        ? "\(L10n.text("Intervals", "Intervallen")) \(item.sets)"
                        : "\(L10n.text("Sets", "Sets")) \(item.sets)",
                    value: $item.sets,
                    in: 1...10
                )

                if isCardio {
                    Text(L10n.text("Time • Distance • Pace", "Tijd • Afstand • Tempo"))
                        .font(.caption2.bold())
                        .foregroundStyle(RFTheme.muted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(RFTheme.field)
                        .clipShape(Capsule())
                } else {
                    TextField(L10n.text("Reps", "Reps"), text: $item.reps)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 86)
                        .multilineTextAlignment(.center)
                }
            }

            HStack {
                TextField(
                    L10n.text("Note (optional)", "Notitie (optioneel)"),
                    text: Binding(
                        get: { item.note ?? "" },
                        set: { item.note = $0.isEmpty ? nil : $0 }
                    )
                )
                .textFieldStyle(.roundedBorder)

                if !isCardio {
                    TextField(
                        "SS",
                        text: Binding(
                            get: { item.superset ?? "" },
                            set: { item.superset = $0.isEmpty ? nil : $0.uppercased() }
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 62)
                    .multilineTextAlignment(.center)
                }
            }
        }
        .padding(.vertical, 5)
        .onAppear {
            if isCardio && item.reps != "cardio" {
                item.reps = "cardio"
            }
        }
    }
}

struct TemplateCard: View {
    let template: WorkoutTemplate
    let onStart: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onSchedule: () -> Void
    let onDelete: () -> Void

    private var exerciseNames: [String] {
        template.plannedExercises?.map(\.name)
            ?? template.exerciseIDs.compactMap(ExerciseCatalog.find).map(\.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(RFTheme.accent.opacity(0.14))
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.title3.bold())
                        .foregroundStyle(RFTheme.accent)
                }
                .frame(width: 44, height: 44)

                Spacer()

                Label("\(exerciseNames.count)", systemImage: "list.bullet")
                    .font(.caption.bold())
                    .foregroundStyle(RFTheme.muted)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(RFTheme.field)
                    .clipShape(Capsule())
                    .accessibilityLabel("\(exerciseNames.count) \(L10n.text("exercises", "oefeningen"))")

                Menu {
                    Button(action: onEdit) {
                        Label(L10n.text("Edit Template", "Template bewerken"), systemImage: "pencil")
                    }
                    Button(action: onDuplicate) {
                        Label(L10n.text("Duplicate", "Dupliceren"), systemImage: "plus.square.on.square")
                    }
                    Button(action: onSchedule) {
                        Label(L10n.text("Schedule", "Inplannen"), systemImage: "calendar.badge.plus")
                    }
                    ShareLink(
                        item: RepForgeShareCodec.templateURL(
                            name: template.name,
                            exercises: template.plannedExercises ?? template.exerciseIDs.compactMap { id in
                                guard let ex = ExerciseCatalog.find(id) else { return nil }
                                return ProgramExercise(ex.name, AppPreferences.defaultSets, "8–12")
                            }
                        )
                    ) {
                        Label(L10n.text("Share Link", "Deellink"), systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive, action: onDelete) {
                        Label(L10n.text("Delete", "Verwijder"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline)
                        .foregroundStyle(RFTheme.muted)
                        .frame(width: 34, height: 34)
                        .background(RFTheme.field)
                        .clipShape(Circle())
                }
            }

            Text(template.name)
                .font(.headline)
                .lineLimit(2)

            if let plan = template.plannedExercises, !plan.isEmpty {
                Label("~\(TrainingTimeEstimator.minutes(for: plan)) min " +
                      L10n.text("estimated", "geschat"), systemImage: "clock")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(RFTheme.accent)
            }

            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(exerciseNames.prefix(3).enumerated()), id: \.offset) { index, name in
                    HStack(spacing: 7) {
                        Circle()
                            .fill(index == 0 ? RFTheme.accent : RFTheme.muted.opacity(0.5))
                            .frame(width: 5, height: 5)
                        Text(name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                if exerciseNames.count > 3 {
                    Text("+\(exerciseNames.count - 3) \(L10n.text("more", "meer"))")
                        .font(.caption2.bold())
                        .foregroundStyle(RFTheme.accent)
                }
            }

            Spacer(minLength: 2)

            Button(action: onStart) {
                HStack {
                    Image(systemName: "play.fill")
                    Text(L10n.text("Start", "Start"))
                        .font(.subheadline.bold())
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .padding(.vertical, 7)
            }
            .buttonStyle(.borderedProminent)
            .tint(RFTheme.accent)
        }
        .padding(14)
        .frame(minHeight: 198, alignment: .topLeading)
        .background(RFTheme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(RFTheme.cardBorder)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
    }
}

struct TemplateEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    private let template: WorkoutTemplate?

    @State private var name: String
    @State private var items: [ProgramExercise]
    @State private var showPicker = false
    @State private var pickerIDs: [String] = []

    init(prefill: ProgramDay? = nil, template: WorkoutTemplate? = nil) {
        self.template = template

        if let template {
            _name = State(initialValue: template.name)
            let existing = template.plannedExercises ??
                template.exerciseIDs.compactMap { id in
                    guard let exercise = ExerciseCatalog.find(id) else { return nil }
                    return ProgramExercise(
                        exercise.name,
                        exercise.movement == "cardio" ? 1 : 3,
                        exercise.movement == "cardio" ? "cardio" : "8–12"
                    )
                }
            _items = State(initialValue: existing)
        } else if let prefill {
            _name = State(initialValue: "\(prefill.day) — \(prefill.focus)")
            _items = State(initialValue: prefill.exercises)
        } else {
            _name = State(initialValue: "New Template")
            _items = State(initialValue: [])
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Template") {
                    TextField("Name", text: $name)
                }

                Section("Exercises") {
                    ForEach(items.indices, id: \.self) { index in
                        ProgramExerciseEditorRow(item: $items[index])
                    }
                    .onDelete { offsets in
                        items.remove(atOffsets: offsets)
                    }
                    .onMove { source, destination in
                        items.move(fromOffsets: source, toOffset: destination)
                    }

                    Button {
                        pickerIDs = []
                        showPicker = true
                    } label: {
                        Label("Add Exercises", systemImage: "plus")
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .background(RFTheme.bg)
            .navigationTitle(template == nil ? "New Template" : "Edit Template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTemplate()
                    }
                    .bold()
                    .disabled(items.isEmpty)
                }
            }
            .sheet(isPresented: $showPicker, onDismiss: addPickedExercises) {
                ExercisePickerView(selectedIDs: $pickerIDs)
            }
        }
    }

    private func saveTemplate() {
        let ids = items.compactMap { ExerciseCatalog.findByName($0.name)?.id }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = cleanName.isEmpty ? "Workout" : cleanName

        if let template {
            template.name = finalName
            template.exerciseIDs = ids
            template.plannedExercises = items
        } else {
            context.insert(
                WorkoutTemplate(
                    name: finalName,
                    exerciseIDs: ids,
                    plan: items
                )
            )
        }

        try? context.save()
        dismiss()
    }

    private func addPickedExercises() {
        let existing = Set(items.map(\.name))
        for id in pickerIDs {
            guard let exercise = ExerciseCatalog.find(id),
                  !existing.contains(exercise.name) else { continue }
            items.append(
                ProgramExercise(
                    exercise.name,
                    exercise.movement == "cardio" ? 1 : 3,
                    exercise.movement == "cardio" ? "cardio" : "8–12"
                )
            )
        }
        pickerIDs = []
    }
}

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIDs: [String]
    @State private var search = ""
    @State private var muscle = "All"
    @State private var equipment = "All"
    @AppStorage("exerciseShortcutRevision") private var shortcutRevision = 0

    private var filtered: [ExerciseDefinition] {
        _ = shortcutRevision
        return ExerciseCatalog.all.filter { ex in
            ExerciseSearch.matches(ex, query: search) &&
            (muscle == "All" || ex.muscle == muscle) &&
            GymEquipmentFilter.matches(ex, selected: equipment)
        }
    }

    private var favorites: [ExerciseDefinition] {
        ExerciseShortcutStore.favorites.compactMap(ExerciseCatalog.find)
    }

    private var recent: [ExerciseDefinition] {
        ExerciseShortcutStore.recent
            .filter { !ExerciseShortcutStore.favorites.contains($0) }
            .compactMap(ExerciseCatalog.find)
    }

    private var showShortcuts: Bool {
        search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            muscle == "All" && equipment == "All"
    }

    var body: some View {
        NavigationStack {
            List {
                if showShortcuts, !favorites.isEmpty {
                    Section(L10n.text("Favorites", "Favorieten")) {
                        ForEach(favorites) { ex in
                            exerciseRow(ex)
                        }
                    }
                }

                if showShortcuts, !recent.isEmpty {
                    Section(L10n.text("Recent", "Recent")) {
                        ForEach(Array(recent.prefix(10))) { ex in
                            exerciseRow(ex)
                        }
                    }
                }

                Section(showShortcuts ? L10n.text("All exercises", "Alle oefeningen") : L10n.exercises) {
                    ForEach(filtered) { ex in
                        exerciseRow(ex)
                    }
                }
            }
            .searchable(text: $search, prompt: L10n.text("Search exercises, aliases or equipment", "Zoek oefeningen, aliassen of apparatuur"))
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(RFTheme.bg)
            .navigationTitle(L10n.exercises)
            .safeAreaInset(edge: .top) {
                HStack(spacing: 10) {
                    Menu {
                        Button(L10n.text("All muscles", "Alle spiergroepen")) { muscle = "All" }
                        ForEach(ExerciseCatalog.muscles, id: \.self) { option in
                            Button(option) { muscle = option }
                        }
                    } label: {
                        Label(muscle == "All" ? L10n.text("Muscles", "Spieren") : muscle,
                              systemImage: "figure.strengthtraining.traditional")
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                    }

                    Spacer()

                    Menu {
                        ForEach(GymEquipmentFilter.options, id: \.self) { option in
                            Button(GymEquipmentFilter.label(option)) { equipment = option }
                        }
                    } label: {
                        Label(GymEquipmentFilter.label(equipment), systemImage: "slider.horizontal.3")
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedIDs.isEmpty
                             ? L10n.text("No exercises selected", "Geen oefeningen geselecteerd")
                             : "\(selectedIDs.count) \(L10n.text("selected", "geselecteerd"))")
                            .font(.caption.bold())
                        Text(L10n.text("Tap an exercise to add or remove it", "Tik op een oefening om deze toe te voegen of te verwijderen"))
                            .font(.caption2)
                            .foregroundStyle(RFTheme.muted)
                    }

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Text(selectedIDs.isEmpty
                             ? L10n.done
                             : "\(L10n.text("Add", "Voeg toe")) \(selectedIDs.count)")
                            .font(.headline)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(RFTheme.accent)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("Close", "Sluiten")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) { dismiss() }.bold()
                }
            }
        }
    }

    @ViewBuilder
    private func exerciseRow(_ ex: ExerciseDefinition) -> some View {
        HStack(spacing: 10) {
            Button {
                if selectedIDs.contains(ex.id) {
                    selectedIDs.removeAll { $0 == ex.id }
                } else {
                    selectedIDs.append(ex.id)
                    ExerciseShortcutStore.recordRecent(ex.id)
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(ex.name)
                            .foregroundStyle(.primary)
                            .font(.headline)
                        Text("\(ex.muscle) • \(ex.equipment)")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }

                    Spacer()

                    Image(systemName: selectedIDs.contains(ex.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedIDs.contains(ex.id) ? RFTheme.accent : RFTheme.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                ExerciseShortcutStore.toggleFavorite(ex.id)
            } label: {
                Image(systemName: ExerciseShortcutStore.isFavorite(ex.id) ? "star.fill" : "star")
                    .foregroundStyle(ExerciseShortcutStore.isFavorite(ex.id) ? .yellow : RFTheme.muted)
                    .frame(width: 28, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.text("Toggle favorite", "Favoriet wisselen"))
        }
    }
}

// MARK: - Active workout

struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var session: WorkoutSession
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var allSessions: [WorkoutSession]

    @State private var showExercisePicker = false
    @State private var pickerIDs: [String] = []
    @State private var showFinishConfirm = false
    @State private var showSummary = false
    @State private var restRemaining = 0
    @State private var restOriginal = 0
    @State private var restCollapsed = false
    @State private var restExerciseName = ""
    @State private var restEndDate: Date?
    @State private var showWorkoutNote = false
    @State private var draggingExerciseID: UUID?
    @State private var hiddenExerciseIDs: Set<UUID> = []
    @State private var focusMode = false
    @ObservedObject private var heartRateMonitor = HeartRateMonitor.shared

    @AppStorage("keepScreenAwake") private var keepScreenAwake = true
    @AppStorage("autoRestTimer") private var autoRestTimer = true
    @AppStorage("defaultRestSeconds") private var defaultRestSeconds = 90
    @AppStorage("compactWorkoutMode") private var compactWorkoutMode = false
    @AppStorage("countdownHaptics") private var countdownHaptics = true

    private let restTicker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var orderedExercises: [ExerciseLog] {
        session.exercises
            .filter { !hiddenExerciseIDs.contains($0.id) }
            .sorted(by: { $0.order < $1.order })
    }

    private var totalEntries: Int {
        session.exercises.reduce(0) { $0 + $1.sets.count }
    }

    private var completedEntries: Int {
        session.exercises.reduce(0) { $0 + $1.sets.filter(\.completed).count }
    }

    private var workoutProgress: Double {
        totalEntries == 0 ? 0 : Double(completedEntries) / Double(totalEntries)
    }

    private var visibleExercises: [ExerciseLog] {
        guard focusMode else { return orderedExercises }
        if let next = orderedExercises.first(where: { !$0.sets.allSatisfy(\.completed) }) {
            return [next]
        }
        return orderedExercises.last.map { [$0] } ?? []
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: compactWorkoutMode ? 10 : 18) {
                    workoutHero

                    if !compactWorkoutMode && completedEntries > 0 {
                        LiveWorkoutHeatmap(session: session)
                    }

                    if showWorkoutNote {
                        TextField(
                            L10n.text("How did the workout feel?", "Hoe voelde de training?"),
                            text: Binding(
                                get: { session.note ?? "" },
                                set: {
                                    session.note = $0
                                    try? context.save()
                                }
                            ),
                            axis: .vertical
                        )
                        .lineLimit(2...5)
                        .padding(14)
                        .background(RFTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(RFTheme.cardBorder)
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    if session.exercises.isEmpty {
                        EmptyCard(
                            icon: "dumbbell",
                            title: L10n.text("No exercises yet", "Nog geen oefeningen"),
                            text: L10n.text(
                                "Add an exercise to begin logging your workout.",
                                "Voeg een oefening toe om je training te registreren."
                            )
                        )
                    }

                    exerciseCards

                    Button {
                        pickerIDs = []
                        showExercisePicker = true
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(RFTheme.accent.opacity(0.16))
                                Image(systemName: "plus")
                                    .font(.headline.bold())
                                    .foregroundStyle(RFTheme.accent)
                            }
                            .frame(width: 34, height: 34)

                            Text(L10n.addExercise)
                                .font(.headline)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(RFTheme.muted)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .background(RFTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(RFTheme.cardBorder)
                    )
                }
                .padding(RFLayout.pagePadding)
                .padding(.bottom, restRemaining > 0 ? 14 : 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(
                LinearGradient(
                    colors: [RFTheme.bg, RFTheme.bg, RFTheme.accent.opacity(0.035)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.headline.bold())
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if restRemaining > 0, let endDate = restEndDate {
                    RestTimerDock(
                        endDate: endDate,
                        exerciseName: restExerciseName,
                        totalSeconds: max(restOriginal, 1),
                        onAdjust: { adjustRest(by: $0) },
                        onReset: { resetRest() },
                        onSkip: { stopRest() }
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 5)
                }
            }
            .onReceive(restTicker) { _ in
                guard let end = restEndDate else { return }
                let remaining = max(0, Int(ceil(end.timeIntervalSinceNow)))
                // Updating @State once per second used to invalidate the entire
                // exercise list. TimelineView now owns the visible countdown.
                if countdownHaptics && (1...3).contains(remaining) {
                    Haptics.light()
                }

                if remaining == 0 {
                    restRemaining = 0
                    restEndDate = nil
                    RestTimerLiveActivityManager.end()
                    Haptics.success()
                }
            }
            .confirmationDialog(
                L10n.text("Finish this workout?", "Deze training afronden?"),
                isPresented: $showFinishConfirm
            ) {
                Button(L10n.text("Finish Workout", "Training afronden")) {
                    finishWorkout()
                }
                Button(L10n.text("Cancel", "Annuleren"), role: .cancel) {}
            } message: {
                Text(L10n.text(
                    "Completed strength sets and cardio intervals will be saved to history.",
                    "Voltooide krachtsets en cardio-intervallen worden in je geschiedenis opgeslagen."
                ))
            }
            .sheet(isPresented: $showExercisePicker, onDismiss: addPickedExercises) {
                ExercisePickerView(selectedIDs: $pickerIDs)
            }
            .sheet(isPresented: $showSummary) {
                WorkoutSummaryView(
                    session: session,
                    sessions: allSessions,
                    onDone: {
                        showSummary = false
                        dismiss()
                    }
                )
                .interactiveDismissDisabled()
            }
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = keepScreenAwake
            }
            .onChange(of: keepScreenAwake) { _, enabled in
                UIApplication.shared.isIdleTimerDisabled = enabled
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }

    @ViewBuilder
    private var exerciseCards: some View {
        ForEach(visibleExercises) { log in
            exerciseCard(log)
        }
    }

    @ViewBuilder
    private func exerciseCard(_ log: ExerciseLog) -> some View {
        WorkoutExerciseBlock(
            log: log,
            sessions: allSessions,
            gymID: GymProfileStore.sessionGymID(session),
            supersetPosition: supersetPosition(for: log),
            onSetCompleted: {
                startRestTimer(for: log)
            },
            onMoveUp: { moveExercise(log, delta: -1) },
            onMoveDown: { moveExercise(log, delta: 1) },
            onDuplicate: { duplicateExercise(log) },
            onRemoveExercise: { removeExercise(log) }
        )
    }

    private func handleExerciseDrop(_ items: [String], targetID: UUID) -> Bool {
        guard let raw = items.first,
              let sourceID = UUID(uuidString: raw) else { return false }
        reorderExercise(sourceID: sourceID, targetID: targetID)
        return true
    }

    private func updateDropTarget(_ id: UUID, targeted: Bool) {
        if targeted {
            draggingExerciseID = id
        } else if draggingExerciseID == id {
            draggingExerciseID = nil
        }
    }

    private var workoutHero: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(RFTheme.accent.opacity(0.14))
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.title2.bold())
                        .foregroundStyle(RFTheme.accent)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title)
                        .font(.title2.bold())
                        .lineLimit(2)

                    Label(
                        GymProfileStore.profile(id: session.gymID).name,
                        systemImage: "mappin.and.ellipse"
                    )
                    .font(.caption)
                    .foregroundStyle(RFTheme.muted)
                }

                Spacer()

                Button(L10n.finish) {
                    showFinishConfirm = true
                }
                .buttonStyle(.borderedProminent)
                .tint(RFTheme.success)
                .font(.subheadline.bold())
            }

            HStack(spacing: 8) {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    WorkoutMetricPill(
                        icon: "clock.fill",
                        text: durationString(session.duration)
                    )
                }

                WorkoutMetricPill(
                    icon: "checkmark.circle.fill",
                    text: "\(completedEntries)/\(totalEntries)"
                )

                if let bpm = heartRateMonitor.bpm {
                    WorkoutMetricPill(
                        icon: "heart.fill",
                        text: "\(bpm) bpm"
                    )
                }

                if session.totalCardioDistanceKm > 0 {
                    WorkoutMetricPill(
                        icon: "figure.run",
                        text: "\(AppPreferences.displayDistance(session.totalCardioDistanceKm).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.distanceLabel)"
                    )
                }

                Spacer()

                Button {
                    withAnimation(.snappy) {
                        focusMode.toggle()
                    }
                } label: {
                    Image(systemName: focusMode ? "scope" : "rectangle.stack.fill")
                        .font(.caption.bold())
                        .padding(8)
                        .background(focusMode ? RFTheme.accent.opacity(0.18) : RFTheme.field.opacity(0.75))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    focusMode
                        ? L10n.text("Show all exercises", "Toon alle oefeningen")
                        : L10n.text("Focus on next exercise", "Focus op volgende oefening")
                )
            }

            VStack(spacing: 7) {
                HStack {
                    Text(L10n.text("Workout progress", "Trainingsvoortgang"))
                        .font(.caption.bold())
                        .foregroundStyle(RFTheme.muted)
                    Spacer()
                    Text("\(Int(workoutProgress * 100))%")
                        .font(.caption.bold())
                        .foregroundStyle(RFTheme.accent)
                }

                ProgressView(value: workoutProgress)
                    .tint(RFTheme.accent)
                    .scaleEffect(x: 1, y: 1.5)
            }

            Button {
                withAnimation(.snappy) {
                    showWorkoutNote.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "note.text")
                    Text(
                        (session.note ?? "").isEmpty
                            ? L10n.text("Add workout note", "Trainingsnotitie toevoegen")
                            : L10n.text("Workout note added", "Trainingsnotitie toegevoegd")
                    )
                        .font(.caption.bold())
                    Spacer()
                    Image(systemName: showWorkoutNote ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .foregroundStyle(RFTheme.muted)
            }
            .buttonStyle(.plain)
        }
        .padding(15)
        .background(RFTheme.surface, in: RoundedRectangle(cornerRadius: 19))
        .overlay(
            RoundedRectangle(cornerRadius: 19).stroke(RFTheme.cardBorder)
        )
    }

    private func finishWorkout() {
        session.endedAt = .now
        stopRest()
        try? context.save()
        Haptics.success()
        showSummary = true
    }

    private func startRestTimer(for log: ExerciseLog) {
        guard autoRestTimer else { return }
        let seconds = log.restSeconds ?? defaultRestSeconds
        guard seconds > 0 else { return }

        let exerciseName = ExerciseCatalog.find(log.exerciseID)?.name ?? session.title
        restRemaining = seconds
        restOriginal = seconds
        restCollapsed = false
        restExerciseName = exerciseName
        let endDate = Date().addingTimeInterval(TimeInterval(seconds))
        restEndDate = endDate
        RestNotificationManager.shared.schedule(seconds: seconds, exerciseName: exerciseName)
        RestTimerLiveActivityManager.startOrUpdate(
            workoutTitle: session.title,
            exerciseName: exerciseName,
            endDate: endDate,
            totalSeconds: seconds
        )
    }

    private func adjustRest(by seconds: Int) {
        let currentEnd = restEndDate ?? Date().addingTimeInterval(TimeInterval(restRemaining))
        let newEnd = currentEnd.addingTimeInterval(TimeInterval(seconds))
        restEndDate = newEnd
        restRemaining = max(0, Int(ceil(newEnd.timeIntervalSinceNow)))
        restOriginal = max(restOriginal, restRemaining)
        RestNotificationManager.shared.schedule(seconds: restRemaining, exerciseName: restExerciseName)
        if restRemaining > 0 {
            RestTimerLiveActivityManager.startOrUpdate(
                workoutTitle: session.title,
                exerciseName: restExerciseName,
                endDate: newEnd,
                totalSeconds: max(restOriginal, restRemaining)
            )
        } else {
            RestTimerLiveActivityManager.end()
        }
        Haptics.light()
    }

    private func resetRest() {
        guard defaultRestSeconds > 0 else { return }
        restOriginal = defaultRestSeconds
        restRemaining = defaultRestSeconds
        let endDate = Date().addingTimeInterval(TimeInterval(defaultRestSeconds))
        restEndDate = endDate
        RestNotificationManager.shared.schedule(seconds: defaultRestSeconds, exerciseName: restExerciseName)
        RestTimerLiveActivityManager.startOrUpdate(
            workoutTitle: session.title,
            exerciseName: restExerciseName,
            endDate: endDate,
            totalSeconds: defaultRestSeconds
        )
        Haptics.light()
    }

    private func stopRest() {
        restRemaining = 0
        restOriginal = 0
        restEndDate = nil
        restExerciseName = ""
        RestNotificationManager.shared.cancel()
        RestTimerLiveActivityManager.end()
        Haptics.light()
    }

    private func addPickedExercises() {
        guard !pickerIDs.isEmpty else { return }
        let existing = Set(session.exercises.map(\.exerciseID))
        var nextOrder = (session.exercises.map(\.order).max() ?? -1) + 1

        for id in pickerIDs where !existing.contains(id) {
            let exercise = ExerciseCatalog.find(id)
            let initialCount = exercise?.movement == "cardio" ? 1 : AppPreferences.defaultSets

            session.exercises.append(
                ExerciseLog(
                    exerciseID: id,
                    order: nextOrder,
                    restSeconds: defaultRestSeconds,
                    sets: (0..<initialCount).map { WorkoutSet(order: $0) }
                )
            )
            nextOrder += 1
        }

        pickerIDs = []
        try? context.save()
    }

    private func supersetPosition(for log: ExerciseLog) -> String? {
        guard let group = log.supersetGroup?.trimmingCharacters(in: .whitespacesAndNewlines),
              !group.isEmpty else { return nil }

        let members = orderedExercises.filter {
            $0.supersetGroup?.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(group) == .orderedSame
        }

        guard members.count > 1,
              let index = members.firstIndex(where: { $0.id == log.id }) else { return nil }

        return "\(group.uppercased())\(index + 1)"
    }

    private func reorderExercise(sourceID: UUID, targetID: UUID) {
        var ordered = orderedExercises
        guard let source = ordered.firstIndex(where: { $0.id == sourceID }),
              let target = ordered.firstIndex(where: { $0.id == targetID }),
              source != target else { return }

        let moved = ordered.remove(at: source)
        ordered.insert(moved, at: target)

        for (index, exercise) in ordered.enumerated() {
            exercise.order = index
        }

        draggingExerciseID = nil
        Haptics.light()
        try? context.save()
    }

    private func moveExercise(_ log: ExerciseLog, delta: Int) {
        var ordered = orderedExercises
        guard let current = ordered.firstIndex(where: { $0.id == log.id }) else { return }
        let destination = current + delta
        guard ordered.indices.contains(destination) else { return }

        ordered.swapAt(current, destination)
        for (index, item) in ordered.enumerated() {
            item.order = index
        }

        Haptics.light()
        try? context.save()
    }

    private func duplicateExercise(_ log: ExerciseLog) {
        let copySets = log.sets.sorted(by: { $0.order < $1.order }).map {
            WorkoutSet(
                order: $0.order,
                weightKg: $0.weightKg,
                reps: $0.reps,
                setTypeRaw: $0.setTypeRaw,
                rpe: $0.rpe,
                rir: $0.rir,
                note: $0.note,
                durationSeconds: $0.durationSeconds,
                distanceKm: $0.distanceKm,
                inclinePercent: $0.inclinePercent,
                calories: $0.calories,
                averageHeartRate: $0.averageHeartRate
            )
        }

        let next = (session.exercises.map(\.order).max() ?? -1) + 1
        session.exercises.append(
            ExerciseLog(
                exerciseID: log.exerciseID,
                order: next,
                targetReps: log.targetReps,
                coachingNote: log.coachingNote,
                supersetGroup: log.supersetGroup,
                sessionNote: log.sessionNote,
                restSeconds: log.restSeconds,
                sets: copySets
            )
        )

        Haptics.light()
        try? context.save()
    }

    private func removeExercise(_ log: ExerciseLog) {
        let logID = log.id
        let exerciseName = ExerciseCatalog.find(log.exerciseID)?.name
        guard !hiddenExerciseIDs.contains(logID) else { return }

        // Cardio rows hold several live Bindings to their WorkoutSet models.
        // Deleting the ExerciseLog in the same interaction can invalidate
        // those bindings. Detach from the workout and save that relationship
        // change only; stale detached logs are cleaned up on a later launch.
        withAnimation(.snappy) {
            hiddenExerciseIDs.insert(logID)
        }

        if restExerciseName == exerciseName {
            stopRest()
        }

        DispatchQueue.main.async {
            guard let index = session.exercises.firstIndex(where: { $0.id == logID }) else {
                hiddenExerciseIDs.remove(logID)
                return
            }

            session.exercises.remove(at: index)

            let remaining = session.exercises.sorted(by: { $0.order < $1.order })
            for (newIndex, exercise) in remaining.enumerated() {
                exercise.order = newIndex
            }

            do {
                try context.save()
                hiddenExerciseIDs.remove(logID)
                Haptics.light()
            } catch {
                if !session.exercises.contains(where: { $0.id == logID }) {
                    session.exercises.append(log)
                    for (newIndex, exercise) in session.exercises
                        .sorted(by: { $0.order < $1.order })
                        .enumerated() {
                        exercise.order = newIndex
                    }
                }
                hiddenExerciseIDs.remove(logID)
            }
        }
    }
}

struct WorkoutMetricPill: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption.bold())
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RFTheme.field.opacity(0.75))
            .clipShape(Capsule())
    }
}

struct RestTimerBanner: View {
    let remaining: Int
    let original: Int
    let exerciseName: String
    let onAdjust: (Int) -> Void
    let onReset: () -> Void
    let onMinimize: () -> Void
    let onSkip: () -> Void

    private var progress: Double {
        min(1, max(0, Double(remaining) / Double(max(original, 1))))
    }

    var body: some View {
        VStack(spacing: 11) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(RFTheme.field, lineWidth: 6)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            RFTheme.accent,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    Text(durationString(TimeInterval(remaining)))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.text("Rest", "Rust"))
                        .font(.headline.bold())

                    Text(exerciseName)
                        .font(.caption)
                        .foregroundStyle(RFTheme.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button(action: onMinimize) {
                    Image(systemName: "chevron.down")
                        .font(.subheadline.bold())
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.plain)
                .background(RFTheme.field)
                .clipShape(Circle())
                .accessibilityLabel(L10n.text("Minimize timer", "Timer minimaliseren"))

                Button(action: onSkip) {
                    Image(systemName: "forward.end.fill")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(RFTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 13))
                .accessibilityLabel(L10n.text("Skip rest", "Rust overslaan"))
            }

            HStack(spacing: 8) {
                RestAdjustmentButton(
                    title: "−15",
                    systemImage: "minus",
                    action: { onAdjust(-15) }
                )

                Button(action: onReset) {
                    Label(
                        L10n.text("Reset", "Reset"),
                        systemImage: "arrow.counterclockwise"
                    )
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .foregroundStyle(RFTheme.muted)
                .background(RFTheme.field)
                .clipShape(RoundedRectangle(cornerRadius: 11))

                RestAdjustmentButton(
                    title: "+15",
                    systemImage: "plus",
                    action: { onAdjust(15) }
                )
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(RFTheme.cardBorder)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 12, y: 5)
    }
}

struct RestAdjustmentButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .foregroundStyle(RFTheme.accent)
        .background(RFTheme.accent.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }
}

struct RestTimerCompactChip: View {
    let remaining: Int
    let onExpand: () -> Void
    let onSubtract15: () -> Void
    let onAdd15: () -> Void
    let onSkip: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onExpand) {
                HStack(spacing: 8) {
                    Image(systemName: "timer")
                    Text(durationString(TimeInterval(remaining)))
                        .font(.headline.monospacedDigit())
                    Image(systemName: "chevron.up")
                        .font(.caption.bold())
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(RFTheme.accent)
            .clipShape(Capsule())

            Button("−15", action: onSubtract15)
                .font(.caption.bold())
                .buttonStyle(.bordered)

            Button("+15", action: onAdd15)
                .font(.caption.bold())
                .buttonStyle(.bordered)

            Spacer(minLength: 0)

            Button(action: onSkip) {
                Image(systemName: "forward.end.fill")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(L10n.text("Skip rest", "Rust overslaan"))
        }
        .padding(7)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(RFTheme.cardBorder)
        )
        .shadow(color: Color.black.opacity(0.14), radius: 9, y: 3)
    }
}

struct WorkoutExerciseBlock: View {
    @Environment(\.modelContext) private var context
    @Bindable var log: ExerciseLog
    let sessions: [WorkoutSession]
    let gymID: String
    let supersetPosition: String?
    let onSetCompleted: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDuplicate: () -> Void
    let onRemoveExercise: () -> Void

    @State private var showRemoveExerciseConfirm = false
    @State private var showOptions = false
    @State private var isCollapsed = false
    @AppStorage("autoCollapseCompleted") private var autoCollapseCompleted = true
    @AppStorage("compactWorkoutMode") private var compactWorkoutMode = false

    private var exercise: ExerciseDefinition? { ExerciseCatalog.find(log.exerciseID) }
    private var isCardio: Bool { exercise?.movement == "cardio" }
    private var orderedSets: [WorkoutSet] { log.sets.sorted(by: { $0.order < $1.order }) }
    private var completedCount: Int { log.sets.filter(\.completed).count }
    private var allCompleted: Bool { !log.sets.isEmpty && completedCount == log.sets.count }

    @State private var priorLog: ExerciseLog?
    @State private var priorSets: [(Double, Int)] = []
    @State private var priorBest: Double = 0
    @State private var historyLoaded = false

    private var previousLog: ExerciseLog? { priorLog }
    private var previous: [(Double, Int)] { priorSets }
    private var best: Double { priorBest }

    // History snapshots are loaded once per exercise instead of scanning the
    // entire workout database on every keystroke or view invalidation.
    private func refreshHistorySnapshot() {
        let past = Metrics.scopedSessions(sessions, gymID: gymID)
        priorLog = past
            .filter { session in session.exercises.contains(where: { $0.exerciseID == log.exerciseID }) }
            .max(by: { ($0.endedAt ?? $0.startedAt) < ($1.endedAt ?? $1.startedAt) })?
            .exercises.first(where: { $0.exerciseID == log.exerciseID })
        priorSets = priorLog?.sets
            .filter(\.countsForPR)
            .sorted(by: { $0.order < $1.order })
            .map { ($0.weightKg, $0.reps) } ?? []
        priorBest = Metrics.personalBest(
            exerciseID: log.exerciseID, sessions: sessions,
            gymID: gymID, startDate: AppPreferences.prStartDate
        )
        historyLoaded = true
    }

    private var canCopyPrevious: Bool {
        isCardio ? !(previousLog?.sets.isEmpty ?? true) : !previous.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            exerciseHeader

            if isCollapsed {
                collapsedSummary
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    if let note = log.coachingNote, !note.isEmpty {
                        Label(note, systemImage: "quote.bubble")
                            .font(.caption)
                            .foregroundStyle(RFTheme.muted)
                            .padding(.horizontal, 4)
                    }

                    if let sessionNote = log.sessionNote, !sessionNote.isEmpty {
                        Label(sessionNote, systemImage: "note.text")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }

                    if isCardio {
                        cardioContent
                    } else {
                        strengthContent
                    }

                    Button {
                        addSet()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text(isCardio
                                 ? L10n.text("Add Interval", "Interval toevoegen")
                                 : L10n.text("Add Set", "Set toevoegen"))
                                .font(.subheadline.bold())
                            Spacer()
                        }
                        .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(RFTheme.accent)
                }
                .padding(.horizontal, compactWorkoutMode ? 10 : 16)
                .padding(.bottom, compactWorkoutMode ? 10 : 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(RFTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 19))
        .overlay(
            RoundedRectangle(cornerRadius: 19)
                .stroke(
                    supersetPosition != nil
                        ? RFTheme.accent.opacity(0.55)
                        : (allCompleted ? RFTheme.success.opacity(0.32) : RFTheme.cardBorder),
                    lineWidth: supersetPosition != nil ? 1.5 : 1
                )
        )
        .overlay(alignment: .leading) {
            if supersetPosition != nil {
                Capsule()
                    .fill(RFTheme.accent)
                    .frame(width: 4)
                    .padding(.vertical, 14)
            }
        }
        .shadow(color: Color.black.opacity(0.035), radius: 5, y: 2)
        .sheet(isPresented: $showOptions) {
            ExerciseLogOptionsView(log: log)
        }
        .confirmationDialog(
            L10n.text("Remove \(exercise?.name ?? "exercise")?", "\(exercise?.name ?? "oefening") verwijderen?"),
            isPresented: $showRemoveExerciseConfirm,
            titleVisibility: .visible
        ) {
            Button(L10n.text("Remove Exercise", "Oefening verwijderen"), role: .destructive) {
                onRemoveExercise()
            }
            Button(L10n.text("Cancel", "Annuleren"), role: .cancel) {}
        } message: {
            Text(L10n.text(
                "This removes the exercise and all of its entries from the current workout.",
                "Dit verwijdert de oefening en alle invoer uit de huidige training."
            ))
        }
        .onAppear {
            if !historyLoaded { refreshHistorySnapshot() }
            if autoCollapseCompleted && allCompleted { isCollapsed = true }
        }
        .onChange(of: log.exerciseID) { _, _ in
            refreshHistorySnapshot()
        }
        .onChange(of: completedCount) { _, _ in
            if autoCollapseCompleted && allCompleted {
                withAnimation(.snappy) {
                    isCollapsed = true
                }
            }
        }
    }

    private var exerciseHeader: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.snappy) {
                    isCollapsed.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(RFTheme.accent.opacity(0.12))
                        Image(systemName: exerciseIcon)
                            .font(.title3.bold())
                            .foregroundStyle(RFTheme.accent)
                    }
                    .frame(width: 46, height: 46)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 7) {
                            Text(exercise?.name ?? "Exercise")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)

                            if let supersetPosition {
                                Text(supersetPosition)
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 4)
                                    .background(RFTheme.accent)
                                    .clipShape(Capsule())
                            }
                        }

                        HStack(spacing: 7) {
                            Text("\(completedCount)/\(log.sets.count) \(isCardio ? L10n.text("intervals", "intervallen") : L10n.text("sets", "sets"))")
                                .foregroundStyle(allCompleted ? RFTheme.success : RFTheme.muted)

                            if isCardio {
                                if let summary = cardioSummary, !summary.isEmpty {
                                    Text("• \(summary)")
                                        .foregroundStyle(RFTheme.muted)
                                }
                            } else if best > 0 {
                                Text("• \(L10n.text("Best", "Beste")) \(AppPreferences.displayWeight(best).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.weightLabel)")
                                    .foregroundStyle(RFTheme.muted)
                            }
                        }
                        .font(.caption)
                        .lineLimit(1)
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .stroke(RFTheme.field, lineWidth: 4)
                        Circle()
                            .trim(
                                from: 0,
                                to: log.sets.isEmpty ? 0 : Double(completedCount) / Double(log.sets.count)
                            )
                            .stroke(
                                allCompleted ? RFTheme.success : RFTheme.accent,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))

                        if allCompleted {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(RFTheme.success)
                        } else {
                            Text("\(completedCount)")
                                .font(.caption2.bold())
                                .foregroundStyle(RFTheme.muted)
                        }
                    }
                    .frame(width: 34, height: 34)

                    Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                        .font(.caption.bold())
                        .foregroundStyle(RFTheme.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                if let ex = exercise {
                    NavigationLink {
                        ExerciseDetailView(exercise: ex)
                    } label: {
                        Label(L10n.text("Exercise Guide", "Oefening uitleg"), systemImage: "info.circle")
                    }
                }

                Button {
                    copyPreviousEntries()
                } label: {
                    Label(
                        isCardio
                            ? L10n.text("Copy Previous Cardio", "Vorige cardio kopiëren")
                            : L10n.text("Copy Previous Sets", "Vorige sets kopiëren"),
                        systemImage: "doc.on.doc"
                    )
                }
                .disabled(!canCopyPrevious)

                Button {
                    withAnimation(.snappy) {
                        isCollapsed.toggle()
                    }
                } label: {
                    Label(
                        isCollapsed
                            ? L10n.text("Expand", "Uitklappen")
                            : L10n.text("Collapse", "Inklappen"),
                        systemImage: isCollapsed ? "chevron.down" : "chevron.up"
                    )
                }

                Button(action: onMoveUp) {
                    Label(L10n.text("Move Up", "Omhoog"), systemImage: "arrow.up")
                }

                Button(action: onMoveDown) {
                    Label(L10n.text("Move Down", "Omlaag"), systemImage: "arrow.down")
                }

                Button(action: onDuplicate) {
                    Label(L10n.text("Duplicate Exercise", "Oefening dupliceren"), systemImage: "plus.square.on.square")
                }

                Button {
                    showOptions = true
                } label: {
                    Label(L10n.text("Exercise Options", "Oefening opties"), systemImage: "slider.horizontal.3")
                }

                Divider()

                Button(role: .destructive) {
                    showRemoveExerciseConfirm = true
                } label: {
                    Label(L10n.text("Remove Exercise", "Oefening verwijderen"), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline)
                    .foregroundStyle(RFTheme.muted)
                    .frame(width: 36, height: 36)
                    .background(RFTheme.field)
                    .clipShape(Circle())
            }
        }
        .padding(compactWorkoutMode ? 10 : 14)
    }

    private var strengthContent: some View {
        VStack(spacing: 10) {
            ForEach(orderedSets) { set in
                WorkoutSetRow(
                    set: set,
                    previous: previous.indices.contains(set.order) ? previous[set.order] : nil,
                    canDelete: log.sets.count > 1,
                    onCompleted: { completed in
                        if completed { onSetCompleted() }
                    },
                    onDelete: { removeSet(set) }
                )
            }
        }
    }

    private var cardioContent: some View {
        VStack(spacing: 10) {
            HStack {
                Label(
                    L10n.text(
                        "Cardio uses time, distance and intensity — not kg/reps.",
                        "Cardio gebruikt tijd, afstand en intensiteit — geen kg/reps."
                    ),
                    systemImage: "waveform.path.ecg"
                )
                .font(.caption)
                .foregroundStyle(RFTheme.muted)
                Spacer()
            }
            .padding(.horizontal, 2)

            ForEach(orderedSets) { set in
                CardioIntervalRow(
                    set: set,
                    canDelete: log.sets.count > 1,
                    onCompleted: { completed in
                        if completed { onSetCompleted() }
                    },
                    onDelete: {
                        removeSet(set)
                    }
                )
            }
        }
    }

    private var collapsedSummary: some View {
        HStack(spacing: 10) {
            Image(systemName: allCompleted ? "checkmark.seal.fill" : "rectangle.compress.vertical")
                .foregroundStyle(allCompleted ? RFTheme.success : RFTheme.accent)

            Text(
                isCardio
                    ? (cardioSummary ?? L10n.text("Cardio ready to log", "Cardio klaar om te loggen"))
                    : strengthCollapsedSummary
            )
            .font(.caption.bold())
            .foregroundStyle(RFTheme.muted)
            .lineLimit(1)

            Spacer()

            Text(allCompleted ? L10n.text("Complete", "Voltooid") : "\(completedCount)/\(log.sets.count)")
                .font(.caption.bold())
                .foregroundStyle(allCompleted ? RFTheme.success : RFTheme.accent)
        }
        .padding(11)
        .background(RFTheme.field.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var strengthCollapsedSummary: String {
        guard let last = orderedSets.last(where: { $0.completed }) else {
            return L10n.text("Tap to expand sets", "Tik om sets uit te klappen")
        }

        return "\(AppPreferences.displayWeight(last.weightKg).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.weightLabel) × \(last.reps)"
    }

    private var cardioSummary: String? {
        let completed = orderedSets.filter(\.completed)
        let source = completed.isEmpty ? orderedSets : completed
        let totalSeconds = source.reduce(0.0) { $0 + ($1.durationSeconds ?? 0) }
        let distanceKm = source.reduce(0.0) { $0 + ($1.distanceKm ?? 0) }

        var parts: [String] = []
        if totalSeconds > 0 {
            parts.append(cardioDurationText(totalSeconds))
        }
        if distanceKm > 0 {
            parts.append(
                "\(AppPreferences.displayDistance(distanceKm).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.distanceLabel)"
            )
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private var exerciseIcon: String {
        guard let exercise else { return "dumbbell.fill" }
        switch exercise.movement {
        case "cardio": return "figure.run"
        case "press": return "arrow.up.forward.circle.fill"
        case "pull": return "arrow.down.backward.circle.fill"
        case "squat": return "figure.strengthtraining.traditional"
        case "hinge": return "figure.flexibility"
        case "core": return "figure.core.training"
        case "curl": return "dumbbell.fill"
        default: return "dumbbell.fill"
        }
    }

    private func copyPreviousEntries() {
        if isCardio {
            guard let previousLog else { return }
            let previousSets = previousLog.sets.sorted(by: { $0.order < $1.order })

            while log.sets.count < previousSets.count {
                log.sets.append(WorkoutSet(order: log.sets.count))
            }

            for (index, old) in previousSets.enumerated() {
                guard log.sets.indices.contains(index) else { continue }
                let set = log.sets[index]
                set.durationSeconds = old.durationSeconds
                set.distanceKm = old.distanceKm
                set.inclinePercent = old.inclinePercent
                set.calories = old.calories
                set.averageHeartRate = old.averageHeartRate
                set.rpe = old.rpe
                set.completed = false
                set.completedAt = nil
            }
        } else {
            guard !previous.isEmpty else { return }

            while log.sets.count < previous.count {
                log.sets.append(WorkoutSet(order: log.sets.count))
            }

            for (index, values) in previous.enumerated() {
                guard log.sets.indices.contains(index) else { continue }
                log.sets[index].weightKg = values.0
                log.sets[index].reps = values.1
                log.sets[index].completed = false
                log.sets[index].completedAt = nil
            }
        }

        Haptics.light()
        try? context.save()
    }

    private func addSet() {
        Haptics.light()
        let next = (log.sets.map(\.order).max() ?? -1) + 1
        log.sets.append(WorkoutSet(order: next))
        try? context.save()
    }

    private func removeSet(_ set: WorkoutSet) {
        guard log.sets.count > 1 else { return }
        log.sets.removeAll { $0.id == set.id }
        context.delete(set)
        renumberSets()
        try? context.save()
    }

    private func renumberSets() {
        for (index, set) in log.sets.sorted(by: { $0.order < $1.order }).enumerated() {
            set.order = index
        }
    }
}

private func cardioDurationText(_ seconds: Double) -> String {
    let total = max(0, Int(seconds.rounded()))
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let secs = total % 60

    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, secs)
    }
    return String(format: "%d:%02d", minutes, secs)
}

struct CardioIntervalRow: View {
    @Environment(\.modelContext) private var context
    @ObservedObject private var heartRateMonitor = HeartRateMonitor.shared
    @Bindable var set: WorkoutSet
    let canDelete: Bool
    let onCompleted: (Bool) -> Void
    let onDelete: () -> Void

    var body: some View {
        SwipeDeleteContainer(canDelete: canDelete, onDelete: onDelete) {
            VStack(spacing: 10) {
                HStack {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(set.completed ? RFTheme.success.opacity(0.16) : RFTheme.accent.opacity(0.12))
                            Text("\(set.order + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(set.completed ? RFTheme.success : RFTheme.accent)
                        }
                        .frame(width: 30, height: 30)

                        Text(L10n.text("Interval", "Interval"))
                            .font(.subheadline.bold())
                    }

                    Spacer()

                    if let pace = paceText {
                        Label(pace, systemImage: "speedometer")
                            .font(.caption.bold())
                            .foregroundStyle(RFTheme.muted)
                    }

                    if let bpm = heartRateMonitor.bpm {
                        Button {
                            set.averageHeartRate = bpm
                            try? context.save()
                            Haptics.light()
                        } label: {
                            Label("\(bpm)", systemImage: "heart.fill")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .accessibilityLabel(L10n.text("Use current heart rate", "Gebruik huidige hartslag"))
                    }

                    Button {
                        set.completed.toggle()
                        set.completedAt = set.completed ? .now : nil
                        if set.completed { Haptics.success() } else { Haptics.light() }
                        try? context.save()
                        onCompleted(set.completed)
                    } label: {
                        Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(set.completed ? RFTheme.success : RFTheme.muted)
                    }
                }

                HStack(spacing: 8) {
                    CardioMetricInput(
                        title: L10n.text("TIME", "TIJD"),
                        unit: "min",
                        icon: "clock",
                        value: Binding(
                            get: { (set.durationSeconds ?? 0) / 60.0 },
                            set: { set.durationSeconds = $0 > 0 ? $0 * 60.0 : nil }
                        )
                    )

                    CardioMetricInput(
                        title: L10n.text("DISTANCE", "AFSTAND"),
                        unit: AppPreferences.distanceLabel,
                        icon: "point.topleft.down.to.point.bottomright.curvepath",
                        value: Binding(
                            get: { AppPreferences.displayDistance(set.distanceKm ?? 0) },
                            set: {
                                let km = AppPreferences.storedDistanceKm($0)
                                set.distanceKm = km > 0 ? km : nil
                            }
                        )
                    )

                    CardioMetricInput(
                        title: L10n.text("INCLINE", "HELLING"),
                        unit: "%",
                        icon: "mountain.2",
                        value: Binding(
                            get: { set.inclinePercent ?? 0 },
                            set: { set.inclinePercent = $0 > 0 ? $0 : nil }
                        )
                    )
                }

                HStack(spacing: 8) {
                    CardioMetricInput(
                        title: L10n.text("CALORIES", "CALORIEËN"),
                        unit: "kcal",
                        icon: "flame.fill",
                        integerOnly: true,
                        value: Binding(
                            get: { set.calories ?? 0 },
                            set: { set.calories = $0 > 0 ? $0 : nil }
                        )
                    )

                    CardioMetricInput(
                        title: L10n.text("AVG HR", "GEM. HF"),
                        unit: "bpm",
                        icon: "heart.fill",
                        integerOnly: true,
                        value: Binding(
                            get: { Double(set.averageHeartRate ?? 0) },
                            set: {
                                let bpm = Int($0.rounded())
                                set.averageHeartRate = bpm > 0 ? bpm : nil
                            }
                        )
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Label(L10n.text("SPEED", "SNELHEID"), systemImage: "gauge.with.dots.needle.50percent")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(RFTheme.muted)
                            .lineLimit(1)

                        Text(speedText)
                            .font(.subheadline.bold())
                            .lineLimit(1)

                        Text(AppPreferences.speedLabel)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(RFTheme.muted)
                    }
                    .padding(9)
                    .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
                    .background(RFTheme.field)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                }
            }
            .padding(11)
            .background(set.completed ? RFTheme.success.opacity(0.055) : RFTheme.raised.opacity(0.52))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(set.completed ? RFTheme.success.opacity(0.26) : RFTheme.cardBorder)
            )
        }
    }

    private var speedText: String {
        guard let duration = set.durationSeconds,
              let distance = set.distanceKm,
              duration > 0,
              distance > 0 else { return "—" }

        let displayedDistance = AppPreferences.displayDistance(distance)
        let hours = duration / 3600.0
        return (displayedDistance / hours)
            .formatted(.number.precision(.fractionLength(0...1)))
    }

    private var paceText: String? {
        guard let duration = set.durationSeconds,
              let distance = set.distanceKm,
              duration > 0,
              distance > 0 else { return nil }

        let displayedDistance = AppPreferences.displayDistance(distance)
        guard displayedDistance > 0 else { return nil }

        let secondsPerUnit = duration / displayedDistance
        let minutes = Int(secondsPerUnit) / 60
        let seconds = Int(secondsPerUnit) % 60
        return "\(minutes):\(String(format: "%02d", seconds))/\(AppPreferences.distanceLabel)"
    }
}

struct CardioMetricInput: View {
    let title: String
    let unit: String
    let icon: String
    var integerOnly: Bool = false
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(RFTheme.muted)
                .lineLimit(1)

            DoneNumberField(
                value: $value,
                integerOnly: integerOnly,
                placeholder: "0"
            )
            .font(.subheadline.bold())
            .frame(height: 24)

            Text(unit)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(RFTheme.muted)
        }
        .padding(9)
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
        .background(RFTheme.field)
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }
}

struct SwipeDeleteContainer<Content: View>: View {
    let canDelete: Bool
    let onDelete: () -> Void
    let content: Content

    init(
        canDelete: Bool,
        onDelete: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.canDelete = canDelete
        self.onDelete = onDelete
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if canDelete {
                Menu {
                    Button(role: .destructive) {
                        Haptics.light()
                        onDelete()
                    } label: {
                        Label(L10n.text("Delete interval", "Interval verwijderen"), systemImage: "trash")
                    }
                } label: {
                    Label(L10n.text("More actions", "Meer acties"), systemImage: "ellipsis")
                        .font(.caption)
                        .foregroundStyle(RFTheme.muted)
                        .frame(minHeight: 36)
                }
            }
            content
        }
        .frame(maxWidth: .infinity)
    }
}

struct ExerciseLogOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var log: ExerciseLog

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.text("Rest timer", "Rusttimer")) {
                    Stepper(
                        "\(L10n.text("Rest", "Rust")): \(log.restSeconds ?? AppPreferences.defaultRestSeconds)s",
                        value: Binding(
                            get: { log.restSeconds ?? AppPreferences.defaultRestSeconds },
                            set: { log.restSeconds = $0 }
                        ),
                        in: 15...600,
                        step: 15
                    )

                    Button(L10n.text("Use app default", "Gebruik app-standaard")) {
                        log.restSeconds = nil
                    }
                }

                Section(L10n.text("Workout note", "Trainingsnotitie")) {
                    TextField(
                        L10n.text("Note for this exercise", "Notitie voor deze oefening"),
                        text: Binding(
                            get: { log.sessionNote ?? "" },
                            set: { log.sessionNote = $0 }
                        ),
                        axis: .vertical
                    )
                    .lineLimit(2...5)
                }
            }
            .navigationTitle(L10n.text("Exercise Options", "Oefening opties"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) {
                        try? context.save()
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}


struct WorkoutSetRow: View {
    @Environment(\.modelContext) private var context
    @Bindable var set: WorkoutSet
    let previous: (Double, Int)?
    let canDelete: Bool
    let onCompleted: (Bool) -> Void
    let onDelete: () -> Void

    @State private var showSetOptions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    showSetOptions = true
                } label: {
                    HStack(spacing: 6) {
                        Text(L10n.text("SET", "SET") + " \(set.order + 1)")
                            .font(.subheadline.weight(.bold))
                        if set.setType != "working" {
                            Text(set.setType.uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(RFTheme.accent)
                        }
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(RFTheme.muted)
                    }
                    .frame(minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 3)

                Menu {
                    Button {
                        showSetOptions = true
                    } label: {
                        Label(L10n.text("Set options", "Setopties"), systemImage: "slider.horizontal.3")
                    }
                    if canDelete {
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label(L10n.text("Delete set", "Set verwijderen"), systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline)
                        .foregroundStyle(RFTheme.muted)
                        .frame(width: 40, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(L10n.text("More set actions", "Meer setacties"))

                Button {
                    // Finish any active number edit first so the final digit is persisted.
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
                    )
                    set.completed.toggle()
                    set.completedAt = set.completed ? .now : nil
                    if set.completed { Haptics.success() } else { Haptics.light() }
                    try? context.save()
                    onCompleted(set.completed)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                        Text(set.completed
                             ? L10n.text("Done", "Klaar")
                             : L10n.text("Log", "Log"))
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(set.completed ? RFTheme.success : RFTheme.accent)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(
                        set.completed ? RFTheme.success.opacity(0.12) : RFTheme.accent.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(set.completed
                    ? L10n.text("Unmark completed set", "Voltooide set terugdraaien")
                    : L10n.text("Complete set", "Set voltooien"))
            }

            HStack(spacing: 10) {
                entryField(
                    title: AppPreferences.weightLabel.uppercased(),
                    value: Binding(
                        get: { AppPreferences.displayWeight(set.weightKg) },
                        set: { set.weightKg = AppPreferences.storedWeightKg($0) }
                    ),
                    integerOnly: false
                )
                entryField(
                    title: L10n.text("REPS", "REPS"),
                    value: Binding(
                        get: { Double(set.reps) },
                        set: { set.reps = max(0, Int($0.rounded())) }
                    ),
                    integerOnly: true
                )
            }

            if AppPreferences.showPreviousSets, let previous {
                HStack(spacing: 6) {
                    Label(
                        L10n.text("Previous", "Vorig") + ": " +
                        AppPreferences.displayWeight(previous.0).formatted(
                            .number.precision(.fractionLength(0...2))
                        ) + " " + AppPreferences.weightLabel + " × \(previous.1)",
                        systemImage: "clock.arrow.circlepath"
                    )
                    .font(.caption2)
                    .foregroundStyle(RFTheme.muted)

                    Spacer(minLength: 0)

                    if !set.completed {
                        Button {
                            set.weightKg = previous.0
                            set.reps = previous.1
                            try? context.save()
                            Haptics.light()
                        } label: {
                            Label(L10n.text("Reuse", "Herhaal"), systemImage: "arrow.down.to.line")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(RFTheme.accent)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            L10n.text("Copy previous weight and repetitions",
                                      "Vorig gewicht en herhalingen kopiëren")
                        )
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            set.completed ? RFTheme.success.opacity(0.075) : RFTheme.raised.opacity(0.65),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(set.completed ? RFTheme.success.opacity(0.25) : RFTheme.cardBorder)
        )
        .sheet(isPresented: $showSetOptions) {
            SetOptionsView(set: set)
        }
    }

    private func entryField(
        title: String, value: Binding<Double>, integerOnly: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundStyle(RFTheme.muted)

            DoneNumberField(value: value, integerOnly: integerOnly, placeholder: "0")
                .frame(height: 48)
                .background(RFTheme.field, in: RoundedRectangle(cornerRadius: 11))
        }
        .frame(maxWidth: .infinity)
    }
}

struct SetOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var set: WorkoutSet

    @State private var useRPE: Bool
    @State private var useRIR: Bool

    init(set: WorkoutSet) {
        self.set = set
        _useRPE = State(initialValue: set.rpe != nil)
        _useRIR = State(initialValue: set.rir != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.text("Set type", "Settype")) {
                    Picker(
                        L10n.text("Type", "Type"),
                        selection: Binding(
                            get: { set.setType },
                            set: { set.setType = $0 }
                        )
                    ) {
                        Text(L10n.text("Working", "Werkset")).tag("working")
                        Text(L10n.text("Warm-up", "Warming-up")).tag("warmup")
                        Text(L10n.text("Drop set", "Dropset")).tag("drop")
                        Text(L10n.text("To failure", "Tot falen")).tag("failure")
                    }
                    .pickerStyle(.segmented)

                    if set.setType == "warmup" {
                        Text(L10n.text(
                            "Warm-up sets are excluded from personal-record calculations.",
                            "Warming-upsets tellen niet mee voor persoonlijke records."
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Section("RPE / RIR") {
                    Toggle("RPE", isOn: $useRPE)
                        .onChange(of: useRPE) { _, enabled in
                            set.rpe = enabled ? (set.rpe ?? 8) : nil
                        }

                    if useRPE {
                        Stepper(
                            "RPE \(set.rpe?.formatted(.number.precision(.fractionLength(0...1))) ?? "8")",
                            value: Binding(
                                get: { set.rpe ?? 8 },
                                set: { set.rpe = $0 }
                            ),
                            in: 5...10,
                            step: 0.5
                        )
                    }

                    Toggle("RIR", isOn: $useRIR)
                        .onChange(of: useRIR) { _, enabled in
                            set.rir = enabled ? (set.rir ?? 2) : nil
                        }

                    if useRIR {
                        Stepper(
                            "RIR \(set.rir ?? 2)",
                            value: Binding(
                                get: { set.rir ?? 2 },
                                set: { set.rir = $0 }
                            ),
                            in: 0...6
                        )
                    }
                }

                Section(L10n.text("Set note", "Setnotitie")) {
                    TextField(
                        L10n.text("Optional note", "Optionele notitie"),
                        text: Binding(
                            get: { set.note ?? "" },
                            set: { set.note = $0 }
                        ),
                        axis: .vertical
                    )
                    .lineLimit(2...5)
                }
            }
            .navigationTitle(L10n.text("Set \(set.order + 1)", "Set \(set.order + 1)"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) {
                        try? context.save()
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}

struct DoneNumberField: UIViewRepresentable {
    @Binding var value: Double
    let integerOnly: Bool
    let placeholder: String

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.keyboardType = integerOnly ? .numberPad : .decimalPad
        field.textAlignment = .center
        field.textColor = .label
        field.tintColor = UIColor(RFTheme.accent)
        field.placeholder = placeholder
        field.adjustsFontSizeToFitWidth = true
        field.minimumFontSize = 13
        field.font = .systemFont(ofSize: 18, weight: .semibold)
        // Keep partial numeric edits in UIKit until editing ends; SwiftData writes
        // on every keypress used to invalidate the entire active workout.

        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.items = [
            UIBarButtonItem(systemItem: .flexibleSpace),
            UIBarButtonItem(
                title: L10n.done,
                style: .done,
                target: context.coordinator,
                action: #selector(Coordinator.doneTapped)
            )
        ]
        field.inputAccessoryView = toolbar
        context.coordinator.field = field
        field.text = formatted(value)
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.parent = self
        guard !uiView.isFirstResponder else { return }
        let expected = formatted(value)
        if uiView.text != expected {
            uiView.text = expected
        }

        if let toolbar = uiView.inputAccessoryView as? UIToolbar,
           let done = toolbar.items?.last {
            done.title = L10n.done
        }
    }

    private func formatted(_ value: Double) -> String {
        guard value != 0 else { return "" }
        if integerOnly { return String(Int(value.rounded())) }
        return value.formatted(.number.precision(.fractionLength(0...2)))
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: DoneNumberField
        weak var field: UITextField?

        init(parent: DoneNumberField) {
            self.parent = parent
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            let raw = (textField.text ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ",", with: ".")
            if raw.isEmpty {
                parent.value = 0
            } else if parent.integerOnly {
                if let parsed = Int(raw), parsed >= 0 {
                    parent.value = Double(parsed)
                }
            } else if let parsed = Double(raw), parsed.isFinite, parsed >= 0 {
                parent.value = parsed
            }
        }

        @objc func doneTapped() {
            field?.resignFirstResponder()
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}


struct WorkoutSummaryView: View {
    let session: WorkoutSession
    let sessions: [WorkoutSession]
    let onDone: () -> Void

    private var completedSets: [WorkoutSet] {
        session.exercises.flatMap(\.sets).filter(\.completed)
    }

    private var prs: [(String, Double, Double)] {
        let previousSessions = sessions.filter { $0.id != session.id && $0.endedAt != nil }

        return session.exercises.compactMap { log in
            let current = log.sets.filter(\.countsForPR).map(\.weightKg).max() ?? 0
            guard current > 0 else { return nil }
            let previous = Metrics.personalBest(
                exerciseID: log.exerciseID,
                sessions: previousSessions,
                gymID: GymProfileStore.sessionGymID(session),
                startDate: AppPreferences.prStartDate
            )
            guard current > previous else { return nil }
            let name = ExerciseCatalog.find(log.exerciseID)?.name ?? "Exercise"
            return (name, current, previous)
        }
    }

    private var progressionSuggestions: [(name: String, current: Double, next: Double, reason: String)] {
        guard AppPreferences.progressionRule != "off" else { return [] }

        return session.exercises.compactMap { log in
            guard ExerciseCatalog.find(log.exerciseID)?.movement != "cardio" else { return nil }

            let workingSets = log.sets.filter { $0.countsForPR && $0.setType == "working" }
            guard !workingSets.isEmpty,
                  let current = workingSets.map(\.weightKg).max(),
                  current > 0 else { return nil }

            let name = ExerciseCatalog.find(log.exerciseID)?.name ?? "Exercise"
            let next = current + AppPreferences.progressionStepKg

            if AppPreferences.progressionRule == "fixed" {
                guard workingSets.allSatisfy({ $0.reps > 0 }) else { return nil }
                let completedText = workingSets
                    .map { "\($0.reps)" }
                    .joined(separator: "/")
                let reason = L10n.text(
                    "Fixed increment: completed working-set reps \(completedText) at \(AppPreferences.displayWeight(current).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.weightLabel).",
                    "Vaste verhoging: werkset-herhalingen \(completedText) voltooid op \(AppPreferences.displayWeight(current).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.weightLabel)."
                )
                return (name, current, next, reason)
            }

            guard let target = log.targetReps,
                  let upper = highestRepTarget(target),
                  workingSets.allSatisfy({ $0.reps >= upper }) else { return nil }

            let repsText = workingSets
                .map { "\($0.reps)" }
                .joined(separator: "/")
            let reason = L10n.text(
                "Target was \(target). You reached the top of the range on every working set (\(repsText)) at \(AppPreferences.displayWeight(current).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.weightLabel).",
                "Doel was \(target). Je haalde de bovenkant van de range op elke werkset (\(repsText)) met \(AppPreferences.displayWeight(current).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.weightLabel)."
            )
            return (name, current, next, reason)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(spacing: 8) {
                        Image(systemName: prs.isEmpty ? "checkmark.circle.fill" : "trophy.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(prs.isEmpty ? RFTheme.success : RFTheme.accent)
                        Text(L10n.text("Workout Complete", "Training voltooid"))
                            .font(.largeTitle.bold())
                        Text(session.title)
                            .foregroundStyle(RFTheme.muted)
                    }
                    .frame(maxWidth: .infinity)

                    ForgeSessionRewards(session: session, sessions: sessions)

                    HStack {
                        StatCard(
                            title: L10n.text("Duration", "Duur"),
                            value: durationString(session.duration),
                            icon: "clock.fill"
                        )

                        if session.totalVolume > 0 {
                            StatCard(
                                title: L10n.text("Volume", "Volume"),
                                value: "\(Int(AppPreferences.displayVolume(session.totalVolume))) \(AppPreferences.weightLabel)",
                                icon: "chart.bar.fill"
                            )
                        } else if session.totalCardioDistanceKm > 0 {
                            StatCard(
                                title: L10n.text("Distance", "Afstand"),
                                value: "\(AppPreferences.displayDistance(session.totalCardioDistanceKm).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.distanceLabel)",
                                icon: "figure.run"
                            )
                        } else {
                            StatCard(
                                title: L10n.text("Entries", "Invoer"),
                                value: "\(completedSets.count)",
                                icon: "checkmark.circle.fill"
                            )
                        }
                    }

                    HStack {
                        StatCard(title: L10n.text("Completed entries", "Voltooide invoer"), value: "\(completedSets.count)", icon: "checkmark.circle.fill")
                        StatCard(title: L10n.text("PRs", "PR's"), value: "\(prs.count)", icon: "trophy.fill")
                    }

                    if session.totalCardioDistanceKm > 0 || session.totalCardioDurationSeconds > 0 {
                        HStack {
                            StatCard(
                                title: L10n.text("Cardio distance", "Cardioafstand"),
                                value: session.totalCardioDistanceKm > 0
                                    ? "\(AppPreferences.displayDistance(session.totalCardioDistanceKm).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.distanceLabel)"
                                    : "—",
                                icon: "figure.run"
                            )
                            StatCard(
                                title: L10n.text("Cardio time", "Cardiotijd"),
                                value: session.totalCardioDurationSeconds > 0
                                    ? cardioDurationText(session.totalCardioDurationSeconds)
                                    : "—",
                                icon: "timer"
                            )
                        }
                    }

                    MuscleHeatMapView(
                        entries: MuscleAnalytics.sessionVolume(session),
                        title: L10n.text("Muscles trained", "Getrainde spieren")
                    )

                    if !prs.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n.text("New personal records", "Nieuwe persoonlijke records"))
                                .font(.title3.bold())

                            ForEach(Array(prs.enumerated()), id: \.offset) { _, pr in
                                HStack {
                                    Image(systemName: "trophy.fill")
                                        .foregroundStyle(RFTheme.accent)
                                    VStack(alignment: .leading) {
                                        Text(pr.0).bold()
                                        Text(
                                            pr.2 > 0
                                            ? "\(AppPreferences.displayWeight(pr.2).formatted(.number.precision(.fractionLength(0...2)))) → \(AppPreferences.displayWeight(pr.1).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.weightLabel)"
                                            : "\(AppPreferences.displayWeight(pr.1).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.weightLabel)"
                                        )
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(12)
                                .background(RFTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }

                    if !progressionSuggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n.text("Next workout suggestions", "Suggesties voor volgende training"))
                                .font(.title3.bold())

                            ForEach(Array(progressionSuggestions.enumerated()), id: \.offset) { _, suggestion in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "arrow.up.right.circle.fill")
                                            .foregroundStyle(RFTheme.success)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(suggestion.name).bold()
                                            Text(
                                                "\(AppPreferences.displayWeight(suggestion.current).formatted(.number.precision(.fractionLength(0...2)))) → \(AppPreferences.displayWeight(suggestion.next).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.weightLabel)"
                                            )
                                            .font(.headline)
                                            .foregroundStyle(RFTheme.success)
                                        }

                                        Spacer()
                                    }

                                    Text(suggestion.reason)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Label(
                                        L10n.text("Suggestion only — you stay in control.", "Alleen een suggestie — jij beslist."),
                                        systemImage: "info.circle"
                                    )
                                    .font(.caption2)
                                    .foregroundStyle(RFTheme.muted)
                                }
                                .padding(12)
                                .background(RFTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(RFTheme.cardBorder)
                                )
                            }
                        }
                    }

                    if let note = session.note, !note.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(L10n.text("Workout note", "Trainingsnotitie"), systemImage: "note.text")
                                .font(.headline)
                            Text(note)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(RFTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button(L10n.done, action: onDone)
                        .buttonStyle(.borderedProminent)
                        .tint(RFTheme.accent)
                        .frame(maxWidth: .infinity)
                        .controlSize(.large)
                }
                .padding()
            }
            .background(RFTheme.bg)
            .navigationTitle(L10n.text("Summary", "Samenvatting"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func highestRepTarget(_ text: String) -> Int? {
        let numbers = text
            .split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }
        return numbers.max()
    }
}

// MARK: - History

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

    @State private var deleteCandidate: WorkoutSession?
    @State private var mode = 0
    @State private var search = ""
    @State private var gymFilter = "all"
    @State private var muscleFilter = "All"
    @State private var periodFilter = "all"
    @State private var onlyPRs = false

    @AppStorage("scheduleRevision") private var scheduleRevision = 0
    @AppStorage("gymRevision") private var gymRevision = 0

    private var completed: [WorkoutSession] {
        sessions.filter { $0.endedAt != nil }
    }

    private var filtered: [WorkoutSession] {
        _ = scheduleRevision
        _ = gymRevision

        return completed.filter { session in
            if gymFilter != "all",
               GymProfileStore.sessionGymID(session) != gymFilter {
                return false
            }

            if muscleFilter != "All" {
                let matchesMuscle = session.exercises.contains { log in
                    guard let exercise = ExerciseCatalog.find(log.exerciseID) else { return false }
                    return exercise.muscle == muscleFilter ||
                        exercise.detailedMuscles.contains(where: { $0.muscle == muscleFilter })
                }
                if !matchesMuscle { return false }
            }

            let calendar = Calendar.current
            switch periodFilter {
            case "7":
                if session.startedAt < (calendar.date(byAdding: .day, value: -7, to: .now) ?? .distantPast) { return false }
            case "30":
                if session.startedAt < (calendar.date(byAdding: .day, value: -30, to: .now) ?? .distantPast) { return false }
            case "year":
                if let start = calendar.dateInterval(of: .year, for: .now)?.start,
                   session.startedAt < start { return false }
            default:
                break
            }

            if onlyPRs && !sessionHasPR(session) {
                return false
            }

            let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return true }

            let haystack = [
                session.title,
                session.note ?? "",
                GymProfileStore.profile(id: session.gymID).name,
                session.startedAt.formatted(date: .long, time: .omitted)
            ] + session.exercises.compactMap { log in
                guard let exercise = ExerciseCatalog.find(log.exerciseID) else { return nil }
                return "\(exercise.name) \(exercise.muscle) \(exercise.equipment)"
            }

            return haystack.contains { $0.localizedCaseInsensitiveContains(trimmed) }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker(L10n.history, selection: $mode) {
                    Text(L10n.text("List", "Lijst")).tag(0)
                    Text(L10n.text("Calendar", "Kalender")).tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                if mode == 0 {
                    WorkoutActivityHeatmap(sessions: completed, condensed: true)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    filterBar

                    if filtered.isEmpty {
                        EmptyCard(
                            icon: "line.3.horizontal.decrease.circle",
                            title: L10n.text("No matching workouts", "Geen overeenkomende trainingen"),
                            text: L10n.text("Change the search or filters.", "Pas de zoekopdracht of filters aan.")
                        )
                        .padding()
                        Spacer()
                    } else {
                        List(filtered) { session in
                            NavigationLink {
                                SessionDetailView(session: session)
                            } label: {
                                historyRow(session)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteCandidate = session
                                } label: {
                                    Label(L10n.text("Delete", "Verwijder"), systemImage: "trash")
                                }
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                } else {
                    WorkoutCalendarView(sessions: completed)
                }
            }
            .background(RFTheme.bg)
            .navigationTitle(L10n.history)
            .searchable(
                text: $search,
                prompt: L10n.text("Search workouts, exercises, gyms…", "Zoek trainingen, oefeningen, gyms…")
            )
            .confirmationDialog(
                L10n.text("Delete workout history?", "Trainingsgeschiedenis verwijderen?"),
                isPresented: Binding(
                    get: { deleteCandidate != nil },
                    set: { if !$0 { deleteCandidate = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(L10n.text("Delete workout", "Training verwijderen"), role: .destructive) {
                    if let session = deleteCandidate {
                        context.delete(session)
                        try? context.save()
                        deleteCandidate = nil
                    }
                }
                Button(L10n.text("Cancel", "Annuleren"), role: .cancel) {
                    deleteCandidate = nil
                }
            } message: {
                Text(L10n.text(
                    "This permanently removes this workout and all of its logged sets.",
                    "Hiermee worden deze training en alle opgeslagen sets permanent verwijderd."
                ))
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    Button(L10n.text("All gyms", "Alle gyms")) { gymFilter = "all" }
                    ForEach(GymProfileStore.load()) { gym in
                        Button {
                            gymFilter = gym.id
                        } label: {
                            if gymFilter == gym.id {
                                Label(gym.name, systemImage: "checkmark")
                            } else {
                                Text(gym.name)
                            }
                        }
                    }
                } label: {
                    Label(
                        gymFilter == "all"
                            ? L10n.text("All gyms", "Alle gyms")
                            : GymProfileStore.profile(id: gymFilter).name,
                        systemImage: "mappin.and.ellipse"
                    )
                }
                .buttonStyle(.bordered)

                Menu {
                    Button(L10n.text("All muscles", "Alle spieren")) { muscleFilter = "All" }
                    ForEach(ExerciseCatalog.muscles, id: \.self) { muscle in
                        Button(muscle) { muscleFilter = muscle }
                    }
                    Divider()
                    ForEach(MuscleMap.trackedMuscles, id: \.self) { muscle in
                        Button(muscle) { muscleFilter = muscle }
                    }
                } label: {
                    Label(
                        muscleFilter == "All" ? L10n.text("Muscle", "Spier") : muscleFilter,
                        systemImage: "figure.strengthtraining.traditional"
                    )
                }
                .buttonStyle(.bordered)

                Menu {
                    Button(L10n.text("All time", "Altijd")) { periodFilter = "all" }
                    Button(L10n.text("Last 7 days", "Laatste 7 dagen")) { periodFilter = "7" }
                    Button(L10n.text("Last 30 days", "Laatste 30 dagen")) { periodFilter = "30" }
                    Button(L10n.text("This year", "Dit jaar")) { periodFilter = "year" }
                } label: {
                    Label(periodLabel, systemImage: "calendar")
                }
                .buttonStyle(.bordered)

                Button {
                    onlyPRs.toggle()
                } label: {
                    Label("PR", systemImage: onlyPRs ? "trophy.fill" : "trophy")
                }
                .buttonStyle(.bordered)
                .tint(onlyPRs ? RFTheme.accent : .gray)

                if gymFilter != "all" || muscleFilter != "All" || periodFilter != "all" || onlyPRs {
                    Button {
                        gymFilter = "all"
                        muscleFilter = "All"
                        periodFilter = "all"
                        onlyPRs = false
                    } label: {
                        Label(L10n.text("Clear", "Wis"), systemImage: "xmark")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func historyRow(_ session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(session.title).font(.headline)
                if sessionHasPR(session) {
                    Image(systemName: "trophy.fill")
                        .font(.caption)
                        .foregroundStyle(RFTheme.accent)
                }
                Spacer()
                Text(session.startedAt, format: .dateTime.day().month(.abbreviated))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                Label(GymProfileStore.profile(id: session.gymID).name, systemImage: "mappin.and.ellipse")
                Text("•")
                Text("\(session.exercises.count) \(L10n.text("exercises", "oefeningen"))")
                Text("•")
                Text(historyPrimaryMetric(session))
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(durationString(session.duration))
                .font(.caption2)
                .foregroundStyle(RFTheme.muted)
        }
        .padding(.vertical, 6)
    }

    private func historyPrimaryMetric(_ session: WorkoutSession) -> String {
        if session.totalVolume > 0 {
            return "\(Int(AppPreferences.displayVolume(session.totalVolume))) \(AppPreferences.weightLabel)"
        }

        if session.totalCardioDistanceKm > 0 {
            return "\(AppPreferences.displayDistance(session.totalCardioDistanceKm).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.distanceLabel)"
        }

        if session.totalCardioDurationSeconds > 0 {
            return cardioDurationText(session.totalCardioDurationSeconds)
        }

        return "—"
    }

    private var periodLabel: String {
        switch periodFilter {
        case "7": return "7d"
        case "30": return "30d"
        case "year": return L10n.text("Year", "Jaar")
        default: return L10n.text("All time", "Altijd")
        }
    }

    private func sessionHasPR(_ session: WorkoutSession) -> Bool {
        let earlier = completed.filter { $0.startedAt < session.startedAt }

        return session.exercises.contains { log in
            let current = log.sets.filter(\.countsForPR).map(\.weightKg).max() ?? 0
            guard current > 0 else { return false }

            let previous = Metrics.personalBest(
                exerciseID: log.exerciseID,
                sessions: earlier,
                gymID: GymProfileStore.sessionGymID(session)
            )

            return current > previous
        }
    }
}

struct WorkoutCalendarView: View {
    let sessions: [WorkoutSession]

    @State private var month = Calendar.current.date(
        from: Calendar.current.dateComponents([.year, .month], from: .now)
    ) ?? .now
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var editingSchedule: ScheduledWorkoutRecord?

    @AppStorage("scheduleRevision") private var scheduleRevision = 0

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private var monthDays: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else {
            return []
        }

        let weekday = calendar.component(.weekday, from: first)
        let prefix = (weekday - calendar.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: prefix)

        for day in range {
            days.append(calendar.date(byAdding: .day, value: day - 1, to: first))
        }

        while days.count % 7 != 0 {
            days.append(nil)
        }
        return days
    }

    private var planned: [ScheduledWorkoutRecord] {
        _ = scheduleRevision
        return WorkoutScheduleStore.load()
    }

    private var selectedSessions: [WorkoutSession] {
        sessions.filter { calendar.isDate($0.startedAt, inSameDayAs: selectedDate) }
    }

    private var selectedPlans: [ScheduledWorkoutRecord] {
        planned.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    Button {
                        shiftMonth(-1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }

                    Spacer()

                    Text(month.formatted(.dateTime.month(.wide).year()))
                        .font(.title3.bold())

                    Spacer()

                    Button {
                        shiftMonth(1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                }
                .padding(.horizontal)

                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.caption2.bold())
                            .foregroundStyle(RFTheme.muted)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                        if let date {
                            CalendarDayCell(
                                date: date,
                                selected: calendar.isDate(date, inSameDayAs: selectedDate),
                                workoutCount: sessions.filter { calendar.isDate($0.startedAt, inSameDayAs: date) }.count,
                                plannedCount: planned.filter {
                                    calendar.isDate($0.date, inSameDayAs: date) && !$0.skipped
                                }.count,
                                skippedCount: planned.filter {
                                    calendar.isDate($0.date, inSameDayAs: date) && $0.skipped
                                }.count
                            ) {
                                selectedDate = calendar.startOfDay(for: date)
                            }
                        } else {
                            Color.clear.frame(height: 48)
                        }
                    }
                }
                .padding(.horizontal)

                Divider()
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 10) {
                    Text(selectedDate.formatted(date: .complete, time: .omitted))
                        .font(.headline)

                    if selectedSessions.isEmpty && selectedPlans.isEmpty {
                        Text(L10n.text("Nothing scheduled or completed.", "Niets gepland of voltooid."))
                            .foregroundStyle(RFTheme.muted)
                            .padding(.vertical, 12)
                    }

                    ForEach(selectedPlans) { item in
                        HStack(spacing: 10) {
                            Image(systemName: item.skipped ? "forward.end.fill" : "calendar.badge.clock")
                                .foregroundStyle(item.skipped ? .orange : RFTheme.accent)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.subheadline.bold())
                                    .strikethrough(item.skipped)
                                Text(
                                    "\(item.date.formatted(date: .omitted, time: .shortened)) • \(GymProfileStore.profile(id: item.gymID).name)"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Menu {
                                Button {
                                    editingSchedule = item
                                } label: {
                                    Label(L10n.text("Reschedule", "Verplaatsen"), systemImage: "calendar")
                                }
                                Button {
                                    WorkoutScheduleStore.toggleSkipped(id: item.id)
                                } label: {
                                    Label(
                                        item.skipped
                                            ? L10n.text("Unskip", "Niet overslaan")
                                            : L10n.text("Skip", "Overslaan"),
                                        systemImage: "forward.end"
                                    )
                                }
                                Button(role: .destructive) {
                                    WorkoutScheduleStore.remove(id: item.id)
                                } label: {
                                    Label(L10n.text("Delete", "Verwijder"), systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .frame(width: 32, height: 32)
                            }
                        }
                        .padding(12)
                        .background(RFTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    ForEach(selectedSessions) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(RFTheme.success)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(session.title)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                    Text(
                                        "\(Int(AppPreferences.displayVolume(session.totalVolume))) \(AppPreferences.weightLabel) • \(durationString(session.duration))"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(RFTheme.muted)
                            }
                            .padding(12)
                            .background(RFTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .padding(.top, 10)
        }
        .sheet(item: $editingSchedule) { item in
            ScheduleWorkoutSheet(seed: item) { updated in
                WorkoutScheduleStore.update(updated)
            }
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    private func shiftMonth(_ delta: Int) {
        if let next = calendar.date(byAdding: .month, value: delta, to: month) {
            month = next
            selectedDate = calendar.startOfDay(for: next)
        }
    }
}

struct CalendarDayCell: View {
    let date: Date
    let selected: Bool
    let workoutCount: Int
    let plannedCount: Int
    let skippedCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.subheadline.bold())
                    .foregroundStyle(selected ? Color.white : Color.primary)

                HStack(spacing: 3) {
                    if workoutCount > 0 {
                        Circle().fill(RFTheme.success).frame(width: 5, height: 5)
                    }
                    if plannedCount > 0 {
                        Circle().fill(RFTheme.accent).frame(width: 5, height: 5)
                    }
                    if skippedCount > 0 {
                        Circle().fill(Color.orange).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(selected ? RFTheme.accent : RFTheme.surface.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

struct SessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let session: WorkoutSession
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var allSessions: [WorkoutSession]
    @State private var showDeleteConfirmation = false

    private var previousComparable: WorkoutSession? {
        let earlier = allSessions.filter {
            $0.endedAt != nil &&
            $0.startedAt < session.startedAt &&
            GymProfileStore.sessionGymID($0) == GymProfileStore.sessionGymID(session)
        }

        if let exact = earlier.first(where: { $0.title == session.title }) {
            return exact
        }

        let currentIDs = Set(session.exercises.map(\.exerciseID))
        guard !currentIDs.isEmpty else { return nil }

        return earlier
            .map { candidate -> (WorkoutSession, Double) in
                let ids = Set(candidate.exercises.map(\.exerciseID))
                let overlap = Double(currentIDs.intersection(ids).count)
                let union = Double(currentIDs.union(ids).count)
                return (candidate, union > 0 ? overlap / union : 0)
            }
            .filter { $0.1 >= 0.45 }
            .sorted { $0.1 > $1.1 }
            .first?.0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.startedAt.formatted(date: .complete, time: .shortened))
                                .font(.caption.bold())
                                .foregroundStyle(RFTheme.muted)

                            Label(
                                GymProfileStore.profile(id: session.gymID).name,
                                systemImage: "mappin.and.ellipse"
                            )
                            .font(.caption.bold())
                            .foregroundStyle(RFTheme.accent)
                        }

                        Spacer()

                        Image(systemName: "checkmark.seal.fill")
                            .font(.title)
                            .foregroundStyle(RFTheme.success)
                    }

                    HStack {
                        StatCard(
                            title: L10n.text("Duration", "Duur"),
                            value: durationString(session.duration),
                            icon: "clock.fill"
                        )

                        if session.totalVolume > 0 {
                            StatCard(
                                title: L10n.text("Volume", "Volume"),
                                value: "\(Int(AppPreferences.displayVolume(session.totalVolume))) \(AppPreferences.weightLabel)",
                                icon: "chart.bar.fill"
                            )
                        } else {
                            StatCard(
                                title: L10n.text("Entries", "Invoer"),
                                value: "\(session.exercises.flatMap(\.sets).filter(\.completed).count)",
                                icon: "checkmark.circle.fill"
                            )
                        }
                    }

                    if session.totalCardioDistanceKm > 0 || session.totalCardioDurationSeconds > 0 {
                        HStack {
                            StatCard(
                                title: L10n.text("Cardio distance", "Cardioafstand"),
                                value: session.totalCardioDistanceKm > 0
                                    ? "\(AppPreferences.displayDistance(session.totalCardioDistanceKm).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.distanceLabel)"
                                    : "—",
                                icon: "figure.run"
                            )
                            StatCard(
                                title: L10n.text("Cardio time", "Cardiotijd"),
                                value: session.totalCardioDurationSeconds > 0
                                    ? cardioDurationText(session.totalCardioDurationSeconds)
                                    : "—",
                                icon: "timer"
                            )
                        }
                    }
                }
                .padding()
                .background(RFTheme.heroGradient)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(RFTheme.cardBorder)
                )

                if let note = session.note, !note.isEmpty {
                    Label(note, systemImage: "note.text")
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RFTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(RFTheme.cardBorder)
                        )
                }

                if let previousComparable {
                    WorkoutComparisonCard(current: session, previous: previousComparable)
                }

                ForEach(session.exercises.sorted(by: { $0.order < $1.order })) { log in
                    let ex = ExerciseCatalog.find(log.exerciseID)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 11)
                                    .fill(RFTheme.accent.opacity(0.12))
                                Image(systemName: ex?.movement == "cardio" ? "figure.run" : "dumbbell.fill")
                                    .foregroundStyle(RFTheme.accent)
                            }
                            .frame(width: 38, height: 38)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(ex?.name ?? "Exercise")
                                    .font(.headline)
                                Text(ex?.movement == "cardio"
                                     ? L10n.text("Cardio", "Cardio")
                                     : "\(log.sets.filter(\.completed).count) \(L10n.text("completed sets", "voltooide sets"))")
                                    .font(.caption)
                                    .foregroundStyle(RFTheme.muted)
                            }

                            Spacer()
                        }

                        if ex?.movement == "cardio" {
                            ForEach(log.sets.filter(\.completed).sorted(by: { $0.order < $1.order })) { set in
                                CardioHistoryEntry(set: set)
                            }
                        } else {
                            ForEach(log.sets.filter(\.completed).sorted(by: { $0.order < $1.order })) { set in
                                HStack {
                                    Text("\(L10n.text("Set", "Set")) \(set.order + 1)")
                                        .foregroundStyle(RFTheme.muted)

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(AppPreferences.displayWeight(set.weightKg).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.weightLabel) × \(set.reps)")
                                            .bold()

                                        HStack(spacing: 6) {
                                            if set.setType != "working" {
                                                Text(set.setType.capitalized)
                                            }
                                            if let rpe = set.rpe {
                                                Text("RPE \(rpe.formatted(.number.precision(.fractionLength(0...1))))")
                                            }
                                            if let rir = set.rir {
                                                Text("RIR \(rir)")
                                            }
                                        }
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    }
                                }
                                .font(.subheadline)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding()
                    .background(RFTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(RFTheme.cardBorder)
                    )
                }
            }
            .padding()
        }
        .background(RFTheme.bg)
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel(L10n.text("Delete workout", "Training verwijderen"))
            }
        }
        .confirmationDialog(
            L10n.text("Delete workout history?", "Trainingsgeschiedenis verwijderen?"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.text("Delete workout", "Training verwijderen"), role: .destructive) {
                context.delete(session)
                try? context.save()
                dismiss()
            }
            Button(L10n.text("Cancel", "Annuleren"), role: .cancel) {}
        } message: {
            Text(L10n.text(
                "This permanently removes this workout and all of its logged sets.",
                "Hiermee worden deze training en alle opgeslagen sets permanent verwijderd."
            ))
        }
    }
}

struct CardioHistoryEntry: View {
    let set: WorkoutSet

    var body: some View {
        VStack(spacing: 7) {
            HStack {
                Text("\(L10n.text("Interval", "Interval")) \(set.order + 1)")
                    .font(.caption.bold())
                    .foregroundStyle(RFTheme.muted)
                Spacer()
                if let paceText {
                    Label(paceText, systemImage: "speedometer")
                        .font(.caption.bold())
                        .foregroundStyle(RFTheme.accent)
                }
            }

            HStack(spacing: 12) {
                if let duration = set.durationSeconds, duration > 0 {
                    historyMetric(
                        icon: "clock",
                        value: cardioDurationText(duration),
                        label: L10n.text("Time", "Tijd")
                    )
                }

                if let distance = set.distanceKm, distance > 0 {
                    historyMetric(
                        icon: "figure.run",
                        value: "\(AppPreferences.displayDistance(distance).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.distanceLabel)",
                        label: L10n.text("Distance", "Afstand")
                    )
                }

                if let calories = set.calories, calories > 0 {
                    historyMetric(
                        icon: "flame.fill",
                        value: "\(Int(calories.rounded()))",
                        label: "kcal"
                    )
                }

                if let hr = set.averageHeartRate, hr > 0 {
                    historyMetric(
                        icon: "heart.fill",
                        value: "\(hr)",
                        label: "bpm"
                    )
                }
            }

            if let incline = set.inclinePercent, incline > 0 {
                HStack {
                    Label(
                        "\(L10n.text("Incline", "Helling")) \(incline.formatted(.number.precision(.fractionLength(0...1))))%",
                        systemImage: "mountain.2"
                    )
                    .font(.caption)
                    .foregroundStyle(RFTheme.muted)
                    Spacer()
                }
            }
        }
        .padding(10)
        .background(RFTheme.field.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var paceText: String? {
        guard let duration = set.durationSeconds,
              let distanceKm = set.distanceKm,
              duration > 0,
              distanceKm > 0 else { return nil }

        let distance = AppPreferences.displayDistance(distanceKm)
        let secondsPerUnit = duration / distance
        let minutes = Int(secondsPerUnit) / 60
        let seconds = Int(secondsPerUnit) % 60
        return "\(minutes):\(String(format: "%02d", seconds))/\(AppPreferences.distanceLabel)"
    }

    private func historyMetric(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(RFTheme.accent)
            Text(value)
                .font(.caption.bold())
                .lineLimit(1)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(RFTheme.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

struct WorkoutComparisonCard: View {
    let current: WorkoutSession
    let previous: WorkoutSession

    private var currentSets: Int {
        current.exercises.flatMap(\.sets).filter(\.completed).count
    }

    private var previousSets: Int {
        previous.exercises.flatMap(\.sets).filter(\.completed).count
    }

    private var volumeDelta: Double {
        current.totalVolume - previous.totalVolume
    }

    private var durationDelta: TimeInterval {
        current.duration - previous.duration
    }

    private var setDelta: Int {
        currentSets - previousSets
    }

    private var exerciseChanges: [(String, Double)] {
        current.exercises.compactMap { log in
            guard let previousLog = previous.exercises.first(where: { $0.exerciseID == log.exerciseID }),
                  let exercise = ExerciseCatalog.find(log.exerciseID) else {
                return nil
            }

            let currentBest = log.sets.filter(\.countsForPR).map(\.weightKg).max() ?? 0
            let previousBest = previousLog.sets.filter(\.countsForPR).map(\.weightKg).max() ?? 0
            guard currentBest > 0 || previousBest > 0 else { return nil }
            return (exercise.name, currentBest - previousBest)
        }
        .sorted { abs($0.1) > abs($1.1) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.text("Compared with previous", "Vergeleken met vorige"))
                        .font(.title3.bold())
                    Text(previous.startedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(RFTheme.muted)
                }
                Spacer()
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundStyle(RFTheme.accent)
            }

            HStack {
                if current.totalVolume > 0 || previous.totalVolume > 0 {
                    comparisonMetric(
                        title: L10n.text("Volume", "Volume"),
                        value: signedWeight(volumeDelta),
                        positive: volumeDelta >= 0
                    )
                } else {
                    comparisonMetric(
                        title: L10n.text("Distance", "Afstand"),
                        value: signedDistance(current.totalCardioDistanceKm - previous.totalCardioDistanceKm),
                        positive: current.totalCardioDistanceKm >= previous.totalCardioDistanceKm
                    )
                }

                comparisonMetric(
                    title: L10n.text("Entries", "Invoer"),
                    value: signedInt(setDelta),
                    positive: setDelta >= 0
                )

                comparisonMetric(
                    title: L10n.text("Time", "Tijd"),
                    value: signedDuration(durationDelta),
                    positive: durationDelta <= 0
                )
            }

            if !exerciseChanges.isEmpty {
                Divider()
                ForEach(Array(exerciseChanges.prefix(5).enumerated()), id: \.offset) { _, item in
                    HStack {
                        Text(item.0)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text(signedWeight(item.1))
                            .font(.caption.bold())
                            .foregroundStyle(item.1 > 0 ? RFTheme.success : item.1 < 0 ? Color.orange : RFTheme.muted)
                    }
                }
            }
        }
        .padding()
        .background(RFTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func comparisonMetric(title: String, value: String, positive: Bool) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundStyle(positive ? RFTheme.success : Color.orange)
            Text(title)
                .font(.caption2)
                .foregroundStyle(RFTheme.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private func signedWeight(_ kg: Double) -> String {
        let displayed = AppPreferences.displayWeight(abs(kg))
        let sign = kg > 0 ? "+" : kg < 0 ? "−" : "±"
        return "\(sign)\(displayed.formatted(.number.precision(.fractionLength(0...1)))) \(AppPreferences.weightLabel)"
    }

    private func signedDistance(_ km: Double) -> String {
        let displayed = AppPreferences.displayDistance(abs(km))
        let sign = km > 0 ? "+" : km < 0 ? "−" : "±"
        return "\(sign)\(displayed.formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.distanceLabel)"
    }

    private func signedInt(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    private func signedDuration(_ value: TimeInterval) -> String {
        let minutes = Int(abs(value) / 60)
        let sign = value > 0 ? "+" : value < 0 ? "−" : "±"
        return "\(sign)\(minutes)m"
    }
}

// MARK: - Exercise library & detail

struct ExerciseLibraryView: View {
    @State private var search = ""
    @State private var muscle = "All"
    @State private var equipment = "All"
    @State private var showCustomEditor = false
    @State private var refreshToken = UUID()
    @State private var deleteCandidate: ExerciseDefinition?

    private var filtered: [ExerciseDefinition] {
        _ = refreshToken
        return ExerciseCatalog.all.filter { ex in
            ExerciseSearch.matches(ex, query: search) &&
            (muscle == "All" || ex.muscle == muscle) &&
            GymEquipmentFilter.matches(ex, selected: equipment)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterPanel

                HStack {
                    Text("\(filtered.count) " + L10n.text("exercises", "oefeningen"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RFTheme.muted)
                    Spacer()
                    if muscle != "All" || equipment != "All" || !search.isEmpty {
                        Button(L10n.text("Clear filters", "Filters wissen")) {
                            search = ""
                            muscle = "All"
                            equipment = "All"
                        }
                        .font(.caption.weight(.semibold))
                    }
                }
                .padding(.horizontal, RFLayout.pagePadding)
                .padding(.vertical, 8)

                if filtered.isEmpty {
                    ContentUnavailableView.search(text: search)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filtered) { ex in
                        NavigationLink {
                            ExerciseDetailView(exercise: ex)
                        } label: {
                            ExerciseLibraryRow(exercise: ex)
                        }
                        .listRowBackground(RFLayout.style == "focused" ? RFTheme.surface : Color.clear)
                        .listRowSeparator(RFLayout.style == "focused" ? .hidden : .visible)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                ExerciseShortcutStore.toggleFavorite(ex.id)
                                refreshToken = UUID()
                            } label: {
                                Label(
                                    ExerciseShortcutStore.isFavorite(ex.id)
                                        ? L10n.text("Unfavorite", "Verwijder favoriet")
                                        : L10n.text("Favorite", "Favoriet"),
                                    systemImage: ExerciseShortcutStore.isFavorite(ex.id) ? "star.slash" : "star.fill"
                                )
                            }
                            .tint(.yellow)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if CustomExerciseStore.isCustom(ex.id) {
                                Button(role: .destructive) {
                                    deleteCandidate = ex
                                } label: {
                                    Label(L10n.text("Delete", "Verwijder"), systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .id(refreshToken)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(RFTheme.bg)
            .searchable(
                text: $search,
                prompt: L10n.text("Exercise or machine name", "Oefening of apparaat")
            )
            .navigationTitle(L10n.exercises)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showCustomEditor = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(L10n.text("Create custom exercise", "Eigen oefening maken"))
                }
            }
            .sheet(isPresented: $showCustomEditor, onDismiss: {
                refreshToken = UUID()
            }) {
                CustomExerciseEditorView()
            }
            .confirmationDialog(
                L10n.text("Delete custom exercise?", "Eigen oefening verwijderen?"),
                isPresented: Binding(
                    get: { deleteCandidate != nil },
                    set: { if !$0 { deleteCandidate = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(L10n.text("Delete", "Verwijder"), role: .destructive) {
                    if let candidate = deleteCandidate {
                        CustomExerciseStore.delete(id: candidate.id)
                        deleteCandidate = nil
                        refreshToken = UUID()
                    }
                }
                Button(L10n.text("Cancel", "Annuleren"), role: .cancel) {
                    deleteCandidate = nil
                }
            } message: {
                Text(L10n.text(
                    "Existing workout history will keep its saved exercise ID, but the exercise will no longer appear in the library.",
                    "Bestaande trainingsgeschiedenis behoudt de opgeslagen oefening-ID, maar de oefening verschijnt niet meer in de bibliotheek."
                ))
            }
        }
    }

    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: RFLayout.style == "compact" ? 8 : 12) {
            HStack {
                Text(L10n.text("Explore equipment", "Verken apparaten"))
                    .font(RFLayout.style == "focused" ? .title3.bold() : .headline)
                Spacer()
                Menu {
                    Button(L10n.text("All muscles", "Alle spiergroepen")) { muscle = "All" }
                    ForEach(ExerciseCatalog.muscles, id: \.self) { option in
                        Button(option) { muscle = option }
                    }
                } label: {
                    Label(
                        muscle == "All" ? L10n.text("Muscles", "Spieren") : muscle,
                        systemImage: "line.3.horizontal.decrease"
                    )
                    .font(.subheadline.weight(.medium))
                }
            }
            .padding(.horizontal, RFLayout.pagePadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(GymEquipmentFilter.options, id: \.self) { option in
                        Button {
                            equipment = option
                        } label: {
                            Text(GymEquipmentFilter.label(option))
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 13)
                                .padding(.vertical, RFLayout.style == "compact" ? 7 : 10)
                                .foregroundStyle(equipment == option ? RFTheme.accent : .primary)
                                .background(
                                    equipment == option ? RFTheme.accent.opacity(0.16) : RFTheme.surface,
                                    in: Capsule()
                                )
                                .overlay(Capsule().stroke(
                                    equipment == option ? RFTheme.accent.opacity(0.65) : RFTheme.cardBorder
                                ))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(equipment == option ? .isSelected : [])
                    }
                }
                .padding(.horizontal, RFLayout.pagePadding)
            }

            if equipment == "Machines" && search.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(GymEquipmentFilter.machineShortcuts, id: \.label) { shortcut in
                            Button {
                                search = shortcut.term
                                muscle = "All"
                            } label: {
                                Label(shortcut.label, systemImage: "magnifyingglass")
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.horizontal, RFLayout.pagePadding)
                }
            }
        }
        .padding(.vertical, RFLayout.style == "compact" ? 8 : 12)
        .background(.ultraThinMaterial)
    }
}

struct ExerciseLibraryRow: View {
    let exercise: ExerciseDefinition

    var body: some View {
        HStack(spacing: RFLayout.style == "compact" ? 10 : 14) {
            ZStack {
                RoundedRectangle(cornerRadius: RFLayout.style == "compact" ? 9 : 15)
                    .fill(RFTheme.accent.opacity(0.12))
                Image(systemName: symbol)
                    .font(RFLayout.style == "compact" ? .body : .title3)
                    .foregroundStyle(RFTheme.accent)
            }
            .frame(width: RFLayout.style == "compact" ? 38 : 54,
                   height: RFLayout.style == "compact" ? 38 : 54)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(exercise.name)
                    .font(RFLayout.style == "compact" ? .subheadline.weight(.semibold) : .headline)
                    .foregroundStyle(.primary)
                HStack(spacing: 5) {
                    Text(exercise.muscle)
                    Text("•")
                    Text(exercise.equipment)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 4)

            if CustomExerciseStore.isCustom(exercise.id) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .foregroundStyle(RFTheme.muted)
                    .accessibilityLabel(L10n.text("Custom exercise", "Eigen oefening"))
            } else if exercise.sourceID != nil {
                Image(systemName: "play.rectangle")
                    .foregroundStyle(RFTheme.muted)
                    .accessibilityLabel(L10n.text("Video available", "Video beschikbaar"))
            }
        }
        .padding(.vertical, RFLayout.style == "compact" ? 0 : 5)
    }

    private var symbol: String {
        switch exercise.movement {
        case "press": return "arrow.up.right"
        case "pull": return "arrow.down.left"
        case "squat": return "figure.strengthtraining.traditional"
        case "hinge": return "figure.flexibility"
        case "cardio": return "figure.run"
        case "core": return "figure.core.training"
        default: return "dumbbell.fill"
        }
    }
}

struct CustomExerciseEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var muscle = "Chest"
    @State private var equipment = "Dumbbell"
    @State private var movement = "press"

    private let muscles = [
        "Chest", "Back", "Shoulders", "Biceps", "Triceps", "Forearms",
        "Quadriceps", "Hamstrings", "Glutes", "Calves", "Core", "Full Body", "Cardio", "Other"
    ]

    private let equipmentOptions = [
        "Barbell", "Dumbbell", "Cable", "Machine", "Bodyweight",
        "Kettlebell", "EZ-Bar", "Trap Bar", "Cardio", "Other"
    ]

    private let movementOptions: [(String, String)] = [
        ("press", "Press"),
        ("pull", "Pull"),
        ("squat", "Squat"),
        ("hinge", "Hinge"),
        ("curl", "Curl"),
        ("extension", "Extension"),
        ("raise", "Raise"),
        ("core", "Core"),
        ("carry", "Carry"),
        ("cardio", "Cardio"),
        ("other", "Other")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.text("Exercise", "Oefening")) {
                    TextField(L10n.text("Exercise name", "Naam oefening"), text: $name)

                    Picker(L10n.text("Muscle", "Spiergroep"), selection: $muscle) {
                        ForEach(muscles, id: \.self) { Text($0).tag($0) }
                    }

                    Picker(L10n.text("Equipment", "Apparatuur"), selection: $equipment) {
                        ForEach(equipmentOptions, id: \.self) { Text($0).tag($0) }
                    }

                    Picker(L10n.text("Movement", "Beweging"), selection: $movement) {
                        ForEach(movementOptions, id: \.0) { option in
                            Text(option.1).tag(option.0)
                        }
                    }
                }

                Section {
                    Text(L10n.text(
                        "Custom exercises are stored locally and automatically appear in workout and template exercise pickers.",
                        "Eigen oefeningen worden lokaal opgeslagen en verschijnen automatisch in de oefeningkiezers voor trainingen en templates."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(L10n.text("New Exercise", "Nieuwe oefening"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("Cancel", "Annuleren")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("Save", "Opslaan")) {
                        CustomExerciseStore.add(
                            name: name,
                            muscle: muscle,
                            equipment: equipment,
                            movement: movement
                        )
                        Haptics.success()
                        dismiss()
                    }
                    .bold()
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}


struct ExerciseDetailView: View {
    let exercise: ExerciseDefinition
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @State private var tab = 0

    private var performances: [(date: Date, weight: Double, oneRM: Double, volume: Double)] {
        guard exercise.movement != "cardio" else { return [] }
        return Metrics.performances(
            exerciseID: exercise.id,
            sessions: sessions,
            gymID: AppPreferences.activeGymID,
            startDate: AppPreferences.prStartDate
        )
    }

    private var cardioPerformances: [(date: Date, distanceKm: Double, duration: Double, calories: Double, avgHR: Double?)] {
        guard exercise.movement == "cardio" else { return [] }

        return Metrics.scopedSessions(
            sessions,
            gymID: AppPreferences.activeGymID,
            startDate: AppPreferences.prStartDate
        )
        .compactMap { session in
            guard let log = session.exercises.first(where: { $0.exerciseID == exercise.id }) else { return nil }
            let completed = log.sets.filter(\.completed)
            guard !completed.isEmpty else { return nil }

            let distance = completed.reduce(0.0) { $0 + ($1.distanceKm ?? 0) }
            let duration = completed.reduce(0.0) { $0 + ($1.durationSeconds ?? 0) }
            let calories = completed.reduce(0.0) { $0 + ($1.calories ?? 0) }
            let heartRates = completed.compactMap(\.averageHeartRate)
            let avgHR = heartRates.isEmpty
                ? nil
                : Double(heartRates.reduce(0, +)) / Double(heartRates.count)

            return (
                session.endedAt ?? session.startedAt,
                distance,
                duration,
                calories,
                avgHR
            )
        }
        .sorted { $0.date < $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("Section", selection: $tab) {
                    Text("Guide").tag(0)
                    Text("History").tag(1)
                    Text("Charts").tag(2)
                    Text("Records").tag(3)
                }
                .pickerStyle(.segmented)

                if tab == 0 { guide }
                if tab == 1 { history }
                if tab == 2 { charts }
                if tab == 3 { records }
            }
            .padding()
        }
        .background(RFTheme.bg)
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var guide: some View {
        ExerciseDemoView(exercise: exercise)

        ExerciseTargetHeatmap(exercise: exercise)

        HStack {
            Label(exercise.muscle, systemImage: "figure.strengthtraining.traditional")
            Spacer()
            Text(exercise.equipment).foregroundStyle(RFTheme.muted)
        }

        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text("Muscles trained", "Getrainde spieren"))
                .font(.title3.bold())

            FlowMuscleTags(contributions: exercise.detailedMuscles)
        }

        Text("How to perform").font(.title3.bold())
        ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { index, step in
            HStack(alignment: .top, spacing: 12) {
                Text("\(index + 1)")
                    .font(.caption.bold())
                    .frame(width: 28, height: 28)
                    .background(RFTheme.accent)
                    .clipShape(Circle())
                Text(step)
            }
        }

        Text("Technique cues").font(.title3.bold()).padding(.top, 4)
        ForEach(exercise.cues, id: \.self) {
            Label($0, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.secondary)
        }

        Text("Training guidance is general information, not medical advice. Stop an exercise if it causes pain and seek qualified help when appropriate.")
            .font(.caption)
            .foregroundStyle(RFTheme.muted)
            .padding(.top, 4)
    }

    @ViewBuilder
    private var history: some View {
        if exercise.movement == "cardio" {
            if cardioPerformances.isEmpty {
                EmptyCard(
                    icon: "clock",
                    title: L10n.text("No cardio history yet", "Nog geen cardiogeschiedenis"),
                    text: L10n.text("Complete this cardio exercise to populate its history.", "Voltooi deze cardio-oefening om geschiedenis op te bouwen.")
                )
            } else {
                ForEach(Array(cardioPerformances.reversed().enumerated()), id: \.offset) { _, p in
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(RFTheme.accent.opacity(0.12))
                            Image(systemName: "figure.run")
                                .foregroundStyle(RFTheme.accent)
                        }
                        .frame(width: 42, height: 42)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(p.date.formatted(date: .abbreviated, time: .omitted))
                                .bold()

                            HStack(spacing: 7) {
                                if p.duration > 0 {
                                    Text(cardioDurationText(p.duration))
                                }
                                if p.distanceKm > 0 {
                                    Text("• \(AppPreferences.displayDistance(p.distanceKm).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.distanceLabel)")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if let pace = cardioPaceText(duration: p.duration, distanceKm: p.distanceKm) {
                            Text(pace)
                                .font(.headline)
                                .foregroundStyle(RFTheme.accent)
                        }
                    }
                    .padding()
                    .background(RFTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(RFTheme.cardBorder)
                    )
                }
            }
        } else if performances.isEmpty {
            EmptyCard(
                icon: "clock",
                title: "No history yet",
                text: "Complete this exercise in a workout to populate its history."
            )
        } else {
            ForEach(Array(performances.reversed().enumerated()), id: \.offset) { _, p in
                HStack {
                    VStack(alignment: .leading) {
                        Text(p.date.formatted(date: .abbreviated, time: .omitted)).bold()
                        Text("\(L10n.text("Volume", "Volume")) \(Int(AppPreferences.displayVolume(p.volume))) \(AppPreferences.weightLabel)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(AppPreferences.displayWeight(p.weight).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.weightLabel)")
                        .font(.headline)
                        .foregroundStyle(RFTheme.accent)
                }
                .padding()
                .background(RFTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    @ViewBuilder
    private var charts: some View {
        if exercise.movement == "cardio" {
            if cardioPerformances.isEmpty {
                EmptyCard(
                    icon: "chart.xyaxis.line",
                    title: L10n.text("No cardio chart data", "Geen cardiografiekdata"),
                    text: L10n.text("Distance and duration trends appear after completed cardio sessions.", "Afstand- en duurtrends verschijnen na voltooide cardiosessies.")
                )
            } else {
                Text(L10n.text("Distance", "Afstand"))
                    .font(.title3.bold())

                Chart {
                    ForEach(Array(cardioPerformances.enumerated()), id: \.offset) { _, p in
                        LineMark(
                            x: .value("Date", p.date),
                            y: .value("Distance", AppPreferences.displayDistance(p.distanceKm))
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(RFTheme.accent)

                        PointMark(
                            x: .value("Date", p.date),
                            y: .value("Distance", AppPreferences.displayDistance(p.distanceKm))
                        )
                        .foregroundStyle(RFTheme.accent)
                    }
                }
                .frame(height: 220)

                Text(L10n.text("Duration", "Duur"))
                    .font(.title3.bold())
                    .padding(.top, 8)

                Chart {
                    ForEach(Array(cardioPerformances.enumerated()), id: \.offset) { _, p in
                        BarMark(
                            x: .value("Date", p.date),
                            y: .value("Minutes", p.duration / 60.0)
                        )
                        .foregroundStyle(RFTheme.accent.gradient)
                    }
                }
                .frame(height: 220)
            }
        } else if performances.isEmpty {
            EmptyCard(
                icon: "chart.xyaxis.line",
                title: "No chart data",
                text: "Your weight progression will appear after completed sessions."
            )
        } else {
            Text("Best weight").font(.title3.bold())
            Chart {
                ForEach(Array(performances.enumerated()), id: \.offset) { _, p in
                    LineMark(
                        x: .value("Date", p.date),
                        y: .value("Weight", AppPreferences.displayWeight(p.weight))
                    )
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", p.date),
                        y: .value("Weight", AppPreferences.displayWeight(p.weight))
                    )
                }
            }
            .frame(height: 220)

            Text("Estimated 1RM").font(.title3.bold()).padding(.top, 8)
            Chart {
                ForEach(Array(performances.enumerated()), id: \.offset) { _, p in
                    AreaMark(
                        x: .value("Date", p.date),
                        y: .value("1RM", AppPreferences.displayWeight(p.oneRM))
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(RFTheme.accent.opacity(0.22))

                    LineMark(
                        x: .value("Date", p.date),
                        y: .value("1RM", AppPreferences.displayWeight(p.oneRM))
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(RFTheme.accent)
                }
            }
            .frame(height: 220)
        }
    }

    @ViewBuilder
    private var records: some View {
        VStack(spacing: 12) {
            HStack {
                Label(recordScopeLabel, systemImage: "scope")
                    .font(.caption.bold())
                    .foregroundStyle(RFTheme.muted)
                Spacer()
            }

            if exercise.movement == "cardio" {
                let longestDistance = cardioPerformances.map(\.distanceKm).max() ?? 0
                let longestDuration = cardioPerformances.map(\.duration).max() ?? 0
                let mostCalories = cardioPerformances.map(\.calories).max() ?? 0
                let fastestPace = cardioPerformances
                    .compactMap { performance -> Double? in
                        guard performance.distanceKm > 0, performance.duration > 0 else { return nil }
                        let displayedDistance = AppPreferences.displayDistance(performance.distanceKm)
                        guard displayedDistance > 0 else { return nil }
                        return performance.duration / displayedDistance
                    }
                    .min()

                RecordRow(
                    name: L10n.text("Longest distance", "Langste afstand"),
                    value: longestDistance > 0
                        ? "\(AppPreferences.displayDistance(longestDistance).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.distanceLabel)"
                        : "—"
                )

                RecordRow(
                    name: L10n.text("Longest duration", "Langste duur"),
                    value: longestDuration > 0 ? cardioDurationText(longestDuration) : "—"
                )

                RecordRow(
                    name: L10n.text("Fastest pace", "Snelste tempo"),
                    value: fastestPace.map { paceText(secondsPerUnit: $0) } ?? "—"
                )

                RecordRow(
                    name: L10n.text("Most calories", "Meeste calorieën"),
                    value: mostCalories > 0 ? "\(Int(mostCalories.rounded())) kcal" : "—"
                )
            } else {
                let bestWeight = performances.map(\.weight).max() ?? 0
                let bestRM = performances.map(\.oneRM).max() ?? 0
                let maxVolume = performances.map(\.volume).max() ?? 0

                RecordRow(
                    name: L10n.text("Best weight", "Beste gewicht"),
                    value: bestWeight > 0
                        ? "\(AppPreferences.displayWeight(bestWeight).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.weightLabel)"
                        : "—"
                )

                RecordRow(
                    name: "Estimated 1RM",
                    value: bestRM > 0
                        ? "\(AppPreferences.displayWeight(bestRM).formatted(.number.precision(.fractionLength(0...1)))) \(AppPreferences.weightLabel)"
                        : "—"
                )

                RecordRow(
                    name: L10n.text("Max session volume", "Max sessievolume"),
                    value: maxVolume > 0
                        ? "\(Int(AppPreferences.displayVolume(maxVolume))) \(AppPreferences.weightLabel)"
                        : "—"
                )
            }
        }
    }

    private func cardioPaceText(duration: Double, distanceKm: Double) -> String? {
        guard duration > 0, distanceKm > 0 else { return nil }
        let distance = AppPreferences.displayDistance(distanceKm)
        guard distance > 0 else { return nil }
        return paceText(secondsPerUnit: duration / distance)
    }

    private func paceText(secondsPerUnit: Double) -> String {
        let minutes = Int(secondsPerUnit) / 60
        let seconds = Int(secondsPerUnit) % 60
        return "\(minutes):\(String(format: "%02d", seconds))/\(AppPreferences.distanceLabel)"
    }

    private var recordScopeLabel: String {
        let period: String
        switch AppPreferences.prScope {
        case "year": period = L10n.text("This year", "Dit jaar")
        case "season": period = L10n.text("Current season", "Huidig seizoen")
        default: period = L10n.text("Lifetime", "Altijd")
        }

        if AppPreferences.separateRecordsByGym {
            return "\(period) • \(GymProfileStore.profile(id: AppPreferences.activeGymID).name)"
        }
        return period
    }
}

struct ExerciseDemoView: View {
    let exercise: ExerciseDefinition
    @StateObject private var model = ExerciseMediaModel()
    @State private var gender = "Male"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Group {
                if model.isLoading {
                    ZStack {
                        Color.black
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(RFTheme.accent)
                            Text("Loading HD exercise demo…")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.65))
                        }
                    }
                } else if let media = model.media,
                          let videoURL = selectedVideoURL(media) {
                    LoopingExerciseVideo(url: videoURL)
                } else if let media = model.media,
                          let imageURL = selectedThumbnailURL(media) {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            ZStack {
                                Color.black
                                image
                                    .resizable()
                                    .scaledToFit()
                            }
                        case .failure:
                            mediaFallback
                        default:
                            ZStack {
                                Color.black
                                ProgressView().tint(RFTheme.accent)
                            }
                        }
                    }
                } else {
                    mediaFallback
                }
            }
            .frame(height: 255)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.10)))

            if let media = model.media {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(media.matchedName)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                        if let sourceURL = media.sourceURL {
                            Link("Demo source: \(media.sourceName)", destination: sourceURL)
                                .font(.caption2)
                                .foregroundStyle(RFTheme.muted)
                        } else {
                            Text("Demo source: \(media.sourceName)")
                                .font(.caption2)
                                .foregroundStyle(RFTheme.muted)
                        }
                    }

                    Spacer()

                    if media.hasBothGenders {
                        Picker("Model", selection: $gender) {
                            Text("M").tag("Male")
                            Text("F").tag("Female")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 88)
                    }
                }
            }
        }
        .task(id: exercise.id) {
            await model.load(exercise: exercise)
        }
    }

    private func selectedVideoURL(_ media: ExerciseMedia) -> URL? {
        if gender == "Female" {
            return media.femaleVideoURL ?? media.maleVideoURL
        }
        return media.maleVideoURL ?? media.femaleVideoURL
    }

    private func selectedThumbnailURL(_ media: ExerciseMedia) -> URL? {
        if gender == "Female" {
            return media.femaleThumbnailURL ?? media.maleThumbnailURL
        }
        return media.maleThumbnailURL ?? media.femaleThumbnailURL
    }

    private var mediaFallback: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, RFTheme.surface],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 10) {
                Image(systemName: "play.slash.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(RFTheme.muted)
                Text("No HD demo found for this exercise")
                    .font(.headline)
                Text("Form instructions are available below.")
                    .font(.caption)
                    .foregroundStyle(RFTheme.muted)
            }
        }
    }
}

final class PlayerLayerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}

struct AVPlayerLayerContainer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.backgroundColor = .black
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        uiView.playerLayer.player = player
        uiView.playerLayer.videoGravity = .resizeAspect
    }
}

struct LoopingExerciseVideo: View {
    let url: URL
    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?
    @State private var isPlaying = true

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.black

            if let player {
                AVPlayerLayerContainer(player: player)
                    .ignoresSafeArea()
            } else {
                ProgressView()
                    .tint(RFTheme.accent)
            }

            Button {
                guard let player else { return }
                isPlaying.toggle()
                if isPlaying {
                    player.play()
                } else {
                    player.pause()
                }
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(.black.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(12)
        }
        .task(id: url) {
            player?.pause()
            player = nil
            looper = nil

            // Play the downloaded local MP4 on subsequent visits, including offline.
            // Streaming remains a fallback when storage is full or downloads fail.
            let playbackURL = (try? await ExerciseVideoCache.shared.localURL(for: url)) ?? url
            guard !Task.isCancelled else { return }

            let item = AVPlayerItem(url: playbackURL)
            let queue = AVQueuePlayer()
            queue.isMuted = true
            queue.actionAtItemEnd = .none

            let loop = AVPlayerLooper(player: queue, templateItem: item)
            player = queue
            looper = loop
            isPlaying = true
            queue.play()
        }
        .onDisappear {
            player?.pause()
        }
    }
}

struct FlowMuscleTags: View {
    let contributions: [MuscleContribution]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 8)], spacing: 8) {
            ForEach(contributions.sorted(by: { $0.weight > $1.weight })) { contribution in
                HStack(spacing: 5) {
                    Circle()
                        .fill(contribution.weight >= 0.8 ? RFTheme.accent : RFTheme.accent.opacity(0.45))
                        .frame(width: 7, height: 7)
                    Text(contribution.muscle)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(RFTheme.raised)
                .clipShape(Capsule())
            }
        }
    }
}

struct MuscleVolumeDashboard: View {
    let entries: [MuscleVolumeEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.text("Weekly muscle volume", "Wekelijks spiervolume"))
                    .font(.title3.bold())
                Spacer()
                Text(L10n.text("effective sets", "effectieve sets"))
                    .font(.caption)
                    .foregroundStyle(RFTheme.muted)
            }

            if entries.isEmpty {
                Text(L10n.text(
                    "Complete working sets this week to build the dashboard.",
                    "Voltooi deze week werksets om het dashboard op te bouwen."
                ))
                .font(.caption)
                .foregroundStyle(RFTheme.muted)
            } else {
                Chart(Array(entries.prefix(10))) { entry in
                    BarMark(
                        x: .value("Sets", entry.sets),
                        y: .value("Muscle", entry.muscle)
                    )
                    .foregroundStyle(RFTheme.accent)
                    .cornerRadius(4)
                    .annotation(position: .trailing) {
                        Text(entry.sets.formatted(.number.precision(.fractionLength(0...1))))
                            .font(.caption2.bold())
                            .foregroundStyle(RFTheme.muted)
                    }
                }
                .frame(height: CGFloat(max(190, min(360, entries.prefix(10).count * 31))))
                .chartXAxis {
                    AxisMarks(position: .bottom)
                }
            }

            Text(L10n.text(
                "Primary muscles count as 1 set; meaningful secondary involvement counts fractionally.",
                "Primaire spieren tellen als 1 set; relevante secundaire belasting telt gedeeltelijk mee."
            ))
            .font(.caption2)
            .foregroundStyle(RFTheme.muted)
        }
        .padding()
        .background(RFTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct MuscleRecoveryDashboard: View {
    let entries: [MuscleRecoveryEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.text("Muscle recovery", "Spierherstel"))
                    .font(.title3.bold())
                Spacer()
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(RFTheme.accent)
            }

            if entries.isEmpty {
                Text(L10n.text(
                    "Recovery estimates appear after completed workouts.",
                    "Herstelschattingen verschijnen na voltooide trainingen."
                ))
                .font(.caption)
                .foregroundStyle(RFTheme.muted)
            } else {
                ForEach(Array(entries.prefix(10))) { entry in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(entry.muscle)
                                .font(.subheadline.bold())
                            Spacer()
                            Text("\(Int(entry.recovery * 100))% • \(entry.status)")
                                .font(.caption.bold())
                                .foregroundStyle(recoveryColor(entry.recovery))
                        }

                        ProgressView(value: entry.recovery)
                            .tint(recoveryColor(entry.recovery))

                        if let last = entry.lastTrained {
                            Text(
                                "\(L10n.text("Last trained", "Laatst getraind")) \(last.formatted(.relative(presentation: .named))) • \(entry.recentSets.formatted(.number.precision(.fractionLength(0...1)))) \(L10n.text("recent sets", "recente sets"))"
                            )
                            .font(.caption2)
                            .foregroundStyle(RFTheme.muted)
                        }
                    }
                }
            }

            Text(L10n.text(
                "Recovery is a training-load estimate based on recent sets and time since training, not a medical measurement.",
                "Herstel is een trainingsbelastingsschatting op basis van recente sets en tijd sinds training, geen medische meting."
            ))
            .font(.caption2)
            .foregroundStyle(RFTheme.muted)
        }
        .padding()
        .background(RFTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func recoveryColor(_ recovery: Double) -> Color {
        if recovery >= 0.85 { return RFTheme.success }
        if recovery >= 0.55 { return RFTheme.accent }
        return .orange
    }
}

struct MuscleHeatMapView: View {
    let entries: [MuscleVolumeEntry]
    let title: String

    private var intensity: [String: Double] {
        let maxValue = max(entries.map(\.sets).max() ?? 1, 1)
        return Dictionary(uniqueKeysWithValues: entries.map {
            ($0.muscle, min(1, $0.sets / maxValue))
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())

            if entries.isEmpty {
                Text(L10n.text("No muscle data yet.", "Nog geen spierdata."))
                    .foregroundStyle(RFTheme.muted)
            } else {
                VStack(spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        BodyMuscleFigure(side: .front, intensity: intensity)
                        BodyMuscleFigure(side: .back, intensity: intensity)
                    }
                    .frame(maxWidth: 420)

                    MuscleHeatLegend()
                        .frame(maxWidth: 220)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 115), spacing: 8)], spacing: 8) {
                    ForEach(Array(entries.prefix(8))) { entry in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(heatColor(intensity[entry.muscle] ?? 0))
                                .frame(width: 8, height: 8)
                            Text(entry.muscle)
                                .font(.caption2)
                                .lineLimit(1)
                            Spacer()
                            Text(entry.sets.formatted(.number.precision(.fractionLength(0...1))))
                                .font(.caption2.bold())
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(RFTheme.raised)
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding()
        .background(RFTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func heatColor(_ value: Double) -> Color {
        MuscleHeatPalette.color(for: value)
    }
}


// MARK: - Profile

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]
    @State private var editing = false
    @State private var showMeasurementEditor = false
    @AppStorage("activeGymID") private var activeGymID = GymProfileStore.defaultID
    @AppStorage("gymRevision") private var gymRevision = 0
    @AppStorage("separateRecordsByGym") private var separateRecordsByGym = true

    private var profile: UserProfile? { profiles.first }
    private var completed: [WorkoutSession] { sessions.filter { $0.endedAt != nil } }

    private var analyticsSessions: [WorkoutSession] {
        guard separateRecordsByGym else { return completed }
        return completed.filter { GymProfileStore.sessionGymID($0) == activeGymID }
    }

    private var weeklyMuscleVolume: [MuscleVolumeEntry] {
        MuscleAnalytics.weeklyVolume(
            sessions: sessions,
            gymID: separateRecordsByGym ? activeGymID : nil
        )
    }

    private var recoveryData: [MuscleRecoveryEntry] {
        MuscleAnalytics.recovery(
            sessions: sessions,
            gymID: separateRecordsByGym ? activeGymID : nil
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let profile {
                    profileDashboard(profile)
                        .padding()
                }
            }
            .background(RFTheme.bg)
            .navigationTitle(L10n.profile)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(L10n.settings)
                }
            }
            .sheet(isPresented: $editing) {
                if let profile {
                    EditProfileView(profile: profile)
                }
            }
            .sheet(isPresented: $showMeasurementEditor) {
                if let profile {
                    BodyMeasurementEditorView(profile: profile)
                }
            }
        }
    }

    @ViewBuilder
    private func profileDashboard(_ profile: UserProfile) -> some View {
        VStack(spacing: 18) {
            ProfileIdentityHeader(
                profile: profile,
                gymName: separateRecordsByGym
                    ? GymProfileStore.profile(id: activeGymID).name
                    : L10n.text("All gyms", "Alle gyms"),
                revision: gymRevision
            )

            ForgeMomentumCard(sessions: analyticsSessions)

            WorkoutActivityHeatmap(sessions: analyticsSessions)

            MuscleIntelligencePanel(sessions: sessions)

            ProfileStatsGrid(
                workoutCount: completed.count,
                totalVolume: completed.reduce(0) { $0 + $1.totalVolume },
                workoutsThisWeek: workoutsThisWeek,
                streak: currentStreak,
                completedSets: totalCompletedSets,
                averageDuration: averageDuration
            )

            ProfileActivityCard(activityData: activityData)

            BodyMeasurementsCard(
                measurements: measurements,
                onAdd: { showMeasurementEditor = true }
            )

            MuscleVolumeDashboard(entries: weeklyMuscleVolume)
            MuscleRecoveryDashboard(entries: recoveryData)

            Button {
                editing = true
            } label: {
                Label(L10n.text("Edit Local Profile", "Lokaal profiel bewerken"), systemImage: "pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var workoutsThisWeek: Int {
        let calendar = Calendar.current
        guard let start = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return 0 }
        return analyticsSessions.filter { $0.startedAt >= start }.count
    }

    private var totalCompletedSets: Int {
        analyticsSessions.reduce(0) { partial, session in
            partial + session.exercises.flatMap(\.sets).filter(\.completed).count
        }
    }

    private var averageDuration: String {
        guard !analyticsSessions.isEmpty else { return "00:00" }
        let average = analyticsSessions.reduce(0.0) { $0 + $1.duration } / Double(analyticsSessions.count)
        return durationString(average)
    }

    private var currentStreak: Int {
        let calendar = Calendar.current
        let weeks = Set(analyticsSessions.compactMap {
            calendar.dateInterval(of: .weekOfYear, for: $0.startedAt)?.start
        })

        guard let currentWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return 0 }

        var count = 0
        var cursor = currentWeek
        while weeks.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    private var activityData: [(date: Date, count: Int)] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: cal.date(byAdding: .day, value: -27, to: .now)!)
        return (0..<28).map { i in
            let date = cal.date(byAdding: .day, value: i, to: start)!
            let count = completed.filter { cal.isDate($0.startedAt, inSameDayAs: date) }.count
            return (date, count)
        }
    }
}

struct BodyMeasurementsCard: View {
    let measurements: [BodyMeasurement]
    let onAdd: () -> Void

    private var chartData: [BodyMeasurement] {
        Array(measurements.prefix(12).reversed())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.text("Body measurements", "Lichaamsmetingen"))
                        .font(.title3.bold())
                    Text(L10n.text("Track trends over time", "Volg trends door de tijd"))
                        .font(.caption)
                        .foregroundStyle(RFTheme.muted)
                }

                Spacer()

                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.headline.bold())
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.borderedProminent)
                .tint(RFTheme.accent)
            }

            if let latest = measurements.first {
                HStack(spacing: 8) {
                    measurementPill(
                        title: L10n.text("Weight", "Gewicht"),
                        value: latest.bodyWeightKg > 0
                            ? "\(AppPreferences.displayWeight(latest.bodyWeightKg).formatted(.number.precision(.fractionLength(0...1)))) \(AppPreferences.weightLabel)"
                            : "—"
                    )

                    measurementPill(
                        title: L10n.text("Body fat", "Vetpercentage"),
                        value: latest.bodyFatPercent.map {
                            "\($0.formatted(.number.precision(.fractionLength(0...1))))%"
                        } ?? "—"
                    )

                    measurementPill(
                        title: L10n.text("Waist", "Taille"),
                        value: lengthText(latest.waistCm)
                    )
                }

                if chartData.count > 1 {
                    Chart(chartData) { item in
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("Weight", AppPreferences.displayWeight(item.bodyWeightKg))
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(RFTheme.accent)

                        PointMark(
                            x: .value("Date", item.date),
                            y: .value("Weight", AppPreferences.displayWeight(item.bodyWeightKg))
                        )
                        .foregroundStyle(RFTheme.accent)
                    }
                    .frame(height: 150)
                }

                if let chest = latest.chestCm,
                   let arm = latest.armCm,
                   let thigh = latest.thighCm {
                    HStack(spacing: 10) {
                        Label("\(L10n.text("Chest", "Borst")) \(lengthText(chest))", systemImage: "figure.arms.open")
                        Label("\(L10n.text("Arm", "Arm")) \(lengthText(arm))", systemImage: "dumbbell.fill")
                        Label("\(L10n.text("Thigh", "Bovenbeen")) \(lengthText(thigh))", systemImage: "figure.walk")
                    }
                    .font(.caption2.bold())
                    .foregroundStyle(RFTheme.muted)
                }
            } else {
                Text(L10n.text(
                    "Add your first measurement to track weight, body fat and circumferences.",
                    "Voeg je eerste meting toe om gewicht, vetpercentage en omtrekken te volgen."
                ))
                .font(.caption)
                .foregroundStyle(RFTheme.muted)
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(RFTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(RFTheme.cardBorder)
        )
    }

    private func measurementPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(RFTheme.muted)
            Text(value)
                .font(.subheadline.bold())
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(RFTheme.field)
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }

    private func lengthText(_ cm: Double?) -> String {
        guard let cm, cm > 0 else { return "—" }
        return "\(AppPreferences.displayHeight(cm).formatted(.number.precision(.fractionLength(0...1)))) \(AppPreferences.heightLabel)"
    }

    private func lengthText(_ cm: Double) -> String {
        "\(AppPreferences.displayHeight(cm).formatted(.number.precision(.fractionLength(0...1)))) \(AppPreferences.heightLabel)"
    }
}

struct BodyMeasurementEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var profile: UserProfile

    @State private var date = Date.now
    @State private var weight: Double
    @State private var bodyFat: Double = 0
    @State private var waist: Double = 0
    @State private var chest: Double = 0
    @State private var arm: Double = 0
    @State private var thigh: Double = 0
    @State private var hip: Double = 0

    init(profile: UserProfile) {
        self.profile = profile
        _weight = State(initialValue: AppPreferences.displayWeight(profile.bodyWeightKg))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.text("Measurement", "Meting")) {
                    DatePicker(
                        L10n.text("Date", "Datum"),
                        selection: $date,
                        displayedComponents: .date
                    )

                    measurementField(
                        L10n.text("Body weight", "Lichaamsgewicht"),
                        unit: AppPreferences.weightLabel,
                        value: $weight
                    )

                    measurementField(
                        L10n.text("Body fat", "Vetpercentage"),
                        unit: "%",
                        value: $bodyFat
                    )
                }

                Section(L10n.text("Circumferences", "Omtrekken")) {
                    measurementField(L10n.text("Waist", "Taille"), unit: AppPreferences.heightLabel, value: $waist)
                    measurementField(L10n.text("Chest", "Borst"), unit: AppPreferences.heightLabel, value: $chest)
                    measurementField(L10n.text("Arm", "Arm"), unit: AppPreferences.heightLabel, value: $arm)
                    measurementField(L10n.text("Thigh", "Bovenbeen"), unit: AppPreferences.heightLabel, value: $thigh)
                    measurementField(L10n.text("Hips", "Heupen"), unit: AppPreferences.heightLabel, value: $hip)
                }
            }
            .navigationTitle(L10n.text("Add Measurement", "Meting toevoegen"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("Cancel", "Annuleren")) { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("Save", "Opslaan")) {
                        save()
                    }
                    .bold()
                }
            }
        }
    }

    @ViewBuilder
    private func measurementField(_ title: String, unit: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            DoneNumberField(
                value: value,
                integerOnly: false,
                placeholder: "0"
            )
            .frame(width: 95, height: 38)

            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)
        }
    }

    private func save() {
        let storedWeight = AppPreferences.storedWeightKg(weight)
        let record = BodyMeasurement(
            date: date,
            bodyWeightKg: storedWeight,
            bodyFatPercent: bodyFat > 0 ? bodyFat : nil,
            waistCm: storedLength(waist),
            chestCm: storedLength(chest),
            armCm: storedLength(arm),
            thighCm: storedLength(thigh),
            hipCm: storedLength(hip)
        )

        context.insert(record)

        if storedWeight > 0 {
            profile.bodyWeightKg = storedWeight
        }

        try? context.save()
        Haptics.success()
        dismiss()
    }

    private func storedLength(_ displayed: Double) -> Double? {
        guard displayed > 0 else { return nil }
        return AppPreferences.storedHeightCm(displayed)
    }
}

struct ProfileIdentityHeader: View {
    let profile: UserProfile
    let gymName: String
    let revision: Int

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [RFTheme.accent.opacity(0.28), RFTheme.accent.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)

                Text(String(profile.displayName.prefix(1)).uppercased())
                    .font(.largeTitle.bold())
                    .foregroundStyle(RFTheme.accent)
            }

            Text(profile.displayName)
                .font(.title.bold())

            Text(profile.bio)
                .foregroundStyle(RFTheme.muted)

            Label(gymName, systemImage: "mappin.and.ellipse")
                .font(.caption.bold())
                .foregroundStyle(RFTheme.accent)
                .id(revision)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RFTheme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(RFTheme.cardBorder)
        )
    }
}

struct ProfileStatsGrid: View {
    let workoutCount: Int
    let totalVolume: Double
    let workoutsThisWeek: Int
    let streak: Int
    let completedSets: Int
    let averageDuration: String

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                StatCard(
                    title: L10n.text("Workouts", "Trainingen"),
                    value: "\(workoutCount)",
                    icon: "dumbbell.fill"
                )
                StatCard(
                    title: L10n.text("Total Volume", "Totaal volume"),
                    value: "\(Int(AppPreferences.displayVolume(totalVolume))) \(AppPreferences.weightLabel)",
                    icon: "chart.bar.fill"
                )
            }

            HStack {
                StatCard(
                    title: L10n.text("This week", "Deze week"),
                    value: "\(workoutsThisWeek)",
                    icon: "calendar"
                )
                StatCard(
                    title: L10n.text("Current streak", "Huidige reeks"),
                    value: "\(streak) \(L10n.text("wk", "wk"))",
                    icon: "flame.fill"
                )
            }

            HStack {
                StatCard(
                    title: L10n.text("Completed sets", "Voltooide sets"),
                    value: "\(completedSets)",
                    icon: "checkmark.circle.fill"
                )
                StatCard(
                    title: L10n.text("Avg duration", "Gem. duur"),
                    value: averageDuration,
                    icon: "timer"
                )
            }
        }
    }
}

struct ProfileActivityCard: View {
    let activityData: [(date: Date, count: Int)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("Training activity", "Trainingsactiviteit"))
                .font(.title3.bold())

            Chart(activityData, id: \.date) { item in
                BarMark(
                    x: .value("Day", item.date, unit: .day),
                    y: .value("Workouts", item.count)
                )
                .foregroundStyle(RFTheme.accent.gradient)
                .cornerRadius(4)
            }
            .frame(height: 190)
            .chartYAxis(.hidden)
        }
        .padding()
        .background(RFTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(RFTheme.cardBorder)
        )
    }
}

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var profile: UserProfile

    var body: some View {
        NavigationStack {
            Form {
                TextField(L10n.text("Display name", "Weergavenaam"), text: $profile.displayName)
                TextField(L10n.text("Bio", "Bio"), text: $profile.bio, axis: .vertical)

                DoneNumberField(
                    value: Binding(
                        get: { AppPreferences.displayWeight(profile.bodyWeightKg) },
                        set: { profile.bodyWeightKg = AppPreferences.storedWeightKg($0) }
                    ),
                    integerOnly: false,
                    placeholder: L10n.text("Body weight", "Lichaamsgewicht")
                )
                .frame(height: 44)
                .overlay(alignment: .trailing) {
                    Text(AppPreferences.weightLabel)
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 10)
                }

                DoneNumberField(
                    value: Binding(
                        get: { AppPreferences.displayHeight(profile.heightCm) },
                        set: { profile.heightCm = AppPreferences.storedHeightCm($0) }
                    ),
                    integerOnly: false,
                    placeholder: L10n.text("Height", "Lengte")
                )
                .frame(height: 44)
                .overlay(alignment: .trailing) {
                    Text(AppPreferences.heightLabel)
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 10)
                }
            }
            .navigationTitle(L10n.profile)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("Save", "Opslaan")) {
                        try? context.save()
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}

// MARK: - Settings

struct ThemeSelector: View {
    @Binding var selection: String

    private let themes: [(id: String, name: String, bg: Color, card: Color, accent: Color)] = [
        ("forge", "Forge Blue", Color(red: 0.055, green: 0.070, blue: 0.078), Color(red: 0.105, green: 0.135, blue: 0.150), Color(red: 0.18, green: 0.63, blue: 1.0)),
        ("oled", "OLED", .black, Color(red: 0.055, green: 0.055, blue: 0.060), Color(red: 0.18, green: 0.63, blue: 1.0)),
        ("graphite", "Graphite", Color(red: 0.075, green: 0.075, blue: 0.082), Color(red: 0.125, green: 0.125, blue: 0.135), Color(red: 0.18, green: 0.63, blue: 1.0)),
        ("navy", "Navy", Color(red: 0.025, green: 0.055, blue: 0.095), Color(red: 0.070, green: 0.105, blue: 0.155), Color(red: 0.18, green: 0.63, blue: 1.0)),
        ("emerald", "Emerald", Color(red: 0.025, green: 0.080, blue: 0.065), Color(red: 0.055, green: 0.145, blue: 0.110), Color(red: 0.10, green: 0.78, blue: 0.48)),
        ("orange", "Orange", Color(red: 0.105, green: 0.055, blue: 0.025), Color(red: 0.175, green: 0.095, blue: 0.045), Color(red: 1.0, green: 0.48, blue: 0.12)),
        ("purple", "Purple", Color(red: 0.070, green: 0.040, blue: 0.105), Color(red: 0.125, green: 0.075, blue: 0.180), Color(red: 0.63, green: 0.43, blue: 1.0)),
        ("midnight", "Midnight", Color(red: 0.012, green: 0.020, blue: 0.055), Color(red: 0.038, green: 0.055, blue: 0.115), Color(red: 0.40, green: 0.56, blue: 1.0)),
        ("cyan", "Arctic Cyan", Color(red: 0.018, green: 0.070, blue: 0.082), Color(red: 0.040, green: 0.130, blue: 0.148), Color(red: 0.08, green: 0.82, blue: 0.94)),
        ("teal", "Deep Teal", Color(red: 0.018, green: 0.065, blue: 0.060), Color(red: 0.038, green: 0.125, blue: 0.110), Color(red: 0.08, green: 0.80, blue: 0.68)),
        ("crimson", "Crimson", Color(red: 0.085, green: 0.022, blue: 0.032), Color(red: 0.155, green: 0.050, blue: 0.065), Color(red: 1.0, green: 0.24, blue: 0.36)),
        ("rose", "Rose", Color(red: 0.082, green: 0.030, blue: 0.064), Color(red: 0.150, green: 0.060, blue: 0.120), Color(red: 1.0, green: 0.36, blue: 0.68)),
        ("gold", "Gold", Color(red: 0.095, green: 0.070, blue: 0.020), Color(red: 0.160, green: 0.115, blue: 0.035), Color(red: 1.0, green: 0.72, blue: 0.18)),
        ("forest", "Forest", Color(red: 0.030, green: 0.060, blue: 0.035), Color(red: 0.060, green: 0.120, blue: 0.070), Color(red: 0.32, green: 0.78, blue: 0.38)),
        ("slate", "Slate", Color(red: 0.045, green: 0.052, blue: 0.065), Color(red: 0.095, green: 0.110, blue: 0.135), Color(red: 0.64, green: 0.72, blue: 0.84)),
        ("neon", "Neon", Color(red: 0.018, green: 0.028, blue: 0.024), Color(red: 0.035, green: 0.085, blue: 0.060), Color(red: 0.30, green: 1.0, blue: 0.54))
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.text("Theme", "Thema"))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(themes, id: \.id) { theme in
                        Button {
                            selection = theme.id
                            Haptics.light()
                        } label: {
                            VStack(spacing: 7) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(theme.bg)
                                        .frame(width: 72, height: 48)

                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(theme.card)
                                        .frame(width: 48, height: 28)

                                    Circle()
                                        .fill(theme.accent)
                                        .frame(width: 13, height: 13)
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(selection == theme.id ? theme.accent : Color.secondary.opacity(0.25), lineWidth: selection == theme.id ? 2.5 : 1)
                                )

                                Text(theme.name)
                                    .font(.caption2)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct PlateCalculatorView: View {
    @State private var targetWeight: Double = AppPreferences.isImperial ? 225 : 100
    @State private var barWeight: Double = AppPreferences.isImperial ? 45 : 20

    private var plates: [Double] {
        AppPreferences.isImperial
            ? [45, 35, 25, 10, 5, 2.5]
            : [25, 20, 15, 10, 5, 2.5, 1.25]
    }

    private var calculation: [(Double, Int)] {
        var remaining = max(0, (targetWeight - barWeight) / 2)
        var result: [(Double, Int)] = []

        for plate in plates {
            let count = Int((remaining + 0.0001) / plate)
            if count > 0 {
                result.append((plate, count))
                remaining -= Double(count) * plate
            }
        }
        return result
    }

    private var actualWeight: Double {
        barWeight + calculation.reduce(0) { $0 + ($1.0 * Double($1.1) * 2) }
    }

    var body: some View {
        Form {
            Section(L10n.text("Target", "Doel")) {
                HStack {
                    Text(L10n.text("Target weight", "Doelgewicht"))
                    Spacer()
                    DoneNumberField(value: $targetWeight, integerOnly: false, placeholder: "0")
                        .frame(width: 100, height: 40)
                    Text(AppPreferences.weightLabel)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text(L10n.text("Bar weight", "Stanggewicht"))
                    Spacer()
                    DoneNumberField(value: $barWeight, integerOnly: false, placeholder: "0")
                        .frame(width: 100, height: 40)
                    Text(AppPreferences.weightLabel)
                        .foregroundStyle(.secondary)
                }
            }

            Section(L10n.text("Load each side", "Belading per kant")) {
                if targetWeight <= barWeight {
                    Text(L10n.text("No plates required.", "Geen schijven nodig."))
                        .foregroundStyle(.secondary)
                } else if calculation.isEmpty {
                    Text(L10n.text("Target cannot be matched with the standard plate set.", "Doel kan niet met de standaard schijven worden gemaakt."))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(calculation.enumerated()), id: \.offset) { _, item in
                        HStack {
                            Image(systemName: "circle.fill")
                                .foregroundStyle(RFTheme.accent)
                            Text("\(item.0.formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.weightLabel)")
                            Spacer()
                            Text("× \(item.1)")
                                .bold()
                        }
                    }

                    LabeledContent(
                        L10n.text("Actual loaded weight", "Werkelijk geladen gewicht"),
                        value: "\(actualWeight.formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.weightLabel)"
                    )
                }
            }

            Section {
                Text(L10n.text(
                    "The calculator assumes the same plates are loaded on both sides of the bar.",
                    "De calculator gaat uit van dezelfde schijven aan beide kanten van de stang."
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(L10n.text("Plate Calculator", "Schijvencalculator"))
    }
}

struct GymManagerView: View {
    @Binding var activeGymID: String
    @State private var gyms = GymProfileStore.load()
    @State private var editingGym: GymProfile?
    @State private var showAdd = false

    var body: some View {
        List {
            Section {
                ForEach(gyms) { gym in
                    Button {
                        activeGymID = gym.id
                        Haptics.light()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: gym.id == activeGymID ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(gym.id == activeGymID ? RFTheme.accent : RFTheme.muted)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(gym.name)
                                    .foregroundStyle(.primary)
                                    .font(.headline)
                                if !gym.note.isEmpty {
                                    Text(gym.note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Button {
                                editingGym = gym
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .swipeActions {
                        if gym.id != GymProfileStore.defaultID {
                            Button(role: .destructive) {
                                GymProfileStore.delete(id: gym.id)
                                gyms = GymProfileStore.load()
                                if activeGymID == gym.id {
                                    activeGymID = GymProfileStore.defaultID
                                }
                            } label: {
                                Label(L10n.text("Delete", "Verwijder"), systemImage: "trash")
                            }
                        }
                    }
                }
            } footer: {
                Text(L10n.text(
                    "The gym attached to a workout determines which previous weights and PRs are shown when gym-specific records are enabled.",
                    "De gym van een training bepaalt welke vorige gewichten en PR's worden getoond wanneer records per gym zijn ingeschakeld."
                ))
            }
        }
        .navigationTitle(L10n.text("Gym Profiles", "Gymprofielen"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $editingGym, onDismiss: reload) { gym in
            GymEditView(gym: gym) { updated in
                GymProfileStore.update(updated)
                reload()
            }
        }
        .sheet(isPresented: $showAdd, onDismiss: reload) {
            GymEditView(
                gym: GymProfile(id: "", name: "", note: ""),
                isNew: true
            ) { newGym in
                let created = GymProfileStore.add(name: newGym.name, note: newGym.note)
                activeGymID = created.id
                reload()
            }
        }
    }

    private func reload() {
        gyms = GymProfileStore.load()
    }
}

struct GymEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var gym: GymProfile
    let isNew: Bool
    let onSave: (GymProfile) -> Void

    init(gym: GymProfile, isNew: Bool = false, onSave: @escaping (GymProfile) -> Void) {
        _gym = State(initialValue: gym)
        self.isNew = isNew
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.text("Gym", "Gym")) {
                    TextField(L10n.text("Gym name", "Naam gym"), text: $gym.name)
                    TextField(
                        L10n.text("Optional note / equipment", "Optionele notitie / apparatuur"),
                        text: $gym.note,
                        axis: .vertical
                    )
                    .lineLimit(2...5)
                }
            }
            .navigationTitle(isNew ? L10n.text("New Gym", "Nieuwe gym") : L10n.text("Edit Gym", "Gym bewerken"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("Cancel", "Annuleren")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("Save", "Opslaan")) {
                        onSave(gym)
                        dismiss()
                    }
                    .bold()
                    .disabled(gym.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct StrongCSVDocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let csvType = UTType(filenameExtension: "csv") ?? .commaSeparatedText
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [csvType, .commaSeparatedText, .plainText, .data],
            asCopy: true
        )
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                onCancel()
                return
            }
            onPick(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var exportSessions: [WorkoutSession]
    @Query(sort: \WorkoutTemplate.createdAt, order: .reverse) private var exportTemplates: [WorkoutTemplate]
    @Query private var exportProfiles: [UserProfile]
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var exportBodyMeasurements: [BodyMeasurement]
    @ObservedObject private var heartRateMonitor = HeartRateMonitor.shared

    @AppStorage("appLanguage") private var appLanguage = "en"
    @AppStorage("measurementSystem") private var measurementSystem = "metric"
    @AppStorage("appearance") private var appearance = "dark"
    @AppStorage("themePreset") private var themePreset = "forge"
    @AppStorage("textSize") private var textSize = "standard"
    @AppStorage("layoutStyle") private var layoutStyle = "balanced"
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("showPreviousSets") private var showPreviousSets = true
    @AppStorage("keepScreenAwake") private var keepScreenAwake = true
    @AppStorage("defaultSets") private var defaultSets = 3
    @AppStorage("defaultRestSeconds") private var defaultRestSeconds = 90
    @AppStorage("autoRestTimer") private var autoRestTimer = true
    @AppStorage("autoCollapseCompleted") private var autoCollapseCompleted = true
    @AppStorage("restNotifications") private var restNotifications = true
    @AppStorage("countdownHaptics") private var countdownHaptics = true
    @AppStorage("compactWorkoutMode") private var compactWorkoutMode = false
    @AppStorage("highContrastWorkout") private var highContrastWorkout = false
    @AppStorage("progressionRule") private var progressionRule = "double"
    @AppStorage("progressionStepKg") private var progressionStepKg = 2.5
    @AppStorage("activeGymID") private var activeGymID = GymProfileStore.defaultID
    @AppStorage("separateRecordsByGym") private var separateRecordsByGym = true
    @AppStorage("prScope") private var prScope = "lifetime"
    @AppStorage("seasonStartDate") private var seasonStartDate = 0.0
    @AppStorage("gymRevision") private var gymRevision = 0

    @State private var showBackupExporter = false
    @State private var showBackupImporter = false
    @State private var showStrongImporter = false
    @State private var backupDocument = RepForgeBackupDocument()
    @State private var backupMessage: String?
    @State private var strongImportMessage: String?

    private var appVersionDisplay: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2.9"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "18"
        return "\(version) (\(build))"
    }

    private var workoutCSV: String {
        var rows: [String] = [
            "date,workout,exercise,set,type,weight_kg,reps,duration_seconds,distance_km,incline_percent,calories,avg_hr,rpe,rir,note"
        ]

        for session in exportSessions where session.endedAt != nil {
            let dateValue = csv(session.startedAt.ISO8601Format())
            let workoutValue = csv(session.title)

            for log in session.exercises.sorted(by: { $0.order < $1.order }) {
                let exerciseName = ExerciseCatalog.find(log.exerciseID)?.name ?? log.exerciseID
                let exerciseValue = csv(exerciseName)

                for set in log.sets.sorted(by: { $0.order < $1.order }) where set.completed {
                    var fields: [String] = []
                    fields.append(dateValue)
                    fields.append(workoutValue)
                    fields.append(exerciseValue)
                    fields.append(String(set.order + 1))
                    fields.append(csv(set.setType))
                    fields.append(csvNumber(set.weightKg))
                    fields.append(String(set.reps))
                    fields.append(optionalCSVNumber(set.durationSeconds))
                    fields.append(optionalCSVNumber(set.distanceKm))
                    fields.append(optionalCSVNumber(set.inclinePercent))
                    fields.append(optionalCSVNumber(set.calories))
                    fields.append(set.averageHeartRate.map(String.init) ?? "")
                    fields.append(optionalCSVNumber(set.rpe))
                    fields.append(set.rir.map(String.init) ?? "")
                    fields.append(csv(set.note ?? ""))
                    rows.append(fields.joined(separator: ","))
                }
            }
        }

        return rows.joined(separator: "\n")
    }

    private func csvNumber(_ value: Double) -> String {
        value.formatted(
            .number
                .locale(Locale(identifier: "en_US_POSIX"))
                .precision(.fractionLength(0...3))
        )
    }

    private func optionalCSVNumber(_ value: Double?) -> String {
        guard let value else { return "" }
        return value.formatted(
            .number
                .locale(Locale(identifier: "en_US_POSIX"))
                .precision(.fractionLength(0...3))
        )
    }

    private var templateBackupText: String {
        exportTemplates.map { template in
            let exercises = template.plannedExercises?.map {
                "\($0.name) | \($0.sets) × \($0.reps)\($0.note.map { " | \($0)" } ?? "")"
            } ?? template.exerciseIDs.compactMap { ExerciseCatalog.find($0)?.name }
            return "# \(template.name)\n" + exercises.joined(separator: "\n")
        }
        .joined(separator: "\n\n")
    }

    private func csv(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.text("Units & region", "Eenheden & regio")) {
                    Picker(L10n.text("Language", "Taal"), selection: $appLanguage) {
                        Text("English").tag("en")
                        Text("Nederlands").tag("nl")
                        Text("Español").tag("es")
                        Text("Deutsch").tag("de")
                        Text("Français").tag("fr")
                    }

                    Picker(L10n.text("Measurement system", "Meetsysteem"), selection: $measurementSystem) {
                        Text(L10n.text("Metric (kg, cm, km)", "Metrisch (kg, cm, km)")).tag("metric")
                        Text(L10n.text("Imperial (lb, in, mi)", "Imperiaal (lb, in, mi)")).tag("imperial")
                    }

                    LabeledContent(L10n.text("Weight", "Gewicht"), value: AppPreferences.weightLabel)
                    LabeledContent(L10n.text("Height", "Lengte"), value: AppPreferences.heightLabel)
                    LabeledContent(L10n.text("Distance", "Afstand"), value: AppPreferences.distanceLabel)
                }

                Section(L10n.text("Appearance", "Weergave")) {
                    Picker(L10n.text("Mode", "Modus"), selection: $appearance) {
                        Text(L10n.text("System", "Systeem")).tag("system")
                        Text(L10n.text("Dark", "Donker")).tag("dark")
                        Text(L10n.text("Light", "Licht")).tag("light")
                    }

                    ThemeSelector(selection: $themePreset)

                    Picker(L10n.text("Layout", "Indeling"), selection: $layoutStyle) {
                        Text(L10n.text("Balanced cards", "Gebalanceerde kaarten")).tag("balanced")
                        Text(L10n.text("Compact lists", "Compacte lijsten")).tag("compact")
                        Text(L10n.text("Focused sections", "Focus op secties")).tag("focused")
                    }
                    Text(L10n.text(
                        "Changes spacing, card shapes, template layout and visual hierarchy—not just colors.",
                        "Verandert afstanden, kaartvormen, template-indeling en visuele hiërarchie, niet alleen kleuren."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Picker(L10n.text("Text size", "Tekstgrootte"), selection: $textSize) {
                        Text(L10n.text("Compact", "Compact")).tag("compact")
                        Text(L10n.text("Standard", "Standaard")).tag("standard")
                        Text(L10n.text("Large", "Groot")).tag("large")
                        Text(L10n.text("Extra large", "Extra groot")).tag("xlarge")
                    }
                }

                Section(L10n.text("Gym & records", "Gym & records")) {
                    NavigationLink {
                        GymManagerView(activeGymID: $activeGymID)
                    } label: {
                        HStack {
                            Label(L10n.text("Gym profiles", "Gymprofielen"), systemImage: "building.2.fill")
                            Spacer()
                            Text(GymProfileStore.profile(id: activeGymID).name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .id(gymRevision)
                    }

                    Toggle(
                        L10n.text("Separate records by gym", "Records per gym scheiden"),
                        isOn: $separateRecordsByGym
                    )

                    Picker(L10n.text("Personal-record period", "Periode persoonlijke records"), selection: $prScope) {
                        Text(L10n.text("Lifetime", "Altijd")).tag("lifetime")
                        Text(L10n.text("This year", "Dit jaar")).tag("year")
                        Text(L10n.text("Current season", "Huidig seizoen")).tag("season")
                    }

                    if prScope == "season" {
                        DatePicker(
                            L10n.text("Season starts", "Seizoen start"),
                            selection: Binding(
                                get: {
                                    seasonStartDate > 0
                                        ? Date(timeIntervalSince1970: seasonStartDate)
                                        : AppPreferences.seasonStartDate
                                },
                                set: { seasonStartDate = $0.timeIntervalSince1970 }
                            ),
                            in: ...Date.now,
                            displayedComponents: .date
                        )
                    }

                    Text(L10n.text(
                        "Previous weights and personal records can be kept separate for each gym. Existing workouts are assigned to Main Gym.",
                        "Vorige gewichten en persoonlijke records kunnen per gym worden bijgehouden. Bestaande trainingen worden aan Hoofdgym toegewezen."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Section(L10n.text("Workout", "Training")) {
                    Stepper(
                        "\(L10n.text("Default sets for new exercises", "Standaard sets voor nieuwe oefeningen")): \(defaultSets)",
                        value: $defaultSets,
                        in: 1...6
                    )

                    Toggle(L10n.text("Show previous sets", "Vorige sets tonen"), isOn: $showPreviousSets)
                    Toggle(L10n.text("Auto-collapse completed exercises", "Voltooide oefeningen automatisch inklappen"), isOn: $autoCollapseCompleted)
                    Toggle(L10n.text("Compact workout layout", "Compacte trainingsweergave"), isOn: $compactWorkoutMode)
                    Toggle(L10n.text("High-contrast workout cards", "Trainingskaarten met hoog contrast"), isOn: $highContrastWorkout)
                    Toggle(L10n.text("Automatic rest timer", "Automatische rusttimer"), isOn: $autoRestTimer)

                    if autoRestTimer {
                        Stepper(
                            "\(L10n.text("Default rest", "Standaard rust")): \(defaultRestSeconds)s",
                            value: $defaultRestSeconds,
                            in: 15...600,
                            step: 15
                        )

                        Toggle(
                            L10n.text("Rest-finished notification + sound", "Melding + geluid wanneer rust voorbij is"),
                            isOn: $restNotifications
                        )
                        .onChange(of: restNotifications) { _, enabled in
                            if enabled {
                                RestNotificationManager.shared.requestAuthorization()
                            } else {
                                RestNotificationManager.shared.cancel()
                            }
                        }

                        Toggle(
                            L10n.text("3-second countdown haptics", "Haptische aftelling van 3 seconden"),
                            isOn: $countdownHaptics
                        )
                    }

                    Picker(
                        L10n.text("Progression rule", "Progressieregel"),
                        selection: $progressionRule
                    ) {
                        Text(L10n.text("Double progression", "Dubbele progressie")).tag("double")
                        Text(L10n.text("Fixed increment", "Vaste verhoging")).tag("fixed")
                        Text(L10n.text("Suggestions off", "Suggesties uit")).tag("off")
                    }

                    if progressionRule != "off" {
                        Stepper(
                            "\(L10n.text("Progression step", "Progressiestap")): \(AppPreferences.displayWeight(progressionStepKg).formatted(.number.precision(.fractionLength(0...2)))) \(AppPreferences.weightLabel)",
                            value: $progressionStepKg,
                            in: 0.25...20,
                            step: 0.25
                        )
                    }

                    Toggle(L10n.text("Keep screen awake during workout", "Scherm aanhouden tijdens training"), isOn: $keepScreenAwake)
                    Toggle(L10n.text("Haptic feedback", "Haptische feedback"), isOn: $hapticsEnabled)
                }

                Section(L10n.text("Heart rate", "Hartslag")) {
                    HStack {
                        Label(
                            heartRateMonitor.isConnected
                                ? (heartRateMonitor.sensorName ?? L10n.text("Connected sensor", "Verbonden sensor"))
                                : L10n.text("Bluetooth HR sensor", "Bluetooth-hartslagsensor"),
                            systemImage: heartRateMonitor.isConnected ? "heart.circle.fill" : "heart.circle"
                        )
                        .foregroundStyle(heartRateMonitor.isConnected ? RFTheme.success : .primary)

                        Spacer()

                        if let bpm = heartRateMonitor.bpm {
                            Text("\(bpm) bpm")
                                .font(.headline)
                                .foregroundStyle(.red)
                        }
                    }

                    if heartRateMonitor.isConnected {
                        Button(role: .destructive) {
                            heartRateMonitor.disconnect()
                        } label: {
                            Label(L10n.text("Disconnect sensor", "Sensor loskoppelen"), systemImage: "xmark.circle")
                        }
                    } else {
                        Button {
                            heartRateMonitor.startScanning()
                        } label: {
                            Label(
                                heartRateMonitor.isScanning
                                    ? L10n.text("Scanning…", "Zoeken…")
                                    : L10n.text("Find heart-rate sensor", "Zoek hartslagsensor"),
                                systemImage: "dot.radiowaves.left.and.right"
                            )
                        }
                        .disabled(heartRateMonitor.isScanning)
                    }

                    Text(L10n.text(
                        "Supports standard Bluetooth Heart Rate Service sensors. When connected, live BPM appears in the workout and can be copied into cardio intervals.",
                        "Ondersteunt standaard Bluetooth Heart Rate Service-sensoren. Na verbinden verschijnt live BPM in de training en kan deze naar cardio-intervallen worden gekopieerd."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Section(L10n.text("Tools", "Hulpmiddelen")) {
                    NavigationLink {
                        PlateCalculatorView()
                    } label: {
                        Label(L10n.text("Plate Calculator", "Schijvencalculator"), systemImage: "circle.grid.2x2.fill")
                    }
                }

                Section(L10n.text("About", "Over")) {
                    LabeledContent(
                        L10n.text("RepForge version", "RepForge-versie"),
                        value: appVersionDisplay
                    )
                    Label(
                        L10n.text(
                            "0.2.9 adds in-app project support and a completely refreshed README.",
                            "0.2.9 voegt ondersteuning voor het project in de app toe en een volledig vernieuwde README."
                        ),
                        systemImage: "sparkles"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    LabeledContent(
                        L10n.text("Exercise media", "Oefenmedia"),
                        value: "Free Exercise DB"
                    )
                }

                Section(L10n.text("Support RepForge", "Steun RepForge")) {
                    Link(destination: URL(string: "https://ko-fi.com/flippyy")!) {
                        HStack(spacing: 12) {
                            Image(systemName: "heart.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.pink)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(L10n.text("Support on Ko-fi", "Steun via Ko-fi"))
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(L10n.text(
                                    "RepForge is free. If you enjoy using it, you can support continued development with an optional donation.",
                                    "RepForge is gratis. Als je de app graag gebruikt, kun je de verdere ontwikkeling steunen met een vrijwillige donatie."
                                ))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(RFTheme.accent)
                        }
                    }
                }

                Section(L10n.text("Storage & export", "Opslag & export")) {
                    LabeledContent(L10n.text("Workout data", "Trainingsdata"), value: L10n.text("Stored locally", "Lokaal opgeslagen"))

                    ShareLink(item: workoutCSV) {
                        Label(L10n.text("Export workout history", "Trainingsgeschiedenis exporteren"), systemImage: "square.and.arrow.up")
                    }

                    ShareLink(item: templateBackupText) {
                        Label(L10n.text("Export templates", "Templates exporteren"), systemImage: "doc.on.doc")
                    }

                    Divider()

                    Button {
                        showStrongImporter = true
                    } label: {
                        Label(
                            L10n.text("Import from Strong CSV", "Importeer vanuit Strong CSV"),
                            systemImage: "arrow.down.doc.fill"
                        )
                    }

                    Text(L10n.text(
                        "Migrates Strong workout history, completed sets, weights, reps, RPE, notes and rest timers. Missing exercises are created automatically. Re-importing the same workout date and name is skipped.",
                        "Migreert Strong-trainingsgeschiedenis, voltooide sets, gewichten, herhalingen, RPE, notities en rusttijden. Ontbrekende oefeningen worden automatisch aangemaakt. Dezelfde trainingsdatum en naam worden bij opnieuw importeren overgeslagen."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Divider()

                    Button {
                        backupDocument = RepForgeBackupDocument(text: makeBackupText())
                        showBackupExporter = true
                    } label: {
                        Label(L10n.text("Full RepForge Backup", "Volledige RepForge-back-up"), systemImage: "externaldrive.fill.badge.plus")
                    }

                    Button {
                        showBackupImporter = true
                    } label: {
                        Label(L10n.text("Restore Full Backup", "Volledige back-up herstellen"), systemImage: "arrow.counterclockwise.circle.fill")
                    }

                    Text(L10n.text(
                        "Full backup includes workout history, templates, profile, custom exercises, gym profiles, planned workouts, program edits, favorites and app settings.",
                        "De volledige back-up bevat trainingsgeschiedenis, templates, profiel, eigen oefeningen, gymprofielen, geplande trainingen, programma-aanpassingen, favorieten en app-instellingen."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

            }
            .scrollContentBackground(.hidden)
            .background(RFTheme.bg)
            .navigationTitle(L10n.settings)
            .fileExporter(
                isPresented: $showBackupExporter,
                document: backupDocument,
                contentType: .json,
                defaultFilename: "RepForge-Backup-\(Date.now.formatted(.dateTime.year().month().day()))"
            ) { result in
                if case .failure(let error) = result {
                    backupMessage = error.localizedDescription
                }
            }
            .fileImporter(
                isPresented: $showBackupImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                restoreBackup(result)
            }
            .sheet(isPresented: $showStrongImporter) {
                StrongCSVDocumentPicker(
                    onPick: { url in
                        showStrongImporter = false
                        importStrongCSV(url)
                    },
                    onCancel: {
                        showStrongImporter = false
                    }
                )
            }
            .alert(
                L10n.text("Strong Import", "Strong-import"),
                isPresented: Binding(
                    get: { strongImportMessage != nil },
                    set: { if !$0 { strongImportMessage = nil } }
                )
            ) {
                Button(L10n.done) { strongImportMessage = nil }
            } message: {
                Text(strongImportMessage ?? "")
            }
            .alert(
                L10n.text("Backup", "Back-up"),
                isPresented: Binding(
                    get: { backupMessage != nil },
                    set: { if !$0 { backupMessage = nil } }
                )
            ) {
                Button(L10n.done) { backupMessage = nil }
            } message: {
                Text(backupMessage ?? "")
            }
        }
    }

    private func importStrongCSV(_ url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let summary = try StrongCSVImporter.importCSV(
                data: data,
                into: context,
                gymID: activeGymID,
                usesImperialUnits: measurementSystem == "imperial"
            )

            var message = L10n.text(
                "Imported \(summary.workoutsImported) workouts and \(summary.setsImported) completed sets from Strong.",
                "\(summary.workoutsImported) trainingen en \(summary.setsImported) voltooide sets uit Strong geïmporteerd."
            )

            if summary.duplicateWorkoutsSkipped > 0 {
                message += "\n" + L10n.text(
                    "Skipped \(summary.duplicateWorkoutsSkipped) workouts that were already in RepForge.",
                    "\(summary.duplicateWorkoutsSkipped) trainingen overgeslagen die al in RepForge stonden."
                )
            }

            if !summary.customExercisesCreated.isEmpty {
                message += "\n" + L10n.text(
                    "Created \(summary.customExercisesCreated.count) missing exercises: \(summary.customExercisesCreated.joined(separator: ", ")).",
                    "\(summary.customExercisesCreated.count) ontbrekende oefeningen aangemaakt: \(summary.customExercisesCreated.joined(separator: ", "))."
                )
            }

            if summary.rowsSkipped > 0 {
                message += "\n" + L10n.text(
                    "Skipped \(summary.rowsSkipped) rows that could not be imported.",
                    "\(summary.rowsSkipped) rijen overgeslagen die niet konden worden geïmporteerd."
                )
            }

            strongImportMessage = message
            Haptics.success()
        } catch {
            strongImportMessage = L10n.text(
                "Could not import Strong CSV: \(error.localizedDescription)",
                "Strong CSV kon niet worden geïmporteerd: \(error.localizedDescription)"
            )
        }
    }

    private func makeBackupText() -> String {
        let templates = exportTemplates.map {
            BackupTemplate(
                id: $0.id,
                name: $0.name,
                exerciseIDs: $0.exerciseIDs,
                plan: $0.plannedExercises,
                createdAt: $0.createdAt
            )
        }

        let sessions = exportSessions.map { session in
            BackupSession(
                id: session.id,
                title: session.title,
                startedAt: session.startedAt,
                endedAt: session.endedAt,
                note: session.note,
                gymID: session.gymID,
                exercises: session.exercises.map { log in
                    BackupExerciseLog(
                        id: log.id,
                        exerciseID: log.exerciseID,
                        order: log.order,
                        targetReps: log.targetReps,
                        coachingNote: log.coachingNote,
                        supersetGroup: log.supersetGroup,
                        sessionNote: log.sessionNote,
                        restSeconds: log.restSeconds,
                        sets: log.sets.map { set in
                            BackupSet(
                                id: set.id,
                                order: set.order,
                                weightKg: set.weightKg,
                                reps: set.reps,
                                completed: set.completed,
                                completedAt: set.completedAt,
                                setTypeRaw: set.setTypeRaw,
                                rpe: set.rpe,
                                rir: set.rir,
                                note: set.note,
                                durationSeconds: set.durationSeconds,
                                distanceKm: set.distanceKm,
                                inclinePercent: set.inclinePercent,
                                calories: set.calories,
                                averageHeartRate: set.averageHeartRate
                            )
                        }
                    )
                }
            )
        }

        let profiles = exportProfiles.map {
            BackupProfile(
                id: $0.id,
                displayName: $0.displayName,
                bio: $0.bio,
                bodyWeightKg: $0.bodyWeightKg,
                heightCm: $0.heightCm,
                createdAt: $0.createdAt
            )
        }

        let bodyMeasurements = exportBodyMeasurements.map {
            BackupBodyMeasurement(
                id: $0.id,
                date: $0.date,
                bodyWeightKg: $0.bodyWeightKg,
                bodyFatPercent: $0.bodyFatPercent,
                waistCm: $0.waistCm,
                chestCm: $0.chestCm,
                armCm: $0.armCm,
                thighCm: $0.thighCm,
                hipCm: $0.hipCm
            )
        }

        let programDays = SwiftDataUserStore.programDays()

        let settings = BackupSettings(
            appLanguage: appLanguage,
            measurementSystem: measurementSystem,
            appearance: appearance,
            themePreset: themePreset,
            textSize: textSize,
            hapticsEnabled: hapticsEnabled,
            showPreviousSets: showPreviousSets,
            keepScreenAwake: keepScreenAwake,
            defaultSets: defaultSets,
            defaultRestSeconds: defaultRestSeconds,
            autoRestTimer: autoRestTimer,
            autoCollapseCompleted: autoCollapseCompleted,
            restNotifications: restNotifications,
            countdownHaptics: countdownHaptics,
            compactWorkoutMode: compactWorkoutMode,
            highContrastWorkout: highContrastWorkout,
            progressionRule: progressionRule,
            progressionStepKg: progressionStepKg,
            activeGymID: activeGymID,
            separateRecordsByGym: separateRecordsByGym,
            prScope: prScope,
            seasonStartDate: seasonStartDate
        )

        let payload = RepForgeBackupPayload(
            version: 1,
            exportedAt: .now,
            templates: templates,
            sessions: sessions,
            profiles: profiles,
            bodyMeasurements: bodyMeasurements,
            customExercises: CustomExerciseStore.load(),
            gyms: GymProfileStore.load(),
            scheduledWorkouts: WorkoutScheduleStore.load(),
            programDays: programDays,
            favorites: ExerciseShortcutStore.favorites,
            recents: ExerciseShortcutStore.recent,
            settings: settings
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(payload) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    private func restoreBackup(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing { url.stopAccessingSecurityScopedResource() }
            }

            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let payload = try decoder.decode(RepForgeBackupPayload.self, from: data)
            try restore(payload)
            backupMessage = L10n.text(
                "Backup restored successfully.",
                "Back-up succesvol hersteld."
            )
        } catch {
            backupMessage = L10n.text(
                "Could not restore backup: \(error.localizedDescription)",
                "Back-up kon niet worden hersteld: \(error.localizedDescription)"
            )
        }
    }

    private func restore(_ payload: RepForgeBackupPayload) throws {
        for session in exportSessions { context.delete(session) }
        for template in exportTemplates { context.delete(template) }
        for profile in exportProfiles { context.delete(profile) }
        for measurement in exportBodyMeasurements { context.delete(measurement) }

        for dto in payload.templates {
            let template = WorkoutTemplate(
                name: dto.name,
                exerciseIDs: dto.exerciseIDs,
                plan: dto.plan
            )
            template.id = dto.id
            template.createdAt = dto.createdAt
            context.insert(template)
        }

        for dto in payload.sessions {
            let logs = dto.exercises.map { logDTO -> ExerciseLog in
                let sets = logDTO.sets.map { setDTO -> WorkoutSet in
                    let set = WorkoutSet(
                        order: setDTO.order,
                        weightKg: setDTO.weightKg,
                        reps: setDTO.reps,
                        completed: setDTO.completed,
                        setTypeRaw: setDTO.setTypeRaw,
                        rpe: setDTO.rpe,
                        rir: setDTO.rir,
                        note: setDTO.note,
                        durationSeconds: setDTO.durationSeconds,
                        distanceKm: setDTO.distanceKm,
                        inclinePercent: setDTO.inclinePercent,
                        calories: setDTO.calories,
                        averageHeartRate: setDTO.averageHeartRate
                    )
                    set.id = setDTO.id
                    set.completedAt = setDTO.completedAt
                    return set
                }

                let log = ExerciseLog(
                    exerciseID: logDTO.exerciseID,
                    order: logDTO.order,
                    targetReps: logDTO.targetReps,
                    coachingNote: logDTO.coachingNote,
                    supersetGroup: logDTO.supersetGroup,
                    sessionNote: logDTO.sessionNote,
                    restSeconds: logDTO.restSeconds,
                    sets: sets
                )
                log.id = logDTO.id
                return log
            }

            let session = WorkoutSession(
                title: dto.title,
                startedAt: dto.startedAt,
                exercises: logs,
                note: dto.note,
                gymID: dto.gymID
            )
            session.id = dto.id
            session.endedAt = dto.endedAt
            context.insert(session)
        }

        for dto in payload.profiles {
            let profile = UserProfile(displayName: dto.displayName)
            profile.id = dto.id
            profile.bio = dto.bio
            profile.bodyWeightKg = dto.bodyWeightKg
            profile.heightCm = dto.heightCm
            profile.createdAt = dto.createdAt
            context.insert(profile)
        }

        for dto in payload.bodyMeasurements ?? [] {
            let measurement = BodyMeasurement(
                date: dto.date,
                bodyWeightKg: dto.bodyWeightKg,
                bodyFatPercent: dto.bodyFatPercent,
                waistCm: dto.waistCm,
                chestCm: dto.chestCm,
                armCm: dto.armCm,
                thighCm: dto.thighCm,
                hipCm: dto.hipCm
            )
            measurement.id = dto.id
            context.insert(measurement)
        }

        CustomExerciseStore.save(payload.customExercises)
        GymProfileStore.save(payload.gyms)
        WorkoutScheduleStore.restore(payload.scheduledWorkouts)
        ExerciseShortcutStore.restore(favorites: payload.favorites, recent: payload.recents)

        SwiftDataUserStore.saveProgramDays(payload.programDays)

        appLanguage = payload.settings.appLanguage
        measurementSystem = payload.settings.measurementSystem
        appearance = payload.settings.appearance
        themePreset = payload.settings.themePreset
        textSize = payload.settings.textSize
        hapticsEnabled = payload.settings.hapticsEnabled
        showPreviousSets = payload.settings.showPreviousSets
        keepScreenAwake = payload.settings.keepScreenAwake
        defaultSets = payload.settings.defaultSets
        defaultRestSeconds = payload.settings.defaultRestSeconds
        autoRestTimer = payload.settings.autoRestTimer
        autoCollapseCompleted = payload.settings.autoCollapseCompleted
        restNotifications = payload.settings.restNotifications ?? true
        countdownHaptics = payload.settings.countdownHaptics ?? true
        compactWorkoutMode = payload.settings.compactWorkoutMode ?? false
        highContrastWorkout = payload.settings.highContrastWorkout ?? false
        progressionRule = payload.settings.progressionRule ?? "double"
        progressionStepKg = payload.settings.progressionStepKg
        activeGymID = payload.settings.activeGymID
        separateRecordsByGym = payload.settings.separateRecordsByGym
        prScope = payload.settings.prScope
        seasonStartDate = payload.settings.seasonStartDate

        try context.save()
    }
}

// MARK: - Shared UI

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(RFTheme.accent)
            Text(value).font(.headline)
            Text(title).font(.caption).foregroundStyle(RFTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RFTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct EmptyCard: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.largeTitle).foregroundStyle(RFTheme.accent)
            Text(title).font(.headline)
            Text(text).multilineTextAlignment(.center).foregroundStyle(RFTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(RFTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct RecordRow: View {
    let name: String
    let value: String

    var body: some View {
        HStack {
            Text(name).font(.headline)
            Spacer()
            Text(value).font(.headline).foregroundStyle(RFTheme.accent)
        }
        .padding()
        .background(RFTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

func durationString(_ interval: TimeInterval) -> String {
    let total = max(0, Int(interval))
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
}
