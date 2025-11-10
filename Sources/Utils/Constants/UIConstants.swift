import SwiftUI

/// UI константы
/// Централизованное хранение всех UI метрик и стилей
public enum UIConstants {
    // MARK: - Window Dimensions

    /// Параметры окон приложения
    public enum Window {
        /// Ширина окна настроек
        public static let settingsWindowWidth: CGFloat = 900

        /// Высота окна настроек
        public static let settingsWindowHeight: CGFloat = 650

        /// Минимальная ширина окна настроек
        public static let settingsWindowMinWidth: CGFloat = 800

        /// Минимальная высота окна настроек
        public static let settingsWindowMinHeight: CGFloat = 600
    }

    /// Ширина окна настроек (deprecated - используйте Window.settingsWindowWidth)
    public static let settingsWindowWidth: CGFloat = 900

    /// Высота окна настроек (deprecated - используйте Window.settingsWindowHeight)
    public static let settingsWindowHeight: CGFloat = 650

    /// Ширина боковой панели
    public static let sidebarWidth: CGFloat = 220

    // MARK: - Corner Radius

    /// Радиус скругления основного окна
    public static let windowCornerRadius: CGFloat = 20

    /// Радиус скругления карточек
    public static let cardCornerRadius: CGFloat = 12

    /// Радиус скругления кнопок
    public static let buttonCornerRadius: CGFloat = 8

    /// Радиус скругления малых элементов
    public static let smallCornerRadius: CGFloat = 6

    // MARK: - Spacing

    /// Основной внешний отступ
    public static let mainPadding: CGFloat = 20

    /// Отступ для карточек
    public static let cardPadding: CGFloat = 16

    /// Отступ для малых элементов
    public static let smallPadding: CGFloat = 12

    /// Минимальный отступ
    public static let minimumPadding: CGFloat = 8

    /// Отступ между секциями
    public static let sectionSpacing: CGFloat = 24

    /// Отступ между элементами
    public static let itemSpacing: CGFloat = 12

    /// Минимальный отступ между элементами
    public static let minimumItemSpacing: CGFloat = 8

    // MARK: - Icon Sizes

    /// Размер большой иконки
    public static let largeIconSize: CGFloat = 50

    /// Размер средней иконки
    public static let mediumIconSize: CGFloat = 30

    /// Размер маленькой иконки
    public static let smallIconSize: CGFloat = 20

    /// Размер иконки индикатора записи
    public static let recordingIndicatorSize: CGFloat = 8

    /// Размер контейнера индикатора записи
    public static let recordingIndicatorContainerSize: CGFloat = 30

    // MARK: - MenuBar

    /// Параметры menu bar
    public enum MenuBar {
        /// Размер иконки в menu bar
        public static let iconSize: CGFloat = 14

        /// Вес иконки
        public static let iconWeight: NSFont.Weight = .regular
    }

    // MARK: - Divider

    /// Толщина разделителя
    public static let dividerWidth: CGFloat = 1

    /// Высота разделителя
    public static let dividerHeight: CGFloat = 0.5

    // MARK: - Shadow

    /// Радиус тени окна
    public static let windowShadowRadius: CGFloat = 15

    /// Радиус тени карточки
    public static let cardShadowRadius: CGFloat = 8

    /// Смещение тени по оси Y
    public static let shadowOffsetY: CGFloat = 5

    /// Прозрачность тени
    public static let shadowOpacity: Double = 0.15

    // MARK: - Opacity

    /// Прозрачность overlay
    public static let overlayOpacity: Double = 0.25

    /// Прозрачность secondary overlay
    public static let secondaryOverlayOpacity: Double = 0.1

    /// Прозрачность border
    public static let borderOpacity: Double = 0.6

    /// Прозрачность secondary text
    public static let secondaryTextOpacity: Double = 0.8

    /// Прозрачность hover
    public static let hoverOpacity: Double = 0.05

    // MARK: - Font Sizes

    /// Размер шрифта заголовка
    public static let titleFontSize: CGFloat = 20

