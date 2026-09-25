#!/bin/bash
# 09-game-speed.sh — скорость боя и передвижения по карте (мод DisciplesGL).
#
# ВАЖНО, что нужно знать (проверено на живой игре):
#   1. Настройки скорости в ИГРОВОМ МЕНЮ не влияют на мод. Меню пишет в секцию
#      [Settings] BattleSpeed= (шкала 1-5), а мод читает свою секцию [Wrapper]
#      с ключами BattleSpeed= и GameSpeed=. Правка в меню записывается в файл,
#      но эффекта нет — менять надо [Wrapper].
#   2. Шкала у мода 1-20, но рабочая зона в НАЧАЛЕ диапазона: 1 — медленно,
#      а 10 и 20 — уже быстро. Разумная «середина на глаз» — 2-3 для боя.
#   3. Настройки применяются при ПЕРЕЗАПУСКЕ игры.
#   4. В игре есть хоткей смены скорости в бою — по умолчанию клавиша 7
#      (в конфиге ключ [FunktionKeys] SpeedToggle=7).
#
# Использование:
#   ./09-game-speed.sh show            — показать текущие значения
#   ./09-game-speed.sh battle 2        — скорость боя 2
#   ./09-game-speed.sh map 5           — скорость передвижения по карте 5
#   ./09-game-speed.sh both 2 5        — бой 2, карта 5
set -u

PREFIX="${WINEPREFIX:-$HOME/.wine-disciples}"
INI="$PREFIX/drive_c/Disciples2/Disciple.ini"

[ -f "$INI" ] || { echo "Нет конфига игры: $INI"; exit 1; }

show() {
  echo "=== Текущие настройки скорости ($INI):"
  awk '/^\[/{s=$0} /^BattleSpeed|^GameSpeed|^SpeedEnabled|^SpeedToggle/{gsub(/\r/,""); printf "    %-14s %s\n", s, $0}' "$INI"
  echo
  echo "    Подсказка: рабочие значения боя — 2-3 (медленнее) ... 5 (быстрее)."
  echo "    Настройка в игровом меню на мод НЕ влияет (пишет в другую секцию)."
}

setkey() {   # setkey <секция> <ключ> <значение>
  python3 - "$INI" "$1" "$2" "$3" <<'PY'
import io, re, sys
p, section, key, val = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
raw = io.open(p, "rb").read().decode("cp1251", "replace")
parts = re.split(r'(\[[^\]]+\])', raw)
out, cur = [], None
for part in parts:
    if re.fullmatch(r'\[[^\]]+\]', part):
        cur = part; out.append(part); continue
    if cur == section:
        part = re.sub(r'(?im)^(\s*%s\s*=\s*).*$' % re.escape(key), r'\g<1>' + val, part, count=1)
    out.append(part)
res = "".join(out)
res = res.replace("\r\n", "\n").replace("\n", "\r\n")   # исходник с CRLF — сохраняем так же
io.open(p, "wb").write(res.encode("cp1251", "replace"))
print("    %s %s = %s" % (section, key, val))
PY
}

case "${1:-show}" in
  show)
    show
    ;;
  battle)
    [ $# -ge 2 ] || { echo "Укажите значение: ./09-game-speed.sh battle 2"; exit 1; }
    cp -a "$INI" "$INI.bak-$(date +%H%M%S)"
    setkey "[Wrapper]" "BattleSpeed" "$2"     # читает мод
    setkey "[Settings]" "BattleSpeed" "$2"    # как в меню, для порядка
    echo "=== Стало:"; show
    echo "    Не забудьте ПЕРЕЗАПУСТИТЬ игру."
    ;;
  map)
    [ $# -ge 2 ] || { echo "Укажите значение: ./09-game-speed.sh map 5"; exit 1; }
    cp -a "$INI" "$INI.bak-$(date +%H%M%S)"
    setkey "[Wrapper]" "GameSpeed" "$2"
    echo "=== Стало:"; show
    echo "    Не забудьте ПЕРЕЗАПУСТИТЬ игру."
    ;;
  both)
    [ $# -ge 3 ] || { echo "Укажите два значения: ./09-game-speed.sh both 2 5"; exit 1; }
    cp -a "$INI" "$INI.bak-$(date +%H%M%S)"
    setkey "[Wrapper]" "BattleSpeed" "$2"
    setkey "[Settings]" "BattleSpeed" "$2"
    setkey "[Wrapper]" "GameSpeed" "$3"
    echo "=== Стало:"; show
    echo "    Не забудьте ПЕРЕЗАПУСТИТЬ игру."
    ;;
  *)
    echo "Использование:"
    echo "  ./09-game-speed.sh show           — показать текущее"
    echo "  ./09-game-speed.sh battle <1-20>  — скорость боя"
    echo "  ./09-game-speed.sh map <1-20>     — скорость карты"
    echo "  ./09-game-speed.sh both <бой> <карта>"
    exit 1
    ;;
esac
