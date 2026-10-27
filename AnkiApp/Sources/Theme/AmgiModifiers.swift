import SwiftUI

enum AmgiStatusTone {
    case accent
    case positive
    case warning
    case danger
    case info
    case neutral

    fileprivate var foregroundColor: Color {
        switch self {
        case .accent:
            return Color.amgiAccent
        case .positive:
            return Color.amgiPositive
        case .warning:
            return Color.amgiWarning
        case .danger:
            return Color.amgiDanger
        case .info:
            return Color.amgiInfo
        case .neutral:
            return Color.amgiTextSecondary
        }
    }

    fileprivate var backgroundColor: Color {
        switch self {
        case .accent:
            return Color.amgiAccent.opacity(0.12)
        case .positive:
            return Color.amgiPositive.opacity(0.14)
        case .warning:
            return Color.amgiWarning.opacity(0.16)
        case .danger:
            return Color.amgiDanger.opacity(0.14)
        case .info:
            return Color.amgiInfo.opacity(0.14)
        case .neutral:
            return Color.amgiSurface
        }
    }

    fileprivate var borderColor: Color {
        switch self {
        case .neutral:
            return Color.amgiBorder.opacity(0.32)
        default:
            return foregroundColor.opacity(0.28)
        }
    }

    fileprivate var toolbarForegroundColor: Color {
        switch self {
        case .neutral:
            return Color.amgiTextPrimary
        default:
            return foregroundColor
        }
    }
}

struct AmgiCardModifier: ViewModifier {
    let elevated: Bool
    var interactive: Bool = false
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .padding(AmgiSpacing.lg)
            .ankiLiquidGlass(
                tint: elevated ? Color.amgiSurfaceElevated.opacity(0.85) : Color.amgiSurface.opacity(0.65),
                interactive: interactive,
                minimumCorner: cornerRadius
            )
            .modifier(ConditionalShadow(enabled: elevated))
    }
}

private struct ConditionalShadow: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.amgiShadow()
        } else {
            content
        }
    }
}

struct AmgiPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .amgiFont(.bodyEmphasis)
            .foregroundStyle(Color.white)
            .padding(.horizontal, AmgiSpacing.lg)
            .padding(.vertical, AmgiSpacing.sm)
            .glassEffect(Glass.regular.tint(Color.amgiAccent).interactive(), in: .capsule)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct AmgiSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .amgiFont(.bodyEmphasis)
            .foregroundStyle(Color.amgiAccent)
            .padding(.horizontal, AmgiSpacing.lg)
            .padding(.vertical, AmgiSpacing.sm)
            .glassEffect(Glass.regular.interactive(), in: .capsule)
            .overlay(
                Capsule()
                    .stroke(Color.amgiAccent.opacity(configuration.isPressed ? 0.45 : 0.75), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct AmgiStatusMessageView: View {
    let title: String
    let message: String
    let systemImage: String
    let tone: AmgiStatusTone

    var body: some View {
        VStack(spacing: AmgiSpacing.md) {
            Label(title, systemImage: systemImage)
                .amgiStatusText(tone, font: .bodyEmphasis)

            Text(message)
                .amgiFont(.caption)
                .foregroundStyle(Color.amgiTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 420)
        .padding(.horizontal, AmgiSpacing.lg)
    }
}

extension View {
    /// iOS 26+ 原生 Liquid Glass 光学折射与同心圆角修饰器
    func ankiLiquidGlass(
        tint: Color? = nil,
        interactive: Bool = false,
        minimumCorner: CGFloat = 24
    ) -> some View {
        let glass: Glass = {
            if let tint {
                return interactive ? Glass.regular.tint(tint).interactive() : Glass.regular.tint(tint)
            } else {
                return interactive ? Glass.regular.interactive() : Glass.regular
            }
        }()
        return self.glassEffect(
            glass,
            in: .rect(corners: .concentric(minimum: .fixed(minimumCorner)), isUniform: true)
        )
    }

    func amgiCard(elevated: Bool = false, interactive: Bool = false, cornerRadius: CGFloat = 20) -> some View {
        modifier(AmgiCardModifier(elevated: elevated, interactive: interactive, cornerRadius: cornerRadius))
    }

    func amgiToolbarIconButton(size: CGFloat = 36) -> some View {
        frame(width: size, height: size)
            .foregroundStyle(Color.amgiTextPrimary)
            .glassEffect(Glass.regular.interactive(), in: .rect(corners: .concentric(minimum: .fixed(12)), isUniform: true))
    }

    func amgiToolbarTextButton(tone: AmgiStatusTone = .accent) -> some View {
        tint(tone.toolbarForegroundColor)
            .foregroundStyle(tone.toolbarForegroundColor)
            .buttonStyle(.glass)
    }

    func amgiStatusText(_ tone: AmgiStatusTone, font: AmgiFont = .captionBold) -> some View {
        amgiFont(font)
            .foregroundStyle(tone.foregroundColor)
    }

    func amgiCapsuleControl(
        backgroundColor: Color = .amgiSurface,
        horizontalPadding: CGFloat = 12,
        verticalPadding: CGFloat = 6
    ) -> some View {
        padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .glassEffect(Glass.regular.tint(backgroundColor).interactive(), in: .capsule)
    }

    func amgiStatusBadge(_ tone: AmgiStatusTone, horizontalPadding: CGFloat = 8, verticalPadding: CGFloat = 4) -> some View {
        amgiFont(.captionBold)
            .foregroundStyle(tone.foregroundColor)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(tone.backgroundColor)
            .overlay(
                Capsule()
                    .stroke(tone.borderColor, lineWidth: 1)
            )
            .clipShape(Capsule())
    }

    func amgiStatusPanel(_ tone: AmgiStatusTone, elevated: Bool = false) -> some View {
        padding(AmgiSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.amgiSurfaceElevated)
            )
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tone.backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(tone.borderColor, lineWidth: 1)
            )
            .modifier(ConditionalShadow(enabled: elevated))
    }

    func amgiSegmentedPicker() -> some View {
        pickerStyle(.segmented)
            .tint(Color.amgiAccent)
    }

    func amgiSectionBackground() -> some View {
        background(Color.amgiBackground)
    }
}
