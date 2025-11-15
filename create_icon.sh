#!/bin/bash

# Скрипт для создания .icns из PNG изображения
# Использование: ./create_icon.sh Resources/AppIcon.png

set -e

INPUT_PNG="${1:-Resources/AppIcon.png}"
ICONSET_DIR="Resources/AppIcon.iconset"
OUTPUT_ICNS="Resources/AppIcon.icns"

# Проверяем наличие исходного изображения
if [ ! -f "$INPUT_PNG" ]; then
    echo "❌ Ошибка: Файл $INPUT_PNG не найден"
    echo "Сохраните логотип как Resources/AppIcon.png"
    exit 1
fi

# Проверяем размер файла (должен быть > 1KB)
FILE_SIZE=$(stat -f%z "$INPUT_PNG")
if [ "$FILE_SIZE" -lt 1000 ]; then
    echo "❌ Ошибка: Файл $INPUT_PNG слишком маленький ($FILE_SIZE байт)"
    echo "Пожалуйста, сохраните настоящее изображение"
    exit 1
fi

echo "🎨 Создание иконки приложения из $INPUT_PNG..."

# Создаем директорию для iconset
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

# Генерируем все необходимые размеры для macOS
echo "📐 Генерация размеров иконки..."

sips -z 16 16     "$INPUT_PNG" --out "$ICONSET_DIR/icon_16x16.png" > /dev/null 2>&1
sips -z 32 32     "$INPUT_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" > /dev/null 2>&1
sips -z 32 32     "$INPUT_PNG" --out "$ICONSET_DIR/icon_32x32.png" > /dev/null 2>&1
sips -z 64 64     "$INPUT_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" > /dev/null 2>&1
sips -z 128 128   "$INPUT_PNG" --out "$ICONSET_DIR/icon_128x128.png" > /dev/null 2>&1
sips -z 256 256   "$INPUT_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null 2>&1
sips -z 256 256   "$INPUT_PNG" --out "$ICONSET_DIR/icon_256x256.png" > /dev/null 2>&1
sips -z 512 512   "$INPUT_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null 2>&1
sips -z 512 512   "$INPUT_PNG" --out "$ICONSET_DIR/icon_512x512.png" > /dev/null 2>&1
sips -z 1024 1024 "$INPUT_PNG" --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null 2>&1

# Конвертируем iconset в .icns
echo "🔄 Конвертация в .icns формат..."
iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICNS"

# Удаляем временную директорию
rm -rf "$ICONSET_DIR"

echo "✅ Иконка создана: $OUTPUT_ICNS"
echo ""
echo "Запустите ./build_app.sh для пересборки приложения с новой иконкой"