    /// Размер шрифта подзаголовка
    public static let subtitleFontSize: CGFloat = 16

    /// Размер шрифта основного текста
    public static let bodyFontSize: CGFloat = 14

    /// Размер шрифта caption
    public static let captionFontSize: CGFloat = 12

    // MARK: - Animation

    /// Длительность короткой анимации
    public static let shortAnimationDuration: Double = 0.2

    /// Длительность средней анимации
    public static let mediumAnimationDuration: Double = 0.3

    /// Длительность длинной анимации
    public static let longAnimationDuration: Double = 0.5

    // MARK: - Colors

    /// Градиенты для секций настроек
    public enum SectionColors {
        public static let debug = Color.red
        public static let general = Color.blue
        public static let models = Color.purple
        public static let hotkeys = Color.orange
        public static let vocabulary = Color.green
        public static let audio = Color.pink
        public static let history = Color.cyan
    }

    /// Градиенты для фона
    public enum GradientColors {
        public static let primaryStart = Color.white.opacity(0.25)
        public static let primaryMid = Color.white.opacity(0.1)
        public static let primaryEnd = Color.white.opacity(0.15)

        public static let borderStart = Color.white.opacity(0.6)
        public static let borderMid = Color.white.opacity(0.2)
        public static let borderEnd = Color.white.opacity(0.4)

        public static let dividerStart = Color.white.opacity(0.0)
        public static let dividerMid = Color.white.opacity(0.3)
        public static let dividerEnd = Color.white.opacity(0.0)
    }

    /// Цвета состояний
    public enum StateColors {
        public static let recording = Color.red
        public static let processing = Color.orange
        public static let ready = Color.green
        public static let error = Color.red
        public static let warning = Color.yellow
        public static let info = Color.blue
        public static let success = Color.green
    }

    // MARK: - Button Dimensions

    /// Высота стандартной кнопки
    public static let buttonHeight: CGFloat = 36

    /// Высота маленькой кнопки
    public static let smallButtonHeight: CGFloat = 28

    /// Минимальная ширина кнопки
    public static let buttonMinWidth: CGFloat = 80

    // MARK: - TextField Dimensions

    /// Высота текстового поля
    public static let textFieldHeight: CGFloat = 32

    /// Высота многострочного текстового поля
    public static let textEditorHeight: CGFloat = 80

    // MARK: - Progress Bar

    /// Высота прогресс-бара
    public static let progressBarHeight: CGFloat = 4

    /// Высота толстого прогресс-бара
    public static let thickProgressBarHeight: CGFloat = 8

    // MARK: - Recording Indicator

    /// Радиус внутреннего градиента индикатора записи
    public static let recordingIndicatorInnerRadius: CGFloat = 3

    /// Радиус внешнего градиента индикатора записи
    public static let recordingIndicatorOuterRadius: CGFloat = 15

    // MARK: - App Icon

    /// Размер иконки приложения в header
    public static let appIconSize: CGFloat = 50

    /// Размер системной иконки в header
    public static let appIconImageSize: CGFloat = 24

    // MARK: - Sidebar Items

    /// Высота элемента боковой панели
    public static let sidebarItemHeight: CGFloat = 40

    /// Отступ для элемента боковой панели
    public static let sidebarItemPadding: CGFloat = 12

    /// Отступ между элементами боковой панели
    public static let sidebarItemSpacing: CGFloat = 4

    // MARK: - Card Layout

    /// Максимальная ширина карточки
    public static let cardMaxWidth: CGFloat = 600

    /// Минимальная высота карточки
    public static let cardMinHeight: CGFloat = 100

    // MARK: - Scroll View

    /// Отступ для ScrollView
    public static let scrollViewPadding: CGFloat = 16

    // MARK: - Menu Bar

    /// Ширина иконки в menu bar
    public static let menuBarIconWidth: CGFloat = 20

    /// Высота иконки в menu bar
    public static let menuBarIconHeight: CGFloat = 16
}
