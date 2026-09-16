import Foundation
import SwiftUI
import UIKit

enum ForecastAppearance: String, CaseIterable, Identifiable {
    case dark
    case light

    var id: Self { self }

    var title: String {
        switch self {
        case .dark: "Dark"
        case .light: "Light"
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .dark: .dark
        case .light: .light
        }
    }
}

enum ForecastTheme {
    static let canvas = adaptive(
        light: UIColor(red: 0.965, green: 0.970, blue: 0.978, alpha: 1),
        dark: .black
    )
    static let surface = adaptive(
        light: UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 1),
        dark: UIColor(red: 0.060, green: 0.064, blue: 0.072, alpha: 1)
    )
    static let raised = adaptive(
        light: UIColor(red: 0.900, green: 0.914, blue: 0.936, alpha: 1),
        dark: UIColor(red: 0.130, green: 0.138, blue: 0.155, alpha: 1)
    )
    static let elevated = adaptive(
        light: UIColor(red: 0.845, green: 0.868, blue: 0.902, alpha: 1),
        dark: UIColor(red: 0.185, green: 0.196, blue: 0.220, alpha: 1)
    )
    static let divider = adaptive(
        light: UIColor.black.withAlphaComponent(0.14),
        dark: UIColor.white.withAlphaComponent(0.16)
    )
    static let primaryText = adaptive(
        light: UIColor(red: 0.035, green: 0.045, blue: 0.060, alpha: 1),
        dark: UIColor(red: 0.973, green: 0.976, blue: 0.984, alpha: 1)
    )
    static let secondaryText = adaptive(
        light: UIColor(red: 0.290, green: 0.325, blue: 0.385, alpha: 1),
        dark: UIColor(red: 0.700, green: 0.725, blue: 0.775, alpha: 1)
    )

    static let profit = adaptive(
        light: UIColor(red: 0.000, green: 0.545, blue: 0.245, alpha: 1),
        dark: UIColor(red: 0.265, green: 1.000, blue: 0.690, alpha: 1)
    )
    static let tickets = adaptive(
        light: UIColor(red: 0.900, green: 0.430, blue: 0.000, alpha: 1),
        dark: UIColor(red: 1.000, green: 0.745, blue: 0.260, alpha: 1)
    )
    static let breakEven = adaptive(
        light: UIColor(red: 0.000, green: 0.390, blue: 0.850, alpha: 1),
        dark: UIColor(red: 0.300, green: 0.650, blue: 1.000, alpha: 1)
    )
    static let revenue = adaptive(
        light: UIColor(red: 0.000, green: 0.555, blue: 0.205, alpha: 1),
        dark: UIColor(red: 0.220, green: 0.860, blue: 0.420, alpha: 1)
    )
    static let revenueSecondary = adaptive(
        light: UIColor(red: 0.130, green: 0.650, blue: 0.180, alpha: 1),
        dark: UIColor(red: 0.420, green: 0.730, blue: 0.290, alpha: 1)
    )
    static let revenueTertiary = adaptive(
        light: UIColor(red: 0.410, green: 0.690, blue: 0.000, alpha: 1),
        dark: UIColor(red: 0.650, green: 0.830, blue: 0.330, alpha: 1)
    )
    static let revenueQuaternary = adaptive(
        light: UIColor(red: 0.000, green: 0.650, blue: 0.430, alpha: 1),
        dark: UIColor(red: 0.160, green: 0.760, blue: 0.550, alpha: 1)
    )
    static let revenueQuinary = adaptive(
        light: UIColor(red: 0.200, green: 0.520, blue: 0.090, alpha: 1),
        dark: UIColor(red: 0.500, green: 0.820, blue: 0.220, alpha: 1)
    )
    static let revenueSenary = adaptive(
        light: UIColor(red: 0.000, green: 0.475, blue: 0.360, alpha: 1),
        dark: UIColor(red: 0.230, green: 0.900, blue: 0.690, alpha: 1)
    )
    static let expense = adaptive(
        light: UIColor(red: 0.850, green: 0.020, blue: 0.130, alpha: 1),
        dark: UIColor(red: 1.000, green: 0.275, blue: 0.400, alpha: 1)
    )
    static let expenseSecondary = adaptive(
        light: UIColor(red: 0.690, green: 0.020, blue: 0.190, alpha: 1),
        dark: UIColor(red: 0.830, green: 0.190, blue: 0.285, alpha: 1)
    )
    static let expenseTertiary = adaptive(
        light: UIColor(red: 0.940, green: 0.190, blue: 0.100, alpha: 1),
        dark: UIColor(red: 1.000, green: 0.500, blue: 0.430, alpha: 1)
    )
    static let expenseQuaternary = adaptive(
        light: UIColor(red: 0.760, green: 0.000, blue: 0.330, alpha: 1),
        dark: UIColor(red: 0.920, green: 0.220, blue: 0.480, alpha: 1)
    )
    static let expenseQuinary = adaptive(
        light: UIColor(red: 0.820, green: 0.180, blue: 0.000, alpha: 1),
        dark: UIColor(red: 1.000, green: 0.390, blue: 0.180, alpha: 1)
    )
    static let expenseSenary = adaptive(
        light: UIColor(red: 0.620, green: 0.000, blue: 0.080, alpha: 1),
        dark: UIColor(red: 0.780, green: 0.150, blue: 0.230, alpha: 1)
    )
    static let target = adaptive(
        light: UIColor(red: 0.560, green: 0.190, blue: 0.875, alpha: 1),
        dark: UIColor(red: 0.720, green: 0.450, blue: 1.000, alpha: 1)
    )
    static let warning = adaptive(
        light: UIColor(red: 0.790, green: 0.405, blue: 0.000, alpha: 1),
        dark: UIColor(red: 1.000, green: 0.745, blue: 0.260, alpha: 1)
    )
    static let headerChrome = adaptive(
        light: UIColor(red: 0.260, green: 0.315, blue: 0.395, alpha: 1),
        dark: UIColor(red: 0.650, green: 0.700, blue: 0.800, alpha: 1)
    )
    static let accentForeground = adaptive(light: .white, dark: .black)

    static let currencyFormat: FloatingPointFormatStyle<Double>.Currency =
        .currency(code: "USD")
        .precision(.fractionLength(0))
        .locale(Locale(identifier: "en_US"))

    static func compactCurrency(_ value: Double) -> String {
        let sign = value < 0 ? "−" : ""
        let magnitude = abs(value)
        if magnitude >= 1_000_000 {
            return "\(sign)$\(trimmed(magnitude / 1_000_000))M"
        }
        if magnitude >= 1_000 {
            return "\(sign)$\(trimmed(magnitude / 1_000))K"
        }
        return value.formatted(currencyFormat)
    }

    static func compactNumber(_ value: Double) -> String {
        let sign = value < 0 ? "−" : ""
        let magnitude = abs(value)
        if magnitude >= 1_000_000 {
            return "\(sign)\(trimmed(magnitude / 1_000_000))M"
        }
        if magnitude >= 1_000 {
            return "\(sign)\(trimmed(magnitude / 1_000))K"
        }
        return value.formatted(.number.precision(.fractionLength(0)))
    }

    static func revenueShade(at index: Int) -> Color {
        let palette = [revenue, revenueSecondary, revenueTertiary, revenueQuaternary, revenueQuinary, revenueSenary]
        return palette[index % palette.count]
    }

    static func expenseShade(at index: Int) -> Color {
        let palette = [expense, expenseSecondary, expenseTertiary, expenseQuaternary, expenseQuinary, expenseSenary]
        return palette[index % palette.count]
    }

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    private static func trimmed(_ value: Double) -> String {
        let format = value.rounded() == value ? "%.0f" : "%.1f"
        return String(format: format, value)
    }
}

