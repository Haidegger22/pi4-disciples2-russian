#!/bin/bash
# 03-install-mod.sh — ставим мод DisciplesGL Modern: он убирает розовые (палитровые) текстуры.
#
# Зачем: игра выводит картинку через DirectDraw/Direct3D, и под Wine палитровые текстуры
# отображаются розовым. DXVK это не лечит (он про Direct3D 8+, а здесь DirectDraw).
# Мод подменяет рендер-библиотеку C4dll и розовый уходит полностью.
#
# Важно: мод ставится ДО русификации и заменяет C4dll-R.dll. Русификатор НЕ должен
# приносить свои исполняемые файлы и библиотеки — иначе мод откатится и розовый вернётся.
set -u

PREFIX="${WINEPREFIX:-$HOME/.wine-disciples}"
GAME_DIR="$PREFIX/drive_c/Disciples2"
BACKUP="${BACKUP:-$HOME/d2-backup-mod}"
MOD_URL="${MOD_URL:-https://github.com/gitTerebi/DisciplesGL-Modern/releases/download/v2026.3/DisciplesGL-Modern-C4dll-R.zip}"
TMP=$(mktemp -d)

echo "=== DisciplesGL Modern: устранение розовых текстур"
echo "    каталог игры: $GAME_DIR"
[ -d "$GAME_DIR" ] || { echo "Нет каталога игры — сначала 02-install-game.sh"; exit 1; }

echo "=== 1) Скачиваю мод"
if command -v curl >/dev/null 2>&1; then
  curl -sL -A "Mozilla/5.0" -o "$TMP/mod.zip" "$MOD_URL"
else
  wget -q -O "$TMP/mod.zip" "$MOD_URL"
fi
SZ=$(stat -c%s "$TMP/mod.zip" 2>/dev/null || echo 0)
echo "    скачано: $(( SZ / 1048576 )) МБ"
[ "$SZ" -gt 1000000 ] || { echo "Скачать не удалось (проверьте ссылку MOD_URL)"; exit 1; }

echo "=== 2) Распаковываю"
if command -v unzip >/dev/null 2>&1; then
  unzip -q -o "$TMP/mod.zip" -d "$TMP/mod"
elif command -v 7z >/dev/null 2>&1; then
  7z x -y -o"$TMP/mod" "$TMP/mod.zip" >/dev/null
else
  python3 -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$TMP/mod.zip" "$TMP/mod"
fi
echo "    файлов в архиве: $(find "$TMP/mod" -type f | wc -l)"
find "$TMP/mod" -type f -iname "*.dll" | sed 's/^/    /'

echo "=== 3) Сохраняю оригиналы в $BACKUP"
mkdir -p "$BACKUP"
for f in C4dll-R.dll C4dll.dll CB63.dll Discipl2.exe; do
  [ -f "$GAME_DIR/$f" ] && cp -a "$GAME_DIR/$f" "$BACKUP/" && echo "    сохранён $f"
done

echo "=== 4) Ставлю файлы мода"
n=0
while IFS= read -r f; do
  base=$(basename "$f")
  cp -f "$f" "$GAME_DIR/$base" && { echo "    поставлен $base ($(( $(stat -c%s "$f") / 1024 )) КБ)"; n=$((n + 1)); }
done < <(find "$TMP/mod" -type f \( -iname "*.dll" -o -iname "*.exe" -o -iname "*.ini" \))
echo "    всего файлов: $n"

rm -rf "$TMP"
echo
echo "=== 5) Проверка"
ls -la "$GAME_DIR"/*.dll 2>/dev/null | awk '{print "    " $5 " " $9}'
echo
echo "Готово. Дальше: ./04-russianize.sh (русский язык), затем ./disciples2.sh (запуск)."
echo "Откат мода: cp -a $BACKUP/. $GAME_DIR/"
