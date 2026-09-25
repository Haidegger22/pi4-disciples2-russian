#!/bin/bash
# 04-russianize.sh — русификация Disciples II: текст, озвучка героев, видеоролики, кампании.
#
# ИСПОЛЬЗОВАНИЕ:
#   1) Положите распакованный русский пакет в ~/d2-ru-pack (см. README, раздел «Где взять»).
#      Ожидаемая структура: ~/d2-ru-pack/app/{Globals,Interf,Scens,ScenData,Exports,Sounds,Campaign,Video,Briefing}
#   2) ЗАКРОЙТЕ ИГРУ. Скрипт сам её остановит, но лучше выйти штатно.
#   3) ./04-russianize.sh
#
# ТРИ ГЛАВНЫХ ПРАВИЛА (все проверены на практике, нарушение ломает игру):
#
#   1. ВЕРСИЯ. Наша сборка — GOG Gold 3.01. Русификатор обязан быть от версии 3.01.
#      Пакет от 2.01 несовместим: с ним игра вообще не стартует (процессов 0),
#      а если подменить файлы при запущенной игре — абракадабра шрифтов и вылеты.
#
#   2. ИГРА ДОЛЖНА БЫТЬ ЗАКРЫТА. Подмена файлов на живой игре портит игру у пользователя.
#
#   3. РЕГИСТР ИМЁН ФАЙЛОВ. Linux различает регистр, Windows — нет. Если в игре лежит
#      Sinfo.DBF, а пакет приносит Sinfo.dbf, это ДВА РАЗНЫХ файла: игра читает верхний
#      (английский), русский лежит рядом и не работает. Поэтому в конце обязательно
#      запускается 07-ru-case-fix.py, который убирает английские двойники.
set -u

PREFIX="${WINEPREFIX:-$HOME/.wine-disciples}"
GAME_DIR="$PREFIX/drive_c/Disciples2"
PKG="${PKG:-$HOME/d2-ru-pack}"
SRC="$PKG/app"
[ -d "$SRC" ] || SRC="$PKG"
BACKUP="${BACKUP:-$HOME/d2-backup-rus}"
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "=== Русификация Disciples II"
echo "    пакет: $SRC"
echo "    игра:  $GAME_DIR"
[ -d "$SRC" ] || { echo "Нет каталога пакета $SRC"; exit 1; }
[ -d "$GAME_DIR" ] || { echo "Нет каталога игры — сначала 02-install-game.sh"; exit 1; }

# --- 0. Проверка версии по заголовкам DBF -----------------------------------
# Совпали записи/размер записи — версия та же, файлы совместимы.
echo
echo "=== 0) Проверка совместимости версии (заголовки DBF)"
python3 - "$SRC" "$GAME_DIR" <<'PY'
import os, struct, sys
src, game = sys.argv[1], sys.argv[2]
def head(p):
    try:
        d = open(p, 'rb').read(32)
        return (struct.unpack('<I', d[4:8])[0], struct.unpack('<H', d[8:10])[0], struct.unpack('<H', d[10:12])[0])
    except Exception:
        return None
bad = 0
for rel in ('Globals/Gunits.dbf', 'Globals/Gaction.DBF', 'Globals/Gspells.dbf'):
    a, b = head(os.path.join(src, rel)), head(os.path.join(game, rel))
    if a and b:
        same = "СОВПАДАЕТ" if a == b else "ОТЛИЧАЕТСЯ"
        print("    %-24s пакет %-22s игра %-22s %s" % (rel, a, b, same))
        if a != b:
            bad += 1
if bad:
    print("    ВНИМАНИЕ: версии не совпадают! Пакет от другой версии игры.")
    print("    Установку лучше прервать (Ctrl+C) — иначе игра может перестать запускаться.")
else:
    print("    версия подходит — можно ставить")
PY

