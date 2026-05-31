import SwiftUI

/// Универсальный компонент для карточек настроек с заголовком, иконкой и содержимым.
/// Refined Native: иконка монохромная (secondary); параметр `color` сохранён для
/// обратной совместимости с местами вызова, но цвет не применяется декоративно.
struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content

    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.md) {
            // Header: монохромная иконка + заголовок
            HStack(spacing: UIConstants.Spacing.sm) {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                    .font(.system(size: 16, weight: .medium))

                Text(title)
                    .font(UIConstants.Typography.headline)
                    .foregroundColor(.primary)
            }

            Divider()
                .overlay(UIConstants.Palette.hairline)

            // Card content
            content
        }
        .padding(UIConstants.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(UIConstants.Palette.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: UIConstants.Radius.card)
                .strokeBorder(UIConstants.Palette.hairline, lineWidth: 1)
        )
    }
}
