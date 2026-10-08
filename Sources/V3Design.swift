import SwiftUI

// FORGE / v3: Completely independent product UI. Existing domain models, data,
// video providers, export and workout metrics remain the compatibility boundary.
enum V3 {
    static var isLight: Bool { AppPreferences.appearance == "light" }
    static var accent: Color {
        AppPreferences.themePreset == "forge"
            ? Color(red: 0.37, green: 0.73, blue: 1.00)
            : RFTheme.accent
    }
    static let energy = Color(red: 1.00, green: 0.70, blue: 0.39)
    static let positive = Color(red: 0.33, green: 0.84, blue: 0.66)
    static var background: Color {
        isLight ? Color(red: 0.95, green: 0.97, blue: 0.99)
                : Color(red: 0.035, green: 0.052, blue: 0.083)
    }
    static var card: Color {
        isLight ? .white : Color(red: 0.079, green: 0.106, blue: 0.15)
    }
    static var inset: Color {
        isLight ? Color(red: 0.925, green: 0.945, blue: 0.97)
                : Color(red: 0.115, green: 0.149, blue: 0.20)
    }
    static var faint: Color {
        isLight ? Color(red: 0.32, green: 0.38, blue: 0.46)
                : Color(red: 0.61, green: 0.70, blue: 0.81)
    }
    static var border: Color { accent.opacity(isLight ? 0.13 : 0.17) }
    static let radius: CGFloat = 24
    static var panelGradient: LinearGradient {
        LinearGradient(
            colors: [accent.opacity(isLight ? 0.21 : 0.32), card, card],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}

struct V3Backdrop: View {
    var body: some View {
        ZStack {
            V3.background
            RadialGradient(
                colors: [V3.accent.opacity(0.12), .clear],
                center: .topTrailing, startRadius: 10, endRadius: 460
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct V3CapsuleButton: View {
    let title: String
    let symbol: String
    var filled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(filled ? (V3.isLight ? Color.white : V3.background) : V3.accent)
                .padding(.horizontal, 18)
                .frame(minHeight: 46)
                .background(filled ? V3.accent : V3.inset, in: Capsule())
        }
        .buttonStyle(V3TapStyle())
    }
}

struct V3TapStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.975 : 1))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.13), value: configuration.isPressed)
    }
}

struct V3Panel<Content: View>: View {
    var highlighted = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: V3.radius, style: .continuous)
                    .fill(highlighted ? V3.panelGradient : LinearGradient(
                        colors: [V3.card, V3.card],
                        startPoint: .top, endPoint: .bottom))
                    .overlay {
                        RoundedRectangle(cornerRadius: V3.radius)
                            .stroke(V3.border, lineWidth: 1)
                    }
            }
    }
}

struct V3SectionTitle: View {
    let title: String
    var detail: String? = nil
    var action: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                if let detail {
                    Text(detail).font(.subheadline).foregroundStyle(V3.faint)
                }
            }
            Spacer(minLength: 2)
            if let action {
                Text(action).font(.caption.bold()).foregroundStyle(V3.accent)
            }
        }
    }
}

struct V3BigNumber: View {
    let amount: String
    let caption: String
    let symbol: String
    var tint: Color = V3.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Image(systemName: symbol).font(.title3)
                    .foregroundStyle(tint)
                Spacer()
            }
            Text(amount)
                .font(.system(.title, design: .rounded, weight: .heavy))
                .monospacedDigit()
                .minimumScaleFactor(0.65)
                .lineLimit(1)
            Text(caption).font(.caption.weight(.medium)).foregroundStyle(V3.faint)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .background(V3.card, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
}

struct V3ProgressArc: View {
    let value: Double
    let title: String
    var diameter: CGFloat = 110
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().stroke(V3.inset, lineWidth: 9)
            Circle().trim(from: 0, to: min(max(value, 0), 1))
                .stroke(V3.accent, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: value)
            VStack(spacing: 0) {
                Text("\(Int(max(0, value) * 100))")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .monospacedDigit()
                Text("%").font(.caption2.weight(.medium)).foregroundStyle(V3.faint)
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title + ": \(Int(value * 100))%")
    }
}

struct V3PrimaryAction: View {
    let title: String
    var symbol = "arrow.right"
    var color: Color = V3.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(.headline.weight(.bold))
                Spacer()
                Image(systemName: symbol).font(.headline.bold())
            }
            .foregroundStyle(V3.isLight ? Color.white : V3.background)
            .padding(.horizontal, 20)
            .frame(minHeight: 58)
            .background(color, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(V3TapStyle())
    }
}

struct V3Tag: View {
    let text: String
    var tint: Color = V3.accent
    var body: some View {
        Text(text)
            .font(.caption2.weight(.heavy))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

struct V3NavigationDock: View {
    @Binding var tab: Int
    let onStart: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let routes = [
        (0, "square.grid.2x2.fill", "Dashboard", "Overzicht"),
        (1, "square.stack.3d.up.fill", "Studio", "Studio"),
        (2, "chart.bar.xaxis", "Journey", "Voortgang")
    ]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(routes, id: \.0) { item in
                Button {
                    if reduceMotion { tab = item.0 }
                    else { withAnimation(.easeInOut(duration: 0.17)) { tab = item.0 } }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: item.1).font(.system(size: 20, weight: .semibold))
                        Text(L10n.text(item.2, item.3))
                            .font(.caption2.weight(tab == item.0 ? .bold : .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundStyle(tab == item.0 ? V3.accent : V3.faint)
                    .frame(maxWidth: .infinity, minHeight: 55)
                    .background(tab == item.0 ? V3.accent.opacity(0.12) : .clear,
                                in: RoundedRectangle(cornerRadius: 17))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(tab == item.0 ? .isSelected : [])
            }

            Button(action: onStart) {
                Image(systemName: "plus")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(V3.isLight ? Color.white : V3.background)
                    .frame(width: 56, height: 56)
                    .background(V3.accent, in: RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(V3TapStyle())
            .accessibilityLabel(L10n.text("Start or resume workout", "Training starten of hervatten"))
        }
        .padding(7)
        .background(V3.card, in: RoundedRectangle(cornerRadius: 25))
        .overlay(RoundedRectangle(cornerRadius: 25).stroke(V3.border))
        .padding(.horizontal, 13)
        .padding(.bottom, 5)
        .background(.ultraThinMaterial)
    }
}
