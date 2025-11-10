//
//  View+Extensions.swift
//  PushToTalk
//
//  Useful SwiftUI View extensions for PushToTalk application
//

import SwiftUI

// MARK: - View Extensions

extension View {
    /// Applies conditional modifier
    /// - Parameters:
    ///   - condition: Condition to check
    ///   - transform: Modifier to apply if true
    /// - Returns: Modified view
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Applies conditional modifier with else clause
    /// - Parameters:
    ///   - condition: Condition to check
    ///   - trueTransform: Modifier to apply if true
    ///   - falseTransform: Modifier to apply if false
    /// - Returns: Modified view
    @ViewBuilder
    func `if`<TrueContent: View, FalseContent: View>(
        _ condition: Bool,
        then trueTransform: (Self) -> TrueContent,
        else falseTransform: (Self) -> FalseContent
    ) -> some View {
        if condition {
            trueTransform(self)
        } else {
            falseTransform(self)
        }
    }

    /// Applies modifier if optional value is not nil
    /// - Parameters:
    ///   - value: Optional value
    ///   - transform: Modifier to apply
    /// - Returns: Modified view
    @ViewBuilder
    func ifLet<Value, Content: View>(
        _ value: Value?,
        transform: (Self, Value) -> Content
    ) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }

    /// Applies standard card styling
    /// - Parameters:
    ///   - backgroundColor: Background color (default .white)
    ///   - cornerRadius: Corner radius (default cardCornerRadius)
    ///   - shadowRadius: Shadow radius (default cardShadowRadius)
    /// - Returns: Styled view
    func cardStyle(
        backgroundColor: Color = Color(NSColor.controlBackgroundColor),
        cornerRadius: CGFloat = UIConstants.cardCornerRadius,
        shadowRadius: CGFloat = UIConstants.cardShadowRadius
    ) -> some View {
        self
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .shadow(color: Color.black.opacity(UIConstants.shadowOpacity), radius: shadowRadius, x: 0, y: 2)
    }

    /// Applies settings section card style
    /// - Parameter color: Section color
    /// - Returns: Styled view
    func settingsSectionCard(color: Color = UIConstants.SectionColors.general) -> some View {
        self
            .padding(UIConstants.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius)
                    .fill(color.opacity(UIConstants.secondaryOverlayOpacity))
            )
    }

    /// Applies hover effect
    /// - Parameter scale: Scale factor on hover (default 1.05)
    /// - Returns: View with hover effect
    func hoverEffect(scale: CGFloat = 1.05) -> some View {
        self
            .scaleEffect(1.0)
            .animation(.easeInOut(duration: UIConstants.shortAnimationDuration), value: scale)
    }

    /// Applies skeleton loading effect
    /// - Parameter isLoading: Loading state
    /// - Returns: View with skeleton effect
    func skeleton(_ isLoading: Bool) -> some View {
        self
            .redacted(reason: isLoading ? .placeholder : [])
            .shimmer(isLoading)
    }

    /// Applies shimmer animation
    /// - Parameter isAnimating: Animation state
    /// - Returns: View with shimmer effect
    @ViewBuilder
    func shimmer(_ isAnimating: Bool) -> some View {
        if isAnimating {
            self.overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.white.opacity(0.3),
                            Color.clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width)
                    .offset(x: isAnimating ? geometry.size.width : -geometry.size.width)
                    .animation(
                        Animation.linear(duration: 1.5).repeatForever(autoreverses: false),
                        value: isAnimating
                    )
                }
            )
        } else {
            self
        }
    }

    /// Applies error state styling
    /// - Parameter isError: Error state
    /// - Returns: Styled view
    func errorStyle(_ isError: Bool) -> some View {
        self
            .if(isError) { view in
                view
                    .overlay(
                        RoundedRectangle(cornerRadius: UIConstants.smallCornerRadius)
                            .stroke(UIConstants.StateColors.error, lineWidth: 2)
                    )
            }
    }

    /// Hides view conditionally
    /// - Parameter hidden: Hidden state
    /// - Returns: View with conditional visibility
    @ViewBuilder
    func hidden(_ hidden: Bool) -> some View {
        if hidden {
            self.hidden()
        } else {
            self
        }
    }

    /// Applies disabled style
    /// - Parameter disabled: Disabled state
    /// - Returns: Styled view
    func disabledStyle(_ disabled: Bool) -> some View {
        self
            .disabled(disabled)
            .opacity(disabled ? 0.5 : 1.0)
    }

    /// Applies standard padding from UIConstants
    /// - Parameter type: Padding type (main, card, small)
    /// - Returns: Padded view
    func standardPadding(_ type: StandardPaddingType = .main) -> some View {
        self.padding(type.value)
    }

    /// Applies corner radius from UIConstants
    /// - Parameter type: Corner radius type
    /// - Returns: View with corner radius
    func standardCornerRadius(_ type: CornerRadiusType = .card) -> some View {
        self.cornerRadius(type.value)
    }
}

// MARK: - Supporting Types

public enum StandardPaddingType {
    case main
    case card
    case small

    var value: CGFloat {
        switch self {
        case .main: return UIConstants.mainPadding
        case .card: return UIConstants.cardPadding
        case .small: return UIConstants.smallPadding
        }
    }
}

public enum CornerRadiusType {
    case window
    case card
    case button
    case small

    var value: CGFloat {
        switch self {
        case .window: return UIConstants.windowCornerRadius
        case .card: return UIConstants.cardCornerRadius
        case .button: return UIConstants.buttonCornerRadius
        case .small: return UIConstants.smallCornerRadius
        }
    }
}

// MARK: - Color Extensions

extension Color {
    /// Creates color from hex string
    /// - Parameter hex: Hex string (e.g., "#FF0000")
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
