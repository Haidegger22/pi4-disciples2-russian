#!/bin/bash
# 02-install-game.sh — ставим Disciples II: Gold (GOG) БЕЗ запуска установщика.
#
# Почему так: установщик GOG под эмуляцией идёт больше 45 минут и часто не доходит
# до конца (каталог получается неполным). Данные же распаковываются нативно
# программой innoextract — база за ~2 минуты, дополнение за ~2 минуты.
#
# Если у вас ДВА установщика (база «Dark Prophecy + Gallean's Return» и дополнение
# «Rise of the Elves») — распаковываем оба и объединяем: в базе есть файлы, которых
# нет в дополнении, и наоборот.
#
# Использование:
#   ./02-install-game.sh ~/d2-setup
# где ~/d2-setup — каталог с файлами setup_*.exe и setup_*-1.bin из GOG-сборки.
set -u

SETUP_DIR="${1:-$HOME/d2-setup}"
PREFIX="${WINEPREFIX:-$HOME/.wine-disciples}"
GAME_DIR="$PREFIX/drive_c/Disciples2"
WORK="${WORK:-$HOME/d2-unpack}"
USE_ADDON="${USE_ADDON:-yes}"     # no — если дополнение не нужно

echo "=== Disciples II: установка из $SETUP_DIR"
echo "    префикс Wine: $PREFIX"
echo "    каталог игры: $GAME_DIR"

if ! command -v innoextract >/dev/null 2>&1; then
  echo "Нет innoextract. Установите: sudo apt-get install -y innoextract"
  exit 1
fi

if [ ! -d "$SETUP_DIR" ]; then
  echo "Нет каталога $SETUP_DIR — положите туда файлы установщика GOG"
  exit 1
fi

mkdir -p "$WORK" "$GAME_DIR"

# --- 1. Находим установщики -------------------------------------------------
mapfile -t SETUPS < <(find "$SETUP_DIR" -maxdepth 1 -iname "setup*.exe" | sort)
if [ "${#SETUPS[@]}" -eq 0 ]; then
  echo "В $SETUP_DIR не найдено setup*.exe"
  exit 1
fi
echo "=== 1) Найдено установщиков: ${#SETUPS[@]}"
for s in "${SETUPS[@]}"; do
  echo "    $(basename "$s")  ($(( $(stat -c%s "$s") / 1048576 )) МБ)"
done

# --- 2. Распаковываем каждый ------------------------------------------------
i=0
for s in "${SETUPS[@]}"; do
  i=$((i + 1))
  OUT="$WORK/pack$i"
  if [ -d "$OUT" ] && [ -n "$(find "$OUT" -type f -print -quit 2>/dev/null)" ]; then
    echo "=== 2.$i) $OUT уже распакован, пропускаю"
    continue
  fi
  rm -rf "$OUT"; mkdir -p "$OUT"
  echo "=== 2.$i) Распаковываю $(basename "$s") (это занимает 1-3 минуты)"
  innoextract -d "$OUT" "$s" >/tmp/d2-innoextract-$i.log 2>&1
  echo "    код: $?  файлов: $(find "$OUT" -type f 2>/dev/null | wc -l)"
  tail -3 /tmp/d2-innoextract-$i.log | sed 's/^/    /'
done

# --- 3. Сводим всё в каталог игры -------------------------------------------
# Структура у разработчика — app/, у игры файлы лежат прямо в каталоге.
echo "=== 3) Собираю каталог игры"
count=0
for OUT in "$WORK"/pack*; do
  SRC="$OUT"
  [ -d "$OUT/app" ] && SRC="$OUT/app"
  if [ -d "$SRC" ]; then
    cp -a "$SRC/." "$GAME_DIR/" 2>/dev/null
    count=$((count + 1))
    echo "    наложен $(basename "$OUT") (файлов в нём: $(find "$SRC" -type f | wc -l))"
  fi
done
echo "    источников наложено: $count"

if [ -n "${USE_ADDON:-}" ] && [ "$USE_ADDON" = "no" ]; then
  echo "    (дополнение отключено флагом USE_ADDON=no)"
fi

# --- 4. Проверка ------------------------------------------------------------
echo "=== 4) Проверка результата"
for f in Discipl2.exe Globals/Gunits.dbf Interf/Interf.ff Exports; do
  if [ -e "$GAME_DIR/$f" ]; then
    echo "    есть: $f"
  else
    echo "    НЕТ:  $f"
  fi
done
echo "    всего файлов: $(find "$GAME_DIR" -type f 2>/dev/null | wc -l)"
echo "    размер: $(du -sh "$GAME_DIR" 2>/dev/null | cut -f1)"
echo
echo "Готово. Дальше: ./03-install-mod.sh (убирает розовые текстуры),"
echo "затем ./04-russianize.sh (русский текст и озвучка) и ./disciples2.sh (запуск)."