enum ForecastMotion {
    static let workspace = Animation.spring(duration: 0.32, bounce: 0)
    // Shared curves keep related surfaces moving as one system. Navigation and
    // resizing intentionally settle more slowly than direct control feedback.
    static let control = Animation.timingCurve(0.16, 1, 0.30, 1, duration: 0.36)
    static let data = Animation.timingCurve(0.16, 1, 0.30, 1, duration: 0.68)
    static let scale = Animation.timingCurve(0.16, 1, 0.30, 1, duration: 0.62)
    static let navigation = Animation.timingCurve(0.16, 1, 0.24, 1, duration: 0.58)
    static let paging = Animation.spring(response: 0.62, dampingFraction: 0.84, blendDuration: 0.24)
    static let reveal = Animation.timingCurve(0.20, 0.82, 0.24, 1, duration: 0.54)
}

// These modifiers compile with the current iOS 18 SDK and automatically adopt
// native Liquid Glass when the project is built with an iOS 26-capable SDK.
// Earlier systems retain a restrained material fallback.
struct BudgetGlassSurfaceModifier: ViewModifier {
    let tint: Color?
    let cornerRadius: CGFloat
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            if let tint {
                content.glassEffect(
                    .regular.tint(tint).interactive(interactive),
                    in: .rect(cornerRadius: cornerRadius)
                )
            } else {
                content.glassEffect(
                    .regular.interactive(interactive),
                    in: .rect(cornerRadius: cornerRadius)
                )
            }
        } else {
            fallback(content)
        }
#else
        fallback(content)
#endif
    }

    private func fallback(_ content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                if let tint {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tint.opacity(0.08))
                        .allowsHitTesting(false)
                }
            }
    }
}

struct BudgetGlassMorphModifier: ViewModifier {
    let id: String
    let namespace: Namespace.ID
    let tint: Color
    let cornerRadius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    .regular.tint(tint.opacity(0.22)).interactive(),
                    in: .rect(cornerRadius: cornerRadius)
                )
                .glassEffectID(id, in: namespace)
        } else {
            fallback(content)
        }
#else
        fallback(content)
#endif
    }

    private func fallback(_ content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .allowsHitTesting(false)
            }
    }
}

struct BudgetSliderGlassModifier: ViewModifier {
    let tint: Color

    @ViewBuilder
    func body(content: Content) -> some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.glassEffect(
                .regular.tint(tint.opacity(0.10)).interactive(),
                in: .capsule
            )
        } else {
            content
        }
#else
        content
#endif
    }
}

extension View {
    func budgetGlassSurface(
        tint: Color? = nil,
        cornerRadius: CGFloat,
        interactive: Bool = false
    ) -> some View {
        modifier(BudgetGlassSurfaceModifier(tint: tint, cornerRadius: cornerRadius, interactive: interactive))
    }

    func budgetGlassMorph(
        id: String,
        namespace: Namespace.ID,
        tint: Color,
        cornerRadius: CGFloat
    ) -> some View {
        modifier(BudgetGlassMorphModifier(id: id, namespace: namespace, tint: tint, cornerRadius: cornerRadius))
    }
}
