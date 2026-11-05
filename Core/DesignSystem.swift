import SwiftUI

/// A deliberately small palette. Two inks and one accent, so the practice
/// screen has almost nothing competing with the word itself.
enum DS {

    // Warm off-white rather than pure white: this app gets used at breakfast
    // and at bedtime, and 100% white at 11pm is hostile.
    static let bg = Color(red: 0.98, green: 0.97, blue: 0.95)
    static let card = Color.white
    static let ink = Color(red: 0.11, green: 0.12, blue: 0.13)
    static let inkMuted = Color(red: 0.42, green: 0.42, blue: 0.44)
    static let hairline = Color(red: 0.89, green: 0.87, blue: 0.84)

    // Deep teal. Reads as clinical without reading as hospital.
    static let accent = Color(red: 0.07, green: 0.42, blue: 0.40)
    static let accentSoft = Color(red: 0.90, green: 0.95, blue: 0.94)

    static let good = Color(red: 0.16, green: 0.55, blue: 0.36)
    static let goodSoft = Color(red: 0.90, green: 0.96, blue: 0.92)

    static let close = Color(red: 0.85, green: 0.60, blue: 0.14)
    static let closeSoft = Color(red: 0.99, green: 0.96, blue: 0.89)

    static let miss = Color(red: 0.72, green: 0.28, blue: 0.24)
    static let missSoft = Color(red: 0.98, green: 0.92, blue: 0.91)

    static func color(for result: AttemptResult) -> Color {
        switch result {
        case .correct: return good
        case .close: return close
        case .missed: return miss
        }
    }

    static func soft(for result: AttemptResult) -> Color {
        switch result {
        case .correct: return goodSoft
        case .close: return closeSoft
        case .missed: return missSoft
        }
    }
}

/// The one card style used everywhere.
struct CardBackground: ViewModifier {
    var padding: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(DS.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(DS.hairline, lineWidth: 1)
            )
    }
}

extension View {
    func card(padding: CGFloat = 18) -> some View {
        modifier(CardBackground(padding: padding))
    }
}

/// Full-width primary button. Sized for a parent holding a phone in one hand
/// while a child is on their lap.
struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = DS.accent
    var foreground: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(tint)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(DS.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(DS.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(DS.inkMuted)
            .textCase(.uppercase)
            .kerning(0.6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
