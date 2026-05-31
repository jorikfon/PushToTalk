import SwiftUI

/// Строка с иконкой и текстом для инструкций (иконка монохромная)
struct InstructionRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: UIConstants.Spacing.md) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .font(.system(size: 16))
                .frame(width: 24)

            Text(text)
                .font(UIConstants.Typography.body)
                .foregroundColor(.primary)
        }
    }
}

/// Карточка для отображения статистики. Refined Native: значение нейтральное
/// (label), фон — нейтральная заливка с волосяной границей; параметр `color`
/// сохранён для совместимости, но декоративно не применяется.
struct StatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: UIConstants.Spacing.xs) {
            Text(value)
                .font(.system(size: 20, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(.primary)

            Text(title)
                .font(UIConstants.Typography.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(UIConstants.Spacing.md)
        .background(UIConstants.Palette.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: UIConstants.Radius.card)
                .strokeBorder(UIConstants.Palette.hairline, lineWidth: 1)
        )
    }
}