# --- 1. Останавливаем игру --------------------------------------------------
echo
echo "=== 1) Останавливаю игру"
pkill -f Discipl2 2>/dev/null; pkill -f wineserver 2>/dev/null; sleep 8
N=$(pgrep -c -f Discipl2 2>/dev/null || echo 0)
echo "    процессов игры: $N"
if [ "${N:-0}" != "0" ]; then
  echo "    Игра не остановилась — файлы менять нельзя. Выйдите из игры и повторите."
  exit 1
fi

# --- 2. Копии заменяемого ---------------------------------------------------
echo
echo "=== 2) Сохраняю копии в $BACKUP"
mkdir -p "$BACKUP"
for d in Globals Interf Scens ScenData Exports Sounds Music Campaign Video Briefing; do
  if [ -d "$GAME_DIR/$d" ]; then
    cp -a "$GAME_DIR/$d" "$BACKUP/" 2>/dev/null && echo "    $d ($(du -sh "$GAME_DIR/$d" | cut -f1))"
  fi
done

# --- 3. Накладываем русские файлы ------------------------------------------
# Исполняемые файлы и библиотеки НЕ копируются: в пакете они от старой сборки
# и откатят мод DisciplesGL (вернутся розовые текстуры).
echo
echo "=== 3) Накладываю файлы локализации"
SIMPLE="Globals Interf Scens ScenData Exports Sounds Campaign Video Briefing"
for d in $SIMPLE; do
  if [ -d "$SRC/$d" ]; then
    mkdir -p "$GAME_DIR/$d"
    cp -a "$SRC/$d/." "$GAME_DIR/$d/" 2>/dev/null
    echo "    $d → $(ls "$GAME_DIR/$d" 2>/dev/null | wc -l) файлов"
  fi
done
# регистр каталога: в некоторых пакетах каталог называется interf, у игры Interf
[ -d "$SRC/interf" ] && cp -a "$SRC/interf/." "$GAME_DIR/Interf/" 2>/dev/null && echo "    interf → Interf (регистр исправлен)"

echo
echo "    Не копирую (намеренно): Discipl2.exe, *.dll — они от старой сборки и вернут розовые текстуры."

# --- 4. Убираем английские двойники регистра -------------------------------
echo
echo "=== 4) Проверяю двойники имён (регистр)"
if [ -f "$HERE/07-ru-case-fix.py" ]; then
  python3 "$HERE/07-ru-case-fix.py" --apply 2>&1 | sed 's/^/    /'
else
  echo "    не найден 07-ru-case-fix.py — проверьте вручную!"
fi

# --- 5. Итог ----------------------------------------------------------------
echo
echo "=== 5) Итог"
python3 - "$GAME_DIR" <<'PY'
import os, re, sys
g = sys.argv[1]
def cyr(p):
    try:
        d = open(p, 'rb').read(400000)
    except Exception:
        return 0
    return sum(len(re.findall(r'[А-Яа-яЁё]{3,}', d.decode(e, 'ignore'))) for e in ('cp1251', 'utf-8'))
checks = [('Globals/Gunits.dbf', 'текст игры'), ('Interf/TApp.dbf', 'интерфейс и титры'),
          ('Scens/Sinfo.dbf', 'тексты истории'), ('Scens/Tscen.dbf', 'тексты сценариев')]
for rel, what in checks:
    p = os.path.join(g, rel)
    n = cyr(p) if os.path.exists(p) else -1
    state = "русский" if n > 0 else ("нет файла" if n < 0 else "Английский!?")
    print("    %-22s %-18s кириллица: %-6d %s" % (rel, what, max(n, 0), state))
# озвучка
m = os.path.join(g, 'Sounds/Midgard.wdb')
if os.path.exists(m):
    print("    %-22s %-18s %.1f МБ" % ('Sounds/Midgard.wdb', 'озвучка героев', os.path.getsize(m) / 1048576))
PY
echo
echo "Ожидаемые размеры для ориентира: Midgard.wdb ≈ 70 МБ (русская озвучка) против 18 МБ английской."
echo
echo "Готово. Запуск: ./disciples2.sh"
echo "Откат: cp -a $BACKUP/. $GAME_DIR/"
