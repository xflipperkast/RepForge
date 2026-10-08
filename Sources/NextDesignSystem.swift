import SwiftUI

// REP FORGE / NEXT — one coherent design language across every primary route.
// All colors respect the user's existing theme preset and light/dark appearance.
enum NextStyle {
    static var ink: Color { RFTheme.bg }
    static var panel: Color { RFTheme.surface }
    static var panelLift: Color { RFTheme.raised }
    static var electric: Color { RFTheme.accent }
    static var muted: Color { RFTheme.muted }
    static var positive: Color { RFTheme.success }
    static let radius: CGFloat = 24

    static var space: CGFloat { RFLayout.style == "compact" ? 15 : 20 }
    static var reducedMotion: Bool { UIAccessibility.isReduceMotionEnabled }

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [RFTheme.accent.opacity(0.28), RFTheme.surface, RFTheme.surface],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct NextCanvas: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    NextStyle.ink.ignoresSafeArea()
                    LinearGradient(
                        colors: [NextStyle.electric.opacity(0.055), .clear, .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                }
            }
    }
}

struct NextSurface: ViewModifier {
    var prominent = false
    var radius: CGFloat = 22
    func body(content: Content) -> some View {
        content
            .padding(prominent ? 20 : 16)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        prominent ? NextStyle.heroGradient : LinearGradient(
                            colors: [NextStyle.panel, NextStyle.panel],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .overlay(alignment: .topTrailing) {
                        if prominent {
                            NextSignatureArtwork()
                                .offset(x: 64, y: -57)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        prominent ? NextStyle.electric.opacity(0.34) : RFTheme.cardBorder,
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    func nextCanvas() -> some View { modifier(NextCanvas()) }
    func nextSurface(prominent: Bool = false, radius: CGFloat = 22) -> some View {
        modifier(NextSurface(prominent: prominent, radius: radius))
    }
}

// Static orbital engraving: a distinctive premium visual without timers,
// blur-heavy layers, or an indefinitely-running animation.
struct NextSignatureArtwork: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(NextStyle.electric.opacity(0.25), lineWidth: 1)
                .frame(width: 212, height: 212)
            Circle()
                .trim(from: 0.08, to: 0.74)
                .stroke(
                    AngularGradient(colors: [
                        NextStyle.electric.opacity(0.0),
                        NextStyle.electric.opacity(0.55),
                        NextStyle.electric.opacity(0.1)
                    ], center: .center),
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .rotationEffect(.degrees(-35))
                .frame(width: 176, height: 176)
            Circle()
                .stroke(NextStyle.electric.opacity(0.15), style:
                        StrokeStyle(lineWidth: 1, dash: [6, 9]))
                .frame(width: 140, height: 140)
            Text("R")
                .font(.system(size: 98, weight: .black, design: .rounded))
                .italic()
                .foregroundStyle(NextStyle.electric.opacity(0.25))
        }
        .frame(width: 240, height: 240)
        .accessibilityHidden(true)
    }
}

struct NextEyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .tracking(2.5)
            .foregroundStyle(NextStyle.electric)
            .accessibilityAddTraits(.isHeader)
    }
}

struct NextHeading: View {
    let title: String
    var subtitle: String? = nil
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle).font(.subheadline).foregroundStyle(NextStyle.muted)
                }
            }
            Spacer(minLength: 0)
            if let trailing {
                Text(trailing)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NextStyle.electric)
            }
        }
    }
}

struct NextStat: View {
    let symbol: String
    let value: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(NextStyle.electric)
                .accessibilityHidden(true)
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .black))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(title)
                .font(.caption)
                .foregroundStyle(NextStyle.muted)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 95, alignment: .leading)
        .nextSurface(radius: 18)
        .accessibilityElement(children: .combine)
    }
}

struct NextPrimaryButton: View {
    let title: String
    var symbol = "arrow.up.right"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title).font(.headline.weight(.bold))
                Spacer()
                Image(systemName: symbol).font(.headline.weight(.heavy))
            }
            .foregroundStyle(Color.black)
            .padding(.horizontal, 20)
            .frame(minHeight: 58)
            .background(NextStyle.electric, in: RoundedRectangle(cornerRadius: 18))
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(NextPressStyle())
    }
}

struct NextPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.975 : 1))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16),
                       value: configuration.isPressed)
    }
}

struct NextLinkRow: View {
    let symbol: String
    let title: String
    var description: String? = nil
    var badge: String? = nil

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(NextStyle.electric)
                .frame(width: 48, height: 48)
                .background(NextStyle.electric.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 15))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                if let description {
                    Text(description).font(.caption).foregroundStyle(NextStyle.muted)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 4)
            if let badge {
                Text(badge).font(.caption.bold()).foregroundStyle(NextStyle.electric)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(NextStyle.muted)
                .accessibilityHidden(true)
        }
        .nextSurface(radius: 18)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct NextScreenHeader: View {
    let eyebrow: String
    let title: String
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NextEyebrow(text: eyebrow)
            Text(title)
                .font(.system(.largeTitle, design: .rounded, weight: .black))
                .tracking(-1.2)
                .minimumScaleFactor(0.75)
                .lineLimit(2)
                .accessibilityAddTraits(.isHeader)
            if let detail {
                Text(detail).font(.subheadline).foregroundStyle(NextStyle.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Custom navigation never uses colored labels alone: every destination has a
/// visible icon, text, semantic selected state and large accessible target.
enum NextRoute: Int, CaseIterable, Identifiable {
    case today, programs, library, activity, athlete
    var id: Int { rawValue }
    var icon: String {
        switch self {
        case .today: return "house.fill"
        case .programs: return "square.stack.3d.up.fill"
        case .library: return "dumbbell.fill"
        case .activity: return "chart.xyaxis.line"
        case .athlete: return "person.crop.circle.fill"
        }
    }
    var label: String {
        switch self {
        case .today: return L10n.text("Today", "Vandaag")
        case .programs: return L10n.text("Plans", "Schema's")
        case .library: return L10n.text("Explore", "Ontdek")
        case .activity: return L10n.text("Progress", "Voortgang")
        case .athlete: return L10n.text("You", "Jij")
        }
    }
}

struct NextNavigation: View {
    @Binding var selection: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(NextRoute.allCases) { route in
                            tabButton(route)
                                .frame(minWidth: 103)
                        }
                    }
                    .padding(6)
                }
                .scrollBounceBehavior(.basedOnSize)
            } else {
                HStack(spacing: 2) {
                    ForEach(NextRoute.allCases) { route in
                        tabButton(route)
                    }
                }
                .padding(6)
            }
        }
        .background(NextStyle.panel, in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(RFTheme.cardBorder)
                .allowsHitTesting(false)
        }
        .padding(.horizontal, 13)
        .padding(.top, 6)
        .padding(.bottom, 3)
        .background(.ultraThinMaterial)
    }

    private func tabButton(_ route: NextRoute) -> some View {
        let selected = selection == route.rawValue
        return Button {
            if reduceMotion {
                selection = route.rawValue
            } else {
                withAnimation(.easeInOut(duration: 0.18)) {
                    selection = route.rawValue
                }
            }
            Haptics.light()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: route.icon)
                    .font(.system(size: 19, weight: selected ? .bold : .medium))
                    .frame(height: 23)
                Text(route.label)
                    .font(.caption2.weight(selected ? .heavy : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(selected ? Color.black : NextStyle.muted)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 51)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(NextStyle.electric)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(route.label)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint(L10n.text("Switch tab", "Wissel tab"))
    }
}
