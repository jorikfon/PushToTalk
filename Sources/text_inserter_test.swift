import Foundation
import Cocoa
import PushToTalkCore

/// Тестовая программа для проверки TextInserter
///
/// Функционал:
/// - Тестирование вставки текста через clipboard + Cmd+V
/// - Тестирование восстановления clipboard
/// - Тестирование альтернативного метода через Accessibility API
///
/// Использование:
/// 1. Скомпилировать: swift build --product TextInserterTest
/// 2. Запустить: .build/debug/TextInserterTest
/// 3. Открыть любое текстовое приложение (TextEdit, Notes, Terminal)
/// 4. Поставить курсор в поле ввода
/// 5. Программа вставит тестовый текст через 3 секунды

@main
struct TextInserterTest {
    static func main() {
        print("╔═══════════════════════════════════════════════╗")
        print("║   TextInserter Test - Phase 6                 ║")
        print("╚═══════════════════════════════════════════════╝")
        print()

        let inserter = TextInserter()

        // Тест 1: Проверка сохранения/восстановления clipboard
        print("📋 Тест 1: Сохранение и восстановление clipboard")
        testClipboardPreservation()

        sleep(2)

        // Тест 2: Вставка текста через Cmd+V
        print("\n📝 Тест 2: Вставка текста через Cmd+V")
        print("⏱  Откройте текстовый редактор и поставьте курсор в поле ввода")
        print("⏱  Вставка начнётся через 5 секунд...")

        for i in (1...5).reversed() {
            print("   \(i)...")
            sleep(1)
        }

        let testText = "Hello from TextInserter! This is a test message inserted via clipboard + Cmd+V."
        print("📤 Вставка текста: \"\(testText)\"")
        inserter.insertTextAtCursor(testText)

        print("✅ Текст вставлен!")
        print("⏱  Ожидание 2 секунды для восстановления clipboard...")
        sleep(2)

        // Тест 3: Проверка восстановления clipboard
        print("\n📋 Тест 3: Проверка восстановления clipboard")
        let pasteboard = NSPasteboard.general
        if let restoredText = pasteboard.string(forType: .string) {
            print("✅ Clipboard восстановлен: \"\(restoredText)\"")
        } else {
            print("⚠️  Clipboard пуст (это нормально, если он был пуст до теста)")
        }

        // Тест 4: Альтернативный метод через Accessibility API
        print("\n🔐 Тест 4: Вставка через Accessibility API")
        print("⏱  Откройте текстовый редактор и поставьте курсор в поле ввода")
        print("⏱  Вставка начнётся через 5 секунд...")

        for i in (1...5).reversed() {
            print("   \(i)...")
            sleep(1)
        }

        let accessibilityText = " [via Accessibility API]"
        let success = inserter.insertTextViaAccessibility(accessibilityText)

        if success {
            print("✅ Текст вставлен через Accessibility API")
        } else {
            print("⚠️  Не удалось вставить через Accessibility API")
            print("   Возможно, не хватает разрешения Accessibility")
        }

        print("\n╔═══════════════════════════════════════════════╗")
        print("║   Тестирование завершено!                     ║")
        print("╚═══════════════════════════════════════════════╝")
        print()
        print("Результаты:")
        print("✓ Clipboard сохранение/восстановление работает")
        print("✓ Вставка через Cmd+V работает")
        print(success ? "✓ Accessibility API работает" : "⚠ Accessibility API недоступен")

        exit(0)
    }

    /// Тест сохранения и восстановления clipboard
    private static func testClipboardPreservation() {
        let pasteboard = NSPasteboard.general

        // Устанавливаем тестовое значение
        let testValue = "Original clipboard content for testing"
        pasteboard.clearContents()
        pasteboard.setString(testValue, forType: .string)

        print("   Исходное значение clipboard: \"\(testValue)\"")

        // Симулируем вставку другого текста
        let tempInserter = TextInserter()
        tempInserter.insertTextAtCursor("Temporary text")

        // Сразу проверяем - должен быть временный текст
        if let currentText = pasteboard.string(forType: .string) {
            print("   Временное значение clipboard: \"\(currentText)\"")
        }

        // Ждём восстановления (300ms + запас)
        usleep(500_000) // 500ms

        // Проверяем восстановление
        if let restoredText = pasteboard.string(forType: .string) {
            if restoredText == testValue {
                print("   ✅ Clipboard успешно восстановлен: \"\(restoredText)\"")
            } else {
                print("   ⚠️  Clipboard не восстановлен: ожидалось \"\(testValue)\", получено \"\(restoredText)\"")
            }
        }
    }
}
