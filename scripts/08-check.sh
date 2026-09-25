#!/bin/bash
# 08-check.sh — проверка всей установки: игра, русификация, мод, звук, экраны.
# Запускать в любой момент: ничего не меняет, только показывает состояние.
set -u

PREFIX="${WINEPREFIX:-$HOME/.wine-disciples}"
G="$PREFIX/drive_c/Disciples2"

ok()   { echo "    [ок]    $*"; }
bad()  { echo "    [НЕТ]   $*"; }
warn() { echo "    [внимание] $*"; }

echo "=============================================================="
echo " Проверка Disciples II — $(date '+%d.%m.%Y %H:%M')"
echo "=============================================================="

echo
echo "=== 1) Игра на месте"
if [ -d "$G" ]; then
  ok "каталог: $G"
  echo "        файлов: $(find "$G" -type f 2>/dev/null | wc -l), размер: $(du -sh "$G" 2>/dev/null | cut -f1)"
  [ -f "$G/Discipl2.exe" ] && ok "Discipl2.exe" || bad "Discipl2.exe"
else
  bad "каталог игры не найден: $G"
fi

echo
echo "=== 2) Hangover (Wine под arm64)"
if command -v wine >/dev/null 2>&1; then
  ok "$(wine --version 2>/dev/null | head -1)"
else
  bad "wine не найден — сначала scripts/01-install-hangover.sh"
fi
if dpkg -l 2>/dev/null | grep -q hangover-wine; then
  ok "пакеты Hangover установлены"
else
  warn "пакеты hangover-* не найдены в dpkg"
fi

echo
echo "=== 3) Мод против розовых текстур (DisciplesGL)"
if [ -f "$G/C4dll-R.dll" ]; then
  ok "C4dll-R.dll на месте ($(( $(stat -c%s "$G/C4dll-R.dll") / 1024 )) КБ)"
else
  warn "C4dll-R.dll нет — возможны розовые текстуры (scripts/03-install-mod.sh)"
fi

echo
echo "=== 4) Русификация — текст"
python3 - "$G" <<'PY'
import os, re, sys
g = sys.argv[1]
def cyr(p):
    try:
        d = open(p, 'rb').read(400000)
    except Exception:
        return 0
    return sum(len(re.findall(r'[А-Яа-яЁё]{3,}', d.decode(e, 'ignore'))) for e in ('cp1251', 'utf-8'))
files = [('Globals/Gunits.dbf', 'текст юнитов'), ('Interf/TApp.dbf', 'интерфейс и титры'),
         ('Scens/Sinfo.dbf', 'истории кампаний'), ('Scens/Tscen.dbf', 'тексты сценариев'),
         ('Globals/TAiMsg.dbf', 'сообщения ИИ'), ('Globals/Tplayer.dbf', 'имена игроков')]
for rel, what in files:
    p = os.path.join(g, rel)
    if not os.path.exists(p):
        print("    [НЕТ]   %-24s %s" % (rel, what)); continue
    n = cyr(p)
    print("    [%s] %-24s %-18s кириллица: %d" % ("ок" if n > 0 else "англ", rel, what, n))
PY

echo
echo "=== 5) Русификация — озвучка и ролики"
for f in "Sounds/Midgard.wdb:озвучка героев:только у русской ~70 МБ, у английской ~18 МБ" \
         "Video/intro.bik:вступление:русское ~6,8 МБ, английское ~16 МБ" \
         "Video/credits.bik:титры:русские ~0,8 МБ"; do
  IFS=':' read -r path what note <<< "$f"
  p="$G/$path"
  if [ -f "$p" ]; then
    ok "$(printf '%-22s (%-16s) %.1f МБ — %s' "$path" "$what" "$(echo "scale=1; $(stat -c%s "$p")/1048576" | bc 2>/dev/null || echo 0)" "$note")"
  else
    bad "$path"
  fi
done
echo "        роликов историй: $(ls "$G/Briefing"/*.bik 2>/dev/null | wc -l)"
echo "        кампаний: $(ls "$G/Campaign"/*.csg 2>/dev/null | wc -l)"
echo "        файлов-описаний кампаний: $(ls "$G/Exports" 2>/dev/null | wc -l)"

echo
echo "=== 6) Двойники имён (регистр) — источник частично английского текста"
FOUND=0
python3 - "$G" <<'PY'
import os, re, sys
g = sys.argv[1]
def cyr(p):
    try:
        d = open(p, 'rb').read(400000)
    except Exception:
        return 0
    return sum(len(re.findall(r'[А-Яа-яЁё]{3,}', d.decode(e, 'ignore'))) for e in ('cp1251', 'utf-8'))
dups = 0
for root, _, files in os.walk(g):
    groups = {}
    for f in files:
        groups.setdefault(f.lower(), []).append(f)
    for low, names in groups.items():
        if len(names) > 1:
            stats = [(n, cyr(os.path.join(root, n))) for n in sorted(names)]
            if any(c > 0 for _, c in stats) and any(c == 0 for _, c in stats):
                dups += 1
                print("    [БЕДА]  %s: %s" % (os.path.relpath(root, g), ", ".join("%s(кир.%d)" % s for s in stats)))
print("    ПРОБЛЕМНЫХ ДВОЙНИКОВ: %d" % dups)
print("    Исправляется: python3 scripts/07-ru-case-fix.py --apply" if dups else "    двойников нет — всё хорошо")
PY

echo
echo "=== 7) Звук"
echo "        выход: $(pactl get-default-sink 2>/dev/null)"
echo "        громкость: $(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)"
Q=$(pw-dump 2>/dev/null | grep -o '"default.clock.quantum": [0-9]*' | head -1)
echo "        буфер: ${Q:-не прочитать}  (нужно 2048, иначе щелчки; см. 05-audio-buffer.sh)"

echo
echo "=== 8) Экраны"
xrandr --listmonitors 2>/dev/null | sed 's/^/    /'
echo "        рабочий стол: $(xdotool getdisplaygeometry 2>/dev/null)"
echo "        (игра открывается на экране в позиции 0,0 — это должен быть тот, который нужен)"

echo
echo "=== 9) Процессы"
echo "        игра: $(pgrep -c -f Discipl2 2>/dev/null || echo 0)   wine: $(pgrep -c -f wineserver 2>/dev/null || echo 0)"

echo
echo "=============================================================="
echo " Если в пунктах 4-6 всё «ок» и двойников нет — русификация полная."
echo "=============================================================="
